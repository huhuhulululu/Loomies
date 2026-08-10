import Testing
import SwiftData
import Foundation
@testable import ClosetModel

@MainActor
struct CalendarPlanServiceTests {

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    @Test func planBindsOutfitToDate() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let top = Item(name: "t"); top.wardrobe = w; ctx.insert(top)
        let o = Outfit(name: "look"); o.wardrobe = w; o.items = [top]; ctx.insert(o)
        try ctx.save()

        let day = Date()
        let plan = CalendarPlanService.plan(outfit: o, on: day, in: ctx)
        #expect(plan != nil)
        #expect(plan!.outfit?.id == o.id)
        #expect(plan!.needsAttention == false)

        let found = CalendarPlanService.plan(on: day, in: ctx)
        #expect(found?.id == plan!.id)
    }

    func makeOutfit(_ ctx: ModelContext, name: String = "look") throws -> Outfit {
        let w = Wardrobe(name: "W-\(name)"); ctx.insert(w)
        let top = Item(name: "t-\(name)"); top.wardrobe = w; ctx.insert(top)
        let o = Outfit(name: name); o.wardrobe = w; o.items = [top]; ctx.insert(o)
        try ctx.save()
        return o
    }

    func cal(_ tzID: String) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: tzID)!
        return c
    }

    /// 跨时区稳定：东京排的 3/20 计划，设备飞到洛杉矶后 3/20 仍能查到——
    /// 计划日以 dayKey（日历日）持久化，不是写入时区的本地午夜瞬时值。
    @Test func planSurvivesTimezoneChange() throws {
        let ctx = try makeContext()
        let o = try makeOutfit(ctx)
        let tokyo = cal("Asia/Tokyo")
        let la = cal("America/Los_Angeles")
        // 东京 2026-03-20 10:00 排计划
        let writeAt = tokyo.date(from: DateComponents(year: 2026, month: 3, day: 20, hour: 10))!
        let plan = CalendarPlanService.plan(outfit: o, on: writeAt, in: ctx, calendar: tokyo)
        #expect(plan?.dayKey == "2026-03-20")
        // 洛杉矶 2026-03-20 12:00 查询 → 同一条计划（旧实现按 LA startOfDay 匹配不到）
        let queryAt = la.date(from: DateComponents(year: 2026, month: 3, day: 20, hour: 12))!
        let found = CalendarPlanService.plan(on: queryAt, in: ctx, calendar: la)
        #expect(found?.id == plan?.id)
    }

    /// 跨时区去重：换时区后再排同一天必须覆盖同一行，不得出现两条计划。
    @Test func planDedupeSurvivesTimezoneChange() throws {
        let ctx = try makeContext()
        let o1 = try makeOutfit(ctx, name: "one")
        let o2 = try makeOutfit(ctx, name: "two")
        let tokyo = cal("Asia/Tokyo")
        let la = cal("America/Los_Angeles")
        let writeAt = tokyo.date(from: DateComponents(year: 2026, month: 3, day: 20, hour: 10))!
        _ = CalendarPlanService.plan(outfit: o1, on: writeAt, in: ctx, calendar: tokyo)
        let queryAt = la.date(from: DateComponents(year: 2026, month: 3, day: 20, hour: 12))!
        let overwritten = CalendarPlanService.plan(outfit: o2, on: queryAt, in: ctx, calendar: la)
        #expect(overwritten?.outfit?.id == o2.id)
        #expect((try ctx.fetch(FetchDescriptor<CalendarPlan>())).count == 1)
    }

    /// 旧数据（dayKey 为空）按写入时区午夜瞬时值退回设备历解释——不丢不炸。
    @Test func legacyPlanWithoutDayKeyStillResolves() throws {
        let ctx = try makeContext()
        let o = try makeOutfit(ctx)
        let legacyDay = Calendar.current.startOfDay(for: Date())
        let legacy = CalendarPlan(date: legacyDay)
        legacy.outfit = o
        ctx.insert(legacy)
        try ctx.save()
        #expect(legacy.dayKey.isEmpty)
        let found = CalendarPlanService.plan(on: Date(), in: ctx)
        #expect(found?.id == legacy.id)
        // 覆盖写会顺带补 dayKey
        let o2 = try makeOutfit(ctx, name: "two")
        _ = CalendarPlanService.plan(outfit: o2, on: Date(), in: ctx)
        #expect(!legacy.dayKey.isEmpty)
        #expect((try ctx.fetch(FetchDescriptor<CalendarPlan>())).count == 1)
    }

    /// 展示日期从 dayKey 反解（本地正午，避开 DST 午夜缺失），不随时区漂移一天。
    @Test func displayDateRendersDayKeyComponents() throws {
        let ctx = try makeContext()
        let o = try makeOutfit(ctx)
        let tokyo = cal("Asia/Tokyo")
        let writeAt = tokyo.date(from: DateComponents(year: 2026, month: 3, day: 20, hour: 10))!
        let plan = try #require(CalendarPlanService.plan(outfit: o, on: writeAt, in: ctx, calendar: tokyo))
        let disp = CalendarPlanService.displayDate(plan)
        let c = Calendar.current.dateComponents([.year, .month, .day], from: disp)
        #expect(c.year == 2026 && c.month == 3 && c.day == 20)
    }

    /// Save-fail toast must not look like success (no “Added to calendar”).
    @Test func saveFailedMessageIsHonest() {
        #expect(CalendarPlanService.saveFailedMessage.localizedCaseInsensitiveContains("couldn't plan"))
        #expect(CalendarPlanService.saveFailedMessage.localizedCaseInsensitiveContains("try again"))
        #expect(!CalendarPlanService.saveFailedMessage.localizedCaseInsensitiveContains("added to calendar"))
        #expect(CalendarPlanService.removeSaveFailedMessage
            .localizedCaseInsensitiveContains("couldn't remove"))
        #expect(CalendarPlanService.removeSaveFailedMessage
            .localizedCaseInsensitiveContains("try again"))
        #expect(!CalendarPlanService.removeSaveFailedMessage
            .localizedCaseInsensitiveContains("added to calendar"))
    }

    @Test func planNeedsAttentionWhenOutfitMissing() throws {
        let ctx = try makeContext()
        let a = Wardrobe(name: "A"); ctx.insert(a)
        let b = Wardrobe(name: "B"); ctx.insert(b)
        let item = Item(name: "x"); item.wardrobe = a; ctx.insert(item)
        let o = Outfit(name: "look"); o.wardrobe = a; o.items = [item]; ctx.insert(o)
        try ctx.save()
        TransferService.transfer(item, to: b, in: ctx)  // marks missing
        #expect(o.missing == true)

        let plan = CalendarPlanService.plan(outfit: o, on: Date(), in: ctx)
        #expect(plan?.needsAttention == true)
    }

    @Test func sameDayUpdatesExistingPlan() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i1 = Item(name: "1"); i1.wardrobe = w; ctx.insert(i1)
        let i2 = Item(name: "2"); i2.wardrobe = w; ctx.insert(i2)
        let o1 = Outfit(name: "a"); o1.wardrobe = w; o1.items = [i1]; ctx.insert(o1)
        let o2 = Outfit(name: "b"); o2.wardrobe = w; o2.items = [i2]; ctx.insert(o2)
        try ctx.save()

        let day = Date()
        let p1 = CalendarPlanService.plan(outfit: o1, on: day, in: ctx)
        let p2 = CalendarPlanService.plan(outfit: o2, on: day, in: ctx)
        #expect(p1 != nil && p2 != nil)
        #expect(p1!.id == p2!.id)
        #expect(p2!.outfit?.id == o2.id)
        let all = try ctx.fetch(FetchDescriptor<CalendarPlan>())
        #expect(all.count == 1)
    }

    @Test func listAndRemovePlans() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let item = Item(name: "t"); item.wardrobe = w; ctx.insert(item)
        let o = Outfit(name: "look"); o.wardrobe = w; o.items = [item]; ctx.insert(o)
        try ctx.save()
        let p = CalendarPlanService.plan(outfit: o, on: Date(), in: ctx)
        #expect(p != nil)
        #expect(CalendarPlanService.plans(for: w, in: ctx).count == 1)
        #expect(CalendarPlanService.remove(p!, in: ctx))
        #expect(CalendarPlanService.plans(for: w, in: ctx).isEmpty)
    }

    /// Delete piece → permanentlyMissing look on a plan must surface Attention (not silent).
    @Test func deleteItemFlagsPlannedLookNeedsAttention() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let item = Item(name: "top"); item.wardrobe = w; ctx.insert(item)
        let o = Outfit(name: "look"); o.wardrobe = w; o.items = [item]; o.isFavorite = true
        ctx.insert(o)
        try ctx.save()
        let plan = CalendarPlanService.plan(outfit: o, on: Date(), in: ctx)
        #expect(plan != nil)
        #expect(plan!.needsAttention == false)
        #expect(CalendarPlanService.shouldNeedAttention(o) == false)

        DeleteService.deleteItem(item, in: ctx)
        #expect(o.permanentlyMissing == true)
        #expect(CalendarPlanService.shouldNeedAttention(o) == true)
        #expect(plan!.needsAttention == true)
        #expect(CalendarPlanService.attentionPlans(in: ctx).contains(where: { $0.id == plan!.id }))
    }
}
