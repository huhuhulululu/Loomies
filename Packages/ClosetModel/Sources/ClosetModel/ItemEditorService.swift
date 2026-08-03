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
        public init(name: String? = nil, slotRaw: String? = nil, occasionsRaw: [String]? = nil,
                    brand: String? = nil, sizeLabel: String? = nil, warmthRaw: Int? = nil,
                    chestFlatWidthInches: Double? = nil, waistFlatWidthInches: Double? = nil) {
            self.name = name; self.slotRaw = slotRaw; self.occasionsRaw = occasionsRaw
            self.brand = brand; self.sizeLabel = sizeLabel; self.warmthRaw = warmthRaw
            self.chestFlatWidthInches = chestFlatWidthInches
            self.waistFlatWidthInches = waistFlatWidthInches
        }
    }

    public static func apply(_ patch: Patch, to item: Item, in context: ModelContext) {
        if let name = patch.name {
            let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { item.name = t }
        }
        if let slot = patch.slotRaw { item.slotRaw = slot }
        if let occ = patch.occasionsRaw { item.occasionsRaw = occ }
        if let brand = patch.brand { item.brand = brand.isEmpty ? nil : brand }
        if let size = patch.sizeLabel { item.sizeLabel = size.isEmpty ? nil : size }
        if let w = patch.warmthRaw { item.warmthRaw = w }
        if let c = patch.chestFlatWidthInches { item.chestFlatWidthInches = c }
        if let w = patch.waistFlatWidthInches { item.waistFlatWidthInches = w }
        item.revision += 1
        ModelSave.save(context, label: "itemEdit")
        AppLog.info("edited item \(item.name)", .data)
    }
}
