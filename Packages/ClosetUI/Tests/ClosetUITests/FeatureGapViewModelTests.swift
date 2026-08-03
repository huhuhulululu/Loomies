import Testing
import SwiftData
import Foundation
@testable import ClosetUI
import ClosetModel
import ClosetCore

@MainActor
struct FeatureGapViewModelTests {

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    @Test func itemDetailSavesEdits() throws {
        let ctx = try makeContext()
        let i = Item(name: "tee"); i.slotRaw = "top"; ctx.insert(i)
        try ctx.save()
        let vm = ItemDetailViewModel(item: i)
        vm.name = "White tee"
        vm.brand = "Uniqlo"
        vm.statusRaw = "inWash"
        vm.save(in: ctx)
        #expect(i.name == "White tee")
        #expect(i.brand == "Uniqlo")
        #expect(i.statusRaw == "inWash")
    }

    @Test func transferMovesItem() throws {
        let ctx = try makeContext()
        let a = Wardrobe(name: "NYC"); ctx.insert(a)
        let b = Wardrobe(name: "BKK"); ctx.insert(b)
        let i = Item(name: "x"); i.wardrobe = a; ctx.insert(i)
        try ctx.save()
        let vm = TransferViewModel(item: i)
        vm.loadDestinations(in: ctx)
        #expect(vm.destinations.count == 1)
        vm.selectedDestinationID = b.id
        vm.transfer(in: ctx)
        #expect(i.wardrobe?.id == b.id)
    }

    @Test func bodyProfileCompletesFFIT() throws {
        let ctx = try makeContext()
        let pid = UUID()
        let vm = BodyProfileViewModel(personID: pid)
        vm.bust = "36"; vm.waist = "26"; vm.hip = "36"; vm.highHip = "34"
        vm.save(in: ctx)
        #expect(vm.isComplete)
        #expect(vm.shapeLabel != nil)
    }

    @Test func outfitActionsSaveAndPlan() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        func mk(_ n: String, _ s: String) -> Item {
            let i = Item(name: n); i.slotRaw = s; i.wardrobe = w
            i.occasionsRaw = ["work"]; i.warmthRaw = Warmth.light.rawValue
            i.colorIsNeutral = true; i.statusRaw = "available"; ctx.insert(i); return i
        }
        let t = mk("t", "top"); let b = mk("b", "bottom"); let s = mk("s", "shoes")
        try ctx.save()
        let scored = RecommendationService.suggestions(
            for: w, anchors: [t], occasion: "work", daytimeTempF: 75).first
        #expect(scored != nil)
        let actions = OutfitActionsViewModel()
        actions.saveFavorite(scored: scored!, occasion: "work", in: w, context: ctx)
        #expect(OutfitFavoriteService.favorites(in: w).count == 1)
        actions.planToday(scored: scored!, occasion: "work", in: w, context: ctx)
        let plans = try ctx.fetch(FetchDescriptor<CalendarPlan>())
        #expect(!plans.isEmpty)
    }
}
