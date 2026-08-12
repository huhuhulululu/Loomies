import Foundation
import SwiftData
import ClosetCore

/// 单品字段编辑（入库后修正 / 详情页）。
public enum ItemEditorService {

    public struct Patch: Equatable, Sendable {
        public var name: String?
        public var slotRaw: String?
        public var occasionsRaw: [String]?
        public var brand: String?
        public var sizeLabel: String?
        public var warmthRaw: Int?
        public var chestFlatWidthInches: Double?
        public var waistFlatWidthInches: Double?
        /// 臀宽（D100）：下装合身判定的第二个约束
        public var hipFlatWidthInches: Double?
        /// When true, write flat widths even if nil (clears measures). Detail form uses this.
        public var replaceFlatWidths: Bool
        /// 整表提交时置 true：`warmthRaw == nil` 才解释为「清为未知」而非「不动」。
        public var replaceWarmth: Bool
        /// 风格属性（体型加权输入）；空数组 = 清空，nil = 不动。
        public var attributesRaw: [String]?
        /// 颜色（配色打分输入）；仅当 `replaceColor` 为 true 时写入（含置 nil 的中性态）。
        public var colorHue: Double?
        public var colorIsNeutral: Bool?
        public var replaceColor: Bool
        /// 护理符号（结构化，D93）；空数组 = 清空，nil = 不动。
        public var careRaw: [String]?
        /// 自由备注（D93）；仅当 `replaceNotes` 为 true 时写入（含清空）。
        /// **不可信输入**：落库前过 `ItemNotes.sanitize`（长度上限 + 控制字符归一）。
        public var notes: String?
        public var replaceNotes: Bool
        public init(name: String? = nil, slotRaw: String? = nil, occasionsRaw: [String]? = nil,
                    brand: String? = nil, sizeLabel: String? = nil, warmthRaw: Int? = nil,
                    chestFlatWidthInches: Double? = nil, waistFlatWidthInches: Double? = nil,
                    hipFlatWidthInches: Double? = nil,
                    replaceFlatWidths: Bool = false,
                    replaceWarmth: Bool = false,
                    attributesRaw: [String]? = nil,
                    colorHue: Double? = nil, colorIsNeutral: Bool? = nil,
                    replaceColor: Bool = false,
                    careRaw: [String]? = nil,
                    notes: String? = nil, replaceNotes: Bool = false) {
            self.replaceWarmth = replaceWarmth
            self.careRaw = careRaw
            self.notes = notes
            self.replaceNotes = replaceNotes
            self.name = name; self.slotRaw = slotRaw; self.occasionsRaw = occasionsRaw
            self.brand = brand; self.sizeLabel = sizeLabel; self.warmthRaw = warmthRaw
            self.chestFlatWidthInches = chestFlatWidthInches
            self.waistFlatWidthInches = waistFlatWidthInches
            self.hipFlatWidthInches = hipFlatWidthInches
            self.replaceFlatWidths = replaceFlatWidths
            self.attributesRaw = attributesRaw
            self.colorHue = colorHue
            self.colorIsNeutral = colorIsNeutral
            self.replaceColor = replaceColor
        }
    }

    /// Applies patch and saves. Returns `false` when ModelSave fails (caller must not toast “Saved.”).
    @discardableResult
    public static func apply(_ patch: Patch, to item: Item, in context: ModelContext) -> Bool {
        // 保暖度必须在 Warmth 序级内（ItemStatusService allowed-set 同款守卫）：
        // 脏 raw 会在 Adapter 解析为 nil → 天气硬过滤当未知静默放行。
        if let w = patch.warmthRaw, Warmth(rawValue: w) == nil {
            AppLog.error("rejected invalid warmthRaw \(w) for item=\(AppLog.ref(item.id))", .data)
            return false
        }
        // 平铺宽来自自由文本 Double 解析（strtod 语义放行 nan/inf/负值）：非有限或
        // 非正值拒绝——脏值落库会让 JSON 导出（默认 .throw）永久失败，FitMark 也只认 >0。
        for measure in [patch.chestFlatWidthInches, patch.waistFlatWidthInches,
                        patch.hipFlatWidthInches] {
            if let m = measure, !m.isFinite || m <= 0 {
                AppLog.error("rejected invalid flat width for item=\(AppLog.ref(item.id))", .data)
                return false
            }
        }
        // 风格属性 allowed-set 守卫（与 warmthRaw 同款）：脏 raw 会在 Adapter 解析为空集，
        // 体型加权静默归零而 UI 仍显示已勾选。
        if let attrs = patch.attributesRaw,
           attrs.contains(where: { StyleAttribute(rawValue: $0) == nil }) {
            AppLog.error("rejected unknown style attribute for item=\(AppLog.ref(item.id))", .data)
            return false
        }
        // 护理符号 allowed-set 守卫（与 StyleAttribute 同款）：脏 raw 会在读回时静默丢弃，
        // 而 UI 仍显示已勾选——两边看到的不是同一份数据。
        if let care = patch.careRaw,
           care.contains(where: { CareSymbol(rawValue: $0) == nil }) {
            AppLog.error("rejected unknown care symbol for item=\(AppLog.ref(item.id))", .data)
            return false
        }
        // 颜色 hue 必须有限且在 [0,360)：脏值让配色关系判定失效（NaN 一律 neutral）。
        if patch.replaceColor, let h = patch.colorHue, !h.isFinite || h < 0 || h >= 360 {
            AppLog.error("rejected invalid color hue for item=\(AppLog.ref(item.id))", .data)
            return false
        }
        // Snapshot mutated fields: rollback() 只清脏标记不清内存值 → 失败须先还原（ItemStatusService 同款）。
        let oldName = item.name
        let oldSlotRaw = item.slotRaw
        let oldOccasionsRaw = item.occasionsRaw
        let oldBrand = item.brand
        let oldSizeLabel = item.sizeLabel
        let oldWarmthRaw = item.warmthRaw
        let oldChestFlatWidthInches = item.chestFlatWidthInches
        let oldWaistFlatWidthInches = item.waistFlatWidthInches
        let oldHipFlatWidthInches = item.hipFlatWidthInches
        let oldAttributesRaw = item.attributesRaw
        let oldColorHue = item.colorHue
        let oldColorIsNeutral = item.colorIsNeutral
        let oldCareRaw = item.careRaw
        let oldNotes = item.notes
        let oldRevision = item.revision

        if let name = patch.name {
            guard let t = TextNormalize.blankToNil(name) else {
                // 空白名拒绝而非静默丢弃：静默丢弃后 UI 仍弹 Saved.，用户无从分辨。
                AppLog.error("rejected blank name patch for item=\(AppLog.ref(item.id))", .data)
                return false
            }
            item.name = t
        }
        // Persist displaySlot truth (same as intake persistSlot): dirty top + blazer name → outerwear.
        let draftSlot = patch.slotRaw ?? item.slotRaw
        if patch.slotRaw != nil || patch.name != nil {
            item.slotRaw = GarmentSlot.resolved(draftSlot, name: item.name).rawValue
        }
        if let occ = patch.occasionsRaw { item.occasionsRaw = occ }
        // brand/size 与 name 同一判空标准（trim）：" " 落库会阻塞条码补全且详情页显示空白非 nil。
        if let brand = patch.brand { item.brand = TextNormalize.blankToNil(brand) }
        if let size = patch.sizeLabel { item.sizeLabel = TextNormalize.blankToNil(size) }
        if patch.replaceWarmth {
            item.warmthRaw = patch.warmthRaw   // nil = 清为未知（不硬过滤）
        } else if let w = patch.warmthRaw {
            item.warmthRaw = w
        }
        if patch.replaceFlatWidths {
            // Detail form: empty fields must clear FitMark source measures.
            item.chestFlatWidthInches = patch.chestFlatWidthInches
            item.waistFlatWidthInches = patch.waistFlatWidthInches
            item.hipFlatWidthInches = patch.hipFlatWidthInches
        } else {
            if let c = patch.chestFlatWidthInches { item.chestFlatWidthInches = c }
            if let w = patch.waistFlatWidthInches { item.waistFlatWidthInches = w }
            if let h = patch.hipFlatWidthInches { item.hipFlatWidthInches = h }
        }
        if let attrs = patch.attributesRaw {
            // 去重 + rawValue 排序：确定性（禁止依赖入参/Set 顺序），导出快照可复现
            item.attributesRaw = Array(Set(attrs)).sorted()
        }
        if patch.replaceColor {
            item.colorHue = patch.colorHue
            item.colorIsNeutral = patch.colorIsNeutral ?? item.colorIsNeutral
        }
        if let care = patch.careRaw {
            // 去重 + rawValue 排序：确定性（与 attributesRaw 同约定）
            item.careRaw = CareSymbol.persistOrder(care.compactMap(CareSymbol.init(rawValue:)))
                .map(\.rawValue)
        }
        if patch.replaceNotes {
            // 不可信输入的唯一入口（DESIGN §321）：截断 + 控制字符归一
            item.notes = ItemNotes.sanitize(patch.notes)
        }
        item.revision += 1
        guard ModelSave.save(context, label: "itemEdit") else {
            // 还原内存值，再 rollback 清脏标记——UI 不得显示未入库的新值。
            item.name = oldName
            item.slotRaw = oldSlotRaw
            item.occasionsRaw = oldOccasionsRaw
            item.brand = oldBrand
            item.sizeLabel = oldSizeLabel
            item.warmthRaw = oldWarmthRaw
            item.chestFlatWidthInches = oldChestFlatWidthInches
            item.waistFlatWidthInches = oldWaistFlatWidthInches
            item.hipFlatWidthInches = oldHipFlatWidthInches
            item.attributesRaw = oldAttributesRaw
            item.colorHue = oldColorHue
            item.colorIsNeutral = oldColorIsNeutral
            item.careRaw = oldCareRaw
            item.notes = oldNotes
            item.revision = oldRevision
            context.rollback()   // 失败变更不得滞留，否则污染下一次无关 save
            AppLog.error("edited item save failed item=\(AppLog.ref(item.id))", .data)
            return false
        }
        AppLog.info("edited item=\(AppLog.ref(item.id)) slot=\(item.slotRaw)", .data)
        return true
    }
}
