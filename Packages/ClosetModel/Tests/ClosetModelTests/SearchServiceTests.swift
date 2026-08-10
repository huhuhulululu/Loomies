import Testing
import SwiftData
import Foundation
@testable import ClosetModel
import ClosetCore

@MainActor
struct SearchServiceTests {

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    @Test func searchCrossesWardrobesByText() throws {
        let ctx = try makeContext()
        let a = Wardrobe(name: "NYC"); ctx.insert(a)
        let b = Wardrobe(name: "BKK"); ctx.insert(b)
        let i1 = Item(name: "Blue Shirt"); i1.brand = "Everlane"; i1.wardrobe = a; ctx.insert(i1)
        let i2 = Item(name: "Red Pants"); i2.wardrobe = b; ctx.insert(i2)
        let i3 = Item(name: "Blue Skirt"); i3.wardrobe = b; ctx.insert(i3)
        try ctx.save()

        let hits = SearchService.searchItems(.init(text: "blue"), in: ctx)
        #expect(hits.count == 2)
        #expect(Set(hits.map(\.name)) == Set(["Blue Shirt", "Blue Skirt"]))
    }

    @Test func searchByBrand() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "Tee"); i.brand = "Uniqlo"; i.wardrobe = w; ctx.insert(i)
        try ctx.save()
        let hits = SearchService.searchItems(.init(text: "uniq"), in: ctx)
        #expect(hits.count == 1)
        #expect(hits[0].name == "Tee")
    }

    @Test func searchFiltersSlotAndOccasionAndWardrobe() throws {
        let ctx = try makeContext()
        let a = Wardrobe(name: "A"); ctx.insert(a)
        let b = Wardrobe(name: "B"); ctx.insert(b)
        // 真 top（避免 blazer/oxford 等 displaySlot 名称纠偏）
        let top = Item(name: "Poplin Shirt"); top.slotRaw = "top"; top.occasionsRaw = ["work"]
        top.wardrobe = a; ctx.insert(top)
        let casual = Item(name: "Tee"); casual.slotRaw = "top"; casual.occasionsRaw = ["casual"]
        casual.wardrobe = a; ctx.insert(casual)
        let other = Item(name: "Work Shirt B"); other.slotRaw = "top"; other.occasionsRaw = ["work"]
        other.wardrobe = b; ctx.insert(other)
        try ctx.save()

        let hits = SearchService.searchItems(
            .init(slotRaw: "top", occasion: "work", wardrobeID: a.id), in: ctx)
        #expect(hits.count == 1)
        #expect(hits[0].name == "Poplin Shirt")
    }

    @Test func searchSlotFilterUsesDisplaySlotTruthForDirtyBlazer() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        // 脏数据：西装误标 top → 筛 Outerwear 应命中（与叠衣/列表 Type 同真相）
        let blazer = Item(name: "Navy Blazer")
        blazer.slotRaw = "top"
        blazer.wardrobe = w
        ctx.insert(blazer)
        let tee = Item(name: "White Tee")
        tee.slotRaw = "top"
        tee.wardrobe = w
        ctx.insert(tee)
        let coat = Item(name: "Camel Coat")
        coat.slotRaw = "outerwear"
        coat.wardrobe = w
        ctx.insert(coat)
        try ctx.save()

        let outerHits = SearchService.searchItems(.init(slotRaw: "outerwear"), in: ctx)
        #expect(Set(outerHits.map(\.name)) == Set(["Navy Blazer", "Camel Coat"]))

        let topHits = SearchService.searchItems(.init(slotRaw: "top"), in: ctx)
        #expect(topHits.map(\.name) == ["White Tee"])
        #expect(!topHits.contains { $0.name == "Navy Blazer" })
    }

    /// CM-4: occasion facet must normalize case/whitespace on both sides (CandidateFilter parity).
    @Test func occasionFacetNormalizesCaseAndWhitespace() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "Poplin Shirt"); i.slotRaw = "top"; i.occasionsRaw = ["Work"]
        i.wardrobe = w; ctx.insert(i)
        try ctx.save()

        // Chip lowercase vs stored capitalized.
        #expect(SearchService.searchItems(.init(occasion: "work"), in: ctx).map(\.name) == ["Poplin Shirt"])
        // Chip with surrounding whitespace.
        #expect(SearchService.searchItems(.init(occasion: " work "), in: ctx).map(\.name) == ["Poplin Shirt"])
        // Non-matching occasion still excluded.
        #expect(SearchService.searchItems(.init(occasion: "casual"), in: ctx).isEmpty)
    }

    @Test func searchByStatus() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let ok = Item(name: "ok"); ok.statusRaw = "available"; ok.wardrobe = w; ctx.insert(ok)
        let wash = Item(name: "wash"); wash.statusRaw = "inWash"; wash.wardrobe = w; ctx.insert(wash)
        try ctx.save()
        let hits = SearchService.searchItems(.init(statusRaw: "inWash"), in: ctx)
        #expect(hits.count == 1)
        #expect(hits[0].name == "wash")
    }

    /// Closet grid type chips: same displaySlot truth as search (dirty blazer → outerwear).
    @Test func closetBrowseFilterItemsByStatusAndResolvedSlot() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let blazer = Item(name: "Navy Blazer")
        blazer.slotRaw = "top"
        blazer.statusRaw = "available"
        blazer.wardrobe = w
        ctx.insert(blazer)
        let tee = Item(name: "White Tee")
        tee.slotRaw = "top"
        tee.statusRaw = "inWash"
        tee.wardrobe = w
        ctx.insert(tee)
        let belt = Item(name: "Leather Belt")
        belt.slotRaw = "accessory"
        belt.statusRaw = "available"
        belt.wardrobe = w
        ctx.insert(belt)
        try ctx.save()
        let all = [blazer, tee, belt]

        let outer = SearchService.filterItems(all, slotRaw: "outerwear")
        #expect(outer.map(\.name) == ["Navy Blazer"])

        let tops = SearchService.filterItems(all, slotRaw: "top")
        #expect(tops.map(\.name) == ["White Tee"])

        let availableOuter = SearchService.filterItems(
            all, statusRaw: "available", slotRaw: "outerwear")
        #expect(availableOuter.map(\.name) == ["Navy Blazer"])

        let availableTops = SearchService.filterItems(
            all, statusRaw: "available", slotRaw: "top")
        #expect(availableTops.isEmpty)

        let accessories = SearchService.filterItems(all, slotRaw: GarmentSlot.accessory.rawValue)
        #expect(accessories.map(\.name) == ["Leather Belt"])

        #expect(SearchService.filterItems(all).count == 3)
        #expect(SearchService.matches(blazer, slotRaw: "outerwear"))
        #expect(!SearchService.matches(blazer, slotRaw: "top"))
    }

    /// Grid status chips must cover full ItemStatusService.allowed (incl. pending).
    @Test func closetBrowseFilterIncludesPendingAndAllAllowedStatuses() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        var byStatus: [String: Item] = [:]
        for raw in ItemStatusService.allowed {
            let i = Item(name: "piece-\(raw)")
            i.slotRaw = "top"
            i.statusRaw = raw
            i.wardrobe = w
            ctx.insert(i)
            byStatus[raw] = i
        }
        try ctx.save()
        let all = Array(byStatus.values)

        #expect(ItemStatusService.allowed.contains("pending"))
        #expect(ItemStatusService.displayName("pending") == "Pending")
        #expect(!ItemStatusService.displayName("pending").isEmpty)
        // Corrupt / unknown storage — human "Unknown", never bare camelCase dump.
        #expect(ItemStatusService.displayName("bogus") == "Unknown")
        #expect(ItemStatusService.displayName("") == "Unknown")
        #expect(ItemStatusService.displayName("inWash") == "In wash")

        for raw in ItemStatusService.allowed {
            let hits = SearchService.filterItems(all, statusRaw: raw)
            #expect(hits.count == 1, "status \(raw) should match one piece")
            #expect(hits[0].name == "piece-\(raw)")
        }
        #expect(SearchService.filterItems(all, statusRaw: "pending").map(\.name)
            == ["piece-pending"])
    }
}
