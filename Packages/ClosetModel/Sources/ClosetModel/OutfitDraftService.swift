import Foundation
import SwiftData

/// 手动拼贴草稿落库（DESIGN §F5 平铺拼贴）：选本柜单品 → 建 Outfit，强制跨柜不变量。
public enum OutfitDraftError: Error, Equatable, LocalizedError {
    case emptySelection
    case crossWardrobe          // 选中单品不在同一衣柜
    case wardrobeMismatch       // 选中单品不在目标衣柜
    case saveFailed             // ModelContext.save failed (not silent)

    /// Customer-facing en-US (Today Save/Plan flash; never raw enum dump).
    public var errorDescription: String? {
        switch self {
        case .emptySelection:
            return "No pieces from this look are in your closet."
        case .crossWardrobe:
            return "Pieces must all be in the same closet."
        case .wardrobeMismatch:
            return "Those pieces aren't in this closet."
        case .saveFailed:
            return "Couldn't save this look — try again"
        }
    }
}

public enum OutfitDraftService {

    /// 用本柜单品创建搭配。失败不落库（含 save 失败 → 回滚 insert 并 throw）。
    /// isFavorite/occasion/source 随单次提交写入（收藏落库不得分两次 save）。
    @discardableResult
    public static func create(
        name: String,
        items: [Item],
        in wardrobe: Wardrobe,
        isFavorite: Bool = false,
        occasion: String? = nil,
        source: String? = nil,
        context: ModelContext
    ) throws -> Outfit {
        guard !items.isEmpty else { throw OutfitDraftError.emptySelection }
        let wardrobeID = wardrobe.id
        for item in items {
            guard let wid = item.wardrobe?.id else { throw OutfitDraftError.crossWardrobe }
            if wid != wardrobeID { throw OutfitDraftError.wardrobeMismatch }
        }
        // 全部同柜但不是目标柜（理论上与上等价，双保险）
        let ownerIDs = Set(items.compactMap { $0.wardrobe?.id })
        if ownerIDs.count != 1 { throw OutfitDraftError.crossWardrobe }

        let outfit = Outfit(name: name)
        outfit.wardrobe = wardrobe
        outfit.items = items
        outfit.missing = false
        outfit.permanentlyMissing = false
        outfit.isFavorite = isFavorite
        outfit.occasionRaw = occasion
        outfit.sourceRaw = source
        context.insert(outfit)
        // 再走一遍不变量守卫
        guard WardrobeInvariant.isValid(outfit) else {
            // 先解开内存关系（rollback 不回写内存幻影），再 rollback 丢弃 pending insert + 清脏标记
            //（delete 只删行，脏标记与幻影关系都会滞留）
            outfit.wardrobe = nil
            outfit.items = []
            context.rollback()   // 失败变更不得滞留，否则污染下一次无关 save
            throw OutfitDraftError.crossWardrobe
        }
        guard ModelSave.save(context, label: "outfitDraft") else {
            // 先解开内存关系（rollback 不回写内存幻影），再 rollback 丢弃 pending insert + 清脏标记
            outfit.wardrobe = nil
            outfit.items = []
            context.rollback()   // 失败变更不得滞留，否则污染下一次无关 save
            throw OutfitDraftError.saveFailed
        }
        return outfit
    }
}
