import Testing
import SwiftData
import Foundation
@testable import ClosetUI
import ClosetModel

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
        vm.text = "zzzz-no-match"
        #expect(vm.isFiltering)
        vm.run(in: ctx)
        #expect(vm.results.isEmpty)

        vm.slotRaw = "shoes"
        #expect(vm.isFiltering)
        vm.clearFiltersKeepingWardrobe()
        #expect(vm.text.isEmpty)
        #expect(vm.slotRaw == nil)
        #expect(vm.wardrobeID == w.id)
        vm.run(in: ctx)
        #expect(vm.results.count == 1)
    }
}
