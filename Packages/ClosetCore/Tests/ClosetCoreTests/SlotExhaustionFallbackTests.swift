import Testing
import Foundation
@testable import ClosetCore

/// D112：D89 的降级判在**单品层**，而空屏发生在**搭配层**。
///
/// `filterWithRepeatFallback` 只在「一件都不剩」时才放宽防重复。
/// 但只要任意一个槽位被穿光（小衣柜里通常是鞋），其余槽位的件仍然留着——
/// 单品集非空 → 不降级 → grammar 拼不出完整一身 → **0 条建议**。
/// 而空态文案会甩锅给天气/场合（`wornCount >= available` 判不成立），
/// 默认全自动状态下两个补救按钮都不渲染，用户无路可走。
///
/// 触发点不是罕见情况，正是 App 的主动作：**第一次点「Wore it」之后**
/// （穿着窗口含今天），Today 当场空屏，且要等整个衣柜都穿过一遍才自愈——
/// 与 D89 的本意完全相反。
struct SlotExhaustionFallbackTests {

    private func item(
        _ id: String, _ slot: GarmentSlot, warmth: Warmth? = .light,
        occasions: Set<String> = ["work"]
    ) -> CandidateItem {
        CandidateItem(
            id: id, slot: slot, occasions: occasions, warmth: warmth,
            status: .available)
    }

    private func complete(
        _ pool: [CandidateItem], worn: Set<String>, tempF: Double = 72
    ) -> OutfitCompleter.Result {
        OutfitCompleter.completeDetailed(
            anchors: [], pool: pool,
            context: FilterContext(
                occasion: "work", daytimeTempF: tempF, wornWithin7DaysIDs: worn),
            scoring: ScoringContext(),
            maxSuggestions: 5)
    }

    private var workCloset: [CandidateItem] {
        [item("top-1", .top), item("top-2", .top), item("top-3", .top),
         item("bot-1", .bottom), item("bot-2", .bottom),
         item("shoe-1", .shoes)]
    }

    /// 基线：没穿过任何东西时给得出建议。
    @Test func aFreshClosetSuggests() {
        #expect(!complete(workCloset, worn: []).suggestions.isEmpty)
    }

    /// 唯一那双鞋穿过 → 仍须给建议（降级），不得空屏。
    @Test func exhaustingTheOnlyShoesStillSuggests() {
        let result = complete(workCloset, worn: ["shoe-1"])
        #expect(!result.suggestions.isEmpty,
                "唯一一双鞋今天穿过，Today 就空了 —— 这正是用户点「Wore it」之后看到的")
        #expect(result.repeatGateRelaxed,
                "给了建议却不说降级过 —— 用户会以为这些是全新搭配")
    }

    /// 端到端复现「按下 Wore it 就空屏」：穿一身之后仍须有建议。
    @Test func checkingInOneLookDoesNotBlankTheScreen() {
        let result = complete(workCloset, worn: ["top-1", "bot-1", "shoe-1"])
        #expect(!result.suggestions.isEmpty)
        #expect(result.repeatGateRelaxed)
    }

    /// 降级仍**只放宽防重复**：场合与天气仍是硬门。
    @Test func relaxingRepeatDoesNotRelaxOccasionOrWeather() {
        var pool = workCloset
        pool.append(item("gala-shoe", .shoes, occasions: ["gala"]))
        let result = complete(pool, worn: ["shoe-1"])
        #expect(!result.suggestions.isEmpty)
        for s in result.suggestions {
            #expect(!s.outfit.itemIDs.contains("gala-shoe"),
                    "放宽防重复顺手放宽了场合硬门")
        }
    }

    /// 降级也**不放行在洗/外借件**（第三条硬门原样）。
    ///
    /// D192：这条语义原来只被 `AntiRepeatFallbackTests.fallbackKeepsUnavailableItemsOut`
    /// 守着——而它测的是零调用点的 `filterWithRepeatFallback`，
    /// 生产跑的是 `OutfitCompleter` 里的内联版。删那个死 API 之前先把这条搬过来，
    /// 否则会连同一条**真语义**的覆盖一起删掉。
    @Test func relaxingRepeatDoesNotLetLaundryBackIn() {
        var pool = workCloset
        var laundry = item("shoe-wash", .shoes)
        laundry = CandidateItem(
            id: laundry.id, slot: laundry.slot, occasions: laundry.occasions,
            warmth: laundry.warmth, status: .inWash)
        pool.append(laundry)
        let result = complete(pool, worn: ["shoe-1"])
        #expect(!result.suggestions.isEmpty)
        for s in result.suggestions {
            #expect(!s.outfit.itemIDs.contains("shoe-wash"),
                    "放宽防重复顺手把在洗的件放了进来")
        }
    }

    /// 一件未标温区的单品能绕过天气门 —— 它不该因此**吃掉**降级。
    /// （原报告的第二个变体：加一件衣服反而让全部建议消失。）
    @Test func oneUntaggedItemDoesNotSuppressTheFallback() {
        let winter = [
            item("coat", .outerwear, warmth: .veryWarm),
            item("wool-top", .top, warmth: .veryWarm),
            item("wool-pant", .bottom, warmth: .veryWarm),
            item("boots", .shoes, warmth: .veryWarm),
            item("tank", .top, warmth: nil),   // 未标温区 → 跳过天气门
        ]
        let worn: Set<String> = ["coat", "wool-top", "wool-pant", "boots"]
        let result = complete(winter, worn: worn, tempF: 28)
        #expect(!result.suggestions.isEmpty,
                "加一件没标温区的背心，反而让所有建议消失了")
    }

    /// 降级也拼不出一身时，**不得**谎称降级过（D89 纪律 #2 原样保留）。
    @Test func noOutfitEvenRelaxedReportsNoRelaxation() {
        let topsOnly = [item("top-1", .top), item("top-2", .top)]
        let result = complete(topsOnly, worn: ["top-1"])
        #expect(result.suggestions.isEmpty)
        #expect(!result.repeatGateRelaxed,
                "空结果的原因不是防重复，别对用户说反话")
    }

    /// 严格通道拼得出来时不得降级（降级是兜底，不是常态）。
    @Test func aWorkableStrictPassDoesNotRelax() {
        var pool = workCloset
        pool.append(item("shoe-2", .shoes))
        let result = complete(pool, worn: ["shoe-1"])
        #expect(!result.suggestions.isEmpty)
        #expect(!result.repeatGateRelaxed)
        for s in result.suggestions {
            #expect(!s.outfit.itemIDs.contains("shoe-1"),
                    "还有没穿过的鞋，却把穿过的那双端出来了")
        }
    }

    /// 降级后最近穿过的仍排在后面（降权，不是无视）。
    @Test func relaxedResultsStillDeprioritiseWornPieces() {
        var pool = workCloset
        pool.append(item("top-4", .top))
        let result = complete(pool, worn: ["shoe-1", "top-1", "top-2", "top-3"])
        let first = try? #require(result.suggestions.first)
        #expect(first?.outfit.itemIDs.contains("top-4") == true,
                "唯一没穿过的上装没有排在最前")
    }
}
