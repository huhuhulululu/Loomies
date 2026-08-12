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
        #expect(DemoSeedService.loadButtonAccessibilityHint
            .localizedCaseInsensitiveContains("sample")
            || DemoSeedService.loadButtonAccessibilityHint
            .localizedCaseInsensitiveContains("demo"))
    }
}
