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
        vm.colorPaletteID = "black"     // 中性：存色板槽位 hue，打分层忽略、回读靠它
        vm.warmthRaw = nil              // 用户撤回温区（未知不硬过滤）
        vm.save(in: ctx)
        #expect(item.colorIsNeutral == true)
        #expect(item.colorHue == GarmentColorPalette.entry(id: "black")?.hueDegrees)
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
        #expect(item?.colorHue == GarmentColorPalette.entry(id: "navy")?.hueDegrees)
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

/// D88：颜色选中态的**往返**。此前写入侧对中性色一律 `colorHue = nil`，
/// 回读侧见 hue 为 nil 就返回 nil——用户选 Black → 提示「Saved.」→ 退出重进，
/// 色板显示「未选中」；7 个中性色在存储层塌成同一状态、彼此不可区分。
/// 更糟的是清空语义：`colorIsNeutral: swatch?.isNeutral ?? item.colorIsNeutral`
/// 让「取消选择」回落到旧值，一旦存成中性就再无路径改回「颜色未知」，
/// 引擎会永久按「万能百搭」给它打分。UI 诚实两头都踩：显示成没选过，又隐瞒了数据仍是中性。
@MainActor
struct ItemColorRoundTripTests {

    func makeContext() throws -> ModelContext {
        try ModelContext(ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    func makeItem(in ctx: ModelContext) throws -> Item {
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let i = Item(name: "tee"); i.slotRaw = "top"; i.wardrobe = w
        i.statusRaw = "available"; ctx.insert(i)
        try ctx.save()
        return i
    }

    /// 每个中性色都必须原样回读（7 个互相可分辨，不是同一个「中性」）。
    @Test func everyNeutralSwatchSurvivesAReopen() throws {
        let ctx = try makeContext()
        for entry in GarmentColorPalette.entries where entry.isNeutral {
            let item = try makeItem(in: ctx)
            let vm = ItemDetailViewModel(item: item)
            vm.colorPaletteID = entry.id
            vm.save(in: ctx)
            // 重开详情页 = 重建 ViewModel
            let reopened = ItemDetailViewModel(item: item)
            #expect(reopened.colorPaletteID == entry.id,
                    Comment(rawValue: "中性色 \(entry.id) 回读成 \(reopened.colorPaletteID ?? "nil")"))
            #expect(item.colorIsNeutral)
        }
    }

    /// 彩色同样往返（回归保护，别修中性把彩色改坏）。
    @Test func chromaticSwatchSurvivesAReopen() throws {
        let ctx = try makeContext()
        let item = try makeItem(in: ctx)
        let vm = ItemDetailViewModel(item: item)
        vm.colorPaletteID = "olive"
        vm.save(in: ctx)
        let reopened = ItemDetailViewModel(item: item)
        #expect(reopened.colorPaletteID == "olive")
        #expect(!item.colorIsNeutral)
    }

    /// 「再点一次取消」必须真的能回到未知——中性不是单向门。
    @Test func clearingColorReturnsToUnknownNotStickyNeutral() throws {
        let ctx = try makeContext()
        let item = try makeItem(in: ctx)
        let vm = ItemDetailViewModel(item: item)
        vm.colorPaletteID = "navy"
        vm.save(in: ctx)
        #expect(item.colorIsNeutral)

        let reopened = ItemDetailViewModel(item: item)
        reopened.colorPaletteID = nil       // 用户再点一次取消
        reopened.save(in: ctx)
        #expect(item.colorHue == nil)
        #expect(!item.colorIsNeutral)       // 不得粘住旧的中性标记
        #expect(ItemDetailViewModel(item: item).colorPaletteID == nil)
    }

    /// 用户没碰颜色 → 保存不得改写它。此前 `replaceColor: true` 无条件生效，
    /// 而 colorPaletteID 是 nearest() 量化过的：入库识别给的 15° 会在用户
    /// 只改了个名字之后被静默改写成色板的 28°（orange）。数据变了，没人告诉他。
    @Test func savingWithoutTouchingColorKeepsTheOriginalHue() throws {
        let ctx = try makeContext()
        let item = try makeItem(in: ctx)
        item.colorHue = 15          // 入库识别 / 条码补全给的连续色相
        item.colorIsNeutral = false
        try ctx.save()

        let vm = ItemDetailViewModel(item: item)
        vm.name = "Renamed Tee"     // 只改名字，没动色板
        vm.save(in: ctx)
        #expect(item.colorHue == 15)
        #expect(item.name == "Renamed Tee")
    }

    /// 存量行（hue nil + 中性标记）无法还原具体是哪个中性色——诚实地显示为未知，
    /// 不猜一个 Black 出来。
    @Test func legacyNeutralWithoutHueReadsAsUnknown() throws {
        let ctx = try makeContext()
        let item = try makeItem(in: ctx)
        item.colorHue = nil
        item.colorIsNeutral = true
        try ctx.save()
        #expect(ItemDetailViewModel(item: item).colorPaletteID == nil)
    }
}
