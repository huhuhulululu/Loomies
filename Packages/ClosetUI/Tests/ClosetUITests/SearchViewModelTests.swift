import Testing
import SwiftData
import Foundation
@testable import ClosetUI
import ClosetModel
import ClosetCore
import ClosetIntake

@MainActor
struct SearchViewModelTests {

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    @Test func runFindsByText() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "Navy Blazer"); i.wardrobe = w; ctx.insert(i)
        try ctx.save()

        let vm = SearchViewModel()
        vm.text = "navy"
        vm.run(in: ctx)
        #expect(vm.results.count == 1)
        #expect(vm.results[0].name == "Navy Blazer")
    }

    @Test func clearResetsFiltersAndResults() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "Tee"); i.wardrobe = w; ctx.insert(i)
        try ctx.save()
        let vm = SearchViewModel()
        vm.text = "tee"; vm.slotRaw = "top"; vm.run(in: ctx)
        #expect(!vm.results.isEmpty)
        vm.clear()
        #expect(vm.text.isEmpty)
        #expect(vm.slotRaw == nil)
        #expect(vm.results.isEmpty)
    }

    @Test func emptyQueryShowsNoMatchesAndClearKeepsWardrobe() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "Tee"); i.slotRaw = "top"; i.wardrobe = w; ctx.insert(i)
        try ctx.save()

        let vm = SearchViewModel()
        vm.wardrobeID = w.id
        #expect(!vm.isFiltering)
        #expect(vm.emptyStateTitle == "No pieces here")
        #expect(vm.emptyStateDescription.localizedCaseInsensitiveContains("add a piece"))
        vm.text = "zzzz-no-match"
        #expect(vm.isFiltering)
        vm.run(in: ctx)
        #expect(vm.results.isEmpty)
        #expect(vm.emptyStateTitle == "No matches")
        #expect(vm.emptyStateDescription.localizedCaseInsensitiveContains("filter"))
        #expect(!vm.emptyStateDescription.localizedCaseInsensitiveContains("try-on"))
        #expect(!vm.emptyStateTitle.localizedCaseInsensitiveContains("error"))

        vm.slotRaw = "shoes"
        #expect(vm.isFiltering)
        vm.clearFiltersKeepingWardrobe()
        #expect(vm.text.isEmpty)
        #expect(vm.slotRaw == nil)
        #expect(vm.wardrobeID == w.id)
        #expect(vm.emptyStateTitle == "No pieces here")
        vm.run(in: ctx)
        #expect(vm.results.count == 1)
    }

    /// Closet search chips must cover every GarmentSlot (incl. accessory) with displayTitle labels.
    @Test func slotFilterIncludesAccessoryAndAllCases() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let belt = Item(name: "Leather Belt"); belt.slotRaw = "accessory"; belt.wardrobe = w
        ctx.insert(belt)
        let tee = Item(name: "White Tee"); tee.slotRaw = "top"; tee.wardrobe = w
        ctx.insert(tee)
        try ctx.save()

        // Chip set contract: UI ForEach(GarmentSlot.allCases) — accessory must be present.
        #expect(GarmentSlot.allCases.contains(.accessory))
        #expect(GarmentSlot.accessory.displayTitle == "Accessory")
        #expect(Set(GarmentSlot.allCases.map(\.rawValue)).count == GarmentSlot.allCases.count)

        let vm = SearchViewModel()
        vm.wardrobeID = w.id
        vm.slotRaw = GarmentSlot.accessory.rawValue
        vm.run(in: ctx)
        #expect(vm.results.map(\.name) == ["Leather Belt"])
        #expect(!vm.results.contains { $0.name == "White Tee" })

        vm.slotRaw = GarmentSlot.top.rawValue
        vm.run(in: ctx)
        #expect(vm.results.map(\.name) == ["White Tee"])
    }

    /// Search status facet (grid carries into search) — find laundry-only without losing type chip.
    @Test func statusFilterFindsInWashAndClearsWithWardrobe() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let ready = Item(name: "Office Shirt"); ready.slotRaw = "top"; ready.statusRaw = "available"
        ready.wardrobe = w; ctx.insert(ready)
        let wash = Item(name: "Weekend Tee"); wash.slotRaw = "top"; wash.statusRaw = "inWash"
        wash.wardrobe = w; ctx.insert(wash)
        try ctx.save()

        #expect(ItemStatusService.allowed.contains("inWash"))

        let vm = SearchViewModel()
        vm.wardrobeID = w.id
        vm.statusRaw = "inWash"
        #expect(vm.isFiltering)
        vm.run(in: ctx)
        #expect(vm.results.map(\.name) == ["Weekend Tee"])

        // Combined type + status (grid facets carried into search).
        vm.slotRaw = GarmentSlot.top.rawValue
        vm.run(in: ctx)
        #expect(vm.results.map(\.name) == ["Weekend Tee"])

        vm.clearFiltersKeepingWardrobe()
        #expect(vm.statusRaw == nil)
        #expect(vm.slotRaw == nil)
        #expect(vm.wardrobeID == w.id)
        #expect(!vm.isFiltering)
        vm.run(in: ctx)
        #expect(Set(vm.results.map(\.name)) == Set(["Office Shirt", "Weekend Tee"]))
    }

    /// Closet/Search meta line: type · status · optional storage (detail assign surface).
    @Test func closetItemRowMetaLineIncludesLocationWhenSet() {
        #expect(ClosetItemRowCopy.metaLine(
            slotDisplayTitle: "Top",
            statusDisplayName: "Available") == "Top · Available")
        #expect(ClosetItemRowCopy.metaLine(
            slotDisplayTitle: "Top",
            statusDisplayName: "In wash",
            locationName: "  Rod  ") == "Top · In wash · Rod")
        #expect(ClosetItemRowCopy.metaLine(
            slotDisplayTitle: "Shoes",
            statusDisplayName: "Available",
            locationName: "   ") == "Shoes · Available")
        // Live item: dirty blazer slot + location name.
        let i = Item(name: "Navy Blazer"); i.slotRaw = "top"; i.statusRaw = "available"
        let loc = StorageLocation(name: "Rail A"); i.location = loc
        #expect(ClosetItemRowCopy.metaLine(for: i) == "Outerwear · Available · Rail A")
        i.location = nil
        #expect(ClosetItemRowCopy.metaLine(for: i) == "Outerwear · Available")
        #expect(!ClosetItemRowCopy.metaLine(for: i).localizedCaseInsensitiveContains("try-on"))
    }

    /// Grid empty copy mirrors facets (status/type) and stays honest for VoiceOver.
    @Test func closetGridEmptyCopyMatchesFacetState() {
        #expect(ClosetGridEmptyCopy.title(isFacetFiltering: false) == "Empty closet")
        #expect(ClosetGridEmptyCopy.title(isFacetFiltering: true) == "No matches")
        let bare = ClosetGridEmptyCopy.description(
            isFacetFiltering: false, hasSlotFilter: false, hasStatusFilter: false)
        #expect(bare.localizedCaseInsensitiveContains("add a piece"))
        #expect(!bare.localizedCaseInsensitiveContains("try-on"))
        let both = ClosetGridEmptyCopy.description(
            isFacetFiltering: true, hasSlotFilter: true, hasStatusFilter: true)
        #expect(both.localizedCaseInsensitiveContains("status"))
        #expect(both.localizedCaseInsensitiveContains("type"))
        let typeOnly = ClosetGridEmptyCopy.description(
            isFacetFiltering: true, hasSlotFilter: true, hasStatusFilter: false)
        #expect(typeOnly.localizedCaseInsensitiveContains("type"))
        let statusOnly = ClosetGridEmptyCopy.description(
            isFacetFiltering: true, hasSlotFilter: false, hasStatusFilter: true)
        #expect(statusOnly.localizedCaseInsensitiveContains("status"))
        // Icon-only toolbar chrome (Search / Add) — same honesty bar as Calendar + CTA.
        #expect(ClosetGridEmptyCopy.searchToggleAccessibilityLabel(isSearchOpen: false)
            == "Search closet")
        #expect(ClosetGridEmptyCopy.searchToggleAccessibilityLabel(isSearchOpen: true)
            == "Close search")
        #expect(ClosetGridEmptyCopy.addPieceAccessibilityLabel == "Add piece")
        #expect(ClosetGridEmptyCopy.addPieceAccessibilityLabel
            == IntakeEmptyCopy.chooseTitle)
    }

    /// Closet empty “Load samples” must share Today Outcome flash (no silent ModelSave fail).
    @Test func closetLoadSamplesFlashMatchesSeedOutcome() {
        #expect(DemoSeedService.Outcome.saveFailed.flashMessage
            == DemoSeedService.saveFailedMessage)
        #expect(DemoSeedService.Outcome.saveFailed.flashMessage
            .localizedCaseInsensitiveContains("couldn't load"))
        #expect(!DemoSeedService.Outcome.saveFailed.flashMessage
            .localizedCaseInsensitiveContains("added"))
        #expect(DemoSeedService.Outcome.added(9).flashMessage.contains("9"))
        #expect(DemoSeedService.Outcome.alreadyPopulated.flashMessage
            .localizedCaseInsensitiveContains("already"))
        // Today / Closet / Me Load samples share demo-not-photos VO hint.
        #expect(DemoSeedService.loadButtonAccessibilityHint
            .localizedCaseInsensitiveContains("demo"))
        #expect(DemoSeedService.loadButtonAccessibilityHint
            .localizedCaseInsensitiveContains("not from your photos"))
        // Closet seed + Calendar plan-remove use CustomerFlashStyle fail paint rule.
        #expect(CustomerFlashStyle.isFailure(DemoSeedService.saveFailedMessage))
        #expect(CustomerFlashStyle.isFailure(
            DemoSeedService.Outcome.saveFailed.flashMessage))
        #expect(CustomerFlashStyle.isFailure(
            DemoSeedService.Outcome.saveFailed.meDemoFlashMessage))
        #expect(!CustomerFlashStyle.isFailure(
            DemoSeedService.Outcome.added(3).flashMessage))
        #expect(!CustomerFlashStyle.isFailure(
            DemoSeedService.Outcome.alreadyPopulated.flashMessage))
        #expect(CustomerFlashStyle.isFailure(CalendarPlanService.removeSaveFailedMessage))
        #expect(!CustomerFlashStyle.isFailure("Added to calendar."))
    }

    /// QuickAdd ModelSave fail must surface the same toast as manual Add (not silent stay).
    @Test func quickAddSaveFailedMessageIsHonest() {
        #expect(QuickAddSheet.saveFailedMessage == IntakeViewModel.confirmSaveFailedMessage)
        #expect(QuickAddSheet.saveFailedMessage.localizedCaseInsensitiveContains("couldn't save"))
        #expect(QuickAddSheet.saveFailedMessage.localizedCaseInsensitiveContains("try again"))
        #expect(!QuickAddSheet.saveFailedMessage.localizedCaseInsensitiveContains("try-on"))
    }

    /// Occasion facet (work/casual/date/gala chips) — SearchService contains match + clear.
    @Test func occasionFilterFindsWorkAndClearsWithWardrobe() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let office = Item(name: "Blazer"); office.slotRaw = "outerwear"
        office.occasionsRaw = ["work"]; office.wardrobe = w; ctx.insert(office)
        let weekend = Item(name: "Tee"); weekend.slotRaw = "top"
        weekend.occasionsRaw = ["casual"]; weekend.wardrobe = w; ctx.insert(weekend)
        try ctx.save()

        let vm = SearchViewModel()
        vm.wardrobeID = w.id
        vm.occasion = "work"
        #expect(vm.isFiltering)
        vm.run(in: ctx)
        #expect(vm.results.map(\.name) == ["Blazer"])

        vm.occasion = "casual"
        vm.run(in: ctx)
        #expect(vm.results.map(\.name) == ["Tee"])

        vm.clearFiltersKeepingWardrobe()
        #expect(vm.occasion == nil)
        #expect(vm.wardrobeID == w.id)
        #expect(!vm.isFiltering)
        vm.run(in: ctx)
        #expect(Set(vm.results.map(\.name)) == Set(["Blazer", "Tee"]))
    }
}
