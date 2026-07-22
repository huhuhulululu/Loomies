import Testing
import SwiftData
import Foundation
@testable import ClosetModel

@MainActor
struct DataLayerTests {

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    /// 组一个衣柜 + 若干单品 + 一套搭配的辅助。
    func makeWardrobe(_ ctx: ModelContext, name: String) -> Wardrobe {
        let w = Wardrobe(name: name); ctx.insert(w); return w
    }
    func addItem(_ ctx: ModelContext, to w: Wardrobe, name: String) -> Item {
        let i = Item(name: name); i.wardrobe = w; ctx.insert(i); return i
    }

    @Test func containerBuildsWithAllEntities() throws {
        _ = try makeContext()   // 8 实体注册成功即证 schema 合法
    }

    @Test func outfitValidWhenAllItemsInSameWardrobe() throws {
        let ctx = try makeContext()
        let w = makeWardrobe(ctx, name: "NYC")
        let top = addItem(ctx, to: w, name: "top")
        let bottom = addItem(ctx, to: w, name: "bottom")
        let o = Outfit(name: "look"); o.wardrobe = w; o.items = [top, bottom]; ctx.insert(o)
        try ctx.save()
        #expect(WardrobeInvariant.isValid(o))
    }

    @Test func outfitInvalidWhenItemFromOtherWardrobe() throws {
        let ctx = try makeContext()
        let a = makeWardrobe(ctx, name: "A"); let b = makeWardrobe(ctx, name: "B")
        let itemInA = addItem(ctx, to: a, name: "x")
        let o = Outfit(name: "cross"); o.wardrobe = b; o.items = [itemInA]; ctx.insert(o) // 跨柜引用
        try ctx.save()
        #expect(!WardrobeInvariant.isValid(o))
    }

    @Test func transferMovesItemAndMarksOutfitMissing() throws {
        let ctx = try makeContext()
        let a = makeWardrobe(ctx, name: "A"); let b = makeWardrobe(ctx, name: "B")
        let item = addItem(ctx, to: a, name: "shirt")
        let o = Outfit(name: "look"); o.wardrobe = a; o.items = [item]; ctx.insert(o)
        try ctx.save()
        #expect(o.missing == false)

        TransferService.transfer(item, to: b, in: ctx)
        #expect(item.wardrobe?.id == b.id)   // 已转移
        #expect(o.missing == true)           // 原柜搭配缺件
        #expect(item.revision == 1)          // 版本自增
    }

    @Test func transferBackRestoresOutfit() throws {
        let ctx = try makeContext()
        let a = makeWardrobe(ctx, name: "A"); let b = makeWardrobe(ctx, name: "B")
        let item = addItem(ctx, to: a, name: "shirt")
        let o = Outfit(name: "look"); o.wardrobe = a; o.items = [item]; ctx.insert(o)
        try ctx.save()
        TransferService.transfer(item, to: b, in: ctx)
        #expect(o.missing == true)
        TransferService.transfer(item, to: a, in: ctx)   // 转回
        #expect(o.missing == false)                       // 自动恢复
    }

    @Test func transferMarksCalendarPlanNeedsAttention() throws {
        let ctx = try makeContext()
        let a = makeWardrobe(ctx, name: "A"); let b = makeWardrobe(ctx, name: "B")
        let item = addItem(ctx, to: a, name: "shirt")
        let o = Outfit(name: "look"); o.wardrobe = a; o.items = [item]; ctx.insert(o)
        let plan = CalendarPlan(date: Date(timeIntervalSince1970: 1_700_000_000)); plan.outfit = o; ctx.insert(plan)
        try ctx.save()
        TransferService.transfer(item, to: b, in: ctx)
        #expect(plan.needsAttention == true)
    }
}
