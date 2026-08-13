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

    // D146：`refreshAttention(for:in:)` 已删——**全仓零调用点**（连测试都没有）。
    // 它做的是 `recomputeAttention` + 立即 save，而每个真实调用点都要
    // 把 attention 的重算并进**自己那一次** save（中途 save 会提前提交
    // pending 变更——这条纪律在 deleteItem/transfer 的注释里反复写过）。
    // 换句话说它的语义与本仓的写入模型相冲，永远不会有人该调它。
    //
    // 复活条件：出现一个「只改 attention、不改别的」的独立入口
    //（比如日历页手动「刷新提醒」按钮）。那时再加回来，
    // 并且必须有人检查它的返回值——失败了不许静默。

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
        // D168：**先把参与比较的键摊成纯值再排**（D157 同款）。
        // 直接排 SwiftData 模型时每次比较都走属性访问层——实测 400 条计划
        // 111ms，摊平后 37ms，行为一个字不变（`CalendarOrderTests` 钉住）。
        //
        // 更快的两条路都**会改行为**，故不取：让存储层排序（30ms）表达不了
        // `resolvedDayKey` 对旧数据的回退与同日的 id 决胜；再加分页（3ms）
        // 是产品决定（日历显示多少条）。
        var decorated: [(key: String, id: String, plan: CalendarPlan)] = []
        for plan in all {
            decorated.append((resolvedDayKey(plan), plan.id.uuidString, plan))
        }
        decorated.sort { ($0.key, $0.id) > ($1.key, $1.id) }
        return decorated.map(\.plan)
    }

    /// 某柜相关计划（outfit.wardrobe 匹配）。
    public static func plans(for wardrobe: Wardrobe, in context: ModelContext) -> [CalendarPlan] {
        allPlans(in: context).filter { $0.outfit?.wardrobe?.id == wardrobe.id }
    }

    /// 仅 needsAttention。
    public static func attentionPlans(in context: ModelContext) -> [CalendarPlan] {
        allPlans(in: context).filter(\.needsAttention)
    }

    /// 删除一条搭配**之前**必须先解绑它的计划（D114）。
    ///
    /// `CalendarPlan.outfit` 是 schema 里唯一没有反向关系的引用——SwiftData
    /// 因此不会在搭配被删时置空它，实测会留下一条指向已删行的悬挂引用。
    /// 加反向端是**破坏性** schema 变更（golden 门判定；且 TestFlight 上已有
    /// 真实安装数据，为一条当前不可达的隐患冒开不了库的风险不划算，见 ADR D114），
    /// 所以不变式由这里统一维持，`PlanUnbindLintTests` 守住每个删除点都调它。
    ///
    /// 不落库：调用方在自己的那次 save 里一并提交（失败也一起回滚）。
    /// 返回解绑的条数，供收据如实说话。
    @discardableResult
    public static func unbindPlans(referencing outfit: Outfit, in context: ModelContext) -> Int {
        let all = (try? context.fetch(FetchDescriptor<CalendarPlan>())) ?? []
        let targetID = outfit.id
        var unbound = 0
        for plan in all where plan.outfit?.id == targetID {
            plan.outfit = nil
            plan.needsAttention = true   // 这条计划现在没有搭配可穿，须让用户看见
            unbound += 1
        }
        return unbound
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
