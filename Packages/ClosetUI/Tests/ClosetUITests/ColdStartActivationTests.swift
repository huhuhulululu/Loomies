import Testing
import SwiftData
import Foundation
@testable import ClosetUI
import ClosetModel
import ClosetCore

/// D91（缺口 #14）：冷启动激活面接线证据。
/// 服务层算得对不算数——要证明它接在**用户真正看到的那块**上，
/// 且随入库即时变化（DESIGN §475「即时兑现」）。
@MainActor
struct ColdStartActivationTests {

    func makeContext() throws -> (ModelContext, Wardrobe) {
        let ctx = try ModelContext(ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        try ctx.save()
        return (ctx, w)
    }

    @discardableResult
    func add(_ name: String, _ slot: String, to w: Wardrobe, in ctx: ModelContext) -> Item {
        let i = Item(name: name); i.slotRaw = slot; i.wardrobe = w
        i.statusRaw = "available"; i.occasionsRaw = ["work"]
        ctx.insert(i)
        return i
    }

    /// 空衣柜：进度不是 0（预赋 20%），但里程碑一条都不得声称兑现。
    @Test func emptyClosetShowsEndowedProgressAndNoClaims() throws {
        let (ctx, w) = try makeContext()
        let candidates = (w.items ?? []).map { $0.toCandidateItem() }
        #expect(ActivationProgress.fraction(itemCount: 0, onboarded: true) == 0.2)
        let m = try #require(ActivationProgress.headlineMilestone(items: candidates))
        #expect(!m.canDressOnce)
        #expect(!m.headline.localizedCaseInsensitiveContains("ready"))
        _ = ctx
    }

    /// 入库到能穿一次 → 里程碑当场兑现（不是等下次冷启动才更新）。
    @Test func milestoneFlipsAsSoonAsAnOutfitIsPossible() throws {
        let (ctx, w) = try makeContext()
        add("Tee", "top", to: w, in: ctx)
        add("Jeans", "bottom", to: w, in: ctx)
        try ctx.save()
        var candidates = (w.items ?? []).map { $0.toCandidateItem() }
        #expect(ActivationProgress.headlineMilestone(items: candidates)?.canDressOnce == false)

        add("Boots", "shoes", to: w, in: ctx)
        try ctx.save()
        candidates = (w.items ?? []).map { $0.toCandidateItem() }
        let after = try #require(ActivationProgress.headlineMilestone(items: candidates))
        #expect(after.canDressOnce)
        #expect(after.distinctLooks == 1)
    }

    /// 冷启动横幅只在冷启动期出现——过了门槛就不该继续占着首屏。
    @Test func bannerBelongsToColdStartOnly() throws {
        let (ctx, w) = try makeContext()
        for i in 0..<10 { add("Piece \(i)", "top", to: w, in: ctx) }
        try ctx.save()
        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 70)
        #expect(!vm.isColdStart)
    }

    /// 进度随入库单调上升，且真实衣柜里不会倒退。
    @Test func progressGrowsWithEveryPiece() throws {
        let (ctx, w) = try makeContext()
        var last = ActivationProgress.fraction(itemCount: 0, onboarded: true)
        for i in 0..<6 {
            add("Piece \(i)", "top", to: w, in: ctx)
            try ctx.save()
            let now = ActivationProgress.fraction(
                itemCount: (w.items ?? []).count, onboarded: true)
            #expect(now > last)
            last = now
        }
    }

    /// 双路径文案存在且不含未兑现承诺（真实起步那条要给具体动作）。
    @Test func coldStartCopyOffersBothPaths() {
        #expect(CopilotColdStartCopy.realStartTitle.contains("30"))
        #expect(!CopilotColdStartCopy.realStartTitle.localizedCaseInsensitiveContains("try-on"))
        // 按钮开的是选择器，不是相机——文案不得说「拍」（D98）
        #expect(!CopilotColdStartCopy.realStartTitle.localizedCaseInsensitiveContains("shoot"))
        #expect(!CopilotColdStartCopy.realStartTitle.localizedCaseInsensitiveContains("camera"))
        #expect(DemoSeedService.loadButtonAccessibilityHint
            .localizedCaseInsensitiveContains("sample")
            || DemoSeedService.loadButtonAccessibilityHint
            .localizedCaseInsensitiveContains("demo"))
    }
}

/// D98：**首启必须落在冷启动面上**。此前 onboarding 完成时自动播种 9 件 demo，
/// 而冷启动阈值是 8——于是预赋进度、里程碑、真实起步按钮在真实首启路径上
/// 永远不渲染，DESIGN §475 的「双路径」被替用户决定成了 demo。
/// 这道门若早在，D91 那一波就不会漏。
@MainActor
struct FirstRunLandsInColdStartTests {

    func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    /// 走完 onboarding → 衣柜是空的 → Today 处于冷启动（横幅会渲染）。
    @Test func finishingOnboardingLeavesAnEmptyClosetInColdStart() throws {
        let ctx = try makeContext()
        let vm = OnboardingViewModel()
        vm.displayName = "Ada"; vm.city = "Austin"
        #expect(vm.finish(in: ctx))
        let w = try #require(vm.wardrobe)
        #expect((w.items ?? []).isEmpty, "onboarding 不得替用户决定用 demo 起步")
        let today = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 70)
        #expect(today.isColdStart, "首启必须落在冷启动面上，否则整个激活面不可达")
    }

    /// demo 是**用户选的**那条路径：点了才有，且点完就不再是冷启动。
    @Test func demoIsAChoiceNotADefault() throws {
        let ctx = try makeContext()
        let vm = OnboardingViewModel()
        vm.displayName = "Ada"; vm.city = "Austin"
        #expect(vm.finish(in: ctx))
        let w = try #require(vm.wardrobe)

        let outcome = DemoSeedService.seed(w, in: ctx)
        if case .added = outcome {} else { Issue.record("demo 播种失败：\(outcome)") }
        let after = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 70)
        #expect(!after.isColdStart)
    }

    /// 横幅显示区间（1-7 件）里 demo 按钮不得是死键——
    /// `seedIfEmpty` 对非空衣柜是 no-op，那个区间点了什么都不会发生。
    @Test func demoButtonStillWorksWithAFewPiecesAlreadyIn() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let i = Item(name: "Tee"); i.slotRaw = "top"; i.wardrobe = w
        i.statusRaw = "available"; ctx.insert(i)
        try ctx.save()
        let before = (w.items ?? []).count
        #expect(CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 70).isColdStart)

        // 横幅用的必须是 seed 而不是 seedIfEmpty
        let outcome = DemoSeedService.seed(w, in: ctx)
        if case .added = outcome {} else { Issue.record("非空衣柜下 demo 应仍能加件") }
        #expect((w.items ?? []).count > before)
        // seedIfEmpty 在此就是死键——记录这个差别，防有人改回去
        #expect(DemoSeedService.seedIfEmpty(w, in: ctx) == .alreadyPopulated)
    }

    /// 进度、里程碑、冷启动门必须读**同一个集合**：
    /// 7 件可用 + 15 件在洗，不得出现「100% ready」与「还在冷启动」同屏。
    @Test func progressAndGateReadTheSameItemSet() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        for i in 0..<7 {
            let it = Item(name: "Ready \(i)"); it.slotRaw = "top"; it.wardrobe = w
            it.statusRaw = "available"; ctx.insert(it)
        }
        for i in 0..<15 {
            let it = Item(name: "Wash \(i)"); it.slotRaw = "top"; it.wardrobe = w
            it.statusRaw = "inWash"; ctx.insert(it)
        }
        try ctx.save()
        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 70)
        #expect(vm.isColdStart)                       // 可用件 7 < 8
        #expect(vm.availableItems.count == 7)
        // 横幅读 availableItems：进度不得因为一堆在洗件而显示「ready」
        let fraction = ActivationProgress.fraction(
            itemCount: vm.availableItems.count, onboarded: true)
        #expect(fraction < 1)
        #expect(!ActivationProgress.caption(itemCount: vm.availableItems.count, onboarded: true)
            .localizedCaseInsensitiveContains("ready"))
    }
}
