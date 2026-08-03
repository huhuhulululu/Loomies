import Foundation
import SwiftData

/// 穿搭日历计划（DESIGN §F5 / 实体 CalendarPlan）。
/// v1.0 最小：某日绑定本柜 Outfit；Outfit 缺件 → needsAttention。
public enum CalendarPlanService {

    /// 为 date 建/更新计划。若 outfit 跨柜不变量失败，仍可写入但 needsAttention=true。
    @discardableResult
    public static func plan(
        outfit: Outfit, on date: Date, in context: ModelContext
    ) -> CalendarPlan {
        let day = calendarDay(date)
        // 同日已有计划则覆盖 outfit
        let existing = (try? context.fetch(FetchDescriptor<CalendarPlan>())) ?? []
        let plan: CalendarPlan
        if let found = existing.first(where: { calendarDay($0.date) == day }) {
            plan = found
            plan.outfit = outfit
        } else {
            plan = CalendarPlan(date: day)
            plan.outfit = outfit
            context.insert(plan)
        }
        plan.needsAttention = outfit.missing || !WardrobeInvariant.isValid(outfit)
        try? context.save()
        return plan
    }

    /// 刷新某搭配关联计划的 needsAttention（转移后调用）。
    public static func refreshAttention(for outfit: Outfit, in context: ModelContext) {
        let plans = (try? context.fetch(FetchDescriptor<CalendarPlan>())) ?? []
        for p in plans where p.outfit?.id == outfit.id {
            p.needsAttention = outfit.missing || !WardrobeInvariant.isValid(outfit)
        }
        try? context.save()
    }

    /// 查询某日计划（按日历日对齐）。
    public static func plan(on date: Date, in context: ModelContext) -> CalendarPlan? {
        let day = calendarDay(date)
        let all = (try? context.fetch(FetchDescriptor<CalendarPlan>())) ?? []
        return all.first { calendarDay($0.date) == day }
    }

    private static func calendarDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
}
