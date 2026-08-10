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
        /// When true, write flat widths even if nil (clears measures). Detail form uses this.
        public var replaceFlatWidths: Bool
        public init(name: String? = nil, slotRaw: String? = nil, occasionsRaw: [String]? = nil,
                    brand: String? = nil, sizeLabel: String? = nil, warmthRaw: Int? = nil,
                    chestFlatWidthInches: Double? = nil, waistFlatWidthInches: Double? = nil,
                    replaceFlatWidths: Bool = false) {
            self.name = name; self.slotRaw = slotRaw; self.occasionsRaw = occasionsRaw
            self.brand = brand; self.sizeLabel = sizeLabel; self.warmthRaw = warmthRaw
            self.chestFlatWidthInches = chestFlatWidthInches
            self.waistFlatWidthInches = waistFlatWidthInches
            self.replaceFlatWidths = replaceFlatWidths
        }
    }

    /// Applies patch and saves. Returns `false` when ModelSave fails (caller must not toast “Saved.”).
    @discardableResult
    public static func apply(_ patch: Patch, to item: Item, in context: ModelContext) -> Bool {
        // 保暖度必须在 Warmth 序级内（ItemStatusService allowed-set 同款守卫）：
        // 脏 raw 会在 Adapter 解析为 nil → 天气硬过滤当未知静默放行。
        if let w = patch.warmthRaw, Warmth(rawValue: w) == nil {
            AppLog.error("rejected invalid warmthRaw \(w) for \(item.name)", .data)
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
        let oldRevision = item.revision

        if let name = patch.name {
            let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { item.name = t }
        }
        // Persist displaySlot truth (same as intake persistSlot): dirty top + blazer name → outerwear.
        let draftSlot = patch.slotRaw ?? item.slotRaw
        if patch.slotRaw != nil || patch.name != nil {
            item.slotRaw = GarmentSlot.resolved(draftSlot, name: item.name).rawValue
        }
        if let occ = patch.occasionsRaw { item.occasionsRaw = occ }
        if let brand = patch.brand { item.brand = brand.isEmpty ? nil : brand }
        if let size = patch.sizeLabel { item.sizeLabel = size.isEmpty ? nil : size }
        if let w = patch.warmthRaw { item.warmthRaw = w }
        if patch.replaceFlatWidths {
            // Detail form: empty fields must clear FitMark source measures.
            item.chestFlatWidthInches = patch.chestFlatWidthInches
            item.waistFlatWidthInches = patch.waistFlatWidthInches
        } else {
            if let c = patch.chestFlatWidthInches { item.chestFlatWidthInches = c }
            if let w = patch.waistFlatWidthInches { item.waistFlatWidthInches = w }
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
            item.revision = oldRevision
            context.rollback()   // 失败变更不得滞留，否则污染下一次无关 save
            AppLog.error("edited item save failed \(item.name)", .data)
            return false
        }
        AppLog.info("edited item \(item.name) slot=\(item.slotRaw)", .data)
        return true
    }
}
