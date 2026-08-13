import Testing
import Foundation
@testable import ClosetUI
import ClosetCore

/// D148：**三值语义只做了一半——引擎对了，用户不知道。**
///
/// 温区未标 → 天气门整条跳过（`CandidateFilter` gate #1：温度未知或温区未知
/// 都不过滤）。这个设计是对的：不替用户假设。
///
/// 但录入面的提示写的是「Used to filter by weather. **Leave unset if unsure.**」
/// ——它主动**邀请**用户留空，却只字不提留空的后果。
/// 于是：厚羽绒服留成「Not set」，85°F 那天照样被推出来，
/// 用户看到的是「这 App 不懂天气」，而真相是「你没告诉它这件多厚」。
///
/// 场合那条早就把话说全了（「Leave all off if it works for anything」）——
/// 同一个控件文件里，两条同类提示一条说了一条没说。
struct UnsetAttributeDisclosureTests {

    /// 留空的**后果**必须写出来，不能只说「不确定就留空」。
    @Test func theWarmthHintSaysWhatUnsetMeans() {
        let hint = WarmthPicker.hint.lowercased()
        #expect(hint.contains("weather"))
        // 「永远不会被天气筛掉」——这才是留空的真实语义
        #expect(hint.contains("never") || hint.contains("always"),
                Comment(rawValue: "邀请用户留空却不说后果：\(WarmthPicker.hint)"))
    }

    /// 文案与引擎必须同向：说「未标不会被筛掉」，引擎就得真不筛。
    @Test func theCopyMatchesTheEngine() {
        let unlabelled = CandidateItem(
            id: "x", slot: .top, occasions: [], warmth: nil, status: .available)
        let labelledHeavy = CandidateItem(
            id: "y", slot: .top, occasions: [], warmth: .veryWarm, status: .available)
        // 大热天
        let ctx = FilterContext(occasion: "casual", daytimeTempF: 85)
        let kept = CandidateFilter.filter([unlabelled, labelledHeavy], context: ctx)
        #expect(kept.contains { $0.id == "x" },
                "文案承诺未标不会被筛掉，引擎却筛了")
        #expect(!kept.contains { $0.id == "y" },
                "标了 veryWarm 的在 85°F 仍被留下 —— 那天气门等于没有")
    }

    /// 场合那条本来就说全了，别在收口时把它改坏。
    @Test func theOccasionHintStillSaysItsConsequence() {
        #expect(OccasionChips.hint.localizedCaseInsensitiveContains("anything"))
    }

    /// 两条提示都不许留下「设了会怎样、不设会怎样」的空白。
    @Test func neitherHintInvitesABlindChoice() {
        for hint in [WarmthPicker.hint, OccasionChips.hint] {
            #expect(hint.count > 40, Comment(rawValue: "提示短到说不清后果：\(hint)"))
        }
    }
}
