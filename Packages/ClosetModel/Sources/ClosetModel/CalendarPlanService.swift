import Foundation
import SwiftData
import ClosetCore

/// 穿搭日历计划（DESIGN §F5 / 实体 CalendarPlan）。
/// v1.0 最小：某日绑定本柜 Outfit；Outfit 缺件/永久缺件 → needsAttention。
public enum CalendarPlanService {

    /// Customer toast when ModelSave fails on plan (no silent “Added to calendar”).
    public static let saveFailedMessage = "Couldn't plan — try again"

    /// Customer toast when ModelSave fails on swipe-delete (list must not silently drop).
    public static let removeSaveFailedMessage = "Couldn't remove plan — try again"

    /// True when Calendar should flag the plan (transfer missing, deleted piece, or cross-wardrobe).
    public static func shouldNeedAttention(_ outfit: Outfit) -> Bool {
        outfit.missing
            || outfit.permanentlyMissing
            || !WardrobeInvariant.isValid(outfit)
    }

    /// 为 date 建/更新计划。若 outfit 跨柜不变量失败，仍可写入但 needsAttention=true。
    /// Returns `nil` when ModelSave fails (new insert discarded by rollback; existing outfit/attention restored).
    @discardableResult
    public static func plan(
        outfit: Outfit, on date: Date, in context: ModelContext
    ) -> CalendarPlan? {
        let day = calendarDay(date)
        // 同日已有计划则覆盖 outfit
        let existing = (try? context.fetch(FetchDescriptor<CalendarPlan>())) ?? []
        let plan: CalendarPlan
        let isNew: Bool
        let previousOutfit: Outfit?
        let previousAttention: Bool
        if let found = existing.first(where: { calendarDay($0.date) == day }) {
            plan = found
            previousOutfit = found.outfit
            previousAttention = found.needsAttention
            plan.outfit = outfit
            isNew = false
        } else {
            plan = CalendarPlan(date: day)
            plan.outfit = outfit
            context.insert(plan)
            previousOutfit = nil
            previousAttention = false
            isNew = true
        }
        plan.needsAttention = shouldNeedAttention(outfit)
        guard ModelSave.save(context, label: "calendarPlan") else {
            if !isNew {
                plan.outfit = previousOutfit
                plan.needsAttention = previousAttention
            }
            // rollback 一并丢弃新建 pending insert（delete+rollback 会残留脏标记）
            context.rollback()   // 失败变更不得滞留，否则污染下一次无关 save
            AppLog.error("calendarPlan save failed", .data)
            return nil
        }
        return plan
    }

    /// 不落盘的 attention 重算——供 deleteItem / transfer 内部调用，
    /// 由调用方在操作结尾单次 save（中途 save 会提前提交 pending 变更）。
    public static func recomputeAttention(for outfit: Outfit, in context: ModelContext) {
        let plans = (try? context.fetch(FetchDescriptor<CalendarPlan>())) ?? []
        for p in plans where p.outfit?.id == outfit.id {
            p.needsAttention = shouldNeedAttention(outfit)
        }
    }

    /// 刷新某搭配关联计划的 needsAttention 并立即落盘（独立调用方使用）。
    @discardableResult
    public static func refreshAttention(for outfit: Outfit, in context: ModelContext) -> Bool {
        recomputeAttention(for: outfit, in: context)
        return ModelSave.save(context, label: "calendarRefresh")
    }

    /// 查询某日计划（按日历日对齐）。
    public static func plan(on date: Date, in context: ModelContext) -> CalendarPlan? {
        let day = calendarDay(date)
        let all = (try? context.fetch(FetchDescriptor<CalendarPlan>())) ?? []
        return all.first { calendarDay($0.date) == day }
    }

    /// 全部计划，新→旧。
    public static func allPlans(in context: ModelContext) -> [CalendarPlan] {
        let all = (try? context.fetch(FetchDescriptor<CalendarPlan>())) ?? []
        return all.sorted { $0.date > $1.date }
    }

    /// 某柜相关计划（outfit.wardrobe 匹配）。
    public static func plans(for wardrobe: Wardrobe, in context: ModelContext) -> [CalendarPlan] {
        allPlans(in: context).filter { $0.outfit?.wardrobe?.id == wardrobe.id }
    }

    /// 仅 needsAttention。
    public static func attentionPlans(in context: ModelContext) -> [CalendarPlan] {
        allPlans(in: context).filter(\.needsAttention)
    }

    /// 删除计划。 Returns `false` when ModelSave fails.
    @discardableResult
    public static func remove(_ plan: CalendarPlan, in context: ModelContext) -> Bool {
        context.delete(plan)
        guard ModelSave.save(context, label: "calendarRemove") else {
            context.rollback()   // 失败删除不得滞留，否则污染下一次无关 save
            AppLog.error("calendarRemove save failed", .data)
            return false
        }
        return true
    }

    public static func calendarDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
}
