import Testing
import Foundation
@testable import ClosetCore

/// D89：「近 7 天防重复」的语义分歧定夺。
/// DESIGN 自相矛盾——§193/§379 写「近期重复**降权**」，§200 把它列为**硬门**；
/// 实现取了硬排除。后果：小衣柜（三件上装本周都穿过）今天直接零建议，
/// 而 UI 只会显示空态，不告诉用户是防重复把候选清空的。
///
/// 定夺（照搬 DESIGN §199 对同类问题已给的处方「覆盖率低于门槛 → 自动切模式」）：
/// **默认硬门**（它来自竞品差评实证，有真实价值），**但硬门会清空候选时自动降级为降权**，
/// 并如实告知用户「这些最近都穿过」——不得静默给出与「de-prioritized 7 days」矛盾的结果。
struct AntiRepeatFallbackTests {

    func item(_ id: String, slot: GarmentSlot = .top) -> CandidateItem {
        CandidateItem(id: id, slot: slot, occasions: ["work"], warmth: .light,
                      status: .available)
    }

    /// 有没穿过的件时：硬门照旧生效（防重复的本职工作）。
    @Test func hardGateStillExcludesWhenAlternativesExist() {
        let pool = [item("a"), item("b")]
        let ctx = FilterContext(occasion: "work", daytimeTempF: 70,
                                wornWithin7DaysIDs: ["a"])
        let out = CandidateFilter.filterWithRepeatFallback(pool, context: ctx)
        #expect(out.items.map(\.id) == ["b"])
        #expect(!out.repeatGateRelaxed)
        #expect(out.recentlyWornIDs.isEmpty)
    }

    /// 全都穿过时：降级为降权而不是交出空结果。
    @Test func emptyResultFallsBackToDownweighting() {
        let pool = [item("a"), item("b")]
        let ctx = FilterContext(occasion: "work", daytimeTempF: 70,
                                wornWithin7DaysIDs: ["a", "b"])
        let out = CandidateFilter.filterWithRepeatFallback(pool, context: ctx)
        #expect(Set(out.items.map(\.id)) == ["a", "b"])
        #expect(out.repeatGateRelaxed)
        // 降权信息要传下去，打分层据此排后
        #expect(out.recentlyWornIDs == ["a", "b"])
    }

    /// 降级**只放宽防重复**——场合与天气仍是硬门（那两条没有分歧）。
    @Test func fallbackDoesNotRelaxOccasionOrWeather() {
        let gala = CandidateItem(id: "g", slot: .top, occasions: ["gala"], warmth: .light,
                                 status: .available)
        let ctx = FilterContext(occasion: "work", daytimeTempF: 70,
                                wornWithin7DaysIDs: ["g"])
        let out = CandidateFilter.filterWithRepeatFallback([gala], context: ctx)
        // 场合不符 → 即使放宽防重复也进不来（空结果在这里是**正确**答案）
        #expect(out.items.isEmpty)
        #expect(!out.repeatGateRelaxed)
    }

    /// 洗衣/外借件任何时候都不进候选（放宽的是防重复，不是可用性）。
    @Test func fallbackKeepsUnavailableItemsOut() {
        let laundry = CandidateItem(id: "l", slot: .top, occasions: ["work"], warmth: .light,
                                    status: .inWash)
        let ctx = FilterContext(occasion: "work", daytimeTempF: 70, wornWithin7DaysIDs: ["l"])
        let out = CandidateFilter.filterWithRepeatFallback([laundry], context: ctx)
        #expect(out.items.isEmpty)
        #expect(!out.repeatGateRelaxed)
    }

    /// 空池不算「放宽过」——没东西可推和「都穿过了」是两回事，文案不得混。
    @Test func emptyPoolIsNotARelaxation() {
        let ctx = FilterContext(occasion: "work", daytimeTempF: 70, wornWithin7DaysIDs: [])
        let out = CandidateFilter.filterWithRepeatFallback([], context: ctx)
        #expect(out.items.isEmpty)
        #expect(!out.repeatGateRelaxed)
    }

    /// 降权是**排序**影响，不是再次排除：最近穿过的排在没穿过的后面。
    @Test func downweightOrdersRecentlyWornLast() {
        let worn = item("worn")
        let fresh = item("fresh")
        let ranked = CandidateFilter.rankByRecency([worn, fresh], recentlyWornIDs: ["worn"])
        #expect(ranked.map(\.id) == ["fresh", "worn"])
        // 同类内部按 id 决胜（排序确定性）
        let two = CandidateFilter.rankByRecency(
            [item("b"), item("a")], recentlyWornIDs: [])
        #expect(two.map(\.id) == ["a", "b"])
    }

    /// 放宽时必须有话可说——静默给出「刚穿过的那身」与打卡回执自相矛盾。
    @Test func relaxationHasHonestCopy() {
        #expect(CandidateFilter.repeatRelaxedCaption
            .localizedCaseInsensitiveContains("recently"))
        #expect(!CandidateFilter.repeatRelaxedCaption.isEmpty)
    }
}

/// D105：降权排序的首键现在由生产与 `rankByRecency` **共用**——
/// 此前两处各写一份，而只有没人用的那份有测试覆盖。
struct RecencyOrderPrimitiveTests {
    @Test func wornSortsAfterUnworn() {
        #expect(CandidateFilter.recencyOrder("fresh", "worn", recentlyWornIDs: ["worn"]) == true)
        #expect(CandidateFilter.recencyOrder("worn", "fresh", recentlyWornIDs: ["worn"]) == false)
    }

    /// 同类打平返回 nil，交给调用方比下一键（生产用体型预分，rankByRecency 用 id）。
    @Test func tiesDeferToTheCaller() {
        #expect(CandidateFilter.recencyOrder("a", "b", recentlyWornIDs: []) == nil)
        #expect(CandidateFilter.recencyOrder("a", "b", recentlyWornIDs: ["a", "b"]) == nil)
    }
}
