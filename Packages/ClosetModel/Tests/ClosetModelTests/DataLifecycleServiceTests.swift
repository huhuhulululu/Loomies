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

    /// M1: barcode must round-trip through ItemDTO (export must not silently drop it).
    @Test func exportRoundTripsBarcode() throws {
        let ctx = try makeContext()
        let (_, _, item) = try seedCloset(in: ctx)
        item.barcode = "012345678905"
        try ctx.save()

        let snap = try DataLifecycleService.exportSnapshot(in: ctx)
        #expect(snap.items.count == 1)
        #expect(snap.items[0].barcode == "012345678905")

        // DTO Codable round-trip: barcode survives encode/decode too.
        let data = try DataLifecycleService.exportJSONData(in: ctx)
        let decoded = try JSONDecoder().decode(DataLifecycleService.ExportSnapshot.self, from: data)
        #expect(decoded.items[0].barcode == "012345678905")

        // Item without barcode exports as nil, not dropped key crash.
        item.barcode = nil
        try ctx.save()
        let snap2 = try DataLifecycleService.exportSnapshot(in: ctx)
        #expect(snap2.items[0].barcode == nil)
    }

    /// 历史脏数据兜底：库里已有非有限 Double（旧版本无守卫时落库）不得把导出永久锁死
    /// （JSONEncoder 默认 .throw；CCPA 数据可携带性不能因一件脏单品失效）。
    @Test func exportSurvivesNonFiniteFlatWidthInStore() throws {
        let ctx = try makeContext()
        let (_, _, item) = try seedCloset(in: ctx)
        item.chestFlatWidthInches = .infinity
        item.waistFlatWidthInches = .nan
        try ctx.save()
        let data = try DataLifecycleService.exportJSONData(in: ctx)
        #expect(!data.isEmpty)
    }

    /// CM-3: avatar presentation preferences must round-trip through full export (not silently dropped).
    @Test func exportRoundTripsPresentationFields() throws {
        let ctx = try makeContext()
        let (person, _, _) = try seedCloset(in: ctx)
        let profile = try ctx.fetch(FetchDescriptor<PersonBodyProfile>()).first
        #expect(profile != nil)
        profile?.presentationSexRaw = "male"
        profile?.presentationPhenotypeRaw = "african"
        try ctx.save()

        let snap = try DataLifecycleService.exportSnapshot(in: ctx, includeBodyDimensions: true)
        #expect(snap.bodyProfiles?.count == 1)
        #expect(snap.bodyProfiles?[0].personID == person.id.uuidString)
        #expect(snap.bodyProfiles?[0].presentationSexRaw == "male")
        #expect(snap.bodyProfiles?[0].presentationPhenotypeRaw == "african")

        // DTO Codable round-trip: fields survive encode/decode too.
        let data = try DataLifecycleService.exportJSONData(in: ctx, includeBodyDimensions: true)
        let decoded = try JSONDecoder().decode(DataLifecycleService.ExportSnapshot.self, from: data)
        #expect(decoded.bodyProfiles?[0].presentationSexRaw == "male")
        #expect(decoded.bodyProfiles?[0].presentationPhenotypeRaw == "african")

        // Unset presentation fields export as nil, not dropped key crash.
        profile?.presentationSexRaw = nil
        profile?.presentationPhenotypeRaw = nil
        try ctx.save()
        let snap2 = try DataLifecycleService.exportSnapshot(in: ctx, includeBodyDimensions: true)
        #expect(snap2.bodyProfiles?[0].presentationSexRaw == nil)
        #expect(snap2.bodyProfiles?[0].presentationPhenotypeRaw == nil)
    }

    /// M2: deleteAllUserData routes through ModelSave — forced failure rolls back staged deletes and throws.
    @Test func deleteAllForcedSaveFailureRollsBackAndThrows() throws {
        let ctx = try makeContext()
        _ = try seedCloset(in: ctx)
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }

        #expect(throws: DeleteError.saveFailed) {
            try DataLifecycleService.deleteAllUserData(in: ctx, wipeItemImages: false)
        }
        // Staged cascade deletes must not linger: row counts unchanged after rollback.
        #expect(try ctx.fetch(FetchDescriptor<Person>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<Wardrobe>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<Item>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<Outfit>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<WearRecord>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<CalendarPlan>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<PersonBodyProfile>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<StorageLocation>()).count == 1)
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
        // Toast must not omit body/wear (confirm dialog promises both gone).
        #expect(receipt.summaryLine.localizedCaseInsensitiveContains("body profiles"))
        #expect(receipt.summaryLine.localizedCaseInsensitiveContains("wear records"))
        #expect(receipt.summaryLine.hasPrefix("Deleted "))
        #expect(!receipt.summaryLine.contains("error"))
    }

    @Test func deleteAllIsIdempotentOnEmptyStore() throws {
        let ctx = try makeContext()
        let receipt = try DataLifecycleService.deleteAllUserData(in: ctx, wipeItemImages: false)
        #expect(receipt.deletedItems == 0)
        #expect(receipt.deletedPersons == 0)
        // Empty store: no body/wear clauses (counts zero).
        #expect(receipt.summaryLine == "Deleted 0 items, 0 looks, 0 closets.")
        #expect(!receipt.summaryLine.localizedCaseInsensitiveContains("body"))
    }

    @Test func deleteReceiptSummaryLineMentionsBodyWhenPresent() {
        let withBody = DataLifecycleService.DeleteReceipt(
            deletedAt: "t",
            deletedPersons: 1,
            deletedWardrobes: 1,
            deletedLocations: 0,
            deletedItems: 2,
            deletedOutfits: 1,
            deletedWearRecords: 0,
            deletedPlans: 0,
            deletedBodyProfiles: 1,
            wipedItemImages: true)
        #expect(withBody.summaryLine.contains("2 items"))
        #expect(withBody.summaryLine.contains("1 body profiles"))
        #expect(!withBody.summaryLine.localizedCaseInsensitiveContains("wear records"))
    }

    @Test func exportReadyMessageStatesBodyInclusionHonestly() {
        let withBody = DataLifecycleService.exportReadyMessage(includeBodyDimensions: true)
        #expect(withBody.localizedCaseInsensitiveContains("includes body"))
        #expect(!withBody.localizedCaseInsensitiveContains("omitted"))
        #expect(!withBody.localizedCaseInsensitiveContains("chars"))

        let without = DataLifecycleService.exportReadyMessage(includeBodyDimensions: false)
        #expect(without.localizedCaseInsensitiveContains("omitted"))
        #expect(!without.localizedCaseInsensitiveContains("includes body measurements."))
        #expect(without.hasPrefix("Export ready"))

        // Me Export button VO — share sheet + body toggle (not a silent “done”).
        let hint = DataLifecycleService.exportButtonAccessibilityHint
        #expect(hint.localizedCaseInsensitiveContains("share"))
        #expect(hint.localizedCaseInsensitiveContains("body"))
        #expect(hint.localizedCaseInsensitiveContains("toggle"))
        #expect(!hint.localizedCaseInsensitiveContains("try-on"))
        // Me Delete all VO — confirm + permanent wipe (parity with export hint).
        let delHint = DataLifecycleService.deleteAllButtonAccessibilityHint
        #expect(delHint.localizedCaseInsensitiveContains("confirm"))
        #expect(delHint.localizedCaseInsensitiveContains("permanent"))
        #expect(!delHint.localizedCaseInsensitiveContains("try-on"))
        #expect(!delHint.localizedCaseInsensitiveContains("share sheet"))
    }

    /// Me export/delete failure chips stay human (no NSError / domain dump).
    @Test func exportAndDeleteFailureMessagesAreCustomerFacing() {
        let exp = DataLifecycleService.exportFailedMessage
        #expect(exp.localizedCaseInsensitiveContains("couldn't export"))
        #expect(exp.localizedCaseInsensitiveContains("try again"))
        #expect(!exp.contains("NSError"))
        #expect(!exp.contains("localizedDescription"))
        let del = DataLifecycleService.deleteAllFailedMessage
        #expect(del.localizedCaseInsensitiveContains("couldn't delete"))
        #expect(del.localizedCaseInsensitiveContains("try again"))
        #expect(!del.contains("error 0"))
    }
}
