import Testing
import SwiftData
import Foundation
@testable import ClosetUI
import ClosetModel
import ClosetCore

@MainActor
struct CopilotViewModelTests {

    func setup() throws -> (ModelContext, Wardrobe, Item) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        let ctx = ModelContext(container)
        let w = Wardrobe(name: "A"); ctx.insert(w)
        func mk(_ name: String, _ slot: String, status: String = "available") -> Item {
            let i = Item(name: name); i.slotRaw = slot; i.wardrobe = w
            i.occasionsRaw = ["work"]; i.warmthRaw = Warmth.light.rawValue
            i.colorHue = 0; i.colorIsNeutral = true; i.statusRaw = status
            ctx.insert(i); return i
        }
        let top = mk("top", "top"); _ = mk("bottom", "bottom"); _ = mk("shoes", "shoes")
        _ = mk("dirtyBottom", "bottom", status: "inWash")
        try ctx.save()
        return (ctx, w, top)
    }

    @Test func copilotRefreshProducesSuggestions() throws {
        let (_, w, top) = try setup()
        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 75)
        vm.toggleAnchor(top)
        #expect(vm.isAnchored(top))
        vm.refresh()
        #expect(!vm.suggestions.isEmpty)
        #expect(vm.suggestions[0].outfit.itemIDs.contains(top.id.uuidString))
    }

    @Test func fullAutoProducesSuggestions() throws {
        let (_, w, _) = try setup()
        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 75)
        vm.fullAuto = true
        vm.refresh()
        #expect(!vm.suggestions.isEmpty)
    }

    @Test func availableItemsExcludesInWash() throws {
        let (_, w, _) = try setup()
        let vm = CopilotViewModel(wardrobe: w)
        #expect(vm.availableItems.allSatisfy { $0.statusRaw == "available" })
        #expect(vm.availableItems.count == 3)   // 4 件中 1 件在洗
    }

    @Test func toggleAnchorAddsAndRemoves() throws {
        let (_, w, top) = try setup()
        let vm = CopilotViewModel(wardrobe: w)
        vm.toggleAnchor(top); #expect(vm.isAnchored(top))
        vm.toggleAnchor(top); #expect(!vm.isAnchored(top))
    }

    @Test func refreshAcceptsBodyShapeAndWornIDs() throws {
        let (_, w, top) = try setup()
        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 75)
        vm.bodyShape = .hourglass
        vm.wornWithin7DaysIDs = ["some-other-id"]
        vm.toggleAnchor(top)
        vm.refresh()
        #expect(!vm.suggestions.isEmpty)
    }
}
