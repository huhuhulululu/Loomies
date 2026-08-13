import Testing
import Foundation
@testable import ClosetCore

/// D200：合身反馈回流的**下半截**——从合身标记走到推荐排序。
///
/// D196 让「你穿过之后说的」压过了尺寸算出来的预测，但只到**合身标记**为止；
/// 我当时明写「推荐侧的回流是下一波的事」。这就是那一波。
///
/// `MARKET.md` 判 H3 合身判断是「唯一无人占据的纵深——没人做**决策层**的合身」。
/// 合身标记是**展示层**；真正的决策层是「今天先给你看哪一身」。
///
/// ### 只降权「紧」，不动「松」
///
/// 紧 = 穿着难受，用户多半不想再穿；松可能是**故意的**（oversize 是一种穿法）。
/// 把两者一视同仁就是拿自己的审美替用户做主——而这条产品线的铁律是用户掌舵。
///
/// ### 只降权，绝不排除
///
/// 那是用户自己的衣服。降权让它排在后面，用户翻两下还能选到；
/// 排除会让它**凭空消失**，而他不会知道为什么（同 D89 对防重复的判断）。
struct ReportedTightScoringTests {

    private func item(
        _ id: String, _ slot: GarmentSlot, hue: Double? = nil
    ) -> CandidateItem {
        CandidateItem(
            id: id, slot: slot, occasions: [], warmth: .light, status: .available,
            color: hue.map { GarmentColor(hueDegrees: $0, isNeutral: false) })
    }

    private func outfit(_ ids: [String], _ items: [CandidateItem]) -> Outfit {
        Outfit(items: items.filter { ids.contains($0.id) })
    }

    /// **本波的核心**：说过两次「紧」的那件，整套分数要掉下来。
    @Test func aPieceYouCalledTightDragsItsOutfitDown() {
        let pool = [item("top", .top), item("bot", .bottom), item("shoe", .shoes)]
        let look = outfit(["top", "bot", "shoe"], pool)

        let neutral = OutfitScorer.score(look, context: ScoringContext())
        let withTight = OutfitScorer.score(
            look, context: ScoringContext(reportedTightItemIDs: ["top"]))
        #expect(withTight.value < neutral.value, Comment(rawValue:
            "用户说过两次这件紧，它照样排在最前 —— 反馈没进决策层"))
    }

    /// 两件都紧比一件更靠后（信号可叠加）。
    @Test func twoTightPiecesAreWorseThanOne() {
        let pool = [item("top", .top), item("bot", .bottom), item("shoe", .shoes)]
        let look = outfit(["top", "bot", "shoe"], pool)
        let one = OutfitScorer.score(look, context: ScoringContext(
            reportedTightItemIDs: ["top"])).value
        let two = OutfitScorer.score(look, context: ScoringContext(
            reportedTightItemIDs: ["top", "bot"])).value
        #expect(two < one)
    }

    /// **说「松」不降权**——oversize 是一种穿法，不是毛病。
    @Test func callingSomethingLooseIsNotAComplaint() {
        let pool = [item("top", .top), item("bot", .bottom), item("shoe", .shoes)]
        let look = outfit(["top", "bot", "shoe"], pool)
        // 「松」根本不进这个集合（口径就在字段名里：reportedTight）
        let neutral = OutfitScorer.score(look, context: ScoringContext())
        let looseIgnored = OutfitScorer.score(look, context: ScoringContext(
            reportedTightItemIDs: []))
        #expect(looseIgnored.value == neutral.value)
    }

    /// 不认识的 id 不影响任何东西（历史记录里的软引用可能指向已删的件）。
    @Test func anUnknownIDChangesNothing() {
        let pool = [item("top", .top), item("bot", .bottom), item("shoe", .shoes)]
        let look = outfit(["top", "bot", "shoe"], pool)
        #expect(OutfitScorer.score(look, context: ScoringContext(
            reportedTightItemIDs: ["ghost"])).value
            == OutfitScorer.score(look, context: ScoringContext()).value)
    }

    /// **降权不是排除**：分数掉了，但它仍然是个候选。
    @Test func aTightPieceIsStillAnOption() {
        let pool = [item("top", .top), item("bot", .bottom), item("shoe", .shoes)]
        let look = outfit(["top", "bot", "shoe"], pool)
        let scored = OutfitScorer.score(
            look, context: ScoringContext(reportedTightItemIDs: ["top", "bot", "shoe"]))
        #expect(scored.value > 0, Comment(rawValue:
            "三件全说过紧就把分数压到 0 以下 —— 那等于把用户的衣服判了死刑"))
    }

    /// 降权要**说出口**（D131 的纪律：改了结果就得让用户知道为什么）。
    @Test func theDownweightIsExplained() {
        let pool = [item("top", .top), item("bot", .bottom), item("shoe", .shoes)]
        let look = outfit(["top", "bot", "shoe"], pool)
        let scored = OutfitScorer.score(
            look, context: ScoringContext(reportedTightItemIDs: ["top"]))
        #expect(scored.reasons.contains { $0.localizedCaseInsensitiveContains("tight") },
                Comment(rawValue: "分数被改了却不说为什么：\(scored.reasons)"))
    }

    /// 没有反馈时**不出**这句话（别造噪声）。
    @Test func noFeedbackMeansNoSentence() {
        let pool = [item("top", .top), item("bot", .bottom), item("shoe", .shoes)]
        let look = outfit(["top", "bot", "shoe"], pool)
        let scored = OutfitScorer.score(look, context: ScoringContext())
        #expect(!scored.reasons.contains { $0.localizedCaseInsensitiveContains("tight") })
    }

    /// 量纲要合理：比配色（±0.3）轻，比 60-30-10（0.1）重——
    /// 它是**一条真实的用户信号**，但不该盖过一身衣服搭得好不好。
    @Test func theWeightSitsBetweenColourAndTrim() {
        let pool = [item("top", .top), item("bot", .bottom), item("shoe", .shoes)]
        let look = outfit(["top", "bot", "shoe"], pool)
        let drop = OutfitScorer.score(look, context: ScoringContext()).value
            - OutfitScorer.score(look, context: ScoringContext(
                reportedTightItemIDs: ["top"])).value
        #expect(drop > 0.1, Comment(rawValue: "降权 \(drop) 太轻，等于没有"))
        #expect(drop < 0.3, Comment(rawValue: "降权 \(drop) 盖过了配色，喧宾夺主"))
    }
}
