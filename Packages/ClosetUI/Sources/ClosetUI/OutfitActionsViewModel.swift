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
            message = "Saved to favorites."
        } catch {
            message = "Save failed: \(error.localizedDescription)"
            AppLog.error("favorite failed \(error)", .app)
        }
    }

    public func planToday(
        scored: ScoredOutfit, occasion: String, in wardrobe: Wardrobe, context: ModelContext
    ) {
        do {
            let name = "Plan \(Date().formatted(date: .abbreviated, time: .omitted))"
            let outfit = try OutfitFavoriteService.saveFavorite(
                name: name,
                itemIDs: scored.outfit.itemIDs,
                occasion: occasion,
                in: wardrobe,
                source: "copilot-plan",
                context: context)
            _ = CalendarPlanService.plan(outfit: outfit, on: Date(), in: context)
            message = "Added to calendar."
        } catch {
            message = "Plan failed: \(error.localizedDescription)"
            AppLog.error("plan failed \(error)", .app)
        }
    }
}
