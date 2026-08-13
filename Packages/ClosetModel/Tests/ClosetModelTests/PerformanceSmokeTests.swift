import Testing
import Foundation
import SwiftData
@testable import ClosetModel
import ClosetCore

/// D173：MVP-PLAN 的 M1 退出门写着「**M1 末尾插一次百件网格性能 smoke（不等 M3）**」——
/// 而它从没做过。本 session 抓到的两次性能灾难正是它该拦的：
/// 冷天推荐 3013ms 主线程冻结（D151/D152）、百件网格单次 body 排序 183ms（D157）。
///
/// **这不是性能断言，是灾难探测器。** 门限取实测值的十几倍——
/// 精确的性能目标要真机 Instruments（M3 的事），而这里要挡住的是
/// 「某次改动让它慢一个数量级」这种事：那种回归在 CI 上也看得见，
/// 而且往往是一行代码引起的（把纯值排序换回排模型、把批量查询换回逐件查）。
///
/// 门限刻意宽松：宁可漏掉 2 倍的劣化，也不要一条动不动就红的测试——
/// 一条被无视的红测试比没有测试更糟。
@MainActor
struct PerformanceSmokeTests {

    private func makeClosetWith(items count: Int) throws -> (ModelContext, Wardrobe) {
        let ctx = try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
        let w = Wardrobe(name: "Smoke"); ctx.insert(w)
        let slots = ["top", "bottom", "shoes", "outerwear"]
        for i in 0..<count {
            let it = Item(name: "piece-\(String(format: "%03d", (i * 37) % max(count, 1)))")
            it.wardrobe = w
            it.slotRaw = slots[i % slots.count]
            it.statusRaw = i % 9 == 0 ? "inWash" : "available"
            it.occasionsRaw = ["work"]
            it.warmthRaw = Warmth.medium.rawValue
            it.colorHue = Double((i * 17) % 360)
            it.colorIsNeutral = i % 6 == 0
            ctx.insert(it)
        }
        try ctx.save()
        return (ctx, w)
    }

    /// 百件网格的排序**不得退回「直接排 SwiftData 模型」**（D157）。
    ///
    /// 判据取**相对比值**而非绝对毫秒：与「同样内容的纯值数组排序」相比，
    /// 慢出 4 倍以上就说明键没有被摊平。相对判据与机器速度无关，
    /// 在慢 CI 上也不会假红——而绝对门限要么松到抓不住（第一版取 150ms，
    /// 我把 `sortedByName` 改回排模型，门照样绿），要么紧到动不动就红。
    @Test func theGridSortDoesNotDegradeToModelSorting() throws {
        let (_, w) = try makeClosetWith(items: 100)
        let all = w.items ?? []
        // 纯值基准：同样的比较规则，只是键已经摊平
        struct Row { let name: String; let id: String }
        let rows = all.map { Row(name: $0.name, id: $0.id.uuidString) }
        _ = all.sortedByName()          // 预热两条路
        _ = rows.sorted { $0.name == $1.name ? $0.id < $1.id : $0.name < $1.name }

        var baseline = 0.0, actual = 0.0
        for _ in 0..<5 {
            var t0 = CFAbsoluteTimeGetCurrent()
            _ = rows.sorted { $0.name == $1.name ? $0.id < $1.id : $0.name < $1.name }
            baseline += CFAbsoluteTimeGetCurrent() - t0
            t0 = CFAbsoluteTimeGetCurrent()
            _ = all.sortedByName()
            actual += CFAbsoluteTimeGetCurrent() - t0
        }
        let ratio = actual / max(baseline, 1e-9)
        #expect(ratio < 4, Comment(rawValue:
            "排 100 件比排等量纯值慢 \(String(format: "%.1f", ratio)) 倍 —— "
            + "键没摊平，多半是 `sortedByName` 又排回 SwiftData 模型了（D157）"))
    }

    /// 百件衣柜的推荐：冷天（组合空间最大）。
    /// 实测（D151 之后）约 200-400ms；门限 3000ms = 十倍量级的余量。
    @Test func aHundredPieceColdDayRecommendationFinishes() throws {
        let (_, w) = try makeClosetWith(items: 100)
        let t0 = CFAbsoluteTimeGetCurrent()
        let out = RecommendationService.detailed(
            for: w, anchors: [], occasion: "work", daytimeTempF: 38,
            wornWithin7DaysIDs: [], bodyShape: nil, bodyShapeWeight: 0,
            colorSeason: nil, coldBias: 0, maxSuggestions: 3)
        let ms = (CFAbsoluteTimeGetCurrent() - t0) * 1000
        #expect(!out.suggestions.isEmpty, "百件衣柜冷天拼不出一身 —— 引擎坏了，不是慢")
        #expect(ms < 3000, Comment(rawValue:
            "百件冷天推荐用了 \(String(format: "%.0f", ms))ms —— "
            + "多半是又开始把每套都物化了（D151）"))
    }

    /// 两年穿着记录的整柜统计（检索页每行都要）。
    /// 实测约 85ms；门限 1000ms。
    @Test func twoYearsOfWearStatsStayBounded() throws {
        let (ctx, w) = try makeClosetWith(items: 100)
        let ids = (w.items ?? []).map(\.id)
        for d in 0..<730 {
            let r = WearRecord(date: Date().addingTimeInterval(-86_400 * Double(d)))
            r.wornItemIDs = [ids[d % ids.count].uuidString]
            r.wardrobeSnapshotID = w.id
            ctx.insert(r)
        }
        try ctx.save()

        let t0 = CFAbsoluteTimeGetCurrent()
        let stats = WearStatsService.stats(forItemsIn: w, in: ctx)
        let ms = (CFAbsoluteTimeGetCurrent() - t0) * 1000
        #expect(stats.count == 100)
        #expect(ms < 1000, Comment(rawValue:
            "整柜穿着统计用了 \(String(format: "%.0f", ms))ms —— "
            + "多半是又退回逐件全表扫描了（D141）"))
    }
}
