import Foundation
import SwiftData
import ClosetCore

/// 搭配收藏 / 从 copilot 候选落库（DESIGN §F5）。
public enum OutfitFavoriteService {

    /// 用本柜单品 id 列表建收藏搭配（强制同柜）。
    @discardableResult
    public static func saveFavorite(
        name: String,
        itemIDs: [String],
        occasion: String?,
        in wardrobe: Wardrobe,
        source: String = "copilot",
        context: ModelContext
    ) throws -> Outfit {
        let all = wardrobe.items ?? []
        let items = itemIDs.compactMap { id in all.first { $0.id.uuidString == id } }
        guard !items.isEmpty else { throw OutfitDraftError.emptySelection }
        let outfit = try OutfitDraftService.create(
            name: name, items: items, in: wardrobe, context: context)
        outfit.isFavorite = true
        outfit.occasionRaw = occasion
        outfit.sourceRaw = source
        ModelSave.save(context, label: "outfitFavorite")
        AppLog.notice("favorite outfit \(name) items=\(items.count)", .data)
        return outfit
    }

    public static func setFavorite(_ outfit: Outfit, _ flag: Bool, in context: ModelContext) {
        outfit.isFavorite = flag
        ModelSave.save(context, label: "outfitFavoriteToggle")
    }

    public static func favorites(in wardrobe: Wardrobe) -> [Outfit] {
        (wardrobe.outfits ?? []).filter { $0.isFavorite && !$0.permanentlyMissing }
            .sorted { $0.name < $1.name }
    }
}
