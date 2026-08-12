import Foundation
import SwiftData
import ClosetCore

/// 搭配收藏 / 从 copilot 候选落库（DESIGN §F5）。
public enum OutfitFavoriteService {

    /// 用本柜单品 id 列表建收藏搭配（强制同柜）。
    @discardableResult
    /// `isFavorite` 可关（D103）：Today 的「Plan」需要一个搭配实体来挂日历，
    /// 但用户没要求收藏——顺手标成收藏会让收藏列表凭空多出「Plan Aug 12」。
    public static func saveFavorite(
        name: String,
        itemIDs: [String],
        occasion: String?,
        in wardrobe: Wardrobe,
        source: String = "copilot",
        isFavorite: Bool = true,
        context: ModelContext
    ) throws -> Outfit {
        let all = wardrobe.items ?? []
        let items = itemIDs.compactMap { id in all.first { $0.id.uuidString == id } }
        guard !items.isEmpty else { throw OutfitDraftError.emptySelection }
        // 单次提交：favorite/occasion/source 随 create 一次落库，
        // 不得第二次 save（中途失败会残留非收藏 outfit 而 UI 报失败）。
        let outfit = try OutfitDraftService.create(
            name: name, items: items, in: wardrobe,
            isFavorite: isFavorite, occasion: occasion, source: source, context: context)
        AppLog.notice("favorite outfit=\(AppLog.ref(outfit.id)) items=\(items.count)", .data)
        return outfit
    }

    /// 丢弃一个刚建出来、结果没人引用的搭配（D103）。
    /// Today 的「Plan」先建搭配再挂日历；日历没落库时那个搭配就是孤儿，
    /// 必须一并回滚，否则「失败」之后库里仍多一条没人引用的搭配。
    /// 删除住在服务层——表现层出现 `context.delete` 只可能是 create 失败的错误善后
    ///（`WiringLintTests` 守着这条）。
    @discardableResult
    public static func discardOrphan(_ outfit: Outfit, in context: ModelContext) -> Bool {
        // D112：断关系前先快照。`rollback()` 撤得掉未落库的**行**，撤不掉已被改过的
        // 内存**关系**——不还原的话这条搭配会带着「零件 / 无主柜」活下来，
        // 并被**下一次无关的成功 save** 永久写进库里（实测：一次 setStatus 就够了）。
        // 样板见 `DeleteService.deleteLocation`。
        let previousWardrobe = outfit.wardrobe
        let previousItems = outfit.items ?? []
        // D114：先解绑日历计划。`CalendarPlan.outfit` 没有反向关系，
        // SwiftData 不会替我们置空——不解绑就留下一条指向已删行的悬挂引用。
        let unboundPlans = (try? context.fetch(FetchDescriptor<CalendarPlan>()))?
            .filter { $0.outfit?.id == outfit.id } ?? []
        CalendarPlanService.unbindPlans(referencing: outfit, in: context)
        outfit.wardrobe = nil
        outfit.items = []
        context.delete(outfit)
        guard ModelSave.save(context, label: "discardOrphanOutfit") else {
            outfit.wardrobe = previousWardrobe
            outfit.items = previousItems
            for plan in unboundPlans { plan.outfit = outfit }   // 解绑也要还原（同一条纪律）
            context.rollback()   // 失败删除不得滞留，否则污染下一次无关 save
            AppLog.error("orphan outfit discard failed \(AppLog.ref(outfit.id))", .data)
            return false
        }
        return true
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
