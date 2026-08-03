import Testing
import SwiftData
import Foundation
@testable import ClosetModel

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
        let top = Item(name: "Blazer"); top.slotRaw = "top"; top.occasionsRaw = ["work"]
        top.wardrobe = a; ctx.insert(top)
        let casual = Item(name: "Tee"); casual.slotRaw = "top"; casual.occasionsRaw = ["casual"]
        casual.wardrobe = a; ctx.insert(casual)
        let other = Item(name: "Blazer B"); other.slotRaw = "top"; other.occasionsRaw = ["work"]
        other.wardrobe = b; ctx.insert(other)
        try ctx.save()

        let hits = SearchService.searchItems(
            .init(slotRaw: "top", occasion: "work", wardrobeID: a.id), in: ctx)
        #expect(hits.count == 1)
        #expect(hits[0].name == "Blazer")
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
}
