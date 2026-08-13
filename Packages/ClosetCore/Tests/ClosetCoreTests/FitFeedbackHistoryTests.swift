import Testing
import Foundation
@testable import ClosetCore

/// D196：**问了不用比不问更糟。**
///
/// 每次打卡都问「今天穿着怎么样」，答案进了历史、进了导出，
/// 却从不回流到合身标记或推荐——`FitFeedbackCopy` 的抬头写着这是 v1.0 的
/// 刻意取舍（「只采集：不喂 FitEngine、不改推荐」）。
///
/// 那个取舍在「还没有足够记录」的阶段是对的。有了记录之后它就站不住了：
/// `FitEngine` 那条是**预测**（拿平铺尺寸算 ease），而打卡那一问是**实测**
///（衣服穿在身上什么感觉）。两者冲突时没有理由继续相信预测。
///
/// `MARKET.md` 把「合身判断」判为 H3——「唯一无人占据的纵深，没人做决策层的合身」。
/// 而决策层的合身，起点就是**采信用户穿过的结果**。
struct FitFeedbackHistoryTests {

    private func e(_ id: String, _ v: FitVerdict) -> FitFeedbackHistory.Entry {
        FitFeedbackHistory.Entry(itemID: id, verdict: v)
    }

    /// 一次不算数——「那天吃多了」不该变成永久结论。
    @Test func oneReportIsNotAConclusion() {
        let out = FitFeedbackHistory.settled(from: [e("a", .tight)])
        #expect(out["a"] == nil, "一次反馈就下结论 —— 那天吃多了也算数？")
    }

    /// 两次同样的就够了。
    @Test func twoMatchingReportsSettle() {
        let out = FitFeedbackHistory.settled(from: [e("a", .tight), e("a", .tight)])
        let settled = try? #require(out["a"])
        #expect(settled?.verdict == .tight)
        #expect(settled?.count == 2)
        #expect(settled?.total == 2)
    }

    /// **打平就是没有结论**——不许从两个里挑一个。
    @Test func aTieIsNoConclusion() {
        let out = FitFeedbackHistory.settled(from: [
            e("a", .tight), e("a", .tight), e("a", .loose), e("a", .loose),
        ])
        #expect(out["a"] == nil, Comment(rawValue:
            "说紧两次、说松两次，却挑了一个 —— 宁可不说，不说错"))
    }

    /// 多数成立就算数，少数派照实计入 total（用户看得到「5 次里 3 次」）。
    @Test func aStrictMajoritySettlesAndKeepsTheCount() {
        let out = FitFeedbackHistory.settled(from: [
            e("a", .tight), e("a", .tight), e("a", .tight),
            e("a", .fitted), e("a", .loose),
        ])
        let settled = try? #require(out["a"])
        #expect(settled?.verdict == .tight)
        #expect(settled?.count == 3)
        #expect(settled?.total == 5)
    }

    /// 多但不过半 → 不算数（3 tight / 2 fitted / 2 loose 里 tight 只有 3/7）。
    @Test func aPluralityWithoutMajorityDoesNotSettle() {
        let out = FitFeedbackHistory.settled(from: [
            e("a", .tight), e("a", .tight), e("a", .tight),
            e("a", .fitted), e("a", .fitted),
            e("a", .loose), e("a", .loose),
        ])
        #expect(out["a"] == nil)
    }

    /// 逐件独立，互不串味。
    @Test func itemsAreIndependent() {
        let out = FitFeedbackHistory.settled(from: [
            e("a", .tight), e("a", .tight),
            e("b", .loose), e("b", .loose), e("b", .loose),
            e("c", .fitted),
        ])
        #expect(out["a"]?.verdict == .tight)
        #expect(out["b"]?.verdict == .loose)
        #expect(out["c"] == nil, "只报过一次的件不该有结论")
    }

    /// 空输入不炸也不编。
    @Test func noRecordsMeanNoClaims() {
        #expect(FitFeedbackHistory.settled(from: []).isEmpty)
    }

    /// 文案要说清**这是用户自己说的**——与 App 算的混在一起，
    /// 用户就没法判断该信哪个。
    @Test func theCaptionNamesWhoSaidIt() {
        let settled = FitFeedbackHistory.Settled(verdict: .tight, count: 3, total: 4)
        let caption = FitFeedbackHistory.caption(settled)
        #expect(caption.localizedCaseInsensitiveContains("you"), Comment(rawValue: caption))
        #expect(caption.contains("3"))
    }

    /// 一致时**不出**「不一致说明」——别造噪声。
    @Test func agreementProducesNoExtraSentence() {
        let settled = FitFeedbackHistory.Settled(verdict: .tight, count: 2, total: 2)
        #expect(FitFeedbackHistory.disagreementCaption(
            settled: settled, predicted: .tight) == nil)
    }

    /// 不一致时要说清「按你说的来」。
    @Test func disagreementSaysWhichOneWins() {
        let settled = FitFeedbackHistory.Settled(verdict: .tight, count: 2, total: 2)
        let text = try? #require(FitFeedbackHistory.disagreementCaption(
            settled: settled, predicted: .loose))
        #expect((text ?? "").localizedCaseInsensitiveContains("measurement"),
                Comment(rawValue: text ?? "nil"))
    }
}
