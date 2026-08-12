import Testing
import SwiftData
import Foundation
@testable import ClosetModel
import ClosetCore

/// D112：`.serialized` 是 **suite / 参数化用例** 的 trait；
/// 挂在非参数化的单个 `@Test` 上**什么都不做**（全仓曾有 25 处这样的写法，
/// 于是「这里安全因为串行」的说法全是假的）。本套用进程级钩子
///（`ItemImageStore.forceFailure` / 共享图片根），必须真的串行。
@Suite(.serialized)
@MainActor
struct FeatureGapServicesTests {

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    @Test func itemStatusRejectsInvalid() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "tee"); i.wardrobe = w; ctx.insert(i)
        #expect(!ItemStatusService.setStatus(i, to: "bogus", in: ctx))
        #expect(i.statusRaw == "available")
        #expect(ItemStatusService.setStatus(i, to: "inWash", in: ctx))
        #expect(i.statusRaw == "inWash")
    }

    @Test func storageLocationTreeAndAssign() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let rod = StorageLocationService.create(name: "Rod", in: w, context: ctx)
        let drawer = StorageLocationService.create(name: "Drawer", in: w, parent: rod, context: ctx)
        #expect(rod != nil && drawer != nil)
        let list = StorageLocationService.list(in: w)
        #expect(list.map(\.name) == ["Rod", "Drawer"])
        let i = Item(name: "tee"); i.wardrobe = w; ctx.insert(i)
        #expect(StorageLocationService.assign(i, to: drawer, in: ctx))
        #expect(i.location?.id == drawer!.id)
    }

    /// Create/assign/remove save-fail toast must not look like success.
    @Test func storageLocationSaveFailedMessagesAreHonest() {
        #expect(StorageLocationService.createSaveFailedMessage
            .localizedCaseInsensitiveContains("couldn't add"))
        #expect(StorageLocationService.createSaveFailedMessage
            .localizedCaseInsensitiveContains("try again"))
        #expect(!StorageLocationService.createSaveFailedMessage
            .localizedCaseInsensitiveContains("added"))
        #expect(StorageLocationService.assignSaveFailedMessage
            .localizedCaseInsensitiveContains("couldn't update"))
        #expect(StorageLocationService.assignSaveFailedMessage
            .localizedCaseInsensitiveContains("try again"))
        // Me Storage swipe-delete — same honesty bar as calendar/favorites remove.
        #expect(StorageLocationService.removeSaveFailedMessage
            .localizedCaseInsensitiveContains("couldn't remove"))
        #expect(StorageLocationService.removeSaveFailedMessage
            .localizedCaseInsensitiveContains("try again"))
        #expect(!StorageLocationService.removeSaveFailedMessage
            .localizedCaseInsensitiveContains("removed"))
    }

    @Test func itemEditorPatchesFields() throws {
        let ctx = try makeContext()
        let i = Item(name: "old"); ctx.insert(i)
        ItemEditorService.apply(.init(name: "new", slotRaw: "bottom", brand: "Everlane"), to: i, in: ctx)
        #expect(i.name == "new")
        #expect(i.brand == "Everlane")
        #expect(i.slotRaw == "bottom")
    }

    /// Detail rename: top + blazer name persists outerwear (intake persistSlot parity).
    @Test func itemEditorResolvesDirtyBlazerNameToOuterwear() throws {
        let ctx = try makeContext()
        let i = Item(name: "Piece"); i.slotRaw = "top"; ctx.insert(i)
        ItemEditorService.apply(.init(name: "Navy Blazer", slotRaw: "top"), to: i, in: ctx)
        #expect(i.name == "Navy Blazer")
        #expect(i.slotRaw == "outerwear")

        // Name-only patch still re-resolves existing slot against new name.
        let tee = Item(name: "Coat-ish"); tee.slotRaw = "top"; ctx.insert(tee)
        ItemEditorService.apply(.init(name: "White Tee"), to: tee, in: ctx)
        #expect(tee.slotRaw == "top")
    }

    /// Detail form empty flat fields must clear stored measures (FitMark source).
    @Test func itemEditorReplaceFlatWidthsClearsWhenNil() throws {
        let ctx = try makeContext()
        let i = Item(name: "tee"); i.slotRaw = "top"
        i.chestFlatWidthInches = 18
        i.waistFlatWidthInches = 14
        ctx.insert(i)
        // Partial patch without replace flag leaves measures.
        ItemEditorService.apply(.init(name: "tee"), to: i, in: ctx)
        #expect(i.chestFlatWidthInches == 18)
        // replaceFlatWidths + nil clears (user wiped fields).
        ItemEditorService.apply(
            .init(chestFlatWidthInches: nil, waistFlatWidthInches: nil, replaceFlatWidths: true),
            to: i, in: ctx)
        #expect(i.chestFlatWidthInches == nil)
        #expect(i.waistFlatWidthInches == nil)
        ItemEditorService.apply(
            .init(chestFlatWidthInches: 19, waistFlatWidthInches: nil, replaceFlatWidths: true),
            to: i, in: ctx)
        #expect(i.chestFlatWidthInches == 19)
        #expect(i.waistFlatWidthInches == nil)
    }

    /// 自由文本 Double 解析会放行 nan/inf/负值（strtod 语义）：服务层必须拒绝，
    /// 否则脏值落库后 JSON 导出（.throw 策略）永久失败。
    @Test func itemEditorRejectsNonFiniteOrNonPositiveFlatWidths() throws {
        let ctx = try makeContext()
        let i = Item(name: "tee"); i.slotRaw = "top"
        i.chestFlatWidthInches = 18
        ctx.insert(i)
        for bad in [Double.nan, .infinity, -.infinity, -5, 0] {
            let ok = ItemEditorService.apply(
                .init(chestFlatWidthInches: bad, replaceFlatWidths: true), to: i, in: ctx)
            #expect(!ok)
            #expect(i.chestFlatWidthInches == 18)
            let okWaist = ItemEditorService.apply(
                .init(waistFlatWidthInches: bad), to: i, in: ctx)
            #expect(!okWaist)
            #expect(i.waistFlatWidthInches == nil)
        }
        // 正常值不受守卫误伤
        #expect(ItemEditorService.apply(
            .init(chestFlatWidthInches: 19, replaceFlatWidths: true), to: i, in: ctx))
        #expect(i.chestFlatWidthInches == 19)
    }

    /// brand/size 判空与 name 同标准（trim）：空白串落库为 nil，真值 trim 后存。
    @Test func itemEditorTrimsBrandAndSizeBlankToNil() throws {
        let ctx = try makeContext()
        let i = Item(name: "tee"); i.slotRaw = "top"
        ctx.insert(i)
        #expect(ItemEditorService.apply(.init(brand: "  ", sizeLabel: " M "), to: i, in: ctx))
        #expect(i.brand == nil)
        #expect(i.sizeLabel == "M")
        #expect(ItemEditorService.apply(.init(brand: " Acne Studios "), to: i, in: ctx))
        #expect(i.brand == "Acne Studios")
    }

    /// 空白名 patch 必须拒绝（return false），不得静默丢弃后仍让 UI 弹 Saved.。
    @Test func itemEditorRejectsBlankNamePatch() throws {
        let ctx = try makeContext()
        let i = Item(name: "tee"); i.slotRaw = "top"
        ctx.insert(i)
        #expect(!ItemEditorService.apply(.init(name: "   "), to: i, in: ctx))
        #expect(i.name == "tee")
        #expect(!ItemEditorService.apply(.init(name: ""), to: i, in: ctx))
        #expect(i.name == "tee")
    }

    /// 空白名存放位置守卫下沉服务层（public API 不能只靠 View 层 gate）。
    @Test func storageLocationCreateRejectsBlankName() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        try ctx.save()
        #expect(StorageLocationService.create(name: "   ", in: w, context: ctx) == nil)
        #expect(StorageLocationService.create(name: "", in: w, context: ctx) == nil)
        #expect(try ctx.fetch(FetchDescriptor<StorageLocation>()).isEmpty)
        // trim 后落库
        let loc = StorageLocationService.create(name: " Rod ", in: w, context: ctx)
        #expect(loc?.name == "Rod")
    }

    /// 同级重名存放位置在 Picker 里不可区分：同 parent 拒绝，跨 parent 允许。
    @Test func storageLocationCreateRejectsDuplicateSiblingName() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        try ctx.save()
        let rod = StorageLocationService.create(name: "Rod", in: w, context: ctx)
        #expect(rod != nil)
        // 同级（根层）重名拒绝（大小写/空白不敏感）
        #expect(StorageLocationService.create(name: " rod ", in: w, context: ctx) == nil)
        // 不同 parent 下同名允许（"Left shelf/Box" 与 "Right shelf/Box"）
        let shelf = StorageLocationService.create(name: "Shelf", in: w, context: ctx)
        #expect(StorageLocationService.create(name: "Rod", in: w, parent: shelf, context: ctx) != nil)
    }

    /// 同级同名兄弟节点（历史数据）list 顺序按 (name,id) 决胜，不随 fetch 顺序漂移。
    @Test func storageLocationListSameNameStableByID() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let l1 = StorageLocation(name: "Box"); l1.wardrobe = w; ctx.insert(l1)
        let l2 = StorageLocation(name: "Box"); l2.wardrobe = w; ctx.insert(l2)
        try ctx.save()
        let expected = [l1, l2].sorted { $0.id.uuidString < $1.id.uuidString }.map(\.id)
        #expect(StorageLocationService.list(in: w).map(\.id) == expected)
    }

    /// D83 属性录入：风格属性写入面。此前 attributesRaw 全仓无生产者 →
    /// 体型加权（FFIT × 属性二维表）在真实数据上 affinity 恒 0。
    @Test func itemEditorWritesStyleAttributesDeterministically() throws {
        let ctx = try makeContext()
        let i = Item(name: "tee"); i.slotRaw = "top"
        ctx.insert(i)
        // 乱序 + 重复 → 去重且按 rawValue 稳定排序（禁止依赖入参顺序）
        #expect(ItemEditorService.apply(
            .init(attributesRaw: ["belt", "wrap", "belt"]), to: i, in: ctx))
        #expect(i.attributesRaw == ["belt", "wrap"])
        // 未知属性整包拒绝（allowed-set 守卫，与 warmthRaw 同款）
        #expect(!ItemEditorService.apply(
            .init(attributesRaw: ["wrap", "notAnAttribute"]), to: i, in: ctx))
        #expect(i.attributesRaw == ["belt", "wrap"])
        // 空数组 = 清空（用户取消全部勾选）
        #expect(ItemEditorService.apply(.init(attributesRaw: []), to: i, in: ctx))
        #expect(i.attributesRaw.isEmpty)
    }

    /// D83：温区可清空（用户撤回「未知不硬过滤」）——nil 默认是「不动」，
    /// 详情表单整表提交需显式 replaceWarmth。
    @Test func itemEditorReplaceWarmthClearsWhenNil() throws {
        let ctx = try makeContext()
        let i = Item(name: "tee"); i.slotRaw = "top"
        i.warmthRaw = Warmth.light.rawValue
        ctx.insert(i)
        // 不带 replace 的 nil → 保持原值
        #expect(ItemEditorService.apply(.init(name: "tee"), to: i, in: ctx))
        #expect(i.warmthRaw == Warmth.light.rawValue)
        // 带 replace 的 nil → 清为未知
        #expect(ItemEditorService.apply(.init(replaceWarmth: true), to: i, in: ctx))
        #expect(i.warmthRaw == nil)
        // 带 replace 的合法值 → 写入
        #expect(ItemEditorService.apply(
            .init(warmthRaw: Warmth.veryWarm.rawValue, replaceWarmth: true), to: i, in: ctx))
        #expect(i.warmthRaw == Warmth.veryWarm.rawValue)
    }

    /// D83：颜色写入面。此前 quick-add/manual 一律写 isNeutral=true + hue=nil →
    /// 配色协调与 60-30-10 打分恒中性。
    @Test func itemEditorWritesAndClearsColor() throws {
        let ctx = try makeContext()
        let i = Item(name: "tee"); i.slotRaw = "top"
        ctx.insert(i)
        #expect(ItemEditorService.apply(
            .init(colorHue: 212, colorIsNeutral: false, replaceColor: true), to: i, in: ctx))
        #expect(i.colorHue == 212)
        #expect(i.colorIsNeutral == false)
        // 中性（无 hue 语义）：hue 置 nil、isNeutral=true —— Adapter 会保住「中性」语义
        #expect(ItemEditorService.apply(
            .init(colorHue: nil, colorIsNeutral: true, replaceColor: true), to: i, in: ctx))
        #expect(i.colorHue == nil)
        #expect(i.colorIsNeutral == true)
        // 不带 replaceColor 的 patch 不得动颜色（部分更新不误清）
        #expect(ItemEditorService.apply(.init(name: "tee2"), to: i, in: ctx))
        #expect(i.colorIsNeutral == true)
        // 非有限/越界 hue 拒绝（与平铺宽守卫同标准）
        for bad in [Double.nan, .infinity, -5, 360] {
            #expect(!ItemEditorService.apply(
                .init(colorHue: bad, colorIsNeutral: false, replaceColor: true), to: i, in: ctx))
        }
        #expect(i.colorHue == nil)
    }

    /// D85 波 B：位置树。`listWithDepth` 供 UI 缩进展示；`siblingNameConflicts` 让
    /// UI 能在提交前诚实报「重名」而不是笼统的「Couldn't add — try again」。
    @Test func listWithDepthGivesTreeLevelsDeterministically() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        try ctx.save()
        let closet = StorageLocationService.create(name: "Closet 1", in: w, context: ctx)
        let rail = StorageLocationService.create(name: "Rail A", in: w, parent: closet, context: ctx)
        _ = StorageLocationService.create(name: "Box 1", in: w, parent: rail, context: ctx)
        _ = StorageLocationService.create(name: "Attic", in: w, context: ctx)

        let nodes = StorageLocationService.listWithDepth(in: w)
        #expect(nodes.map { "\($0.depth):\($0.location.name)" }
            == ["0:Attic", "0:Closet 1", "1:Rail A", "2:Box 1"])
        // list(in:) 与之同源（顺序一致）
        #expect(StorageLocationService.list(in: w).map(\.name) == nodes.map(\.location.name))
    }

    /// 审查发现的回落缺陷：`parent?.children ?? 根层` 在 children 为 nil 时会拿根层当兄弟，
    /// 于是「父节点下新建与某根节点同名」被误报重名（客户可见的谎）。
    @Test func siblingNameConflictsIsParentScopedWithoutRootFallback() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        try ctx.save()
        let closet = try #require(StorageLocationService.create(name: "Closet 1", in: w, context: ctx))
        _ = StorageLocationService.create(name: "Attic", in: w, context: ctx)
        // 根层同名（大小写/空白不敏感）→ 冲突
        #expect(StorageLocationService.siblingNameConflicts(" attic ", in: w, parent: nil))
        #expect(!StorageLocationService.siblingNameConflicts("Basement", in: w, parent: nil))
        // 子层与根层同名 → **不**冲突（即使父节点尚无子节点）
        #expect((closet.children ?? []).isEmpty)
        #expect(!StorageLocationService.siblingNameConflicts("Attic", in: w, parent: closet))
        #expect(StorageLocationService.create(name: "Attic", in: w, parent: closet, context: ctx) != nil)
        // 同一父下再同名 → 冲突
        #expect(StorageLocationService.siblingNameConflicts("attic", in: w, parent: closet))
        // 文案存在且诚实（不是笼统的 try again）
        #expect(!StorageLocationService.duplicateSiblingMessage.isEmpty)
        #expect(StorageLocationService.duplicateSiblingMessage
            .localizedCaseInsensitiveContains("already exists"))
    }

    @Test func saveFavoriteFromIDsAndPlan() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let t = Item(name: "t"); t.slotRaw = "top"; t.wardrobe = w; ctx.insert(t)
        let b = Item(name: "b"); b.slotRaw = "bottom"; b.wardrobe = w; ctx.insert(b)
        try ctx.save()
        let o = try OutfitFavoriteService.saveFavorite(
            name: "Work look", itemIDs: [t.id.uuidString, b.id.uuidString],
            occasion: "work", in: w, context: ctx)
        #expect(o.isFavorite)
        #expect(o.occasionRaw == "work")
        #expect(OutfitFavoriteService.favorites(in: w).count == 1)

        #expect(OutfitFavoriteService.setFavorite(o, false, in: ctx))
        #expect(o.isFavorite == false)
        #expect(OutfitFavoriteService.favorites(in: w).isEmpty)

        #expect(OutfitFavoriteService.setFavorite(o, true, in: ctx))
        #expect(OutfitFavoriteService.favorites(in: w).count == 1)

        let plan = CalendarPlanService.plan(outfit: o, on: Date(), in: ctx)
        #expect(plan != nil)
        #expect(plan!.outfit?.id == o.id)
        #expect(plan!.needsAttention == false)
    }

    /// Toggle save-fail toast must not look like success (row must stay in favorites).
    @Test func setFavoriteSaveFailedMessageIsHonest() {
        #expect(OutfitFavoriteService.toggleSaveFailedMessage
            .localizedCaseInsensitiveContains("couldn't update"))
        #expect(OutfitFavoriteService.toggleSaveFailedMessage
            .localizedCaseInsensitiveContains("try again"))
        #expect(!OutfitFavoriteService.toggleSaveFailedMessage
            .localizedCaseInsensitiveContains("removed"))
        #expect(!OutfitFavoriteService.toggleSaveFailedMessage
            .localizedCaseInsensitiveContains("saved to favorites"))
    }

    @Test func crossWardrobeLocationAssignBlocked() throws {
        let ctx = try makeContext()
        let a = Wardrobe(name: "A"); ctx.insert(a)
        let b = Wardrobe(name: "B"); ctx.insert(b)
        let loc = StorageLocationService.create(name: "Rod", in: a, context: ctx)
        #expect(loc != nil)
        let i = Item(name: "x"); i.wardrobe = b; ctx.insert(i)
        #expect(!StorageLocationService.assign(i, to: loc, in: ctx))
        #expect(i.location == nil)
    }

    /// M2: save 失败必须 rollback——变更不得滞留污染下一次无关 save。
    @Test func statusSaveFailureRollsBackContext() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "tee"); i.wardrobe = w; ctx.insert(i)
        try ctx.save()
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        #expect(!ItemStatusService.setStatus(i, to: "inWash", in: ctx))
        #expect(i.statusRaw == "available")   // rollback 恢复原值
        #expect(!ctx.hasChanges)              // 失败变更不再滞留
    }

    /// CM-1: itemEdit save 失败须还原内存字段值 + rollback——UI 不得显示未入库的新值。
    @Test func itemEditorSaveFailureRestoresValuesAndRollsBack() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "old tee"); i.slotRaw = "top"; i.brand = "Uniqlo"
        i.occasionsRaw = ["casual"]; i.wardrobe = w; ctx.insert(i)
        try ctx.save()
        let oldRevision = i.revision
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        #expect(!ItemEditorService.apply(
            .init(name: "new tee", slotRaw: "bottom", occasionsRaw: ["work"], brand: "Everlane"),
            to: i, in: ctx))
        #expect(i.name == "old tee")
        #expect(i.slotRaw == "top")
        #expect(i.occasionsRaw == ["casual"])
        #expect(i.brand == "Uniqlo")
        #expect(i.revision == oldRevision)
        #expect(!ctx.hasChanges)              // 失败变更不再滞留
    }

    /// CM-2: transfer save 失败须 rollback——还原字段值之外脏标记也不得滞留。
    @Test func transferSaveFailureRollsBackContext() throws {
        let ctx = try makeContext()
        let a = Wardrobe(name: "A"); ctx.insert(a)
        let b = Wardrobe(name: "B"); ctx.insert(b)
        let i = Item(name: "tee"); i.wardrobe = a; ctx.insert(i)
        try ctx.save()
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        #expect(!TransferService.transfer(i, to: b, in: ctx))
        #expect(i.wardrobe?.id == a.id)       // 内存值已还原
        #expect(!ctx.hasChanges)              // 失败变更不再滞留
    }

    /// CM-2: locationAssign save 失败须 rollback——与 transfer 同款。
    @Test func locationAssignSaveFailureRollsBackContext() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let loc = StorageLocationService.create(name: "Rod", in: w, context: ctx)
        let i = Item(name: "tee"); i.wardrobe = w; ctx.insert(i)
        try ctx.save()
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        #expect(!StorageLocationService.assign(i, to: loc, in: ctx))
        #expect(i.location == nil)            // 内存值已还原
        #expect(!ctx.hasChanges)              // 失败变更不再滞留
    }

    /// M4: 位置或单品任一侧无衣柜归属（nil）也须阻断，不得静默放行。
    @Test func orphanLocationAssignBlocked() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let orphan = StorageLocation(name: "orphan"); ctx.insert(orphan)   // 无衣柜归属
        let i = Item(name: "x"); i.wardrobe = w; ctx.insert(i)
        try ctx.save()
        #expect(!StorageLocationService.assign(i, to: orphan, in: ctx))
        #expect(i.location == nil)
        // 同柜正常 assign 与解绑（nil 目标 = 清除位置）不受影响
        let loc = StorageLocationService.create(name: "Rod", in: w, context: ctx)
        #expect(StorageLocationService.assign(i, to: loc, in: ctx))
        #expect(StorageLocationService.assign(i, to: nil, in: ctx))
        #expect(i.location == nil)
    }
}
