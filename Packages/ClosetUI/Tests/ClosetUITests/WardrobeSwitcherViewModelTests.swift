import Testing
import SwiftData
import Foundation
@testable import ClosetUI
import ClosetModel

@MainActor
struct WardrobeSwitcherViewModelTests {

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    @Test func selectsAndListsWardrobes() throws {
        let ctx = try makeContext()
        let person = Person(name: "Alex"); ctx.insert(person)
        let nyc = Wardrobe(name: "NYC"); nyc.owner = person; ctx.insert(nyc)
        let bkk = Wardrobe(name: "BKK"); bkk.owner = person; ctx.insert(bkk)
        try ctx.save()

        let vm = WardrobeSwitcherViewModel(person: person)
        #expect(vm.wardrobes.count == 2)
        #expect(vm.active != nil)
        vm.select(bkk)
        #expect(vm.active?.id == bkk.id)
    }

    @Test func createWardrobeSetsActive() throws {
        let ctx = try makeContext()
        let person = Person(name: "Alex"); ctx.insert(person)
        try ctx.save()
        let vm = WardrobeSwitcherViewModel(person: person)
        #expect(vm.active == nil)
        vm.newName = "Paris"
        vm.newCity = "Paris"
        let w = vm.createWardrobe(in: ctx)
        #expect(w?.name == "Paris")
        #expect(w?.locationCity == "Paris")
        #expect(vm.active?.id == w?.id)
        #expect(vm.newName.isEmpty)
        #expect(vm.wardrobes.count == 1)
    }

    @Test func createRequiresName() throws {
        let ctx = try makeContext()
        let person = Person(name: "Alex"); ctx.insert(person)
        let vm = WardrobeSwitcherViewModel(person: person)
        vm.newName = "   "
        #expect(vm.createWardrobe(in: ctx) == nil)
    }
}
