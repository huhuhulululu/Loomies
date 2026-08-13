import Testing
import Foundation
@testable import ClosetCore

/// D131：**1-ULP 的浮点噪声能决定推荐名次**。
///
/// 排序用 `a.value != b.value` 精确比较：两套分数本质相同、只因加法顺序不同
/// 差了 1e-16 时，那个噪声就成了名次的决定因素——而后面的稳定决胜键
/// （近期穿着、itemIDs 字典序）根本轮不到。
///
/// 后果是**同一个衣柜、同一天，两次打开顺序可能不一样**，
/// 而用户会觉得推荐在乱跳。
struct ScoreOrderingTests {

    /// 差在噪声量级内 = 同分，交给稳定决胜键。
    @Test func noiseSizedDifferencesCountAsATie() {
        #expect(OutfitScorer.isEffectivelyTied(1.2, 1.2 + 1e-15))
        #expect(OutfitScorer.isEffectivelyTied(1.2, 1.2 - 1e-15))
    }

    /// 真实差距不算打平（否则决胜键会盖过真正的分差）。
    @Test func realDifferencesAreNotTies() {
        #expect(!OutfitScorer.isEffectivelyTied(1.2, 1.25))
        #expect(!OutfitScorer.isEffectivelyTied(1.0, 1.01))
    }

    /// 阈值要小于产品里最小的一档加成（0.1），否则会把真实差异吞掉。
    @Test func theToleranceIsSmallerThanTheSmallestBonus() {
        #expect(OutfitScorer.scoreTolerance < 0.1)
        #expect(OutfitScorer.scoreTolerance > 0)
    }

    /// 加法顺序不同不该改变名次。
    @Test func additionOrderDoesNotDecideTheRanking() {
        // 浮点加法不满足结合律：换个顺序结果会差 1 个 ULP。
        // （0.1+0.2+0.3 那组**恰好**相等，用它做前提这条测试就成了空转。）
        let a = 0.1 + (0.2 + 0.3)
        let b = (0.1 + 0.2) + 0.3
        #expect(a != b, "前提没成立，这条测试就没意义了")
        #expect(OutfitScorer.isEffectivelyTied(a, b))
    }

    /// 打平时按稳定键决胜——同一份输入两次得到同样的顺序。
    @Test func tiedLooksSortDeterministically() {
        func look(_ ids: [String]) -> Outfit {
            Outfit(items: ids.enumerated().map { i, id in
                CandidateItem(
                    id: id,
                    slot: i == 0 ? .top : (i == 1 ? .bottom : .shoes),
                    occasions: [], warmth: .light, status: .available)
            })
        }
        let ctx = ScoringContext()
        let pool = [look(["b1", "b2", "b3"]), look(["a1", "a2", "a3"])]
        func rank(_ outfits: [Outfit]) -> [String] {
            outfits
                .map { ScoredOutfit(outfit: $0, score: OutfitScorer.score($0, context: ctx)) }
                .sorted { OutfitScorer.ranksBefore($0, $1, recentlyWornIDs: []) }
                .map { $0.outfit.itemIDs.joined(separator: ",") }
        }
        #expect(rank(pool) == rank(pool.reversed()),
                "同一份输入换个顺序就排出不同名次")
    }
}
