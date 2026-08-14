import Testing
import Foundation
@testable import ClosetCore

/// D216：宽扫门的文件数账本。下界跟 recorded，涨了必须重录，变窄当场红。
struct TraversalCensusTests {

    private var repoRoot: URL {
        get throws {
            try #require(TraversalCensus.repoRoot(startingAt: #filePath))
        }
    }

    @Test func floorIsSixtyPercentWithAFloorOfThree() {
        #expect(TraversalCensus.floor(recorded: 138) == 82)
        #expect(TraversalCensus.floor(recorded: 49) == 29)
        #expect(TraversalCensus.floor(recorded: 5) == 3)
        #expect(TraversalCensus.floor(recorded: 1) == 3)
    }

    @Test func evaluatePassesInsideTheBand() {
        #expect(TraversalCensus.evaluate(live: 138, recorded: 138) == .pass)
        #expect(TraversalCensus.evaluate(live: 82, recorded: 138) == .pass)
        #expect(TraversalCensus.evaluate(live: 100, recorded: 138) == .pass)
    }

    @Test func evaluateRedsWhenTheWalkGrows() {
        #expect(TraversalCensus.evaluate(live: 139, recorded: 138)
                == .grew(live: 139, recorded: 138))
    }

    @Test func evaluateRedsWhenTheWalkCollapses() {
        #expect(TraversalCensus.evaluate(live: 81, recorded: 138)
                == .collapsed(live: 81, floor: 82, recorded: 138))
        #expect(TraversalCensus.evaluate(live: 0, recorded: 138)
                == .collapsed(live: 0, floor: 82, recorded: 138))
    }

    /// D160/D172：用它声称的范围去撞——账本填一个不可能的数，门必须点名。
    @Test func anInflatedLedgerFailsTheLiveCount() throws {
        let root = try repoRoot
        let live = TraversalCensus.recount(repoRoot: root)
        let recorded = live[TraversalCensus.allPackageSources] ?? 0
        #expect(recorded >= 80, "recount 自己没扫到 Sources —— 先修配方")
        let fake = TraversalCensus.Snapshot(counts: [
            TraversalCensus.allPackageSources: 999,
        ])
        let msg = TraversalCensus.check(
            live: recorded,
            key: TraversalCensus.allPackageSources,
            snapshot: fake)
        #expect(msg != nil)
        #expect(msg?.contains("遍历") == true)
        #expect(msg?.contains("999") == true)
    }

    /// 遍历根指向不存在的目录 → 计数 0 → 下界红（D209 那种假绿的反面）。
    @Test func aBrokenWalkFailsTheFloor() throws {
        let root = try repoRoot
        let snap = try TraversalCensus.load(repoRoot: root)
        let live = TraversalCensus.countSwift(
            under: root.appendingPathComponent("does-not-exist-d216"))
        #expect(live == 0)
        let msg = TraversalCensus.check(
            live: live,
            key: TraversalCensus.allPackageSources,
            snapshot: snap)
        #expect(msg != nil)
        #expect(msg?.contains("遍历") == true)
    }

    @Test func missingKeyIsNamed() {
        let snap = TraversalCensus.Snapshot(counts: [:])
        let msg = TraversalCensus.check(
            live: 10, key: "noSuchRecipe", snapshot: snap)
        #expect(msg?.contains("noSuchRecipe") == true)
    }

    /// 账本与现场对账。涨了：设 `LOOMIES_TRAVERSAL_RECORD=1` 重录后再跑。
    @Test func recordedCountsMatchTheRecipes() throws {
        let root = try repoRoot
        var live = TraversalCensus.recount(repoRoot: root)
        if ProcessInfo.processInfo.environment[TraversalCensus.recordEnvironmentKey] == "1" {
            try TraversalCensus.record(live, repoRoot: root)
            live = TraversalCensus.recount(repoRoot: root)
        }
        let snap = try TraversalCensus.load(repoRoot: root)
        #expect(Set(snap.counts.keys) == Set(live.keys), Comment(rawValue:
            "账本 key 与配方不一致：账本 \(snap.counts.keys.sorted()) "
            + "现场 \(live.keys.sorted())"))
        for key in live.keys.sorted() {
            let msg = TraversalCensus.check(live: live[key] ?? 0, key: key, snapshot: snap)
            #expect(msg == nil, Comment(rawValue: msg ?? key))
        }
    }
}
