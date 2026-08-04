import Testing
import SwiftData
import Foundation
@testable import ClosetModel
import ClosetCore

@MainActor
struct OutfitAvatarComposerTests {

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    @Test func dressDropsTopBottom() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        func mk(_ name: String, _ slot: String) -> Item {
            let i = Item(name: name); i.slotRaw = slot; i.wardrobe = w
            ctx.insert(i); return i
        }
        let d = mk("d", "dress")
        let t = mk("t", "top")
        let b = mk("b", "bottom")
        let s = mk("s", "shoes")
        try ctx.save()
        let layers = OutfitAvatarComposer.layers(from: [d, t, b, s])
        let slots = Set(layers.map(\.slot))
        #expect(slots.contains(.dress))
        #expect(slots.contains(.shoes))
        #expect(!slots.contains(.top))
        #expect(!slots.contains(.bottom))
    }

    @Test func prefersItemWithImage() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let bare = Item(name: "bare"); bare.slotRaw = "top"; bare.wardrobe = w; ctx.insert(bare)
        let pic = Item(name: "pic"); pic.slotRaw = "top"; pic.wardrobe = w
        pic.localImageRelativePath = "ItemImages/x.jpg"; ctx.insert(pic)
        try ctx.save()
        let layers = OutfitAvatarComposer.layers(from: [bare, pic])
        #expect(layers.count == 1)
        #expect(layers[0].localRelativePath == "ItemImages/x.jpg")
        #expect(layers[0].id.contains(pic.id.uuidString))
    }
}
