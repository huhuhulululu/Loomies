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

    @Test func workLookStacksTeeBlazerTrousersShoes() throws {
        // 纸娃娃正确穿衣：外套与上衣可同屏；z-order 鞋 < 裤 < 上衣 < 外套
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        func mk(_ name: String, _ slot: String, _ path: String) -> Item {
            let i = Item(name: name)
            i.slotRaw = slot
            i.localImageRelativePath = path
            i.wardrobe = w
            ctx.insert(i)
            return i
        }
        let tee = mk("White tee", "top", "ItemImages/tee.png")
        // 脏数据：blazer 误标 top → displaySlot 应纠到 outerwear
        let blazer = mk("Navy blazer", "top", "ItemImages/blazer.png")
        let pants = mk("Black trousers", "bottom", "ItemImages/pants.png")
        let shoes = mk("White sneakers", "shoes", "ItemImages/shoes.png")
        try ctx.save()
        let layers = OutfitAvatarComposer.layers(from: [tee, blazer, pants, shoes])
        let bySlot = Dictionary(uniqueKeysWithValues: layers.map { ($0.slot, $0) })
        #expect(bySlot[.top] != nil)
        #expect(bySlot[.outerwear] != nil)
        #expect(bySlot[.bottom] != nil)
        #expect(bySlot[.shoes] != nil)
        #expect(bySlot[.top]?.localRelativePath == "ItemImages/tee.png")
        #expect(bySlot[.outerwear]?.localRelativePath == "ItemImages/blazer.png")
        #expect(OutfitAvatarComposer.hasVisibleGarments(layers))
        #expect(OutfitAvatarComposer.wearSummary(of: layers).contains("top"))
        #expect(OutfitAvatarComposer.wearSummary(of: layers).contains("outer"))
        // z-order ascending sort from composer
        let zs = layers.map(\.zIndex)
        #expect(zs == zs.sorted())
        #expect(bySlot[.shoes]!.zIndex < bySlot[.bottom]!.zIndex)
        #expect(bySlot[.bottom]!.zIndex < bySlot[.top]!.zIndex)
        #expect(bySlot[.top]!.zIndex < bySlot[.outerwear]!.zIndex)
    }

    @Test func mapSlotAliasesSupportCommonNames() {
        #expect(BodyAvatarComposer.mapSlot("blazer") == .outerwear)
        #expect(BodyAvatarComposer.mapSlot("jeans") == .bottom)
        #expect(BodyAvatarComposer.mapSlot("sneakers") == .shoes)
        #expect(BodyAvatarComposer.displaySlot(slotRaw: "top", itemName: "Navy Blazer") == .outerwear)
        #expect(BodyAvatarComposer.displaySlot(slotRaw: "top", itemName: "White tee") == .top)
    }

    @Test func sameSlotBothWithImagesLaterWins() throws {
        // 同槽都有图 → 数组中靠后的覆盖（outfit 顺序靠调用方保证）
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let first = Item(name: "first"); first.slotRaw = "top"; first.wardrobe = w
        first.localImageRelativePath = "ItemImages/first.png"; ctx.insert(first)
        let second = Item(name: "second"); second.slotRaw = "top"; second.wardrobe = w
        second.localImageRelativePath = "ItemImages/second.png"; ctx.insert(second)
        try ctx.save()
        let layers = OutfitAvatarComposer.layers(from: [first, second])
        #expect(layers.count == 1)
        #expect(layers[0].localRelativePath == "ItemImages/second.png")
        #expect(layers[0].id.contains(second.id.uuidString))
    }

    @Test func emptyImagePathTreatedAsNoImage() throws {
        // localImageRelativePath == "" 视同无图，输给有图的同槽候选
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let empty = Item(name: "empty"); empty.slotRaw = "bottom"; empty.wardrobe = w
        empty.localImageRelativePath = ""; ctx.insert(empty)
        let pic = Item(name: "pic"); pic.slotRaw = "bottom"; pic.wardrobe = w
        pic.localImageRelativePath = "ItemImages/pants.png"; ctx.insert(pic)
        try ctx.save()
        // 空串在后 → 仍被有图的覆盖
        let layers = OutfitAvatarComposer.layers(from: [pic, empty])
        #expect(layers.count == 1)
        #expect(layers[0].localRelativePath == "ItemImages/pants.png")
        #expect(layers[0].id.contains(pic.id.uuidString))
    }

    @Test func layersByItemIDsMatchesAndIgnoresUnknown() throws {
        // ScoredOutfit → wear 路径：按 id 取件；未知 id 静默忽略不崩
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        func mk(_ name: String, _ slot: String, _ path: String) -> Item {
            let i = Item(name: name)
            i.slotRaw = slot
            i.localImageRelativePath = path
            i.wardrobe = w
            ctx.insert(i)
            return i
        }
        let tee = mk("tee", "top", "ItemImages/tee.png")
        let pants = mk("pants", "bottom", "ItemImages/pants.png")
        _ = mk("coat", "outerwear", "ItemImages/coat.png")
        try ctx.save()
        let ids = [tee.id.uuidString, pants.id.uuidString, UUID().uuidString]
        let layers = OutfitAvatarComposer.layers(itemIDs: ids, in: w)
        let slots = Set(layers.map(\.slot))
        #expect(slots == [.top, .bottom])
        let bySlot = Dictionary(uniqueKeysWithValues: layers.map { ($0.slot, $0) })
        #expect(bySlot[.top]?.id.contains(tee.id.uuidString) == true)
        #expect(bySlot[.bottom]?.id.contains(pants.id.uuidString) == true)
        // 全部 id 不匹配 → undressed，不崩
        let none = OutfitAvatarComposer.layers(itemIDs: [UUID().uuidString], in: w)
        #expect(none.isEmpty)
        #expect(!OutfitAvatarComposer.hasVisibleGarments(none))
        #expect(OutfitAvatarComposer.wearSummary(of: none) == "undressed")
    }

    @Test func demoSeedProducesWearableSilhouettes() throws {
        let ctx = try makeContext()
        let person = Person(name: "Demo")
        ctx.insert(person)
        let w = Wardrobe(name: "Seed")
        w.owner = person
        ctx.insert(w)
        let n = DemoSeedService.seed(w, in: ctx).committedCount
        #expect(n >= 5)
        let items = w.items ?? []
        let layers = OutfitAvatarComposer.layers(from: items)
        #expect(OutfitAvatarComposer.hasVisibleGarments(layers))
        // 至少应有上/下/鞋中的若干层可叠
        let slots = Set(layers.map(\.slot))
        #expect(slots.contains(.top) || slots.contains(.dress))
        #expect(slots.contains(.bottom) || slots.contains(.dress))
        #expect(slots.contains(.shoes))
        #expect(slots.contains(.outerwear), "blazer/coat must stack as outerwear with tops")
        // 每层有本地图 → fullCanvas 路径
        let allVisual = layers.allSatisfy { $0.hasVisual }
        #expect(allVisual)
    }

    @Test func dirtyDressLabeledTopSuppressesRealTopBottom() throws {
        // 脏数据：dress 误标 top → displaySlot 纠到 .dress，压制真 top/bottom（不双重渲染）
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        func mk(_ name: String, _ slot: String, _ path: String) -> Item {
            let i = Item(name: name)
            i.slotRaw = slot
            i.localImageRelativePath = path
            i.wardrobe = w
            ctx.insert(i)
            return i
        }
        let dress = mk("Wrap dress", "top", "ItemImages/dress.png")
        let tee = mk("White tee", "top", "ItemImages/tee.png")
        let pants = mk("Black trousers", "bottom", "ItemImages/pants.png")
        let shoes = mk("White sneakers", "shoes", "ItemImages/shoes.png")
        try ctx.save()
        let layers = OutfitAvatarComposer.layers(from: [dress, tee, pants, shoes])
        let slots = Set(layers.map(\.slot))
        #expect(slots.contains(.dress))
        #expect(slots.contains(.shoes))
        #expect(!slots.contains(.top), "dress must suppress real top — no double render")
        #expect(!slots.contains(.bottom), "dress must suppress real bottom — no double render")
        let dressLayer = layers.first { $0.slot == .dress }
        #expect(dressLayer?.id.contains(dress.id.uuidString) == true)
        #expect(dressLayer?.localRelativePath == "ItemImages/dress.png")
    }

    @Test func skipsUnmappableSlot() throws {
        // displaySlot 返回 nil 的槽位（如 accessory）→ else-continue 丢弃，不产生层
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let belt = Item(name: "Leather belt"); belt.slotRaw = "accessory"
        belt.localImageRelativePath = "ItemImages/belt.png"; belt.wardrobe = w
        ctx.insert(belt)
        let tee = Item(name: "White tee"); tee.slotRaw = "top"
        tee.localImageRelativePath = "ItemImages/tee.png"; tee.wardrobe = w
        ctx.insert(tee)
        try ctx.save()
        let layers = OutfitAvatarComposer.layers(from: [belt, tee])
        #expect(layers.count == 1)
        #expect(layers[0].slot == .top)
        #expect(layers[0].id.contains(tee.id.uuidString))
        #expect(!layers.contains { $0.id.contains(belt.id.uuidString) })
    }

    @Test func wearSummaryFixedOrderAndImagelessSlots() throws {
        // 契约：固定槽位顺序 outer · top · dress · bottom · shoes（与传入数组顺序无关）
        func layer(_ slot: BodyAvatarSlot) -> BodyAvatarLayer {
            BodyAvatarLayer(
                id: slot.rawValue, slot: slot,
                frame: BodyAvatarAnchors.frame(for: slot), zIndex: 0)
        }
        let scrambled = [layer(.shoes), layer(.bottom), layer(.dress), layer(.top), layer(.outerwear)]
        #expect(OutfitAvatarComposer.wearSummary(of: scrambled) == "outer · top · dress · bottom · shoes")
        #expect(OutfitAvatarComposer.wearSummary(of: []) == "undressed")

        // 无图层仍列槽位（供 UI 提示）
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let tee = Item(name: "tee"); tee.slotRaw = "top"; tee.wardrobe = w; ctx.insert(tee)
        let pants = Item(name: "pants"); pants.slotRaw = "bottom"; pants.wardrobe = w; ctx.insert(pants)
        try ctx.save()
        let layers = OutfitAvatarComposer.layers(from: [tee, pants])
        #expect(layers.allSatisfy { !$0.hasVisual })
        #expect(OutfitAvatarComposer.wearSummary(of: layers) == "top · bottom")
    }

    @Test func layersByItemIDsFollowsOutfitOrderForSameSlot() throws {
        // 同槽 last-writer-wins 必须按 outfit 的 itemIDs 顺序，而非 wardrobe.items 的任意顺序
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let topA = Item(name: "topA"); topA.slotRaw = "top"; topA.wardrobe = w
        topA.localImageRelativePath = "ItemImages/a.png"; ctx.insert(topA)
        let topB = Item(name: "topB"); topB.slotRaw = "top"; topB.wardrobe = w
        topB.localImageRelativePath = "ItemImages/b.png"; ctx.insert(topB)
        try ctx.save()
        // itemIDs 后者赢，与 wardrobe.items 内部顺序无关（两个方向都钉住）
        let abWin = OutfitAvatarComposer.layers(
            itemIDs: [topA.id.uuidString, topB.id.uuidString], in: w)
        #expect(abWin.count == 1)
        #expect(abWin[0].id.contains(topB.id.uuidString))
        #expect(abWin[0].localRelativePath == "ItemImages/b.png")
        let baWin = OutfitAvatarComposer.layers(
            itemIDs: [topB.id.uuidString, topA.id.uuidString], in: w)
        #expect(baWin.count == 1)
        #expect(baWin[0].id.contains(topA.id.uuidString))
        #expect(baWin[0].localRelativePath == "ItemImages/a.png")
    }
}
