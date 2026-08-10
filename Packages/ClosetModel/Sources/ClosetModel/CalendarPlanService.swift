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
        outfit: Outfit, on date: Date, in context: ModelContext,
        calendar: Calendar = .current
    ) -> CalendarPlan? {
        let key = dayKey(for: date, calendar: calendar)
        // 同日已有计划则覆盖 outfit（按 dayKey 对齐，跨时区稳定）
        let existing = (try? context.fetch(FetchDescriptor<CalendarPlan>())) ?? []
        let plan: CalendarPlan
        let isNew: Bool
        let previousOutfit: Outfit?
        let previousAttention: Bool
        let previousDayKey: String
        if let found = existing.first(where: { resolvedDayKey($0) == key }) {
            plan = found
            previousOutfit = found.outfit
            previousAttention = found.needsAttention
            previousDayKey = found.dayKey
            plan.outfit = outfit
            plan.dayKey = key   // 旧数据（空键）覆盖写时顺带固化
            isNew = false
        } else {
            plan = CalendarPlan(date: calendar.startOfDay(for: date))
            plan.dayKey = key
            plan.outfit = outfit
            context.insert(plan)
            previousOutfit = nil
            previousAttention = false
            previousDayKey = ""
            isNew = true
        }
        plan.needsAttention = shouldNeedAttention(outfit)
        guard ModelSave.save(context, label: "calendarPlan") else {
            if !isNew {
                plan.outfit = previousOutfit
                plan.needsAttention = previousAttention
                plan.dayKey = previousDayKey
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

    /// 查询某日计划（按 dayKey 日历日对齐，跨时区稳定）。
    public static func plan(
        on date: Date, in context: ModelContext, calendar: Calendar = .current
    ) -> CalendarPlan? {
        let key = dayKey(for: date, calendar: calendar)
        let all = (try? context.fetch(FetchDescriptor<CalendarPlan>())) ?? []
        return all.first { resolvedDayKey($0) == key }
    }

    /// 全部计划，新→旧（dayKey 字典序 = 时序；同日历史重复行按 id 决胜）。
    public static func allPlans(in context: ModelContext) -> [CalendarPlan] {
        let all = (try? context.fetch(FetchDescriptor<CalendarPlan>())) ?? []
        return all.sorted {
            (resolvedDayKey($0), $0.id.uuidString) > (resolvedDayKey($1), $1.id.uuidString)
        }
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

    // MARK: - DayKey（日历日持久化口径）

    /// "yyyy-MM-dd"（按给定 calendar 的日界；固定 gregorian 组件格式，无 locale 依赖）。
    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 2026, c.month ?? 1, c.day ?? 1)
    }

    /// 计划的有效日键：旧数据（空键）退回按当前设备历解释 date（与历史行为一致）。
    public static func resolvedDayKey(_ plan: CalendarPlan) -> String {
        plan.dayKey.isEmpty ? dayKey(for: plan.date) : plan.dayKey
    }

    /// 展示用日期：dayKey → 当前时区**正午**瞬时值（避开 DST 无午夜日），
    /// `Text(_, style: .date)` 渲染不再随时区漂一天。
    public static func displayDate(_ plan: CalendarPlan) -> Date {
        let key = resolvedDayKey(plan)
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return plan.date }
        var comps = DateComponents()
        comps.year = parts[0]; comps.month = parts[1]; comps.day = parts[2]; comps.hour = 12
        return Calendar.current.date(from: comps) ?? plan.date
    }
}
