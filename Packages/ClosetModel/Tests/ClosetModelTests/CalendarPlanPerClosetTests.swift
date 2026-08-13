import Testing
import SwiftData
import Foundation
@testable import ClosetModel

/// D176：**在 B 柜排今天的计划，会把 A 柜今天的计划静默改写掉。**
///
/// `CalendarPlan` 是 schema 里唯一没有衣柜字段的实体——归属只能从
/// `outfit.wardrobe` 派生。读取侧一直是按柜的（`plans(for:)` 过滤
/// `outfit?.wardrobe?.id`），**写入侧却是全库的**：
/// `existing.first(where: { resolvedDayKey($0) == key })` 一个字都没提衣柜，
/// 命中即 `plan.outfit = outfit`。
///
/// 于是「一天一条计划」这条不变式被悄悄放大成了全 App 级别，而
/// DESIGN.md §F5 写的是「日历计划：日期 × **衣柜** × 搭配」。
///
/// 用户看到的：在度假柜排好周六穿什么，回到主柜一看——周六空了。
/// 两次操作都只播报 `Planned X.`，没有任何一处告诉他刚覆盖了什么。
///
/// 为什么一直没红：唯一覆盖「两柜同一天」的用例
/// （`FeatureGapViewModelTests.onlyThisClosetsPlansAreListed`）用
/// `CalendarPlan(date:) + p.outfit = o + ctx.insert(p)` 手工插行，
/// **绕开了生产写入器**——它测的是读取侧的过滤，不是写入侧的作用域。
/// 本波把那个 helper 也改成走 `CalendarPlanService.plan`。
@MainActor
struct CalendarPlanPerClosetTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config))
    }

    private func makeOutfit(_ ctx: ModelContext, in w: Wardrobe, name: String) -> Outfit {
        let item = Item(name: "i-\(name)"); item.wardrobe = w; ctx.insert(item)
        let o = Outfit(name: name); o.wardrobe = w; o.items = [item]; ctx.insert(o)
        return o
    }

    /// **本波的核心**：两个柜各排各的，谁也别动谁。
    @Test func planningInOneClosetDoesNotOverwriteAnother() throws {
        let ctx = try makeContext()
        let home = Wardrobe(name: "Home"); ctx.insert(home)
        let lake = Wardrobe(name: "Lake"); ctx.insert(lake)
        let homeLook = makeOutfit(ctx, in: home, name: "home look")
        let lakeLook = makeOutfit(ctx, in: lake, name: "lake look")
        try ctx.save()

        let day = Date()
        #expect(CalendarPlanService.plan(outfit: homeLook, on: day, in: ctx) != nil)
        #expect(CalendarPlanService.plan(outfit: lakeLook, on: day, in: ctx) != nil)

        let homePlans = CalendarPlanService.plans(for: home, in: ctx)
        let lakePlans = CalendarPlanService.plans(for: lake, in: ctx)
        #expect(homePlans.count == 1, Comment(rawValue:
            "主柜今天的计划被度假柜的写入吃掉了（剩 \(homePlans.count) 条）"))
        #expect(homePlans.first?.outfit?.id == homeLook.id)
        #expect(lakePlans.count == 1)
        #expect(lakePlans.first?.outfit?.id == lakeLook.id)
        #expect(try ctx.fetch(FetchDescriptor<CalendarPlan>()).count == 2)
    }

    /// 单柜行为一个字不变：同柜同日再排一次仍是**就地更新**，不是新增一行。
    @Test func sameClosetSameDayStillUpdatesInPlace() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Only"); ctx.insert(w)
        let first = makeOutfit(ctx, in: w, name: "first")
        let second = makeOutfit(ctx, in: w, name: "second")
        try ctx.save()

        let day = Date()
        let p1 = CalendarPlanService.plan(outfit: first, on: day, in: ctx)
        let p2 = CalendarPlanService.plan(outfit: second, on: day, in: ctx)
        #expect(p1?.id == p2?.id, "同柜同日应就地更新")
        #expect(p2?.outfit?.id == second.id)
        #expect(try ctx.fetch(FetchDescriptor<CalendarPlan>()).count == 1)
    }

    /// 搭配被删后那条计划成了无主行（`unbindPlans` 置 outfit = nil）。
    /// 同一天重排时**复用**它，而不是把它永远留在库里——
    /// 无主行不出现在任何一个柜的日历里，只会越攒越多。
    @Test func replanningADayWhoseLookWasDeletedReusesTheOrphanRow() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Only"); ctx.insert(w)
        let doomed = makeOutfit(ctx, in: w, name: "doomed")
        try ctx.save()

        let day = Date()
        let plan = CalendarPlanService.plan(outfit: doomed, on: day, in: ctx)
        #expect(plan != nil)
        #expect(CalendarPlanService.unbindPlans(referencing: doomed, in: ctx) == 1)
        ctx.delete(doomed)
        try ctx.save()

        let replacement = makeOutfit(ctx, in: w, name: "replacement")
        try ctx.save()
        let reused = CalendarPlanService.plan(outfit: replacement, on: day, in: ctx)
        #expect(reused?.id == plan?.id, "无主计划没被复用，库里多攒了一行看不见的计划")
        #expect(try ctx.fetch(FetchDescriptor<CalendarPlan>()).count == 1)
        #expect(reused?.needsAttention == false, "复用后必须重算 attention")
    }

    /// 不同日子照旧各自成行（作用域收紧不得误伤跨日）。
    @Test func differentDaysStillGetTheirOwnRows() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Only"); ctx.insert(w)
        let look = makeOutfit(ctx, in: w, name: "look")
        try ctx.save()

        let today = Date()
        let tomorrow = today.addingTimeInterval(86_400)
        _ = CalendarPlanService.plan(outfit: look, on: today, in: ctx)
        _ = CalendarPlanService.plan(outfit: look, on: tomorrow, in: ctx)
        #expect(CalendarPlanService.plans(for: w, in: ctx).count == 2)
    }
}
