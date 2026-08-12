import Foundation
import SwiftData
import ClosetModel
import ClosetIntake
import ClosetCore

/// 快速添加草稿（D83）：把 QuickAddSheet 里的落库逻辑抽成可测值类型——
/// 此前温区硬编码 `Warmth.light` + 颜色恒中性，导致冷天必空推荐、配色打分恒中性。
/// 未选 = 未知（nil），不替用户假设。
public struct QuickAddDraft: Equatable, Sendable {
    public var name: String
    public var slotRaw: String
    public var occasion: String
    /// nil = 温区未知（不硬过滤）
    public var warmthRaw: Int?
    /// nil = 颜色未知
    public var colorPaletteID: String?

    public init(
        name: String = "",
        slotRaw: String = GarmentSlot.top.rawValue,
        occasion: String = "work",
        warmthRaw: Int? = nil,
        colorPaletteID: String? = nil
    ) {
        self.name = name
        self.slotRaw = slotRaw
        self.occasion = occasion
        self.warmthRaw = warmthRaw
        self.colorPaletteID = colorPaletteID
    }

    public var canCommit: Bool { !TextNormalize.isBlank(name) }

    /// Order-preserving dedup — the picker occasion may already be "casual".
    public static func dedupOccasions(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        return raw.filter { seen.insert($0).inserted }
    }

    /// 落库。失败返回 nil（断关系 + rollback，无幻影，调用方留在表单可重试）。
    @MainActor
    @discardableResult
    public func commit(into wardrobe: Wardrobe, context: ModelContext) -> Item? {
        guard let trimmed = TextNormalize.blankToNil(name) else { return nil }
        let item = Item(name: trimmed)
        let draftSlot = GarmentSlot(rawValue: slotRaw) ?? .top
        item.slotRaw = IntakeViewModel.persistSlot(draftSlot: draftSlot, name: trimmed).rawValue
        item.occasionsRaw = Self.dedupOccasions([occasion, "casual"])
        item.warmthRaw = warmthRaw
        item.statusRaw = "available"
        if let swatch = GarmentColorPalette.entry(id: colorPaletteID) {
            item.colorIsNeutral = swatch.isNeutral
            item.colorHue = swatch.isNeutral ? nil : swatch.hueDegrees
        } else {
            // 未选颜色：保持「未知」而非谎报中性（Adapter 的中性语义只给显式中性）
            item.colorIsNeutral = false
            item.colorHue = nil
        }
        item.wardrobe = wardrobe
        context.insert(item)
        guard ModelSave.save(context, label: "quickAdd") else {
            // 断关系 + rollback（delete 只删行，wardrobe.items 幻影与脏标记滞留）
            item.wardrobe = nil
            context.rollback()
            AppLog.error("quickAdd save failed", .intake)
            return nil
        }
        AppLog.info("quickAdd item=\(AppLog.ref(item.id)) slot=\(item.slotRaw)", .intake)
        return item
    }
}
