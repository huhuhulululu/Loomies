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
        #expect(vm.message.isEmpty)
        #expect(vm.wardrobes.count == 1)
        // ModelSave commit (not silent try?)
        let fetched = try ctx.fetch(FetchDescriptor<Wardrobe>())
        #expect(fetched.contains { $0.name == "Paris" })
    }

    @Test func createRequiresName() throws {
        let ctx = try makeContext()
        let person = Person(name: "Alex"); ctx.insert(person)
        let vm = WardrobeSwitcherViewModel(person: person)
        vm.newName = "   "
        #expect(vm.createWardrobe(in: ctx) == nil)
        #expect(vm.message == WardrobeManageActions.needNameMessage)
        #expect(vm.message.localizedCaseInsensitiveContains("name"))
        #expect(try ctx.fetch(FetchDescriptor<Wardrobe>()).isEmpty)
        // Switcher + Manage list share fail/need-name voice (no dual hardcoded strings).
        #expect(WardrobeManageActions.createFailedMessage
            .localizedCaseInsensitiveContains("couldn't create"))
        #expect(CustomerFlashStyle.isFailure(WardrobeManageActions.createFailedMessage))
        #expect(!CustomerFlashStyle.isFailure(WardrobeManageActions.needNameMessage))
    }

    /// Me → Wardrobes list create — honest name gate + commit (no silent “Created” on empty).
    @Test func manageCreateRequiresNameAndCommits() throws {
        let ctx = try makeContext()
        let empty = WardrobeManageActions.create(
            name: "  ", city: "NYC", existingPeople: [], in: ctx)
        #expect(empty.wardrobe == nil)
        #expect(empty.message == WardrobeManageActions.needNameMessage)
        #expect(try ctx.fetch(FetchDescriptor<Wardrobe>()).isEmpty)

        let person = Person(name: "Alex"); ctx.insert(person)
        try ctx.save()
        let ok = WardrobeManageActions.create(
            name: "Paris", city: "Paris", existingPeople: [person], in: ctx)
        #expect(ok.wardrobe?.name == "Paris")
        #expect(ok.wardrobe?.locationCity == "Paris")
        #expect(ok.message == WardrobeManageActions.createdMessage("Paris"))
        #expect(!ok.message.localizedCaseInsensitiveContains("couldn't"))
        let fetched = try ctx.fetch(FetchDescriptor<Wardrobe>())
        #expect(fetched.contains { $0.name == "Paris" && $0.owner?.id == person.id })
    }

    /// Me Wardrobes list meta — empty city is Title Case “No city”, not “no city”.
    @Test func manageListSubtitleCityCopyIsHuman() {
        #expect(WardrobeManageActions.listSubtitle(itemCount: 0, locationCity: nil)
            == "0 items · No city")
        #expect(WardrobeManageActions.listSubtitle(itemCount: 3, locationCity: "  ")
            == "3 items · No city")
        #expect(WardrobeManageActions.listSubtitle(itemCount: 2, locationCity: "Chicago")
            == "2 items · Chicago")
        #expect(WardrobeManageActions.noCityCaption == "No city")
        #expect(WardrobeManageActions.noCityCaption != "no city")
    }

    /// Empty closets list VO — points to Add form; no try-on / sync claims.
    @Test func manageEmptyListCopyIsHonestForVoiceOver() {
        #expect(WardrobeManageActions.emptyListMessage
            .localizedCaseInsensitiveContains("no closets"))
        #expect(WardrobeManageActions.emptyListMessage
            .localizedCaseInsensitiveContains("add"))
        #expect(!WardrobeManageActions.emptyListMessage
            .localizedCaseInsensitiveContains("try-on"))
        #expect(!WardrobeManageActions.emptyListMessage
            .localizedCaseInsensitiveContains("sync"))
        #expect(!CustomerFlashStyle.isFailure(WardrobeManageActions.emptyListMessage))
        #expect(CustomerFlashStyle.isFailure(WardrobeManageActions.createFailedMessage))
    }
}
