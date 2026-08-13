import Testing
import Foundation
@testable import ClosetCore

/// D133：**槽位截断只按体型预分，没有体型档案的用户等于随机抽样**。
///
/// 每个槽位最多 12 件进入组合枚举，排序键是「体型 affinity → id」。
/// 而绝大多数用户**没填过身体维度**（那要量三围），于是 affinity 全为 0，
/// 退化成纯 id 前缀截断——`Item.id` 是随机 UUID，
/// **一个 60 件上装的衣柜，进入枚举的是随机的 12 件**。
///
/// 后果：配色最搭的那件、色季最合的那件，可能从来没被考虑过——
/// 而打分层里配色和色季的权重白算了，它们只对「碰巧被抽中的那 12 件」起作用。
///
/// 修法不是加大 12（那是指数级代价），是**让截断也看得见配色**。
struct SlotTruncationTests {

    private func item(
        _ id: String, hue: Double?, isNeutral: Bool = false
    ) -> CandidateItem {
        CandidateItem(
            id: id, slot: .top, occasions: [], warmth: .light, status: .available,
            color: hue.map { GarmentColor(hueDegrees: $0, isNeutral: isNeutral) })
    }

    /// 有色季时：合色季的排在前面（它们才该进枚举）。
    @Test func aColourSeasonPullsMatchingPiecesForward() {
        let ctx = ScoringContext(colorSeason: .winter)
        // winter 偏冷色；这里给一冷一暖
        let cool = item("z-cool", hue: 220)      // id 排最后，靠色季才进得来
        let warm = item("a-warm", hue: 30)
        let ranked = OutfitCompleter.preRank([warm, cool], scoring: ctx)
        #expect(ranked.first?.id == "z-cool",
                "合色季的那件没被排前 —— 大衣柜里它永远进不了枚举")
    }

    /// 没有任何上下文时：**有颜色的排在没颜色的前面**。
    ///
    /// 打分层的配色维度只能作用在已知颜色的件上；
    /// 若截断把有颜色的挤掉，那几项权重就等于没有。
    @Test func knownAttributesBeatUnknownOnes() {
        let ranked = OutfitCompleter.preRank(
            [item("a-unknown", hue: nil), item("z-known", hue: 200)],
            scoring: ScoringContext())
        #expect(ranked.first?.id == "z-known")
    }

    /// 体型仍然算数（这条不能被顺手削掉）。
    @Test func bodyShapeStillCounts() {
        let ctx = ScoringContext(bodyShape: .hourglass, bodyShapeWeight: 1.0)
        let suited = CandidateItem(
            id: "z-suited", slot: .top, occasions: [], warmth: .light,
            status: .available, attributes: [.wrap, .belt])
        let plain = CandidateItem(
            id: "a-plain", slot: .top, occasions: [], warmth: .light, status: .available)
        #expect(OutfitCompleter.preRank([plain, suited], scoring: ctx).first?.id == "z-suited")
    }

    /// 完全打平时按 id 决胜——顺序确定，不随集合遍历漂移。
    @Test func tiesFallBackToTheStableKey() {
        let a = item("a", hue: 200), b = item("b", hue: 200)
        #expect(OutfitCompleter.preRank([b, a], scoring: ScoringContext()).map(\.id) == ["a", "b"])
    }

    /// 同一份输入两次得到同样的顺序。
    @Test func preRankingIsDeterministic() {
        let pool = (0..<10).map { item("i\($0)", hue: Double($0) * 25) }
        let ctx = ScoringContext(colorSeason: .summer)
        #expect(OutfitCompleter.preRank(pool, scoring: ctx).map(\.id)
                == OutfitCompleter.preRank(pool.reversed(), scoring: ctx).map(\.id))
    }

    /// 截断上限本身不变——修法不是加大 12（那是指数级代价）。
    @Test func theCapIsUnchanged() {
        #expect(OutfitCompleter.maxOptionsPerSlot == 12)
    }
}
