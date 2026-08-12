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

    @Test func finishWithoutNameAndCitySurfacesHonestMessage() throws {
        let ctx = try makeContext()
        let vm = OnboardingViewModel()
        #expect(!vm.finish(in: ctx))
        #expect(!vm.completed)
        #expect(vm.message == OnboardingViewModel.needNameAndCityMessage)
        #expect(vm.message.localizedCaseInsensitiveContains("name"))
        #expect(vm.message.localizedCaseInsensitiveContains("city"))
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

    /// 脏输入即缺失：非正/非有限围度不落库（否则 isComplete 判齐、UI 宣称 Measured，
    /// FFIT 却静默兜底假体型）；合法值经 clamp 落库。
    @Test func finishDropsNonPositiveMeasuresAndClampsValid() throws {
        let ctx = try makeContext()
        let (consent, cdefaults, csuite) = grantedConsent()
        defer { cdefaults.removePersistentDomain(forName: csuite) }
        let vm = OnboardingViewModel(bodyDataConsent: consent)
        vm.displayName = "Alex"; vm.city = "NYC"
        vm.bustInches = 0; vm.waistInches = -5
        vm.hipInches = .nan; vm.highHipInches = 38
        #expect(vm.finish(in: ctx))
        let p = vm.bodyProfile
        #expect(p?.bustInches == nil)
        #expect(p?.waistInches == nil)
        #expect(p?.hipInches == nil)
        #expect(p?.highHipInches == 38)
        #expect(!vm.bodyShapeReady)
    }

    /// Onboarding save 失败不得残留 person/wardrobe/profile 幻影与脏标记。
    @Test func finishSaveFailureLeavesNoDirtyState() throws {
        let ctx = try makeContext()
        let (consent, cdefaults, csuite) = grantedConsent()
        defer { cdefaults.removePersistentDomain(forName: csuite) }
        let vm = OnboardingViewModel(bodyDataConsent: consent)
        vm.displayName = "Alex"; vm.city = "NYC"
        vm.bustInches = 36; vm.waistInches = 28; vm.hipInches = 38; vm.highHipInches = 34
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
        vm.bustInches = 36
        #expect(!vm.finish(in: ctx))
        #expect(vm.message == BodyDataConsent.requiredMessage)
        // 关键：一个 insert 都没发生
        #expect(!ctx.hasChanges)
        #expect(try ctx.fetch(FetchDescriptor<Person>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<PersonBodyProfile>()).isEmpty)

        // 授权后同一 VM 可完成
        consent.setGranted(true)
        #expect(vm.finish(in: ctx))
        #expect(vm.bodyProfile?.bustInches == 36)
    }

    /// 无围度（仅体型快选/纯 name+city）不受同意门影响——不给用户设无谓路障。
    @Test func finishWithoutMeasuresNeedsNoConsent() throws {
        let ctx = try makeContext()
        let suite = "body-consent-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = OnboardingViewModel(bodyDataConsent: BodyDataConsent(defaults: defaults))
        vm.displayName = "Alex"; vm.city = "NYC"
        vm.popularShapePick = .pear
        #expect(vm.finish(in: ctx))
        #expect(vm.bodyProfile != nil)
        #expect(vm.bodyProfile?.bustInches == nil)
    }

    @Test func finishWithPartialBodyStillNoFFIT() throws {
        let ctx = try makeContext()
        let (consent, cdefaults, csuite) = grantedConsent()
        defer { cdefaults.removePersistentDomain(forName: csuite) }
        let vm = OnboardingViewModel(bodyDataConsent: consent)
        vm.displayName = "Alex"; vm.city = "NYC"
        vm.bustInches = 36; vm.waistInches = 28  // incomplete
        #expect(vm.finish(in: ctx))
        #expect(vm.bodyProfile != nil)
        #expect(!vm.bodyShapeReady)
        #expect(vm.bodyShape == nil)
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

    @Test func finishWithFullBodyActivatesFFIT() throws {
        let ctx = try makeContext()
        let (consent, cdefaults, csuite) = grantedConsent()
        defer { cdefaults.removePersistentDomain(forName: csuite) }
        let vm = OnboardingViewModel(bodyDataConsent: consent)
        vm.displayName = "Alex"; vm.city = "NYC"
        vm.bustInches = 36; vm.waistInches = 26
        vm.hipInches = 36; vm.highHipInches = 34
        #expect(vm.finish(in: ctx))
        #expect(vm.bodyShapeReady)
        #expect(vm.bodyShape != nil)
    }

    @Test func finishWithVisualPickOnly() throws {
        let ctx = try makeContext()
        let vm = OnboardingViewModel()
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
