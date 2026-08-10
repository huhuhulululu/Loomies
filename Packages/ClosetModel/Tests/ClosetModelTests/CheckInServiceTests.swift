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
