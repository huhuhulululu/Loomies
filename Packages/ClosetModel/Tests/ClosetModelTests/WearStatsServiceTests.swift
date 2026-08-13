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

    /// D134：**转移过的件不得归零**。
    ///
    /// 记录挂的是穿着那天的柜快照——按「当前柜」过滤的话，
    /// 用户把冬装挪进「换季箱」的那一刻，一年的记录当场变成「没穿过」。
    /// 单品 id 全局唯一，跨柜聚合正是这里想要的。
    @Test func movingAPieceDoesNotEraseItsHistory() throws {
        let ctx = try makeContext()
        let home = Wardrobe(name: "Home"); ctx.insert(home)
        let box = Wardrobe(name: "Off-season"); ctx.insert(box)
        let coat = Item(name: "Coat"); coat.wardrobe = home; ctx.insert(coat)
        try ctx.save()
        wear(ctx, home, [coat], daysAgo: 30)
        wear(ctx, home, [coat], daysAgo: 10)
        try ctx.save()

        coat.wardrobe = box            // 换季转移
        try ctx.save()

        #expect(WearStatsService.stats(for: coat, in: ctx).count == 2,
                "转移之后一年的穿着记录归零了")
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

/// D138：**超过一年要带年份**。此前一律只给「Aug 11」——
/// 去年八月穿的和上周穿的读起来一模一样，而「上次什么时候穿的」
/// 这个问题的全部价值就在于分辨它们。
struct WearDateCopyTests {

    private func daysAgo(_ n: Int) -> Date {
        Date().addingTimeInterval(-86_400 * Double(n))
    }

    @Test func recentDaysReadAsWords() {
        #expect(WearStatsService.Stats.relative(daysAgo(0)) == "today")
        #expect(WearStatsService.Stats.relative(daysAgo(1)) == "yesterday")
        #expect(WearStatsService.Stats.relative(daysAgo(3)) == "3 days ago")
    }

    /// 一周到一年：月日就够（同一年内不会歧义）。
    @Test func thisYearShowsMonthAndDay() {
        let text = WearStatsService.Stats.relative(daysAgo(60))
        #expect(!text.contains("20"), Comment(rawValue: "半年内不必带年份：\(text)"))
        #expect(text.contains(where: { $0.isNumber }))
    }

    /// 超过一年必须带年份，否则与今年同月同日无法区分。
    @Test func olderThanAYearCarriesTheYear() {
        let text = WearStatsService.Stats.relative(daysAgo(400))
        #expect(text.contains("20"),
                Comment(rawValue: "一年前穿的和上周读起来一样：\(text)"))
    }
}

/// D141：**检索的每一次按键都在扫整张穿着记录表——而且按柜扫了好几遍。**
///
/// `SearchViewModel.refreshWearStats` 对结果里出现的**每个柜**调一次
/// `stats(forItemsIn:)`，而那个方法每次都 `fetch(FetchDescriptor<WearRecord>())`
/// 取全表。跨柜检索命中 5 个柜 = 5 次全表扫描，挂在 0.25s 的防抖上，
/// 每敲一个字重来一遍。而 `WearRecord` 是这个 App 里**增长最快**的表
/// （每天至少一条，一年三百多条，还从不删）。
///
/// 要的其实只是「结果里这些件的统计」——按 id 一次取完就够。
@MainActor
struct WearStatsBatchByIDTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    /// 一次取多件，跨柜也一次搞定（这正是跨柜检索的形状）。
    @Test func oneLookupCoversItemsFromDifferentClosets() throws {
        let ctx = try makeContext()
        let home = Wardrobe(name: "Home"); ctx.insert(home)
        let box = Wardrobe(name: "Off-season"); ctx.insert(box)
        let tee = Item(name: "Tee"); tee.wardrobe = home; ctx.insert(tee)
        let coat = Item(name: "Coat"); coat.wardrobe = box; ctx.insert(coat)
        try ctx.save()
        for (item, wardrobe, days) in [(tee, home, 3), (tee, home, 1), (coat, box, 9)] {
            let rec = WearRecord(date: Date().addingTimeInterval(-86_400 * Double(days)))
            rec.wornItemIDs = [item.id.uuidString]
            rec.wardrobeSnapshotID = wardrobe.id
            ctx.insert(rec)
        }
        try ctx.save()

        let stats = WearStatsService.stats(forItemIDs: [tee.id, coat.id], in: ctx)
        #expect(stats[tee.id]?.count == 2)
        #expect(stats[coat.id]?.count == 1)
    }

    /// 没穿过的件也要有一条（缺键会让调用方分不清「没查」和「没穿过」）。
    @Test func everyRequestedIDGetsAnAnswer() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let tee = Item(name: "Tee"); tee.wardrobe = w; ctx.insert(tee)
        try ctx.save()

        let stats = WearStatsService.stats(forItemIDs: [tee.id], in: ctx)
        #expect(stats[tee.id]?.count == 0)
        #expect(stats[tee.id]?.lastWorn == nil)
    }

    /// 空集合不扫盘（不筛的时候不该为零个 id 去读全表）。
    @Test func anEmptyRequestDoesNoWork() throws {
        let ctx = try makeContext()
        #expect(WearStatsService.stats(forItemIDs: [], in: ctx).isEmpty)
    }

    /// 与逐件查的口径一致（两条路给出不同答案是最难查的那种 bug）。
    @Test func itAgreesWithTheSingleItemLookup() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let tee = Item(name: "Tee"); tee.wardrobe = w; ctx.insert(tee)
        try ctx.save()
        let rec = WearRecord(date: Date().addingTimeInterval(-86_400 * 2))
        rec.wornItemIDs = [tee.id.uuidString]
        rec.wardrobeSnapshotID = w.id
        ctx.insert(rec)
        try ctx.save()

        #expect(WearStatsService.stats(forItemIDs: [tee.id], in: ctx)[tee.id]
                == WearStatsService.stats(for: tee, in: ctx))
    }
}
