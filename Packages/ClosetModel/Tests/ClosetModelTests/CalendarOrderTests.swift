import Testing
import Foundation
import SwiftData
@testable import ClosetModel

/// D168：日历列表也在**排 SwiftData 模型**——每次比较都走属性访问层（D157 同款）。
///
/// 实测（文件库、400 条计划）：现状「全取 + 内存排序」**111ms**，
/// 而先把参与比较的键摊成纯值再排只要 **37ms**，行为一个字不变。
///
/// 也量了另外两条路作对照：让存储层排序 30ms、再加分页只取 30 条 3ms——
/// 都更快，但**都会改行为**：`resolvedDayKey` 对旧数据（空 dayKey）有回退，
/// 且同日要按 id 决胜，而 `SortDescriptor` 表达不了这两条。
/// 分页更是产品决定（日历要显示多少条）。所以这一波只取零风险的那 3 倍。
@MainActor
struct CalendarOrderTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    /// 与旧写法**逐条一致**——这是替换的前提（同 D148/D151/D157 的做法）。
    @Test func theOrderMatchesTheOldComparator() throws {
        let ctx = try makeContext()
        for d in 0..<40 {
            let p = CalendarPlan(date: Date().addingTimeInterval(-86_400 * Double(d)))
            p.dayKey = CalendarPlanService.dayKey(for: p.date)
            ctx.insert(p)
        }
        // 同日多条（逼出 id 决胜）
        let sameDay = Date()
        for _ in 0..<5 {
            let p = CalendarPlan(date: sameDay)
            p.dayKey = CalendarPlanService.dayKey(for: sameDay)
            ctx.insert(p)
        }
        // 旧数据：空 dayKey，走 date 回退
        let legacy = CalendarPlan(date: Date().addingTimeInterval(-86_400 * 3))
        legacy.dayKey = ""
        ctx.insert(legacy)
        try ctx.save()

        let all = try ctx.fetch(FetchDescriptor<CalendarPlan>())
        let legacyOrder = all.sorted {
            (CalendarPlanService.resolvedDayKey($0), $0.id.uuidString)
                > (CalendarPlanService.resolvedDayKey($1), $1.id.uuidString)
        }
        #expect(CalendarPlanService.allPlans(in: ctx).map(\.id) == legacyOrder.map(\.id),
                "新旧排序结果不同 —— 日历行的顺序会变")
    }

    /// 空 dayKey 的旧数据仍按 date 回退定位（不得掉到列表末尾）。
    @Test func legacyRowsKeepTheirDateFallback() throws {
        let ctx = try makeContext()
        let recent = CalendarPlan(date: Date())
        recent.dayKey = CalendarPlanService.dayKey(for: recent.date)
        ctx.insert(recent)
        let legacyToday = CalendarPlan(date: Date())
        legacyToday.dayKey = ""          // 旧数据
        ctx.insert(legacyToday)
        let old = CalendarPlan(date: Date().addingTimeInterval(-86_400 * 30))
        old.dayKey = CalendarPlanService.dayKey(for: old.date)
        ctx.insert(old)
        try ctx.save()

        let ordered = CalendarPlanService.allPlans(in: ctx)
        #expect(ordered.last?.id == old.id, "空 dayKey 的旧数据被排到了最后")
    }

    /// 空表不炸。
    @Test func anEmptyCalendarIsFine() throws {
        #expect(CalendarPlanService.allPlans(in: try makeContext()).isEmpty)
    }
}
