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
    /// D211：这道门用的是**比值**（排模型 vs 排等量纯值），本以为比值天然抗负载——
    /// **实测不是**：load ≈ 31 时量到 15.1（门限 4），而同一次会话里前一趟它是过的。
    /// 原因是两边不同源：SwiftData 模型访问在负载下退化得比纯值排序厉害得多
    ///（锁竞争、faulting），比值跟着一起飘。所以它同样只在安静的机器上说得准。
    @Test(.enabled(if: PerfEnvironment.machineIsQuietEnough))
    func theGridSortDoesNotDegradeToModelSorting() throws {
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

    /// 百件衣柜冷天**拼得出一身**——这是正确性，与快慢无关。
    ///
    /// D211：此前它与时间断言挤在同一个 `@Test` 里，于是机器一忙、时间门一红，
    /// 这条正确性断言也跟着被判失败——**而它其实是过的**。
    /// 性能噪声吞掉正确性信号，是比慢更糟的事。
    @Test func aHundredPieceColdDayStillProducesLooks() throws {
        let (_, w) = try makeClosetWith(items: 100)
        let out = RecommendationService.detailed(
            for: w, anchors: [], occasion: "work", daytimeTempF: 38,
            wornWithin7DaysIDs: [], bodyShape: nil, bodyShapeWeight: 0,
            colorSeason: nil, coldBias: 0, maxSuggestions: 3)
        #expect(!out.suggestions.isEmpty, "百件衣柜冷天拼不出一身 —— 引擎坏了，不是慢")
    }

    /// 百件衣柜的推荐**要多久**：冷天（组合空间最大）。
    /// 实测（D151 之后）约 200-400ms；门限 3000ms = 十倍量级的余量。
    ///
    /// **机器忙的时候这条会被跳过**（见 `machineIsQuietEnough`）——
    /// 跳过是**明说**的（报告里是 skipped 不是 passed），
    /// 而「红了但我说那是负载」是不明说的：说着说着就成了每次都忽略它。
    @Test(.enabled(if: PerfEnvironment.machineIsQuietEnough))
    func aHundredPieceColdDayRecommendationFinishes() throws {
        let (_, w) = try makeClosetWith(items: 100)
        let t0 = CFAbsoluteTimeGetCurrent()
        _ = RecommendationService.detailed(
            for: w, anchors: [], occasion: "work", daytimeTempF: 38,
            wornWithin7DaysIDs: [], bodyShape: nil, bodyShapeWeight: 0,
            colorSeason: nil, coldBias: 0, maxSuggestions: 3)
        let ms = (CFAbsoluteTimeGetCurrent() - t0) * 1000
        #expect(ms < 3000, Comment(rawValue:
            "百件冷天推荐用了 \(String(format: "%.0f", ms))ms —— "
            + "多半是又开始把每套都物化了（D151）"))
    }

    /// 两年穿着记录的整柜统计（检索页每行都要）。
    /// 实测约 85ms；门限 1000ms。
    @Test(.enabled(if: PerfEnvironment.machineIsQuietEnough))
    func twoYearsOfWearStatsStayBounded() throws {
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

/// 性能门的环境判据（`@Test(.enabled(if:))` 的闭包要 Sendable，
/// 因此住在 suite 外面而不是它的 static 成员上）。
enum PerfEnvironment {
    /// 这台机器**此刻**测不测得了性能。
    ///
    /// D211 实证：同一条门在 load ≈ 17-21 时量到 3.9s / 6.6s / 8.4s / 11.2s，
    /// 而门限是 3s、基线实测 200-400ms。用 `git worktree` 把**三波之前的代码**
    /// 拉出来在同一时刻跑，同样红（11.2s）——所以那不是回归，是机器。
    ///
    /// 判据用 **load average 对比核数**，不用自造校准：
    /// 试过「纯 CPU 排序当校准、按比值判断」，三次量到 35 / 75 / 60，
    /// 比值本身就不稳——因为校准是纯 CPU，而被测路径带着 SwiftData 的锁与 I/O，
    /// 两者在负载下**不同比例地变慢**。
    ///
    /// 一开始我以为隔壁 `sortedByName` 那道比值门天然抗负载（它比的是同类操作），
    /// **实测打脸**：load ≈ 31 时它量到 15.1（门限 4），同一次会话里前一趟还是过的。
    /// 「排模型」与「排纯值」也不同源。**结论：这台机器上没有可靠的相对基准**，
    /// 三道时间敏感的门统一靠环境判据，忙就明说跳过。
    static var machineIsQuietEnough: Bool {
        var loads = [Double](repeating: 0, count: 3)
        guard getloadavg(&loads, 3) > 0 else { return true }   // 读不到就照常测
        let cpus = Double(ProcessInfo.processInfo.activeProcessorCount)
        return loads[0] < cpus * 0.5
    }
}
