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
        #expect(OutfitScorer.score(harmonious, context: ctx).reasons.contains {
            $0.localizedCaseInsensitiveContains("colors work")
        })
    }

    @Test func clashingReasonPresent() {
        let clashing = outfit([(0, false), (70, false)])
        #expect(OutfitScorer.score(clashing, context: ctx).reasons.contains {
            $0.localizedCaseInsensitiveContains("clash")
        })
    }

    @Test func noColorInfoGivesBaseNoColorReason() {
        let plain = Outfit(items: [CandidateItem(id: "a", slot: .top), CandidateItem(id: "b", slot: .bottom)])
        let s = OutfitScorer.score(plain, context: ctx)
        #expect(!s.reasons.contains { $0.localizedCaseInsensitiveContains("color") })
    }

    /// D115：理由文案改成**只评价衣服**（DESIGN §10.4 红线禁 flattering 类词），
    /// 断言随之改成新说法——旧断言写的是被禁掉的那句，留着等于把红线焊回去。
    @Test func cutsThatSuitTheProportionsScoreHigher() {
        let suited = Outfit(items: [CandidateItem(id: "a", slot: .top, attributes: [.wrap])])   // 沙漏 +
        let avoid = Outfit(items: [CandidateItem(id: "a", slot: .top, attributes: [.straightNoWaist])]) // 沙漏 -
        let hourglassCtx = ScoringContext(bodyShape: .hourglass)
        #expect(OutfitScorer.score(suited, context: hourglassCtx).value >
                OutfitScorer.score(avoid, context: hourglassCtx).value)
        // 仍要说清「为什么」——合规不等于把理由变成空话
        #expect(OutfitScorer.score(suited, context: hourglassCtx).reasons.contains {
            $0.localizedCaseInsensitiveContains("proportions")
        })
    }

    /// C4: affinity 是无界求和，最终分必须钳在文档化值域 [0, 2]。
    @Test func scoreIsClampedToDocumentedRange() {
        let suited = Outfit(items: (0..<12).map { i in
            CandidateItem(id: "f\(i)", slot: .top, attributes: [.wrap, .belt, .highWaist])
        })
        let avoid = Outfit(items: (0..<12).map { i in
            CandidateItem(id: "a\(i)", slot: .top, attributes: [.straightNoWaist])
        })
        let hourglassCtx = ScoringContext(bodyShape: .hourglass)
        let hi = OutfitScorer.score(suited, context: hourglassCtx)
        let lo = OutfitScorer.score(avoid, context: hourglassCtx)
        #expect(hi.value == OutfitScorer.scoreRange.upperBound)
        #expect(lo.value == OutfitScorer.scoreRange.lowerBound)
        #expect(hi.value > lo.value)
    }

    @Test func personalColorSeasonMovesTheScore() {
        let warmLook = outfit([(0, false), (28, false)]) // red + orange
        let autumn = ScoringContext(colorSeason: .autumn)
        let winter = ScoringContext(colorSeason: .winter)
        let autumnScore = OutfitScorer.score(warmLook, context: autumn)
        let winterScore = OutfitScorer.score(warmLook, context: winter)
        #expect(autumnScore.value > winterScore.value)
        #expect(autumnScore.reasons.contains { $0.localizedCaseInsensitiveContains("autumn") })
        #expect(winterScore.reasons.contains { $0.localizedCaseInsensitiveContains("winter") })
        #expect(OutfitScorer.score(warmLook, context: ctx).value != autumnScore.value)
    }

    @Test func bodyShapeWeightScalesTheShapeTerm() {
        let suited = Outfit(items: [CandidateItem(id: "a", slot: .top, attributes: [.wrap])])
        let measured = ScoringContext(bodyShape: .hourglass, bodyShapeWeight: 1.0)
        let guessed = ScoringContext(bodyShape: .hourglass, bodyShapeWeight: 0.5)
        let ignored = ScoringContext(bodyShape: .hourglass, bodyShapeWeight: 0)
        let full = OutfitScorer.score(suited, context: measured)
        let half = OutfitScorer.score(suited, context: guessed)
        let none = OutfitScorer.score(suited, context: ignored)
        #expect(full.value > half.value)
        #expect(half.value > none.value)
        #expect(none.value == 1.0)
        #expect(none.reasons.contains { $0.localizedCaseInsensitiveContains("body shape") } == false)
    }

    /// en-US primary market: reasons must not leak Chinese UI strings.
    @Test func reasonsAreEnglishForUSMarket() {
        let look = outfit([(0, true), (0, false)])
        let hourglassCtx = ScoringContext(bodyShape: .hourglass)
        let withAttrs = Outfit(items: [
            CandidateItem(id: "a", slot: .top, color: GarmentColor(hueDegrees: 0, isNeutral: true), attributes: [.wrap]),
            CandidateItem(id: "b", slot: .bottom, color: GarmentColor(hueDegrees: 0, isNeutral: false)),
        ])
        for s in [OutfitScorer.score(look, context: ctx),
                  OutfitScorer.score(withAttrs, context: hourglassCtx)] {
            for r in s.reasons {
                #expect(r.unicodeScalars.allSatisfy { $0.isASCII || $0.properties.isWhitespace },
                        "reason should be en-US ASCII: \(r)")
            }
        }
    }
}
