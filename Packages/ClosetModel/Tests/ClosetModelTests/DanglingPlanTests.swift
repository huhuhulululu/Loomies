import Testing
import Foundation
import SwiftData
@testable import ClosetModel

/// D114：`CalendarPlan.outfit` 是 schema 里**唯一没有反向关系**的引用。
///
/// 没有反向关系，SwiftData 就不会在搭配被删时把它置空——这条不变式今天
/// 只靠服务层自觉维持（`DeleteService.deleteWardrobe` 先手动删了绑定的计划，
/// `deletePerson` 名下有柜就直接拒绝）。任何一处新的 `context.delete(outfit)`
/// 都会在没人注意的情况下把它打破，而后果是日历上一条指向已删行的计划。
///
/// 实测确认：不解绑就是一条指向已删行的悬挂引用（本文件第一条用例）。
///
/// 加反向端才是机器保证，但 golden 门把它判为**破坏性**（关系形态变了，
/// 不是加字段），而 TestFlight 上已有真实安装数据——为一条当前不可达的隐患
/// 冒「存量用户开不了库」的风险不划算。于是不变式由 `CalendarPlanService.unbindPlans`
/// 统一维持，`PlanUnbindLintTests` 守住每个删除点都调它。
@MainActor
struct DanglingPlanTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    /// 现状取证：**裸删**搭配确实留下悬挂引用（这就是为什么必须走服务层）。
    /// 这条不是在赞成裸删，而是把「SwiftData 不会替我们置空」钉成可复现事实——
    /// 哪天工具链改了行为，这里会红，届时重新评估加反向端。
    @Test func aBareDeleteDoesLeaveADanglingReference() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Home"); ctx.insert(w)
        let look = ClosetModel.Outfit(name: "Look"); look.wardrobe = w; ctx.insert(look)
        let plan = CalendarPlan(date: Date()); plan.outfit = look; ctx.insert(plan)
        try ctx.save()

        ctx.delete(look)
        try ctx.save()

        let plans = try ctx.fetch(FetchDescriptor<CalendarPlan>())
        #expect(plans.count == 1, "计划被连带删了 —— 那是级联不是置空")
        #expect(plans.first?.outfit != nil,
                "SwiftData 开始自动置空了 —— 重新评估是否还需要 unbindPlans")
    }

    /// 服务层解绑：计划留下、不再指向任何搭配、并被标为需要处理。
    @Test func unbindingClearsTheReferenceAndFlagsAttention() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Home"); ctx.insert(w)
        let look = ClosetModel.Outfit(name: "Look"); look.wardrobe = w; ctx.insert(look)
        let plan = CalendarPlan(date: Date()); plan.outfit = look; ctx.insert(plan)
        try ctx.save()

        #expect(CalendarPlanService.unbindPlans(referencing: look, in: ctx) == 1)
        #expect(plan.outfit == nil)
        #expect(plan.needsAttention, "计划没了搭配却不提示 —— 用户到那天才发现")
    }

    /// 只解绑目标那一条，别人的计划不受影响。
    @Test func unbindingTouchesOnlyTheTargetOutfit() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Home"); ctx.insert(w)
        let a = ClosetModel.Outfit(name: "A"); a.wardrobe = w; ctx.insert(a)
        let b = ClosetModel.Outfit(name: "B"); b.wardrobe = w; ctx.insert(b)
        let pa = CalendarPlan(date: Date()); pa.outfit = a; ctx.insert(pa)
        let pb = CalendarPlan(date: Date()); pb.outfit = b; ctx.insert(pb)
        try ctx.save()

        _ = CalendarPlanService.unbindPlans(referencing: a, in: ctx)
        #expect(pa.outfit == nil)
        #expect(pb.outfit?.id == b.id, "解绑波及了别的搭配的计划")
    }

    /// 丢弃孤儿搭配走的是同一条路：不得留下悬挂计划。
    @Test func discardingAnOrphanUnbindsItsPlans() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Home"); ctx.insert(w)
        let look = ClosetModel.Outfit(name: "Junk"); look.wardrobe = w; ctx.insert(look)
        let plan = CalendarPlan(date: Date()); plan.outfit = look; ctx.insert(plan)
        try ctx.save()

        #expect(OutfitFavoriteService.discardOrphan(look, in: ctx))
        let plans = try ctx.fetch(FetchDescriptor<CalendarPlan>())
        #expect(plans.first?.outfit == nil, "丢弃孤儿之后日历上留了条悬挂计划")
    }

    /// 丢弃失败时解绑也要还原（与关系还原同一条纪律）。
    @Test func aFailedDiscardRestoresTheBinding() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Home"); ctx.insert(w)
        let look = ClosetModel.Outfit(name: "Junk"); look.wardrobe = w; ctx.insert(look)
        let plan = CalendarPlan(date: Date()); plan.outfit = look; ctx.insert(plan)
        try ctx.save()

        ModelSave.forceFailure(on: ctx)
        #expect(OutfitFavoriteService.discardOrphan(look, in: ctx) == false)
        ModelSave.clearForcedFailure(on: ctx)
        #expect(plan.outfit?.id == look.id, "丢弃失败了，计划却已经跟搭配断了")
    }

    /// 删柜仍然把计划**删掉**（不是留一堆空计划）——既有行为不得被这次改动改掉。
    @Test func deletingAWardrobeStillRemovesItsPlans() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Home"); ctx.insert(w)
        let look = ClosetModel.Outfit(name: "Look"); look.wardrobe = w; ctx.insert(look)
        let plan = CalendarPlan(date: Date()); plan.outfit = look; ctx.insert(plan)
        try ctx.save()

        try DeleteService.deleteWardrobe(w, force: true, in: ctx)
        #expect(try ctx.fetch(FetchDescriptor<CalendarPlan>()).isEmpty,
                "删柜之后日历上留下了空计划")
    }
}
