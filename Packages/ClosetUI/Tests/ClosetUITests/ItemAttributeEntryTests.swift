import Testing
import SwiftData
import Foundation
@testable import ClosetUI
@testable import ClosetModel
import ClosetCore

/// D83 属性录入面（温区 / 颜色 / 风格属性）：三者此前无任何录入 UI，
/// 导致天气硬过滤、配色打分、体型加权在真实衣柜数据上空转。
@MainActor
struct ItemAttributeEntryTests {
    init() { ItemImageTestRoot.install() }

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    func makeItem(_ ctx: ModelContext) throws -> Item {
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "tee"); i.slotRaw = "top"; i.wardrobe = w; ctx.insert(i)
        try ctx.save()
        return i
    }

    @Test func detailVMLoadsExistingAttributes() throws {
        let ctx = try makeContext()
        let item = try makeItem(ctx)
        item.warmthRaw = Warmth.warm.rawValue
        item.colorHue = 212; item.colorIsNeutral = false
        item.attributesRaw = ["belt", "wrap"]
        try ctx.save()

        let vm = ItemDetailViewModel(item: item)
        #expect(vm.warmthRaw == Warmth.warm.rawValue)
        #expect(vm.colorPaletteID == "blue")          // 212° 彩色 → 最近色板
        #expect(vm.attributes == Set([StyleAttribute.belt, .wrap]))
    }

    @Test func detailVMDefaultsToUnknownWhenItemHasNothing() throws {
        let ctx = try makeContext()
        let item = try makeItem(ctx)          // 全新单品：温区/颜色/属性均未知
        let vm = ItemDetailViewModel(item: item)
        #expect(vm.warmthRaw == nil)
        #expect(vm.colorPaletteID == nil)
        #expect(vm.attributes.isEmpty)
    }

    @Test func detailVMSavesAllThreeAttributes() throws {
        let ctx = try makeContext()
        let item = try makeItem(ctx)
        let vm = ItemDetailViewModel(item: item)
        vm.warmthRaw = Warmth.veryWarm.rawValue
        vm.colorPaletteID = "red"
        vm.attributes = [.aLine, .highWaist]
        vm.save(in: ctx)

        #expect(vm.message == "Saved.")
        #expect(item.warmthRaw == Warmth.veryWarm.rawValue)
        #expect(item.colorIsNeutral == false)
        #expect(item.colorHue == GarmentColorPalette.entry(id: "red")?.hueDegrees)
        #expect(item.attributesRaw == ["aLine", "highWaist"])   // 排序确定
    }

    @Test func detailVMSavesNeutralColorAndClearsWarmth() throws {
        let ctx = try makeContext()
        let item = try makeItem(ctx)
        item.warmthRaw = Warmth.light.rawValue
        item.colorHue = 212; item.colorIsNeutral = false
        try ctx.save()

        let vm = ItemDetailViewModel(item: item)
        vm.colorPaletteID = "black"     // 中性：hue 无意义 → nil + isNeutral
        vm.warmthRaw = nil              // 用户撤回温区（未知不硬过滤）
        vm.save(in: ctx)
        #expect(item.colorIsNeutral == true)
        #expect(item.colorHue == nil)
        #expect(item.warmthRaw == nil)
    }

    /// 端到端：录入后推荐引擎真的读得到（Adapter → CandidateItem）。
    @Test func enteredAttributesReachRecommendationAdapter() throws {
        let ctx = try makeContext()
        let item = try makeItem(ctx)
        let vm = ItemDetailViewModel(item: item)
        vm.warmthRaw = Warmth.veryWarm.rawValue
        vm.colorPaletteID = "teal"
        vm.attributes = [.wrap]
        vm.save(in: ctx)

        let candidate = item.toCandidateItem()
        #expect(candidate.warmth == .veryWarm)
        #expect(candidate.color?.isNeutral == false)
        #expect(candidate.attributes == Set([StyleAttribute.wrap]))
        // 体型加权不再恒 0（沙漏 × wrap = +1）
        #expect(BodyShapeStyling.affinity(items: [candidate], shape: .hourglass) > 0)
    }

    /// 快速添加不得再硬编码 Warmth.light / 中性色——冷天必空推荐的根因。
    @Test func quickAddDraftCarriesChosenWarmthAndColor() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w); try ctx.save()
        var draft = QuickAddDraft(name: "Wool Coat", slotRaw: "outerwear")
        draft.warmthRaw = Warmth.veryWarm.rawValue
        draft.colorPaletteID = "navy"
        draft.occasion = "work"
        let item = draft.commit(into: w, context: ctx)
        #expect(item != nil)
        #expect(item?.warmthRaw == Warmth.veryWarm.rawValue)
        #expect(item?.colorIsNeutral == true)
        #expect(item?.colorHue == nil)
        #expect(item?.occasionsRaw.contains("work") == true)
        // 未选温区 → 未知（nil），不得替用户假设成 light
        var bare = QuickAddDraft(name: "Mystery Tee", slotRaw: "top")
        bare.occasion = "casual"
        let bareItem = bare.commit(into: w, context: ctx)
        #expect(bareItem?.warmthRaw == nil)
    }

    @Test func quickAddRejectsBlankNameAndForeignSaveFailure() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w); try ctx.save()
        var blank = QuickAddDraft(name: "   ", slotRaw: "top")
        blank.occasion = "casual"
        #expect(blank.commit(into: w, context: ctx) == nil)
        #expect(try ctx.fetch(FetchDescriptor<Item>()).isEmpty)

        var ok = QuickAddDraft(name: "Tee", slotRaw: "top")
        ok.occasion = "casual"
        ModelSave.forceFailure(on: ctx)
        #expect(ok.commit(into: w, context: ctx) == nil)
        #expect(!ctx.hasChanges)              // 断关系 + rollback，无幻影
        #expect((w.items ?? []).isEmpty)
        ModelSave.clearForcedFailure(on: ctx)
        #expect(ok.commit(into: w, context: ctx) != nil)
    }
}
