import Testing
import SwiftData
import Foundation
@testable import ClosetModel
import ClosetCore

@MainActor
struct CheckInServiceTests {
    let today = Date(timeIntervalSince1970: 1_700_000_000)
    var daysAgo: (Int) -> Date { { n in Date(timeIntervalSince1970: 1_700_000_000 - Double(n) * 86400) } }

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    func mk(_ ctx: ModelContext, _ w: Wardrobe, _ name: String, _ slot: String) -> Item {
        let i = Item(name: name); i.slotRaw = slot; i.wardrobe = w
        i.occasionsRaw = ["work"]; i.warmthRaw = Warmth.light.rawValue
        i.colorHue = 0; i.colorIsNeutral = true
        ctx.insert(i); return i
    }

    @Test func recordWearCapturesItemsAndWardrobe() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let top = mk(ctx, w, "top", "top")
        try ctx.save()
        let rec = CheckInService.recordWear(items: [top], on: today, in: w, fitFeedback: "fit", in: ctx)
        #expect(rec != nil)
        #expect(rec!.wornItemIDs == [top.id.uuidString])
        #expect(rec!.wardrobeSnapshotID == w.id)
        #expect(rec!.fitFeedback == "fit")
        let fetched = try ctx.fetch(FetchDescriptor<WearRecord>())
        #expect(fetched.contains { $0.id == rec!.id })
    }

    /// M4: empty selection must not insert a zero-item WearRecord polluting history.
    @Test func recordWearWithEmptyItemsReturnsNilAndInsertsNothing() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        try ctx.save()

        let rec = CheckInService.recordWear(items: [], on: today, in: w, in: ctx)
        #expect(rec == nil)
        #expect(try ctx.fetch(FetchDescriptor<WearRecord>()).isEmpty)
        // History stays clean — no phantom zero-item record in the window.
        #expect(WearHistory.recentlyWornItemIDs(within: 7, asOf: today, in: ctx).isEmpty)
    }

    /// Save-fail toast must not look like success (caller keeps selection for retry).
    @Test func saveFailedMessageIsHonest() {
        #expect(CheckInService.saveFailedMessage.localizedCaseInsensitiveContains("couldn't save"))
        #expect(CheckInService.saveFailedMessage.localizedCaseInsensitiveContains("try again"))
        #expect(!CheckInService.saveFailedMessage.localizedCaseInsensitiveContains("checked in"))
        #expect(!CheckInService.saveFailedMessage.localizedCaseInsensitiveContains("de-prioritized"))
    }

    @Test func recentlyWornWithinWindow() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let recent = mk(ctx, w, "recent", "top")
        let old = mk(ctx, w, "old", "top")
        try ctx.save()
        CheckInService.recordWear(items: [recent], on: daysAgo(2), in: w, in: ctx)  // 2 天前
        CheckInService.recordWear(items: [old], on: daysAgo(10), in: w, in: ctx)     // 10 天前
        let worn = WearHistory.recentlyWornItemIDs(within: 7, asOf: today, in: ctx)
        #expect(worn.contains(recent.id.uuidString))
        #expect(!worn.contains(old.id.uuidString))
    }

    /// 「近 7 天」按日历日算，不是 168 小时滑动窗口：晚间打卡不得比清晨打卡多压制半天。
    @Test func recentlyWornUsesCalendarDaysNotSlidingHours() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "GMT")!
        func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int) -> Date {
            cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h))!
        }
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let jeans = mk(ctx, w, "jeans", "bottom")
        try ctx.save()
        // 8/3 晚 20:00 打卡
        CheckInService.recordWear(items: [jeans], on: date(2026, 8, 3, 20), in: w, in: ctx)
        // 第 7 个日历日（8/9）早上 → 仍压制
        let day7 = WearHistory.recentlyWornItemIDs(within: 7, asOf: date(2026, 8, 9, 9), in: ctx, calendar: cal)
        #expect(day7.contains(jeans.id.uuidString))
        // 第 8 个日历日（8/10）早上 → 解除；旧实现按 168h 算在此仍压制（9:00 < 20:00）
        let day8 = WearHistory.recentlyWornItemIDs(within: 7, asOf: date(2026, 8, 10, 9), in: ctx, calendar: cal)
        #expect(!day8.contains(jeans.id.uuidString))
    }

    /// 非法窗口不得放大为全量压制。
    @Test func recentlyWornWithNonPositiveDaysIsEmpty() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let top = mk(ctx, w, "top", "top")
        try ctx.save()
        CheckInService.recordWear(items: [top], on: today, in: w, in: ctx)
        #expect(WearHistory.recentlyWornItemIDs(within: 0, asOf: today, in: ctx).isEmpty)
        #expect(WearHistory.recentlyWornItemIDs(within: -3, asOf: today, in: ctx).isEmpty)
    }

    /// D85 波 D：合身反馈是打卡后的**追问**（同一条 WearRecord 的 update），
    /// 不是第二种打卡语义。校验 + 快照回滚收敛在这一个入口。
    @Test(.serialized) func setFitFeedbackValidatesAndRollsBack() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let top = mk(ctx, w, "top", "top")
        try ctx.save()
        let rec = try #require(CheckInService.recordWear(items: [top], on: today, in: w, in: ctx))
        #expect(rec.fitFeedback == nil)

        // 合法值写入
        #expect(CheckInService.setFitFeedback(FitVerdict.tight.rawValue, on: rec, in: ctx))
        #expect(rec.fitFeedback == "tight")
        // 空白 = 清除（用户改主意）
        #expect(CheckInService.setFitFeedback("  ", on: rec, in: ctx))
        #expect(rec.fitFeedback == nil)
        // 非法值拒绝（不落库、不静默接受）
        #expect(!CheckInService.setFitFeedback("snug-ish", on: rec, in: ctx))
        #expect(rec.fitFeedback == nil)
        // 大小写容错
        #expect(CheckInService.setFitFeedback("LOOSE", on: rec, in: ctx))
        #expect(rec.fitFeedback == "loose")
        // save 失败：内存值还原 + 无脏标记
        ModelSave.forceFailure(on: ctx)
        #expect(!CheckInService.setFitFeedback("tight", on: rec, in: ctx))
        #expect(rec.fitFeedback == "loose")
        #expect(!ctx.hasChanges)
        ModelSave.clearForcedFailure(on: ctx)
        #expect(!CheckInService.fitFeedbackSaveFailedMessage.isEmpty)
    }

    /// 闭环：打卡 → 穿着历史 → 推荐防重复。
    @Test func closedLoopSuppressesRecentlyWorn() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let top = mk(ctx, w, "top", "top")
        let wornBottom = mk(ctx, w, "wornBottom", "bottom")
        let freshBottom = mk(ctx, w, "freshBottom", "bottom")
        _ = mk(ctx, w, "shoes", "shoes")
        try ctx.save()
        // 昨天穿了 wornBottom
        CheckInService.recordWear(items: [wornBottom], on: daysAgo(1), in: w, in: ctx)
        let worn = WearHistory.recentlyWornItemIDs(within: 7, asOf: today, in: ctx)
        // 今天为 top 求补全 → 应避开 wornBottom，用 freshBottom
        let out = RecommendationService.suggestions(
            for: w, anchors: [top], occasion: "work", daytimeTempF: 75,
            wornWithin7DaysIDs: worn, maxSuggestions: 5)
        #expect(!out.isEmpty)
        #expect(out.allSatisfy { !$0.outfit.itemIDs.contains(wornBottom.id.uuidString) })
        #expect(out.contains { $0.outfit.itemIDs.contains(freshBottom.id.uuidString) })
    }
}
