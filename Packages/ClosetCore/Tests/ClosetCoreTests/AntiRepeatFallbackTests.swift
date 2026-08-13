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
