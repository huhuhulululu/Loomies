import Testing
import SwiftData
import Foundation
@testable import ClosetModel

@MainActor
struct DataLifecycleServiceTests {

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    func seedCloset(in ctx: ModelContext) throws -> (Person, Wardrobe, Item) {
        let p = Person(name: "Ada"); ctx.insert(p)
        let w = Wardrobe(name: "Main", locationCity: "Seattle"); w.owner = p; ctx.insert(w)
        let loc = StorageLocation(name: "Rod"); loc.wardrobe = w; ctx.insert(loc)
        let i = Item(name: "tee"); i.wardrobe = w; i.location = loc; i.slotRaw = "top"; ctx.insert(i)
        let o = Outfit(name: "look"); o.wardrobe = w; o.items = [i]; o.isFavorite = true; ctx.insert(o)
        let wr = WearRecord(date: Date(timeIntervalSince1970: 1_700_000_000), outfitID: o.id)
        wr.wornItemIDs = [i.id.uuidString]
        ctx.insert(wr)
        let plan = CalendarPlan(date: Date(timeIntervalSince1970: 1_700_086_400))
        plan.outfit = o
        ctx.insert(plan)
        let body = PersonBodyProfile(personID: p.id)
        body.bustInches = 34
        body.waistInches = 26
        body.hipInches = 36
        body.highHipInches = 32
        ctx.insert(body)
        try ctx.save()
        return (p, w, i)
    }

    @Test func exportOmitsBodyByDefault() throws {
        let ctx = try makeContext()
        _ = try seedCloset(in: ctx)
        let snap = try DataLifecycleService.exportSnapshot(in: ctx, includeBodyDimensions: false)
        #expect(snap.persons.count == 1)
        #expect(snap.persons[0].name == "Ada")
        #expect(snap.wardrobes.count == 1)
        #expect(snap.items.count == 1)
        #expect(snap.outfits.count == 1)
        #expect(snap.locations.count == 1)
        #expect(snap.wearRecords.count == 1)
        #expect(snap.plans.count == 1)
        #expect(snap.bodyProfiles == nil)
        #expect(snap.includeBodyDimensions == false)
        let json = try DataLifecycleService.exportJSONString(in: ctx)
        #expect(json.contains("Ada"))
        #expect(json.contains("tee"))
        #expect(!json.contains("bustInches"))
    }

    @Test func exportIncludesBodyWhenRequested() throws {
        let ctx = try makeContext()
        _ = try seedCloset(in: ctx)
        let snap = try DataLifecycleService.exportSnapshot(in: ctx, includeBodyDimensions: true)
        #expect(snap.includeBodyDimensions == true)
        #expect(snap.bodyProfiles?.count == 1)
        #expect(snap.bodyProfiles?[0].bustInches == 34)
        let json = try DataLifecycleService.exportJSONString(in: ctx, includeBodyDimensions: true)
        #expect(json.contains("bustInches"))
    }

    @Test func deleteAllWipesEntitiesAndReturnsReceipt() throws {
        let ctx = try makeContext()
        _ = try seedCloset(in: ctx)
        let receipt = try DataLifecycleService.deleteAllUserData(in: ctx, wipeItemImages: false)
        #expect(receipt.deletedPersons == 1)
        #expect(receipt.deletedWardrobes == 1)
        #expect(receipt.deletedItems == 1)
        #expect(receipt.deletedOutfits == 1)
        #expect(receipt.deletedLocations == 1)
        #expect(receipt.deletedWearRecords == 1)
        #expect(receipt.deletedPlans == 1)
        #expect(receipt.deletedBodyProfiles == 1)
        #expect(try ctx.fetch(FetchDescriptor<Person>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<Wardrobe>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<Item>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<Outfit>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<WearRecord>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<CalendarPlan>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<PersonBodyProfile>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<StorageLocation>()).isEmpty)
    }

    @Test func deleteAllIsIdempotentOnEmptyStore() throws {
        let ctx = try makeContext()
        let receipt = try DataLifecycleService.deleteAllUserData(in: ctx, wipeItemImages: false)
        #expect(receipt.deletedItems == 0)
        #expect(receipt.deletedPersons == 0)
    }
}
