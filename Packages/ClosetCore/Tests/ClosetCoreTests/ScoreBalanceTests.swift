import Testing
import Foundation
@testable import ClosetCore

/// D127：**体型项能把配色整个抹平**。
///
/// 体型 affinity 是各单品属性权重之**和**、本身无界（12 件全带加分属性
/// 就能加到 +2 以上），而配色项被限在 ±0.4 上下。最终分钳在 [0,2]：
/// 一旦体型项把分推到上界，配色好不好、色季合不合，**对排序完全不起作用**。
///
/// 后果不是「分数不准」，是**配色维度在大衣柜上直接消失**——
/// 而配色恰恰是用户一眼能验证对错的那一维。
struct ScoreBalanceTests {

    private func item(_ id: String, _ slot: GarmentSlot, attrs: Set<StyleAttribute>) -> CandidateItem {
        CandidateItem(id: id, slot: slot, occasions: [], warmth: .light,
                      status: .available, attributes: attrs)
    }

    private func coloured(_ id: String, _ slot: GarmentSlot, hue: Double) -> CandidateItem {
        CandidateItem(id: id, slot: slot, occasions: [], warmth: .light,
                      status: .available,
                      color: GarmentColor(hueDegrees: hue, isNeutral: false))
    }

    /// 体型贡献必须**有界**——无界的那一项会独吞整个值域。
    @Test func theBodyShapeTermIsBounded() {
        #expect(OutfitScorer.maxBodyShapeContribution > 0)
        #expect(OutfitScorer.maxBodyShapeContribution <= 0.5,
                "体型项的上限比配色项还大，配色就成了噪声")
    }

    /// 属性再多，体型项也加不过上限。
    @Test func manyFlatteringPiecesCannotExceedTheCap() {
        let ctx = ScoringContext(bodyShape: .hourglass, bodyShapeWeight: 1.0)
        let few = [item("a", .top, attrs: [.wrap]), item("b", .bottom, attrs: [.highWaist])]
        let many = (0..<12).map { item("x\($0)", .top, attrs: [.wrap, .belt, .highWaist]) }
        let fewScore = OutfitScorer.score(Outfit(items: few), context: ctx).value
        let manyScore = OutfitScorer.score(Outfit(items: many), context: ctx).value
        #expect(manyScore - 1.0 <= OutfitScorer.maxBodyShapeContribution + 0.0001)
        #expect(manyScore >= fewScore)
    }

    /// **关键回归**：体型项拉满时，配色仍然能改变排序。
    @Test func colourStillMovesTheRankingWhenShapeIsMaxed() {
        let ctx = ScoringContext(bodyShape: .hourglass, bodyShapeWeight: 1.0)
        // 两套都堆满体型加分属性；一套配色协调，一套撞色
        func look(_ prefix: String, hues: [Double]) -> Outfit {
            var items: [CandidateItem] = []
            for (i, hue) in hues.enumerated() {
                items.append(CandidateItem(
                    id: "\(prefix)\(i)",
                    slot: i == 0 ? .top : (i == 1 ? .bottom : .shoes),
                    occasions: [], warmth: .light,
                    status: .available,
                    color: GarmentColor(hueDegrees: hue, isNeutral: false),
                    attributes: [.wrap, .belt, .highWaist]))
            }
            return Outfit(items: items)
        }
        let harmonious = OutfitScorer.score(look("h", hues: [210, 220, 215]), context: ctx).value
        // 60° / 75° 落在撞色区间（既非同族 ≤30°、非补色 160-200°、非三分色 100-140°）
        let clashing = OutfitScorer.score(look("c", hues: [0, 60, 135]), context: ctx).value
        #expect(harmonious > clashing,
                "体型项拉满后，配色对排序完全不起作用了")
    }

    /// 值域仍然有界（跨 outfit 可比较这条不能破）。
    @Test func theScoreStaysInRange() {
        let ctx = ScoringContext(bodyShape: .hourglass, bodyShapeWeight: 1.0)
        let many = (0..<20).map { item("x\($0)", .top, attrs: [.wrap, .belt, .highWaist]) }
        let value = OutfitScorer.score(Outfit(items: many), context: ctx).value
        #expect(OutfitScorer.scoreRange.contains(value))
    }

    /// 负向也要有界：全是不合适的剪裁不该把分砸穿到 0。
    @Test func theNegativeSideIsBoundedToo() {
        let ctx = ScoringContext(bodyShape: .hourglass, bodyShapeWeight: 1.0)
        let many = (0..<20).map { item("x\($0)", .top, attrs: [.straightNoWaist]) }
        let value = OutfitScorer.score(Outfit(items: many), context: ctx).value
        #expect(value >= 1.0 - OutfitScorer.maxBodyShapeContribution - 0.0001)
    }

    /// 置信度缩放仍然生效（快选不得与实测同权）。
    @Test func theWeightStillScalesTheContribution() {
        let full = ScoringContext(bodyShape: .hourglass, bodyShapeWeight: 1.0)
        let half = ScoringContext(bodyShape: .hourglass, bodyShapeWeight: 0.5)
        let look = Outfit(items: [item("a", .top, attrs: [.wrap, .belt])])
        let f = OutfitScorer.score(look, context: full).value
        let h = OutfitScorer.score(look, context: half).value
        #expect(f > h)
    }

    /// 排序时**决定名次的那一项**要能被说出来——
    /// 只显示 `reasons.first` 而理由按配色优先追加，展示的就不是真正拉开差距的那一项。
    @Test func theLeadReasonIsTheOneThatMovedTheScore() {
        let ctx = ScoringContext(bodyShape: .hourglass, bodyShapeWeight: 1.0)
        let shapeDriven = Outfit(items: [
            item("a", .top, attrs: [.wrap, .belt, .highWaist]),
            item("b", .bottom, attrs: [.wrap, .belt, .highWaist]),
        ])
        let reasons = OutfitScorer.score(shapeDriven, context: ctx).reasons
        #expect(reasons.first?.localizedCaseInsensitiveContains("proportions") == true,
                Comment(rawValue: "排在最前的理由不是真正拉开分差的那一项：\(reasons)"))
    }

    /// 有配色贡献时，配色理由排前（同一条规则的另一面）。
    @Test func colourLeadsWhenColourDominates() {
        let ctx = ScoringContext()      // 无体型上下文
        let look = Outfit(items: [
            coloured("a", .top, hue: 210), coloured("b", .bottom, hue: 220),
        ])
        let reasons = OutfitScorer.score(look, context: ctx).reasons
        #expect(reasons.first?.localizedCaseInsensitiveContains("color") == true,
                Comment(rawValue: "\(reasons)"))
    }
}
