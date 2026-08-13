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

    /// M1: 外来衣柜的锚定项必须被丢弃，绝不流入建议（跨柜硬约束不依赖调用方过滤）。
    @Test func foreignAnchorDroppedFromSuggestions() throws {
        let ctx = try makeContext()
        let a = Wardrobe(name: "A"); let b = Wardrobe(name: "B"); ctx.insert(a); ctx.insert(b)
        mk(ctx, a, "topA", "top"); mk(ctx, a, "bottomA", "bottom"); mk(ctx, a, "shoesA", "shoes")
        let foreign = mk(ctx, b, "topB", "top")
        try ctx.save()
        let out = RecommendationService.suggestions(
            for: a, anchors: [foreign], occasion: "work", daytimeTempF: 75, maxSuggestions: 3)
        #expect(!out.isEmpty)   // A 自身成套，仍可产出建议
        for s in out {
            #expect(!s.outfit.itemIDs.contains(foreign.id.uuidString))
        }
    }

    /// 个人色季必须真的参与打分，而不是白放着。
    ///
    /// D192：这句原来写的是「Shipped service path」——**而它不是**。
    /// Today 的生产路径在 `CopilotViewModel.makeRefreshRequest` 里自己做映射，
    /// 本文件验的是一条产品不走的路。断言本身仍有价值（打分链的语义），
    /// 但别把它当成生产证据。
    @Test func personalColorSeasonMovesShippedScore() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        func warm(_ name: String, _ slot: String) -> Item {
            let i = mk(ctx, w, name, slot)
            i.colorHue = 0
            i.colorIsNeutral = false
            return i
        }
        let top = warm("top", "top")
        _ = warm("bottom", "bottom")
        _ = warm("shoes", "shoes")
        try ctx.save()
        let autumn = RecommendationService.suggestions(
            for: w, anchors: [top], occasion: "work", daytimeTempF: 75,
            colorSeason: .autumn, maxSuggestions: 1)
        let winter = RecommendationService.suggestions(
            for: w, anchors: [top], occasion: "work", daytimeTempF: 75,
            colorSeason: .winter, maxSuggestions: 1)
        #expect(!autumn.isEmpty && !winter.isEmpty)
        #expect(autumn[0].score.value > winter[0].score.value)
    }
}
