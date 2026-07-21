import Testing
@testable import ClosetCore

struct OutfitScorerTests {
    let ctx = ScoringContext()

    func outfit(_ hues: [(Double, Bool)]) -> Outfit {
        let items = hues.enumerated().map { i, hn in
            CandidateItem(id: "i\(i)", slot: i == 0 ? .top : .bottom,
                          color: GarmentColor(hueDegrees: hn.0, isNeutral: hn.1))
        }
        return Outfit(items: items)
    }

    @Test func harmoniousScoresHigherThanClashing() {
        let harmonious = outfit([(0, true), (0, false)])      // 中性 + 红 → 协调
        let clashing = outfit([(0, false), (70, false)])      // 红 + 黄绿 → 冲突
        #expect(OutfitScorer.score(harmonious, context: ctx).value >
                OutfitScorer.score(clashing, context: ctx).value)
    }

    @Test func harmoniousReasonPresent() {
        let harmonious = outfit([(0, true), (0, false)])
        #expect(OutfitScorer.score(harmonious, context: ctx).reasons.contains { $0.contains("配色协调") })
    }

    @Test func clashingReasonPresent() {
        let clashing = outfit([(0, false), (70, false)])
        #expect(OutfitScorer.score(clashing, context: ctx).reasons.contains { $0.contains("配色冲突") })
    }

    @Test func noColorInfoGivesBaseNoColorReason() {
        let plain = Outfit(items: [CandidateItem(id: "a", slot: .top), CandidateItem(id: "b", slot: .bottom)])
        let s = OutfitScorer.score(plain, context: ctx)
        #expect(!s.reasons.contains { $0.contains("配色") })
    }

    @Test func bodyShapeFlatteringScoresHigher() {
        let flattering = Outfit(items: [CandidateItem(id: "a", slot: .top, attributes: [.wrap])])   // 沙漏 +
        let avoid = Outfit(items: [CandidateItem(id: "a", slot: .top, attributes: [.straightNoWaist])]) // 沙漏 -
        let hourglassCtx = ScoringContext(bodyShape: .hourglass)
        #expect(OutfitScorer.score(flattering, context: hourglassCtx).value >
                OutfitScorer.score(avoid, context: hourglassCtx).value)
        #expect(OutfitScorer.score(flattering, context: hourglassCtx).reasons.contains { $0.contains("体型") })
    }
}
