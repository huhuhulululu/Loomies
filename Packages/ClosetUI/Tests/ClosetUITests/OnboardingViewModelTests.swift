import Testing
import SwiftData
import Foundation
@testable import ClosetUI
@testable import ClosetModel // for ModelSave.forceFailure test hook
import ClosetCore

@MainActor
struct OnboardingViewModelTests {

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    @Test func cannotFinishWithoutNameAndCity() {
        let vm = OnboardingViewModel()
        #expect(!vm.canFinish)
        vm.displayName = "Alex"
        #expect(!vm.canFinish)
        vm.city = "New York"
        #expect(vm.canFinish)
    }

    @Test func finishCreatesPersonAndWardrobe() throws {
        let ctx = try makeContext()
        let vm = OnboardingViewModel()
        vm.displayName = "Alex"
        vm.city = "New York"
        #expect(vm.finish(in: ctx))
        #expect(vm.completed)
        #expect(vm.message.isEmpty) // success: no error flash
        #expect(vm.person?.name == "Alex")
        #expect(vm.wardrobe?.locationCity == "New York")
        #expect(vm.wardrobe?.owner?.id == vm.person?.id)
        #expect(vm.bodyProfile == nil)
        #expect(!vm.bodyShapeReady)
        // ModelSave commit: fetch proves not silent try?
        let people = try ctx.fetch(FetchDescriptor<Person>())
        #expect(people.contains { $0.name == "Alex" })
    }

    /// D98：只卡城市（姓名不再是闸门），提示词也要跟着只提城市。
    @Test func finishWithoutCitySurfacesHonestMessage() throws {
        let ctx = try makeContext()
        let vm = OnboardingViewModel()
        #expect(!vm.finish(in: ctx))
        #expect(!vm.completed)
        #expect(vm.message == OnboardingViewModel.needNameAndCityMessage)
        #expect(vm.message.localizedCaseInsensitiveContains("city"))
        // 不得再让用户以为姓名是必填
        #expect(!vm.message.localizedCaseInsensitiveContains("name"))
        #expect(try ctx.fetch(FetchDescriptor<Person>()).isEmpty)
        // Save-fail toast is customer-facing + paints as failure (Welcome screen orange).
        #expect(OnboardingViewModel.saveFailedMessage
            .localizedCaseInsensitiveContains("couldn't finish"))
        #expect(OnboardingViewModel.saveFailedMessage
            .localizedCaseInsensitiveContains("try again"))
        #expect(CustomerFlashStyle.isFailure(OnboardingViewModel.saveFailedMessage))
        #expect(!CustomerFlashStyle.isFailure(OnboardingViewModel.needNameAndCityMessage))
        #expect(OnboardingViewModel.saveFailedMessage != OnboardingViewModel.needNameAndCityMessage)
    }


    /// Onboarding save 失败不得残留 person/wardrobe/profile 幻影与脏标记。
    @Test func finishSaveFailureLeavesNoDirtyState() throws {
        let ctx = try makeContext()
        let (consent, cdefaults, csuite) = grantedConsent()
        defer { cdefaults.removePersistentDomain(forName: csuite) }
        let vm = OnboardingViewModel(bodyDataConsent: consent)
        vm.displayName = "Alex"; vm.city = "NYC"
        vm.popularShapePick = .pear
        ModelSave.forceFailure(on: ctx)
        #expect(!vm.finish(in: ctx))
        #expect(!vm.completed)
        #expect(vm.message == OnboardingViewModel.saveFailedMessage)
        #expect(!ctx.hasChanges)
        #expect(try ctx.fetch(FetchDescriptor<Person>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<Wardrobe>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<PersonBodyProfile>()).isEmpty)
        // 清除故障后重试成功
        ModelSave.clearForcedFailure(on: ctx)
        #expect(vm.finish(in: ctx))
    }

    /// 独立 suite 的已授权同意门（既有用例都在测「带围度能落库」，需先授权）。
    func grantedConsent() -> (BodyDataConsent, UserDefaults, String) {
        let suite = "body-consent-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let consent = BodyDataConsent(defaults: defaults)
        consent.setGranted(true)
        return (consent, defaults, suite)
    }

    /// D86：身体维度需单独同意（DESIGN §2.2）。门在**任何 insert 之前**——
    /// insert 之后 return false 会留 pending insert + 关系幻影污染下一次 save。
    @Test func bodyMeasuresRequireConsentAndLeaveNoDirtyState() throws {
        let ctx = try makeContext()
        let suite = "body-consent-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let consent = BodyDataConsent(defaults: defaults)
        #expect(!consent.isGranted)   // 默认未同意

        let vm = OnboardingViewModel(bodyDataConsent: consent)
        vm.displayName = "Alex"; vm.city = "NYC"
        vm.popularShapePick = .pear
        #expect(!vm.finish(in: ctx))
        #expect(vm.message == BodyDataConsent.requiredMessage)
        // 关键：一个 insert 都没发生
        #expect(!ctx.hasChanges)
        #expect(try ctx.fetch(FetchDescriptor<Person>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<PersonBodyProfile>()).isEmpty)

        // 授权后同一 VM 可完成
        consent.setGranted(true)
        #expect(vm.finish(in: ctx))
        #expect(vm.bodyProfile?.popularShapeOverrideRaw == PopularShape.pear.rawValue)
    }

    /// D98 改口径：**纯 name+city**（不碰任何身体输入）不受同意门影响；
    /// 体型快选属于身体数据，与 Me → Body 同样过门（见 OnboardingBodyHonestyTests）。
    @Test func finishWithoutAnyBodyInputNeedsNoConsent() throws {
        let ctx = try makeContext()
        let suite = "body-consent-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = OnboardingViewModel(bodyDataConsent: BodyDataConsent(defaults: defaults))
        vm.displayName = "Alex"; vm.city = "NYC"
        #expect(vm.finish(in: ctx))
        #expect(vm.bodyProfile == nil)   // 没碰身体输入 → 不建身体档案
    }


    /// U3: double finish (double-tap / re-entry) must not duplicate Person/Wardrobe.
    @Test func finishTwiceIsIdempotent() throws {
        let ctx = try makeContext()
        let vm = OnboardingViewModel()
        vm.displayName = "Alex"; vm.city = "New York"
        #expect(vm.finish(in: ctx))
        #expect(vm.finish(in: ctx))  // second call: early return true, no inserts
        #expect(vm.completed)
        #expect(vm.message.isEmpty)
        let people = try ctx.fetch(FetchDescriptor<Person>())
        #expect(people.count == 1)
        #expect(people.first?.name == "Alex")
        let wardrobes = try ctx.fetch(FetchDescriptor<Wardrobe>())
        #expect(wardrobes.count == 1)
    }


    @Test func finishWithVisualPickOnly() throws {
        let ctx = try makeContext()
        let (consent, cdefaults, csuite) = grantedConsent()
        defer { cdefaults.removePersistentDomain(forName: csuite) }
        let vm = OnboardingViewModel(bodyDataConsent: consent)
        vm.displayName = "Alex"; vm.city = "NYC"
        vm.popularShapePick = .pear
        #expect(vm.finish(in: ctx))
        #expect(vm.bodyProfile != nil)
        #expect(!vm.bodyShapeReady)
        #expect(vm.hasBodyReference)
        #expect(vm.bodyProfile?.popularShapeOverrideRaw == PopularShape.pear.rawValue)
        #expect(vm.bodyShape == .triangle)
    }
}

/// D88：Me → Body measurements 的同意门此前是**装饰性**的——未同意时只在 Form 顶部
/// 多一张说明卡，其后的四围输入、Save、精调滑杆（onChange 即落库）全部无条件可用，
/// `save/saveFineTune/selectPopularShape` 也全无 consent 判定。于是从未点过
/// 「Use my measurements」的用户照样能把四围存进库；而代码注释写着「未同意时不直接进录入面」。
/// Onboarding 那条路径门是对的，这条**主录入入口**没有。
@MainActor
struct BodyProfileConsentGateTests {

    func isolatedConsent(granted: Bool) -> BodyDataConsent {
        let suite = UserDefaults(suiteName: "bodygate-\(UUID().uuidString)")!
        let consent = BodyDataConsent(defaults: suite)
        consent.setGranted(granted)
        return consent
    }

    func makeContext() throws -> ModelContext {
        try ModelContext(ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    /// 未同意 → 不落库、不留脏、给诚实提示（保存原子性：insert 之前就拦）。
    @Test func measuresRefusedWithoutConsentAndLeaveNoDirtyState() throws {
        let ctx = try makeContext()
        let vm = BodyProfileViewModel(
            personID: UUID(), bodyDataConsent: isolatedConsent(granted: false))
        vm.bustInches = 34; vm.waistInches = 27; vm.hipInches = 37
        vm.save(in: ctx)
        #expect(vm.message == BodyDataConsent.requiredMessage)
        #expect(try ctx.fetch(FetchDescriptor<PersonBodyProfile>()).isEmpty)
        #expect(!ctx.hasChanges)
    }

    /// 精调滑杆是 onChange 即落库的路径，同样必须被门拦住。
    @Test func fineTuneRefusedWithoutConsent() throws {
        let ctx = try makeContext()
        let vm = BodyProfileViewModel(
            personID: UUID(), bodyDataConsent: isolatedConsent(granted: false))
        vm.fineWaist = 0.95
        vm.saveFineTune(in: ctx)
        #expect(vm.message == BodyDataConsent.requiredMessage)
        #expect(try ctx.fetch(FetchDescriptor<PersonBodyProfile>()).isEmpty)
        #expect(!ctx.hasChanges)
    }

    /// 快选体型也写 PersonBodyProfile（同属身体数据），同样过门。
    @Test func popularShapePickRefusedWithoutConsent() throws {
        let ctx = try makeContext()
        let vm = BodyProfileViewModel(
            personID: UUID(), bodyDataConsent: isolatedConsent(granted: false))
        vm.selectPopularShape(.pear, in: ctx)
        #expect(vm.message == BodyDataConsent.requiredMessage)
        #expect(try ctx.fetch(FetchDescriptor<PersonBodyProfile>()).isEmpty)
        #expect(!ctx.hasChanges)
    }

    /// 同意后照常工作（门不是把功能锁死）。
    @Test func consentGrantedLetsMeasuresThrough() throws {
        let ctx = try makeContext()
        let vm = BodyProfileViewModel(
            personID: UUID(), bodyDataConsent: isolatedConsent(granted: true))
        vm.bustInches = 34; vm.waistInches = 27; vm.hipInches = 37
        vm.save(in: ctx)
        #expect(vm.message != BodyDataConsent.requiredMessage)
        #expect(try ctx.fetch(FetchDescriptor<PersonBodyProfile>()).count == 1)
    }

    /// 展示用底座（性别/表型）不是身体测量数据，但它也写同一张 PersonBodyProfile 行——
    /// 未同意就不该建这行。否则「没同意却建了身体档案」在数据层照样成立。
    @Test func presentationPickersAlsoRespectTheGate() throws {
        let ctx = try makeContext()
        let vm = BodyProfileViewModel(
            personID: UUID(), bodyDataConsent: isolatedConsent(granted: false))
        vm.selectBodySex(.male, in: ctx)
        vm.selectBodyPhenotype(.african, in: ctx)
        #expect(try ctx.fetch(FetchDescriptor<PersonBodyProfile>()).isEmpty)
        #expect(!ctx.hasChanges)
    }
}

/// D98：onboarding 的两处结构性不诚实（对抗审计发现）。
/// 1. 四个身体维度字段在 OnboardingScreen 上**零绑定**——用户填不了，
///    于是同意门那条分支从用户的手指永远走不到，而 `has_body_complete`
///    这个漏斗指标结构性恒为 false：一个永远不可能为真的指标，
///    偏偏出现在「漏斗度量」这个缺口里。
/// 2. 体型快选（onboarding 里**唯一**真能填的身体输入）不过同意门，
///    而 Me → Body 里同一个动作会被拒——两套行为，各自都有测试护着。
@MainActor
struct OnboardingBodyHonestyTests {

    func isolatedConsent(granted: Bool) -> BodyDataConsent {
        let suite = UserDefaults(suiteName: "onb-body-\(UUID().uuidString)")!
        let c = BodyDataConsent(defaults: suite)
        c.setGranted(granted)
        return c
    }

    func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    /// 体型快选是身体数据——未同意时不得落库（与 Me → Body 同一口径）。
    @Test func bodyQuickPickRespectsConsentLikeTheMeTab() throws {
        let ctx = try makeContext()
        let vm = OnboardingViewModel(bodyDataConsent: isolatedConsent(granted: false))
        vm.displayName = "Ada"; vm.city = "Austin"
        vm.popularShapePick = .pear
        #expect(!vm.finish(in: ctx))
        #expect(vm.message == BodyDataConsent.requiredMessage)
        // 同意门必须在**任何 insert 之前**——不得留下 pending 行
        #expect(try ctx.fetch(FetchDescriptor<PersonBodyProfile>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<Person>()).isEmpty)
        #expect(!ctx.hasChanges)
    }

    /// 同意后快选照常落库（门不是把功能锁死）。
    @Test func quickPickWorksOnceConsented() throws {
        let ctx = try makeContext()
        let vm = OnboardingViewModel(bodyDataConsent: isolatedConsent(granted: true))
        vm.displayName = "Ada"; vm.city = "Austin"
        vm.popularShapePick = .pear
        #expect(vm.finish(in: ctx))
        #expect(try ctx.fetch(FetchDescriptor<PersonBodyProfile>()).count == 1)
    }

    /// 不选体型就不建身体档案（没同意也能顺利走完 onboarding）。
    @Test func skippingBodyNeedsNoConsent() throws {
        let ctx = try makeContext()
        let vm = OnboardingViewModel(bodyDataConsent: isolatedConsent(granted: false))
        vm.displayName = "Ada"; vm.city = "Austin"
        #expect(vm.finish(in: ctx))
        #expect(try ctx.fetch(FetchDescriptor<PersonBodyProfile>()).isEmpty)
    }
}

/// D98 尾项：姓名不该硬卡激活。DESIGN §474 点名的个性化三题是
/// 场合构成 / 城市 / 可跳过的身体维度——**姓名不在其中**，它也不个性化任何东西
/// （只是 Me 里的一个显示标签），却和城市一起当着激活的闸门。
/// 城市要留着卡（它喂天气这个真下游），姓名放开。
@MainActor
struct OnboardingNameIsOptionalTests {

    func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    @Test func cityAloneIsEnoughToFinish() throws {
        let ctx = try makeContext()
        let vm = OnboardingViewModel()
        vm.city = "Austin"
        #expect(vm.canFinish)
        #expect(vm.finish(in: ctx))
        let person = try #require(try ctx.fetch(FetchDescriptor<Person>()).first)
        // 空名不得落成空白显示——用一个可读的占位，用户随时能在 Me 改
        #expect(!person.name.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    /// 城市仍是必答——它喂天气（真下游），不是装饰。
    @Test func cityIsStillRequired() throws {
        let ctx = try makeContext()
        let vm = OnboardingViewModel()
        vm.displayName = "Ada"
        #expect(!vm.canFinish)
        #expect(!vm.finish(in: ctx))
        #expect(try ctx.fetch(FetchDescriptor<Person>()).isEmpty)
    }

    /// 填了名字照常用它。
    @Test func providedNameIsKept() throws {
        let ctx = try makeContext()
        let vm = OnboardingViewModel()
        vm.displayName = "  Ada  "; vm.city = "Austin"
        #expect(vm.finish(in: ctx))
        #expect(try ctx.fetch(FetchDescriptor<Person>()).first?.name == "Ada")
    }
}

/// D101（新一轮审计 HIGH）：D98 把 onboarding 体型快选接进了同意门，
/// **却没在那个屏上加任何同意控件**——选择器摆在那里、看起来可选，
/// 选完点继续必被拒，而用户在 onboarding 里没有任何办法授权。
/// 门必须与它守的那个控件同屏出现。
@MainActor
struct OnboardingConsentAffordanceTests {

    func isolated(granted: Bool) -> BodyDataConsent {
        let suite = UserDefaults(suiteName: "onb-aff-\(UUID().uuidString)")!
        let c = BodyDataConsent(defaults: suite)
        c.setGranted(granted)
        return c
    }

    func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    /// VM 必须暴露「当前是否已授权」与「就地授权」，否则那个屏无从渲染同意控件。
    @Test func viewModelExposesConsentStateAndGrant() throws {
        let vm = OnboardingViewModel(bodyDataConsent: isolated(granted: false))
        #expect(!vm.hasBodyDataConsent)
        vm.grantBodyDataConsent()
        #expect(vm.hasBodyDataConsent)
    }

    /// 就地授权之后，同一个 VM 能把体型选择走完（此前是死路）。
    @Test func grantingInPlaceUnblocksTheQuickPick() throws {
        let ctx = try makeContext()
        let vm = OnboardingViewModel(bodyDataConsent: isolated(granted: false))
        vm.city = "Austin"
        vm.popularShapePick = .pear
        #expect(!vm.finish(in: ctx))                  // 未授权：被拒
        #expect(vm.message == BodyDataConsent.requiredMessage)
        vm.grantBodyDataConsent()
        #expect(vm.finish(in: ctx))                   // 授权后走得通
        #expect(try ctx.fetch(FetchDescriptor<PersonBodyProfile>()).count == 1)
    }

    /// 撤回授权后选择也要跟着清掉——不得留一个「已选但存不了」的悬空状态。
    @Test func revokingConsentClearsThePick() throws {
        let vm = OnboardingViewModel(bodyDataConsent: isolated(granted: true))
        vm.popularShapePick = .apple
        vm.revokeBodyDataConsent()
        #expect(!vm.hasBodyDataConsent)
        #expect(vm.popularShapePick == nil)
    }

    /// onboarding 屏必须真的渲染同意控件（结构门：D98 漏的正是这一步）。
    @Test func onboardingScreenRendersAConsentControl() throws {
        let shell = WiringLintTests.productionSources().first {
            $0.path.contains("/app-shell/") && $0.lastPathComponent == "ClosetApp.swift"
        }
        let text = try String(contentsOf: try #require(shell), encoding: .utf8)
        #expect(text.contains("hasBodyDataConsent"),
                "体型选择器与它的同意门必须同屏——否则那个控件永远拒绝")
        #expect(text.contains("grantBodyDataConsent"))
    }
}
