import Foundation
import Observation
import SwiftData
import ClosetModel
import ClosetCore

/// Copilot 建议 → 收藏 / 入日历。
@MainActor
@Observable
public final class OutfitActionsViewModel {
    public private(set) var message: String = ""

    public func saveFavorite(
        scored: ScoredOutfit, occasion: String, in wardrobe: Wardrobe, context: ModelContext
    ) {
        do {
            let name = "Look \(Date().formatted(date: .abbreviated, time: .shortened))"
            _ = try OutfitFavoriteService.saveFavorite(
                name: name,
                itemIDs: scored.outfit.itemIDs,
                occasion: occasion,
                in: wardrobe,
                context: context)
            // Point to Today toolbar so Save is not a dead end (Me-only Favorites was hard to find).
            message = Self.savedToFavoritesMessage
        } catch {
            message = Self.failureMessage(prefix: "Couldn't save", error: error)
            AppLog.error("favorite failed \(AppLog.errRef(error))", .app)
        }
    }

    public func planToday(
        scored: ScoredOutfit, occasion: String, in wardrobe: Wardrobe, context: ModelContext
    ) {
        do {
            let name = "Plan \(Date().formatted(date: .abbreviated, time: .omitted))"
            // D103：计划需要一个搭配实体来挂日历，但用户点的是「Plan」不是「Favorite」——
            // 顺手标成收藏会让收藏列表凭空多出「Plan Aug 12」（隐瞒做了的事）。
            let outfit = try OutfitFavoriteService.saveFavorite(
                name: name,
                itemIDs: scored.outfit.itemIDs,
                occasion: occasion,
                in: wardrobe,
                source: "copilot-plan",
                isFavorite: false,
                context: context)
            guard CalendarPlanService.plan(outfit: outfit, on: Date(), in: context) != nil else {
                // 日历没落库 → 那个只为挂日历而建的搭配是孤儿，必须一并回滚，
                // 否则「失败」之后库里仍多了一条没人引用的搭配（D103）。
                OutfitFavoriteService.discardOrphan(outfit, in: context)
                message = CalendarPlanService.saveFailedMessage
                AppLog.error("planToday calendar ModelSave failed", .app)
                return
            }
            message = "Added to calendar."
        } catch {
            message = Self.failureMessage(prefix: "Couldn't plan", error: error)
            AppLog.error("plan failed \(AppLog.errRef(error))", .app)
        }
    }

    /// Schedule an already-saved favorite (Favorites list / Calendar picker).
    /// Does not re-draft pieces — uses the outfit as stored; missing pieces → plan needsAttention.
    /// Returns `nil` when ModelSave fails (message set; no silent “Added to calendar”).
    @discardableResult
    public func planFavorite(
        _ outfit: ClosetModel.Outfit,
        on date: Date = Date(),
        in context: ModelContext,
        lookTitle: String? = nil
    ) -> CalendarPlan? {
        guard let plan = CalendarPlanService.plan(outfit: outfit, on: date, in: context) else {
            message = CalendarPlanService.saveFailedMessage
            AppLog.error("planFavorite calendar ModelSave failed", .app)
            return nil
        }
        message = Self.planScheduledMessage(
            lookTitle: lookTitle, needsAttention: plan.needsAttention)
        AppLog.info("favorite planned day attention=\(plan.needsAttention)", .app)
        return plan
    }

    /// Shared flash for Favorites / Calendar after scheduling a look.
    /// With a title → "Planned …"; without → "Added to calendar …".
    public static func planScheduledMessage(
        lookTitle: String? = nil,
        needsAttention: Bool
    ) -> String {
        let title = lookTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !title.isEmpty {
            return needsAttention
                ? "Planned \(title) — look needs attention."
                : "Planned \(title)."
        }
        return needsAttention
            ? "Added to calendar — look needs attention."
            : "Added to calendar."
    }

    /// Flash after a successful Save — includes where to open the list.
    public static let savedToFavoritesMessage =
        "Saved to favorites — open via Today toolbar."

    /// Human flash for Save/Plan failures (LocalizedError when available; no raw type dump).
    static func failureMessage(prefix: String, error: Error) -> String {
        if let draft = error as? OutfitDraftError, let desc = draft.errorDescription {
            return "\(prefix) — \(desc)"
        }
        if let localized = (error as? LocalizedError)?.errorDescription, !localized.isEmpty {
            return "\(prefix) — \(localized)"
        }
        return "\(prefix) — try again"
    }
}
