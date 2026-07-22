import Testing
import SwiftData
import Foundation
@testable import ClosetModel

@MainActor
struct DeleteServiceTests {

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    @Test func deleteWardrobeBlockedWhenHasItems() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "x"); i.wardrobe = w; ctx.insert(i)
        try ctx.save()
        #expect(throws: DeleteError.wardrobeNotEmpty) {
            try DeleteService.deleteWardrobe(w, force: false, in: ctx)
        }
    }

    @Test func deleteWardrobeForceCascadesButKeepsWearRecords() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "x"); i.wardrobe = w; ctx.insert(i)
        let wr = WearRecord(date: Date(timeIntervalSince1970: 1_700_000_000)); ctx.insert(wr)
        try ctx.save()
        try DeleteService.deleteWardrobe(w, force: true, in: ctx)
        #expect(try ctx.fetch(FetchDescriptor<Wardrobe>()).isEmpty)   // 衣柜删
        #expect(try ctx.fetch(FetchDescriptor<Item>()).isEmpty)       // 单品级联删
        #expect(try ctx.fetch(FetchDescriptor<WearRecord>()).count == 1) // WearRecord 保留
    }

    @Test func deletePersonBlockedWhenHasWardrobes() throws {
        let ctx = try makeContext()
        let p = Person(name: "me"); ctx.insert(p)
        let w = Wardrobe(name: "A"); w.owner = p; ctx.insert(w)
        try ctx.save()
        #expect(throws: DeleteError.personHasWardrobes) {
            try DeleteService.deletePerson(p, in: ctx)
        }
    }

    @Test func deleteItemMarksOutfitPermanentlyMissing() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "x"); i.wardrobe = w; ctx.insert(i)
        let o = Outfit(name: "look"); o.wardrobe = w; o.items = [i]; ctx.insert(o)
        try ctx.save()
        DeleteService.deleteItem(i, in: ctx)
        #expect(o.permanentlyMissing == true)
        #expect(try ctx.fetch(FetchDescriptor<Item>()).isEmpty)
    }

    @Test func deleteLocationPromotesItemsToParent() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let parent = StorageLocation(name: "closet"); parent.wardrobe = w; ctx.insert(parent)
        let child = StorageLocation(name: "drawer"); child.wardrobe = w; child.parent = parent; ctx.insert(child)
        let i = Item(name: "x"); i.wardrobe = w; i.location = child; ctx.insert(i)
        try ctx.save()
        DeleteService.deleteLocation(child, in: ctx)
        #expect(i.location?.id == parent.id)   // 位置提升至父节点
    }
}
