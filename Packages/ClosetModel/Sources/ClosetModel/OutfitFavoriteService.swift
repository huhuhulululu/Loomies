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
        // 单次提交：favorite/occasion/source 随 create 一次落库，
        // 不得第二次 save（中途失败会残留非收藏 outfit 而 UI 报失败）。
        let outfit = try OutfitDraftService.create(
            name: name, items: items, in: wardrobe,
            isFavorite: true, occasion: occasion, source: source, context: context)
        AppLog.notice("favorite outfit=\(AppLog.ref(outfit.id)) items=\(items.count)", .data)
        return outfit
    }

    /// Customer toast when ModelSave fails on favorite toggle (list must not drop the row).
    public static let toggleSaveFailedMessage = "Couldn't update favorite — try again"

    /// Sets favorite flag. Returns `false` when ModelSave fails (`isFavorite` rolled back).
    @discardableResult
    public static func setFavorite(_ outfit: Outfit, _ flag: Bool, in context: ModelContext) -> Bool {
        let previous = outfit.isFavorite
        outfit.isFavorite = flag
        guard ModelSave.save(context, label: "outfitFavoriteToggle") else {
            outfit.isFavorite = previous
            context.rollback()   // 失败变更不得滞留，否则污染下一次无关 save
            AppLog.error("favorite toggle save failed outfit=\(AppLog.ref(outfit.id))", .data)
            return false
        }
        return true
    }

    public static func favorites(in wardrobe: Wardrobe) -> [Outfit] {
        (wardrobe.outfits ?? []).filter { $0.isFavorite && !$0.permanentlyMissing }
            .sorted { ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString) }
    }
}
