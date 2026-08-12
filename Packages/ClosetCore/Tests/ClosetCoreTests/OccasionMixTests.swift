import Testing
import Foundation
@testable import ClosetCore

/// D97（缺口 #14 补齐）：onboarding 的「场合构成」这一题。
/// DESIGN §474 点名了个性化三题——**场合构成** / 所在城市 / 可跳过的身体维度。
/// 前两者之一（城市）和第三项都在，唯独**场合构成一直没问**，
/// 而 Today 的默认场合是硬编码的 `"work"`：系统替用户假设了他主要为通勤穿衣。
///
/// 诚实边界：这一题只决定两件事——Today 的默认场合、冷启动里哪条里程碑打头。
/// 它**不改**天气门、不改配色、不改体型加权，文案不得暗示更多。
struct OccasionMixTests {

    @Test func choicesMatchTheOccasionsTheEngineActuallyFilterBy() {
        // 与 CandidateFilter / UI 的场合集同源，不得另开一套用户选得到、引擎不认的值
        #expect(OccasionMix.choices == ["work", "casual", "date", "gala"])
        for c in OccasionMix.choices {
            #expect(!OccasionMix.displayTitle(c).isEmpty)
        }
        let titles = OccasionMix.choices.map(OccasionMix.displayTitle)
        #expect(Set(titles).count == titles.count)
    }

    /// 可跳过（DESIGN §474「2-3 题封顶」的前提是每题都不强制）。
    /// 未答 = 未知，**不得**被记成某个具体选择。
    @Test func skippingLeavesItUnknownNotGuessed() {
        #expect(OccasionMix.parse(nil) == nil)
        #expect(OccasionMix.parse("") == nil)
        #expect(OccasionMix.parse("   ") == nil)
        #expect(OccasionMix.parse("nonsense") == nil)
        #expect(OccasionMix.parse("Work") == "work")   // 大小写容错
    }

    /// 未答时 Today 仍需要一个场合——用中性默认，但这**不是**用户的选择，
    /// 两者必须可区分（否则 UI 会把系统假设显示成「你选的」）。
    @Test func defaultOccasionIsSeparableFromAStatedAnswer() {
        #expect(OccasionMix.effectiveOccasion(stated: nil) == OccasionMix.neutralDefault)
        #expect(OccasionMix.effectiveOccasion(stated: "gala") == "gala")
        #expect(!OccasionMix.hasStatedAnswer(nil))
        #expect(OccasionMix.hasStatedAnswer("gala"))
        #expect(OccasionMix.choices.contains(OccasionMix.neutralDefault))
    }

    /// 文案只承诺它真做的两件事，不得暗示改推荐算法。
    @Test func copyDoesNotOverpromise() {
        let q = OccasionMix.question.lowercased()
        #expect(!q.isEmpty)
        let hint = OccasionMix.hint.lowercased()
        for word in ["algorithm", "smarter", "learns", "ai"] {
            #expect(!hint.split(whereSeparator: { !$0.isLetter }).map(String.init).contains(word))
        }
        // 明说可跳过
        #expect(OccasionMix.skipTitle.localizedCaseInsensitiveContains("skip")
                || OccasionMix.skipTitle.localizedCaseInsensitiveContains("not sure"))
    }
}
