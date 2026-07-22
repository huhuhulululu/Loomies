import Testing
import SwiftData
import Foundation
@testable import ClosetModel
import ClosetCore

@MainActor
struct AdapterTests {

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    @Test func adapterMapsAllFields() throws {
        let ctx = try makeContext()
        let it = Item(name: "x")
        it.slotRaw = "dress"; it.subtype = "wrapDress"
        it.occasionsRaw = ["gala", "date"]; it.warmthRaw = Warmth.warm.rawValue
        it.colorHue = 180; it.colorIsNeutral = false
        it.attributesRaw = ["wrap", "belt"]; it.statusRaw = "inWash"
        ctx.insert(it)
        let c = it.toCandidateItem()
        #expect(c.slot == .dress)
        #expect(c.subtype == "wrapDress")
        #expect(c.occasions == ["gala", "date"])
        #expect(c.warmth == .warm)
        #expect(c.color?.hueDegrees == 180)
        #expect(c.attributes.contains(.wrap) && c.attributes.contains(.belt))
        #expect(c.status == .inWash)
        #expect(c.id == it.id.uuidString)
    }

    /// 端到端集成：SwiftData 单品 → 适配器 → copilot 补全器 → 合规打分候选。
    @Test func completerRunsOnRealSwiftDataItems() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        func mk(_ name: String, _ slot: String) -> Item {
            let i = Item(name: name); i.slotRaw = slot; i.wardrobe = w
            i.occasionsRaw = ["work"]; i.warmthRaw = Warmth.light.rawValue
            i.colorHue = 0; i.colorIsNeutral = true
            ctx.insert(i); return i
        }
        let top = mk("top", "top"); let bottom = mk("bottom", "bottom"); let shoes = mk("shoes", "shoes")
        try ctx.save()

        let anchor = top.toCandidateItem()
        let pool = [bottom.toCandidateItem(), shoes.toCandidateItem()]
        let out = OutfitCompleter.complete(
            anchors: [anchor], pool: pool,
            context: FilterContext(occasion: "work", daytimeTempF: 75),
            scoring: ScoringContext(), maxSuggestions: 3)

        #expect(!out.isEmpty)
        #expect(out[0].outfit.itemIDs.contains(top.id.uuidString))     // 锚定项在
        for s in out { #expect(OutfitGrammar.isValid(s.outfit.items)) } // 合规
    }
}
