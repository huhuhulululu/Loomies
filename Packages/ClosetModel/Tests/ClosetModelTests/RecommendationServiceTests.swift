import Testing
import SwiftData
import Foundation
@testable import ClosetModel
import ClosetCore

@MainActor
struct RecommendationServiceTests {

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    @discardableResult
    func mk(_ ctx: ModelContext, _ w: Wardrobe, _ name: String, _ slot: String,
            status: String = "available", attrs: [String] = []) -> Item {
        let i = Item(name: name); i.slotRaw = slot; i.wardrobe = w
        i.occasionsRaw = ["work"]; i.warmthRaw = Warmth.light.rawValue
        i.colorHue = 0; i.colorIsNeutral = true; i.statusRaw = status; i.attributesRaw = attrs
        ctx.insert(i); return i
    }

    @Test func copilotCompletesFromWardrobe() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let top = mk(ctx, w, "top", "top"); mk(ctx, w, "bottom", "bottom"); mk(ctx, w, "shoes", "shoes")
        try ctx.save()
        let out = RecommendationService.suggestions(
            for: w, anchors: [top], occasion: "work", daytimeTempF: 75, maxSuggestions: 3)
        #expect(!out.isEmpty)
        #expect(out[0].outfit.itemIDs.contains(top.id.uuidString))
        for s in out { #expect(OutfitGrammar.isValid(s.outfit.items)) }
    }

    @Test func fullAutoWithoutAnchors() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        mk(ctx, w, "top", "top"); mk(ctx, w, "bottom", "bottom"); mk(ctx, w, "shoes", "shoes")
        try ctx.save()
        let out = RecommendationService.suggestions(for: w, occasion: "work", daytimeTempF: 75)
        #expect(!out.isEmpty)   // 无锚定 = full-auto，仍产出合规搭配
        for s in out { #expect(OutfitGrammar.isValid(s.outfit.items)) }
    }

    @Test func crossWardrobeIsolationEnforcedAtSource() throws {
        let ctx = try makeContext()
        let a = Wardrobe(name: "A"); let b = Wardrobe(name: "B"); ctx.insert(a); ctx.insert(b)
        let topA = mk(ctx, a, "topA", "top")
        mk(ctx, b, "bottomB", "bottom"); mk(ctx, b, "shoesB", "shoes")  // 补件全在 B
        try ctx.save()
        // 锚定 A 的上装、为 A 求建议——B 的下装/鞋绝不能入候选 → 补不出（A 只有上装）
        let out = RecommendationService.suggestions(for: a, anchors: [topA], occasion: "work", daytimeTempF: 75)
        #expect(out.isEmpty)   // 搭配不跨柜：B 的件不可用
    }

    @Test func excludesInWashItems() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let top = mk(ctx, w, "top", "top")
        mk(ctx, w, "bottom", "bottom", status: "inWash")   // 唯一下装在洗
        mk(ctx, w, "shoes", "shoes")
        try ctx.save()
        let out = RecommendationService.suggestions(for: w, anchors: [top], occasion: "work", daytimeTempF: 75)
        #expect(out.isEmpty)   // 在洗件不入候选
    }
}
