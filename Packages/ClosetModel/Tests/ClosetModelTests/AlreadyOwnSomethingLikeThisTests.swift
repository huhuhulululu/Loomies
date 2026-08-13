import Testing
import Foundation
import SwiftData
@testable import ClosetModel
import ClosetCore

/// D120：**「我是不是已经有类似的了？」**
///
/// DEMAND-VALIDATION §2 的 PIVOT 把「记住我哪天穿了什么 / 防重复购买」
/// 记为研究里的 #1 JTBD（19 次自发提及）。D119 做完了前半句（穿着回读），
/// 这条做后半句：**站在店里、手上一件海军蓝毛衣**，想知道柜里已经有几件。
///
/// 检索此前只能按 name/brand 文本、槽位、场合、状态筛——
/// 而在店里那一刻，用户脑子里的检索词就是**颜色 + 品类**，不是名字。
///
/// 设计取舍：颜色按**色板条目**匹配已存的 hue/isNeutral，不引入新字段
/// （schema 单向门 D84）；「有几件」直接给数，不给相似度分数——
/// 那种数字用户没法验证也没法用。
@MainActor
struct AlreadyOwnSomethingLikeThisTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    private func item(
        _ ctx: ModelContext, _ w: Wardrobe, _ name: String, _ slot: String, paletteID: String?
    ) -> Item {
        let i = Item(name: name)
        i.slotRaw = slot
        i.statusRaw = "available"
        i.wardrobe = w
        if let paletteID,
           let entry = GarmentColorPalette.entries.first(where: { $0.id == paletteID }) {
            i.colorHue = entry.hueDegrees
            i.colorIsNeutral = entry.isNeutral
        }
        ctx.insert(i)
        return i
    }

    /// 按颜色筛：只返回那个颜色的件。
    @Test func filteringByColourReturnsOnlyThatColour() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        _ = item(ctx, w, "Navy sweater", "top", paletteID: "navy")
        _ = item(ctx, w, "Navy cardigan", "top", paletteID: "navy")
        _ = item(ctx, w, "Red sweater", "top", paletteID: "red")
        _ = item(ctx, w, "Untagged sweater", "top", paletteID: nil)
        try ctx.save()

        var q = SearchService.Query()
        q.colorPaletteID = "navy"
        let hits = SearchService.searchItems(q, in: ctx)
        #expect(hits.map(\.name) == ["Navy cardigan", "Navy sweater"])
    }

    /// 颜色 + 品类一起筛——店里那一刻的真实问题是「我有几件海军蓝**上衣**」。
    @Test func colourCombinesWithSlot() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        _ = item(ctx, w, "Navy sweater", "top", paletteID: "navy")
        _ = item(ctx, w, "Navy trousers", "bottom", paletteID: "navy")
        try ctx.save()

        var q = SearchService.Query()
        q.colorPaletteID = "navy"
        q.slotRaw = "top"
        #expect(SearchService.searchItems(q, in: ctx).map(\.name) == ["Navy sweater"])
    }

    /// **未标颜色的件不算命中**——三值语义：未知就是未知，不能替用户猜成某个颜色。
    @Test func anUntaggedPieceIsNotAMatch() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        _ = item(ctx, w, "Untagged", "top", paletteID: nil)
        try ctx.save()

        var q = SearchService.Query()
        q.colorPaletteID = "navy"
        #expect(SearchService.searchItems(q, in: ctx).isEmpty)
    }

    /// 不筛颜色时行为不变（这条改动不得影响既有检索）。
    @Test func withoutAColourNothingChanges() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        _ = item(ctx, w, "Navy sweater", "top", paletteID: "navy")
        _ = item(ctx, w, "Untagged", "top", paletteID: nil)
        try ctx.save()
        #expect(SearchService.searchItems(SearchService.Query(), in: ctx).count == 2)
    }

    /// 相近色也算同一色板条目：hue 有偏差的存量数据不该漏掉。
    /// （用户录入时选的就是色板，偏差来自早期自动打标。）
    @Test func aNearbyHueStillMatchesThePaletteEntry() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let navy = try #require(GarmentColorPalette.entries.first { $0.id == "navy" })
        let i = Item(name: "Almost navy")
        i.slotRaw = "top"; i.statusRaw = "available"; i.wardrobe = w
        i.colorHue = navy.hueDegrees + 6      // 色板容差内
        i.colorIsNeutral = navy.isNeutral
        ctx.insert(i)
        try ctx.save()

        var q = SearchService.Query()
        q.colorPaletteID = "navy"
        #expect(SearchService.searchItems(q, in: ctx).count == 1)
    }

    /// 中性/彩色是不同维度：同 hue 但一个中性一个不中性，不是一回事。
    @Test func neutralAndChromaticAreNotInterchangeable() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let red = try #require(GarmentColorPalette.entries.first { $0.id == "red" })
        let i = Item(name: "Neutral at red hue")
        i.slotRaw = "top"; i.statusRaw = "available"; i.wardrobe = w
        i.colorHue = red.hueDegrees
        i.colorIsNeutral = true               // red 是 isNeutral=false
        ctx.insert(i)
        try ctx.save()

        var q = SearchService.Query()
        q.colorPaletteID = "red"
        #expect(SearchService.searchItems(q, in: ctx).isEmpty)
    }

    /// 结果计数：给用户一个能直接读出来的数（「你已经有 4 件」）。
    @Test func theCountReadsAsASentence() {
        #expect(SearchService.resultsHeadline(count: 0) == "Nothing like that yet")
        #expect(SearchService.resultsHeadline(count: 1) == "You already have 1")
        #expect(SearchService.resultsHeadline(count: 4) == "You already have 4")
    }
}
