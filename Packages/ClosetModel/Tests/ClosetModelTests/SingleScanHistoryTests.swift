import Testing
import Foundation
import SwiftData
@testable import ClosetModel
import ClosetCore

/// D156：**打开单品详情，同一张表被扫了两遍。**
///
/// `ItemDetailViewModel.loadHistory` 依次调 `LaundryTracking.caption` 与
/// `WearStatsService.stats(for:)`——两者各自 `fetch(FetchDescriptor<WearRecord>())`
/// 取**全表**再在内存里过滤。实测（文件库、两年每日打卡 730 条）：
/// 单次全表取用约 **72 ms**，于是这一屏白白花掉一倍。
///
/// 试过更外科的招：`propertiesToFetch` 只取需要的两列——**反而更慢**
/// （119ms vs 72ms），SwiftData 的部分取用在这里是负优化。所以能省的
/// 就是那多出来的一遍。
///
/// SwiftData 的 `ModelContext` 绑在主线程上，fetch 本身挪不走
/// （D152 能挪是因为贵的是**计算**，快照成纯值即可；这里贵的是取用本身）。
/// 真要根治得上后台 `@ModelActor`——那是另一个量级的改动，先把重复的这遍去掉。
@MainActor
struct SingleScanHistoryTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    private func seed(_ ctx: ModelContext) throws -> Item {
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let tee = Item(name: "Tee"); tee.wardrobe = w; ctx.insert(tee)
        let other = Item(name: "Jeans"); other.wardrobe = w; ctx.insert(other)
        try ctx.save()
        for d in [1, 3, 9, 40] {
            let rec = WearRecord(date: Date().addingTimeInterval(-86_400 * Double(d)))
            rec.wornItemIDs = [tee.id.uuidString]
            rec.wardrobeSnapshotID = w.id
            ctx.insert(rec)
        }
        let unrelated = WearRecord(date: Date())
        unrelated.wornItemIDs = [other.id.uuidString]
        unrelated.wardrobeSnapshotID = w.id
        ctx.insert(unrelated)
        try ctx.save()
        return tee
    }

    /// 传入记录的版本与自己取表的版本**必须给出同一个答案**——
    /// 这是把两遍并成一遍的前提（同 D148/D151 的做法：先钉等价再替换）。
    @Test func theRecordsOverloadAgreesWithTheFetchingOne() throws {
        let ctx = try makeContext()
        let tee = try seed(ctx)
        let records = try ctx.fetch(FetchDescriptor<WearRecord>())

        #expect(WearStatsService.stats(for: tee, records: records)
                == WearStatsService.stats(for: tee, in: ctx))
        #expect(LaundryTracking.wearsSinceWash(tee, records: records)
                == LaundryTracking.wearsSinceWash(tee, in: ctx))
    }

    /// 洗过之后只数洗后那几次（口径不能因为换了入口而变）。
    @Test func washingResetsTheCountThroughBothPaths() throws {
        let ctx = try makeContext()
        let tee = try seed(ctx)
        tee.lastWashedAt = Date().addingTimeInterval(-86_400 * 5)
        try ctx.save()
        let records = try ctx.fetch(FetchDescriptor<WearRecord>())
        // 洗于 5 天前 → 只数第 1、3 天那两次（9 / 40 天前在洗之前）
        #expect(LaundryTracking.wearsSinceWash(tee, records: records) == 2)
        #expect(LaundryTracking.wearsSinceWash(tee, records: records)
                == LaundryTracking.wearsSinceWash(tee, in: ctx))
    }

    /// 空表不炸。
    @Test func noRecordsIsFine() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let tee = Item(name: "Tee"); tee.wardrobe = w; ctx.insert(tee)
        try ctx.save()
        #expect(WearStatsService.stats(for: tee, records: []).count == 0)
        #expect(LaundryTracking.wearsSinceWash(tee, records: []) == 0)
    }
}
