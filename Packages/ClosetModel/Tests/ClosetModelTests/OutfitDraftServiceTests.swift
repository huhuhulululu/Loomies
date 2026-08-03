import Testing
import SwiftData
import Foundation
@testable import ClosetModel

@MainActor
struct OutfitDraftServiceTests {

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    @Test func createSucceedsWithSameWardrobeItems() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let t = Item(name: "top"); t.wardrobe = w; ctx.insert(t)
        let b = Item(name: "bottom"); b.wardrobe = w; ctx.insert(b)
        try ctx.save()

        let o = try OutfitDraftService.create(name: "look", items: [t, b], in: w, context: ctx)
        #expect(o.name == "look")
        #expect(o.items?.count == 2)
        #expect(WardrobeInvariant.isValid(o))
    }

    @Test func createFailsOnEmpty() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        #expect(throws: OutfitDraftError.emptySelection) {
            try OutfitDraftService.create(name: "x", items: [], in: w, context: ctx)
        }
    }

    @Test func createFailsOnCrossWardrobe() throws {
        let ctx = try makeContext()
        let a = Wardrobe(name: "A"); ctx.insert(a)
        let b = Wardrobe(name: "B"); ctx.insert(b)
        let i1 = Item(name: "1"); i1.wardrobe = a; ctx.insert(i1)
        let i2 = Item(name: "2"); i2.wardrobe = b; ctx.insert(i2)
        try ctx.save()
        #expect(throws: OutfitDraftError.wardrobeMismatch) {
            try OutfitDraftService.create(name: "cross", items: [i1, i2], in: a, context: ctx)
        }
        let all = try ctx.fetch(FetchDescriptor<Outfit>())
        #expect(all.isEmpty)
    }
}
