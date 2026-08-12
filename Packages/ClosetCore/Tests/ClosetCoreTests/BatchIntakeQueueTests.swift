import Testing
import Foundation
@testable import ClosetCore

/// D92（缺口 #9）：批量入库队列。DESIGN §F1 明写「**批量为默认路径**」，
/// 而实现一直是 `selectionLimit = 1`——北极星是 7 天数字化 40 件，
/// 一件一件拍是这条漏斗上最大的阻力。
///
/// copilot 铁律不因批量而松动：**每件仍由用户拍板**（确认/跳过），
/// 不做「选了就自动全入库」。队列只负责游标与诚实记账。
struct BatchIntakeQueueTests {

    @Test func progressCountsFromOneForHumans() {
        var q = BatchIntakeQueue(total: 3)
        #expect(q.progressCaption == "Piece 1 of 3")
        q.record(.added)
        #expect(q.progressCaption == "Piece 2 of 3")
        q.record(.skipped)
        q.record(.failed)
        #expect(q.isFinished)
    }

    /// 汇总必须**逐项如实**——加了几件、跳过几件、几件读不出来，一个都不许含糊。
    @Test func summaryReportsEveryOutcome() {
        var q = BatchIntakeQueue(total: 4)
        q.record(.added); q.record(.added)
        q.record(.skipped)
        q.record(.failed)
        let s = q.summary
        #expect(s.contains("2"))
        #expect(s.localizedCaseInsensitiveContains("added"))
        #expect(s.localizedCaseInsensitiveContains("skipped"))
        #expect(s.localizedCaseInsensitiveContains("couldn't"))
    }

    /// 全部成功时不提失败（噪音），全部失败时不得说「Added 0」这种像成功的话。
    @Test func summaryOmitsZeroBucketsAndNeverFakesSuccess() {
        var all = BatchIntakeQueue(total: 2)
        all.record(.added); all.record(.added)
        #expect(!all.summary.localizedCaseInsensitiveContains("skipped"))
        #expect(!all.summary.localizedCaseInsensitiveContains("couldn't"))

        var none = BatchIntakeQueue(total: 2)
        none.record(.failed); none.record(.failed)
        #expect(!none.summary.contains("Added 0"))
        #expect(none.summary.localizedCaseInsensitiveContains("couldn't"))
    }

    /// 中途退出：已入库的**不回滚**（用户已逐件确认过），但汇总要说清还剩几件没处理。
    @Test func abandoningMidwayKeepsWhatWasConfirmed() {
        var q = BatchIntakeQueue(total: 5)
        q.record(.added); q.record(.added)
        #expect(!q.isFinished)
        let s = q.summaryOnExit
        #expect(s.contains("2"))
        #expect(s.localizedCaseInsensitiveContains("3"))
        #expect(s.localizedCaseInsensitiveContains("left"))
    }

    /// 越界 record 不得让游标跑飞（防御 UI 双击）。
    @Test func recordingBeyondTotalIsIgnored() {
        var q = BatchIntakeQueue(total: 1)
        q.record(.added)
        q.record(.added)
        q.record(.added)
        #expect(q.index == 1)
        #expect(q.outcomes.count == 1)
    }

    /// 空选择不是一次「批量」——不得显示 "Piece 1 of 0"。
    @Test func emptySelectionIsImmediatelyFinished() {
        let q = BatchIntakeQueue(total: 0)
        #expect(q.isFinished)
        #expect(q.progressCaption.isEmpty)
        #expect(q.summary.localizedCaseInsensitiveContains("nothing"))
    }

    /// 选择上限：一次挑太多会让内存与用户耐心都爆掉，且必须**如实告知**截断。
    @Test func selectionCapIsStatedNotSilent() {
        #expect(BatchIntakeQueue.maxSelection >= 20)
        let msg = BatchIntakeQueue.truncationNotice(
            picked: BatchIntakeQueue.maxSelection + 5)
        let text = try! #require(msg)
        #expect(text.contains("\(BatchIntakeQueue.maxSelection)"))
        // 没超限时不出提示（无噪音）
        #expect(BatchIntakeQueue.truncationNotice(picked: 3) == nil)
    }

    /// 计数守恒：outcomes 的三类之和永远等于已处理数。
    @Test func countsAlwaysReconcile() {
        var q = BatchIntakeQueue(total: 6)
        for o in [BatchIntakeQueue.Outcome.added, .skipped, .failed, .added, .added, .skipped] {
            q.record(o)
        }
        #expect(q.addedCount + q.skippedCount + q.failedCount == q.outcomes.count)
        #expect(q.addedCount == 3)
        #expect(q.skippedCount == 2)
        #expect(q.failedCount == 1)
    }
}

/// D92：批量文案必须让用户**知道能一次挑多张**（DESIGN §F1「批量为默认路径」），
/// 且逐张确认的措辞要体现「还有下一张」，不让人以为点完就结束了。
struct BatchIntakeCopyTests {
    @Test func choosingSaysItTakesSeveral() {
        let t = BatchIntakeCopy.chooseTitle.lowercased()
        #expect(t.contains("photos"))
        #expect(t.contains("several") || t.contains("multiple") || t.contains("at once"))
    }

    @Test func confirmWordingSignalsMoreToCome() {
        #expect(BatchIntakeCopy.addAndContinueTitle
            .localizedCaseInsensitiveContains("continue"))
        // 跳过必须是明确动作，不能只有「取消」（取消读起来像放弃整批）
        #expect(BatchIntakeCopy.skipTitle.localizedCaseInsensitiveContains("skip"))
        #expect(!BatchIntakeCopy.skipTitle.localizedCaseInsensitiveContains("cancel"))
    }
}
