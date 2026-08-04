import Testing
import SwiftData
import Foundation
@testable import ClosetModel
import ClosetCore

@MainActor
struct FeatureGapServicesTests {

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    @Test func itemStatusRejectsInvalid() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "tee"); i.wardrobe = w; ctx.insert(i)
        #expect(!ItemStatusService.setStatus(i, to: "bogus", in: ctx))
        #expect(i.statusRaw == "available")
        #expect(ItemStatusService.setStatus(i, to: "inWash", in: ctx))
        #expect(i.statusRaw == "inWash")
    }

    @Test func storageLocationTreeAndAssign() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let rod = StorageLocationService.create(name: "Rod", in: w, context: ctx)
        let drawer = StorageLocationService.create(name: "Drawer", in: w, parent: rod, context: ctx)
        let list = StorageLocationService.list(in: w)
        #expect(list.map(\.name) == ["Rod", "Drawer"])
        let i = Item(name: "tee"); i.wardrobe = w; ctx.insert(i)
        StorageLocationService.assign(i, to: drawer, in: ctx)
        #expect(i.location?.id == drawer.id)
    }

    @Test func itemEditorPatchesFields() throws {
        let ctx = try makeContext()
        let i = Item(name: "old"); ctx.insert(i)
        ItemEditorService.apply(.init(name: "new", slotRaw: "bottom", brand: "Everlane"), to: i, in: ctx)
        #expect(i.name == "new")
        #expect(i.brand == "Everlane")
        #expect(i.slotRaw == "bottom")
    }

    @Test func saveFavoriteFromIDsAndPlan() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let t = Item(name: "t"); t.slotRaw = "top"; t.wardrobe = w; ctx.insert(t)
        let b = Item(name: "b"); b.slotRaw = "bottom"; b.wardrobe = w; ctx.insert(b)
        try ctx.save()
        let o = try OutfitFavoriteService.saveFavorite(
            name: "Work look", itemIDs: [t.id.uuidString, b.id.uuidString],
            occasion: "work", in: w, context: ctx)
        #expect(o.isFavorite)
        #expect(o.occasionRaw == "work")
        #expect(OutfitFavoriteService.favorites(in: w).count == 1)

        OutfitFavoriteService.setFavorite(o, false, in: ctx)
        #expect(o.isFavorite == false)
        #expect(OutfitFavoriteService.favorites(in: w).isEmpty)

        OutfitFavoriteService.setFavorite(o, true, in: ctx)
        #expect(OutfitFavoriteService.favorites(in: w).count == 1)

        let plan = CalendarPlanService.plan(outfit: o, on: Date(), in: ctx)
        #expect(plan.outfit?.id == o.id)
        #expect(plan.needsAttention == false)
    }

    @Test func crossWardrobeLocationAssignBlocked() throws {
        let ctx = try makeContext()
        let a = Wardrobe(name: "A"); ctx.insert(a)
        let b = Wardrobe(name: "B"); ctx.insert(b)
        let loc = StorageLocationService.create(name: "Rod", in: a, context: ctx)
        let i = Item(name: "x"); i.wardrobe = b; ctx.insert(i)
        StorageLocationService.assign(i, to: loc, in: ctx)
        #expect(i.location == nil)
    }
}
