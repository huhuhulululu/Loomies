import Testing
import Foundation
import SwiftData
@testable import ClosetModel
import ClosetCore

/// D119：**记了一年，从来不给用户看**。
///
/// 每次「Wore it」都落了一条 `WearRecord`，而单品详情页上没有任何一处
/// 回答「这件我穿过几次 / 上次什么时候穿的」。DEMAND-VALIDATION §2 记录的
/// PIVOT 明确点名「记住我哪天穿了什么 / 防重复购买」是研究里的 **#1 JTBD
/// （19 次自发提及）**——而本仓写了数据、没有出口。
///
/// 刻意**不做**的：CPW（每次穿着成本，要价格数据）、利用率仪表盘、
/// 「最少穿」排行榜。那些是 FEATURE-GAP 里被否掉的「统计秀」，
/// 这里只做一句在用户看得见的地方就能用上的话。
@MainActor
struct WearStatsServiceTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    private func wear(
        _ ctx: ModelContext, _ wardrobe: Wardrobe, _ items: [Item], daysAgo: Int
    ) {
        let rec = WearRecord(date: Date().addingTimeInterval(-86_400 * Double(daysAgo)))
        rec.wornItemIDs = items.map { $0.id.uuidString }
        rec.wardrobeSnapshotID = wardrobe.id
        ctx.insert(rec)
    }

    /// 没穿过就说没穿过——**不得**伪造一个 0 或者一个日期。
    @Test func aNeverWornPieceSaysSo() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let tee = Item(name: "Tee"); tee.wardrobe = w; ctx.insert(tee)
        try ctx.save()

        let stats = WearStatsService.stats(for: tee, in: ctx)
        #expect(stats.count == 0)
        #expect(stats.lastWorn == nil)
        #expect(stats.summary == WearStatsService.neverWornSummary)
    }

    /// 穿过几次就是几次。
    @Test func itCountsEveryWear() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let tee = Item(name: "Tee"); tee.wardrobe = w; ctx.insert(tee)
        try ctx.save()
        wear(ctx, w, [tee], daysAgo: 10)
        wear(ctx, w, [tee], daysAgo: 3)
        wear(ctx, w, [tee], daysAgo: 1)
        try ctx.save()

        let stats = WearStatsService.stats(for: tee, in: ctx)
        #expect(stats.count == 3)
    }

    /// 上次穿是**最近**那次，不是第一次。
    @Test func theLastWornDateIsTheMostRecent() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let tee = Item(name: "Tee"); tee.wardrobe = w; ctx.insert(tee)
        try ctx.save()
        wear(ctx, w, [tee], daysAgo: 30)
        wear(ctx, w, [tee], daysAgo: 2)
        try ctx.save()

        let stats = try #require(WearStatsService.stats(for: tee, in: ctx).lastWorn)
        let daysAgo = Calendar.current.dateComponents(
            [.day], from: stats, to: Date()).day ?? -1
        #expect(daysAgo <= 2)
    }

    /// 别人的穿着不算在我头上。
    @Test func anotherPiecesWearsDoNotCount() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let tee = Item(name: "Tee"); tee.wardrobe = w; ctx.insert(tee)
        let jeans = Item(name: "Jeans"); jeans.wardrobe = w; ctx.insert(jeans)
        try ctx.save()
        wear(ctx, w, [jeans], daysAgo: 1)
        try ctx.save()

        #expect(WearStatsService.stats(for: tee, in: ctx).count == 0)
        #expect(WearStatsService.stats(for: jeans, in: ctx).count == 1)
    }

    /// **跨柜不串**：同一件只属于一个柜，别的柜的快照不该算进来
    ///（与 `WearHistoryView` 的既有口径一致）。
    @Test func anotherClosetsRecordsDoNotLeakIn() throws {
        let ctx = try makeContext()
        let home = Wardrobe(name: "Home"); ctx.insert(home)
        let trip = Wardrobe(name: "Trip"); ctx.insert(trip)
        let tee = Item(name: "Tee"); tee.wardrobe = home; ctx.insert(tee)
        try ctx.save()
        wear(ctx, home, [tee], daysAgo: 1)
        wear(ctx, trip, [tee], daysAgo: 2)   // 另一个柜的快照
        try ctx.save()

        #expect(WearStatsService.stats(for: tee, in: ctx).count == 1)
    }

    /// 摘要文案：单数/复数、以及「几天前」这种人话。
    @Test func theSummaryReadsLikeASentence() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let tee = Item(name: "Tee"); tee.wardrobe = w; ctx.insert(tee)
        try ctx.save()
        wear(ctx, w, [tee], daysAgo: 1)
        try ctx.save()

        let summary = WearStatsService.stats(for: tee, in: ctx).summary
        #expect(summary.contains("once") || summary.contains("1 time"),
                Comment(rawValue: summary))
        #expect(!summary.contains("times"), Comment(rawValue: "单数写成了复数：\(summary)"))
    }

    @Test func pluralWearsReadCorrectly() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let tee = Item(name: "Tee"); tee.wardrobe = w; ctx.insert(tee)
        try ctx.save()
        wear(ctx, w, [tee], daysAgo: 5)
        wear(ctx, w, [tee], daysAgo: 2)
        try ctx.save()
        #expect(WearStatsService.stats(for: tee, in: ctx).summary.contains("2 times"))
    }

    /// 一次批量取（详情页之外还要给检索页用，逐件查会退化成 N 次全表扫描）。
    @Test func aBatchLookupAgreesWithTheSingleOne() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let tee = Item(name: "Tee"); tee.wardrobe = w; ctx.insert(tee)
        let jeans = Item(name: "Jeans"); jeans.wardrobe = w; ctx.insert(jeans)
        try ctx.save()
        wear(ctx, w, [tee], daysAgo: 3)
        wear(ctx, w, [tee, jeans], daysAgo: 1)
        try ctx.save()

        let batch = WearStatsService.stats(forItemsIn: w, in: ctx)
        #expect(batch[tee.id]?.count == 2)
        #expect(batch[jeans.id]?.count == 1)
        #expect(batch[tee.id]?.count == WearStatsService.stats(for: tee, in: ctx).count)
    }
}
