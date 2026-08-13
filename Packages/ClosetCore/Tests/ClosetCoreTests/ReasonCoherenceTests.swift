import Testing
import Foundation
@testable import ClosetCore

/// D131：**同一身既被告知「撞色，换一件」，又被夸「配色平衡」**。
///
/// 两个判据各自成立（色族 ≤3 与色相是否冲突是两回事），但摆在一起读
/// 就是自相矛盾：用户刚被告知要换一件，下一行却说配得好——
/// 他不知道该信哪句，也不知道到底要不要换。
///
/// 分数照旧（平衡确实值那 0.1），只是**撞色时不说那句话**：
/// 那一刻唯一有用的信息是「哪件该换」。
struct ReasonCoherenceTests {

    private func coloured(_ id: String, _ slot: GarmentSlot, hue: Double) -> CandidateItem {
        CandidateItem(id: id, slot: slot, occasions: [], warmth: .light,
                      status: .available,
                      color: GarmentColor(hueDegrees: hue, isNeutral: false))
    }

    /// 撞色时不得出现任何夸配色的话。
    @Test func aClashingLookIsNeverPraisedForItsPalette() {
        // 0 / 60 / 135：两两都不在同族(≤30°)、补色(160-200°)、三分色(100-140°)区间
        let look = Outfit(items: [
            coloured("a", .top, hue: 0),
            coloured("b", .bottom, hue: 60),
            coloured("c", .shoes, hue: 135),
        ])
        let reasons = OutfitScorer.score(look, context: ScoringContext()).reasons
        #expect(reasons.contains { $0.localizedCaseInsensitiveContains("clash") })
        #expect(!reasons.contains { $0.localizedCaseInsensitiveContains("balanced") },
                Comment(rawValue: "撞色的一身同时被夸「平衡」：\(reasons)"))
    }

    /// 协调时该夸就夸（别把有用的正反馈也一起删掉）。
    @Test func aHarmoniousLookStillGetsItsPraise() {
        let look = Outfit(items: [
            coloured("a", .top, hue: 210),
            coloured("b", .bottom, hue: 220),
        ])
        let reasons = OutfitScorer.score(look, context: ScoringContext()).reasons
        #expect(reasons.contains { $0.localizedCaseInsensitiveContains("work well") })
    }

    /// 分数不受文案改动影响——平衡确实值那 0.1，只是不说出口。
    @Test func theScoreIsUnchangedByTheCopyRule() {
        let clashing = Outfit(items: [
            coloured("a", .top, hue: 0),
            coloured("b", .bottom, hue: 60),
        ])
        let value = OutfitScorer.score(clashing, context: ScoringContext()).value
        // 1.0 基准 − 0.3 撞色 + 0.1 平衡（两色必然 ≤3 族）
        #expect(abs(value - 0.8) < 1e-9, Comment(rawValue: "\(value)"))
    }

    /// 理由之间不得互相否定（总闸：任何一套都不许同时出现正反两句配色评价）。
    @Test func noLookGetsOppositePaletteVerdicts() {
        let hues: [[Double]] = [
            [0, 60, 135], [210, 220, 215], [10, 190], [0, 120, 240], [45, 300],
        ]
        for set in hues {
            let look = Outfit(items: set.enumerated().map { i, hue in
                coloured("i\(i)", i == 0 ? .top : (i == 1 ? .bottom : .shoes), hue: hue)
            })
            let reasons = OutfitScorer.score(look, context: ScoringContext()).reasons
            let praises = reasons.filter {
                $0.localizedCaseInsensitiveContains("work well")
                    || $0.localizedCaseInsensitiveContains("balanced")
            }
            let scolds = reasons.filter {
                $0.localizedCaseInsensitiveContains("clash")
                    || $0.localizedCaseInsensitiveContains("try one main color")
            }
            #expect(praises.isEmpty || scolds.isEmpty,
                    Comment(rawValue: "同一套里正反都说了：\(reasons)"))
        }
    }
}
