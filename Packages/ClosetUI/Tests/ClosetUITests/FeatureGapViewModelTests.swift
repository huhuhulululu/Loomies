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

    @Test func itemDetailDeleteRemovesItemAndMarksOutfitMissing() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Home"); ctx.insert(w)
        let i = Item(name: "old tee"); i.slotRaw = "top"; i.wardrobe = w; ctx.insert(i)
        let o = Outfit(name: "look"); o.isFavorite = true; o.wardrobe = w
        o.items = [i]; ctx.insert(o)
        try ctx.save()
        let id = i.id
        let vm = ItemDetailViewModel(item: i)
        #expect(!vm.didDelete)
        vm.delete(in: ctx)
        #expect(vm.didDelete)
        let left = try ctx.fetch(FetchDescriptor<Item>()).filter { $0.id == id }
        #expect(left.isEmpty)
        #expect(o.permanentlyMissing == true)
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
        vm.bustInches = 36
        vm.waistInches = 26
        vm.hipInches = 36
        vm.highHipInches = 34
        vm.save(in: ctx)
        #expect(vm.isComplete)
        #expect(vm.shapeLabel != nil)
        #expect(vm.liveMeasurements != nil)
        #expect(vm.popularShape == .hourglass)
        #expect(vm.confidence == .measured)
    }

    @Test func bodyProfileLivePreviewWithoutSave() {
        let vm = BodyProfileViewModel(personID: UUID())
        vm.bustInches = 34
        vm.waistInches = 30
        vm.hipInches = 42
        vm.highHipInches = 38
        vm.refreshPreview()
        #expect(vm.isComplete)
        #expect(vm.popularShape == .pear)
        #expect(vm.liveMeasurements?.hip == 42)
    }

    @Test func bodyProfileQuickPickWithoutMeasures() throws {
        let ctx = try makeContext()
        let pid = UUID()
        let vm = BodyProfileViewModel(personID: pid)
        vm.selectPopularShape(.apple, in: ctx)
        #expect(vm.selectedPopular == .apple)
        #expect(vm.popularShape == .apple)
        #expect(vm.confidence == .visualOnly)
        #expect(!vm.isComplete)
        #expect(vm.profile?.popularShapeOverrideRaw == PopularShape.apple.rawValue)
    }

    @Test func bodyProfileInferHighHip() {
        let vm = BodyProfileViewModel(personID: UUID())
        vm.waistInches = 28
        vm.hipInches = 40
        vm.applyInferredHighHip()
        #expect(vm.highHipInferred)
        #expect(vm.highHipInches != nil)
        #expect(vm.highHipInches! > 28 && vm.highHipInches! < 40)
    }

    @Test func bodyProfileMetricDisplay() {
        let vm = BodyProfileViewModel(personID: UUID())
        vm.bustInches = 36
        vm.usesMetric = true
        let s = vm.displayValue(inches: 36)
        #expect(s == "91" || s.hasPrefix("91"))
    }

    @Test func bodyMorphUpdatesWithFineTune() {
        let vm = BodyProfileViewModel(personID: UUID())
        vm.selectedPopular = .hourglass
        vm.refreshPreview()
        let baseWaist = vm.morph.waist
        vm.fineWaist = 0.92
        vm.refreshPreview()
        #expect(vm.morph.waist < baseWaist)
        vm.resetFineTune()
        #expect(abs(vm.fineWaist - 1) < 0.001)
    }

    @Test func bodyMorphFromMeasurements() {
        let vm = BodyProfileViewModel(personID: UUID())
        vm.bustInches = 40
        vm.waistInches = 26
        vm.hipInches = 40
        vm.highHipInches = 34
        vm.refreshPreview()
        #expect(vm.morph.chest > 1.0)
        #expect(vm.morph.waist < 1.0)
    }

    @Test func bodyFineTunePersistsAcrossLoad() throws {
        let ctx = try makeContext()
        let pid = UUID()
        let vm = BodyProfileViewModel(personID: pid)
        vm.selectedPopular = .pear
        vm.fineChest = 1.05
        vm.fineWaist = 0.94
        vm.fineHip = 1.08
        vm.fineHeight = 1.02
        vm.save(in: ctx)
        let vm2 = BodyProfileViewModel(personID: pid)
        vm2.load(in: ctx)
        #expect(abs(vm2.fineChest - 1.05) < 0.001)
        #expect(abs(vm2.fineWaist - 0.94) < 0.001)
        #expect(abs(vm2.fineHip - 1.08) < 0.001)
        #expect(abs(vm2.fineHeight - 1.02) < 0.001)
        #expect(vm2.morph.hip > 1.0)
    }

    @Test func outfitActionsSaveAndPlan() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        func mk(_ n: String, _ s: String) -> Item {
            let i = Item(name: n); i.slotRaw = s; i.wardrobe = w
            i.occasionsRaw = ["work"]; i.warmthRaw = Warmth.light.rawValue
            i.colorIsNeutral = true; i.statusRaw = "available"; ctx.insert(i); return i
        }
        let t = mk("t", "top"); let _ = mk("b", "bottom"); let _ = mk("s", "shoes")
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
