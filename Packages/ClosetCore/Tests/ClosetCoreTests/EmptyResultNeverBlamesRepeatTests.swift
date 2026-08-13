import Testing
import Foundation
@testable import ClosetCore

/// D188 之一：**「你这周把这里穿遍了」这句话只要出现就一定是错的。**
///
/// `OutfitCompleter` 的逻辑本身是对的（D89 纪律 #2）：严格通道拼不出、
/// 且确有近期穿着记录时，摘掉防重复再拼一次；**放宽了还拼不出**就把
/// `repeatGateRelaxed` 重置为 false——空结果的原因不是防重复。
///
/// 问题在于下游据此写了一条分支：`if !repeatGateRelaxed, wornCount > 0 …`
/// 就说「You've worn everything here in the past week — wait a day」。
/// 而由上面那段可推出：**结果为空 ⟹ repeatGateRelaxed 必为 false**，
/// 于是那条分支的前置在空态里恒真，而它给的下一步（「等一天」）恒无用——
/// 防重复已经放宽过一次并且失败了，明天再来还是拼不出。
///
/// 这条把不变式钉在**引擎**上，而不是靠读代码推断。
struct EmptyResultNeverBlamesRepeatTests {

    private func item(_ id: String, _ slot: GarmentSlot, warmth: Warmth = .light)
        -> CandidateItem {
        CandidateItem(id: id, slot: slot, occasions: [], warmth: warmth, status: .available)
    }

    private func complete(_ pool: [CandidateItem], tempF: Double) -> OutfitCompleter.Result {
        OutfitCompleter.completeDetailed(
            anchors: [], pool: pool,
            context: FilterContext(
                occasion: "casual", daytimeTempF: tempF,
                wornWithin7DaysIDs: Set(pool.map(\.id)), coldBias: 0),
            scoring: ScoringContext(daytimeTempF: tempF),
            maxSuggestions: 3)
    }

    /// **不变式**：拼不出任何一套时，防重复一定不是原因。
    /// 一柜薄衣服 + 极冷的天：天气门把整柜筛空，且全部件近 7 天都穿过。
    @Test func anEmptyResultAlwaysReportsTheRepeatGateAsNotTheCause() {
        let pool = [
            item("a", .top), item("b", .bottom), item("c", .shoes),
            item("d", .top), item("e", .bottom), item("f", .shoes),
        ]
        let result = complete(pool, tempF: 20)
        #expect(result.suggestions.isEmpty, "前提不成立：这套输入本该拼不出")
        #expect(result.repeatGateRelaxed == false, Comment(rawValue:
            "结果为空却报告防重复仍在起作用 —— 下游会据此叫用户「等一天」，"
            + "而放宽重试已经失败过一次了"))
    }

    /// 反面：放宽之后拼得出来时，`repeatGateRelaxed` 才该为 true
    ///（这条保证上面那条不是因为它恒为 false 而空转）。
    @Test func relaxingTheGateIsReportedWhenItActuallyHelped() {
        let pool = [item("a", .top), item("b", .bottom), item("c", .shoes)]
        let result = complete(pool, tempF: 70)
        #expect(!result.suggestions.isEmpty, "前提不成立：放宽后本该拼得出")
        #expect(result.repeatGateRelaxed, "放宽真的救回来了，却没如实报告")
    }
}
