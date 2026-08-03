import Testing
import SwiftData
import Foundation
@testable import ClosetUI
import ClosetModel
import ClosetCore

@MainActor
struct CopilotViewModelTests {

    init() {
        // 避免 DebugSettings 单例污染用例
        DebugSettings.shared.forceColdStart = false
        DebugSettings.shared.disableAntiRepeat = false
        AppLog.setMinLevel(.debug)
    }

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
        // setup 仅 3 件会触发冷启动；本用例测 full-auto 本身，压低阈值
        vm.coldStartThreshold = 1
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

    @Test func coldStartBlocksFullAutoWithoutAnchor() throws {
        let (_, w, top) = try setup()
        // setup 有 3 available < default threshold 8 → cold start
        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 75)
        #expect(vm.isColdStart)
        vm.fullAuto = true
        vm.refresh()
        #expect(vm.suggestions.isEmpty)  // 无锚定 → 空

        vm.toggleAnchor(top)
        vm.refresh()
        #expect(!vm.suggestions.isEmpty) // 有锚定 → 可补全
    }

    @Test func coldStartWithoutAnchorSetsStatusMessage() throws {
        let (_, w, _) = try setup()
        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 75)
        vm.refresh()
        #expect(vm.suggestions.isEmpty)
        #expect(vm.statusMessage.contains("Cold start") || vm.statusMessage.contains("anchor"))
        #expect(vm.lastRefreshMS >= 0)
    }

    @Test func largeClosetAllowsFullAuto() throws {
        let (ctx, w, _) = try setup()
        DebugSettings.shared.forceColdStart = false
        // 再塞够件数越过阈值
        for i in 0..<10 {
            let item = Item(name: "extra\(i)")
            item.slotRaw = i % 2 == 0 ? "top" : "bottom"
            item.wardrobe = w
            item.occasionsRaw = ["work"]
            item.warmthRaw = Warmth.light.rawValue
            item.colorIsNeutral = true
            item.statusRaw = "available"
            ctx.insert(item)
        }
        // 再补鞋若干
        for i in 0..<3 {
            let s = Item(name: "shoes\(i)"); s.slotRaw = "shoes"; s.wardrobe = w
            s.occasionsRaw = ["work"]; s.warmthRaw = Warmth.light.rawValue
            s.colorIsNeutral = true; s.statusRaw = "available"; ctx.insert(s)
        }
        try ctx.save()
        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 75)
        #expect(!vm.isColdStart)
        vm.fullAuto = true
        vm.refresh()
        #expect(!vm.suggestions.isEmpty)
    }
}
