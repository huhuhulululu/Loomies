import Foundation
import SwiftData

/// 手动拼贴草稿落库（DESIGN §F5 平铺拼贴）：选本柜单品 → 建 Outfit，强制跨柜不变量。
public enum OutfitDraftError: Error, Equatable {
    case emptySelection
    case crossWardrobe          // 选中单品不在同一衣柜
    case wardrobeMismatch       // 选中单品不在目标衣柜
}

public enum OutfitDraftService {

    /// 用本柜单品创建搭配。失败不落库。
    @discardableResult
    public static func create(
        name: String,
        items: [Item],
        in wardrobe: Wardrobe,
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
        context.insert(outfit)
        // 再走一遍不变量守卫
        guard WardrobeInvariant.isValid(outfit) else {
            context.delete(outfit)
            throw OutfitDraftError.crossWardrobe
        }
        try? context.save()
        return outfit
    }
}
