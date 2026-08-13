import Testing
import Foundation
import SwiftData
@testable import ClosetUI
import ClosetModel
import ClosetCore

/// D128：**空态从不说缺的是哪个槽位**，而引擎明明算得出来。
///
/// 一个有 12 件上装、8 条下装、**一双鞋都没有**的衣柜，
/// 今天拼不出任何一套——而用户看到的是
/// 「Nothing here fits today's weather and occasion — try another occasion」。
/// 换场合当然没用：缺的是鞋。他会一个一个场合试过去，然后以为 App 坏了。
///
/// `OutfitGrammar` 早就把 `.missingShoes` 这类违规算出来了；
/// 空态只要问一句就行。**能说出「差什么」才叫可行动**。
@MainActor
struct EmptyReasonSlotTests {

    private func item(_ id: String, _ slot: GarmentSlot) -> CandidateItem {
        CandidateItem(id: id, slot: slot, occasions: [], warmth: .light, status: .available)
    }

    /// 只缺鞋 → 点名鞋。
    @Test func itNamesTheMissingShoes() {
        let pool = [item("t", .top), item("b", .bottom)]
        let text = CopilotEmptyReason.text(
            candidates: pool, wornCount: 0, anchorCount: 0,
            repeatGateRelaxed: false)
        #expect(text.localizedCaseInsensitiveContains("shoes"),
                Comment(rawValue: "缺鞋却让用户去换场合：\(text)"))
    }

    /// 只缺下装 → 点名下装。
    @Test func itNamesTheMissingBottom() {
        let pool = [item("t", .top), item("s", .shoes)]
        let text = CopilotEmptyReason.text(
            candidates: pool, wornCount: 0, anchorCount: 0,
            repeatGateRelaxed: false)
        #expect(text.localizedCaseInsensitiveContains("bottom")
                || text.localizedCaseInsensitiveContains("trousers")
                || text.localizedCaseInsensitiveContains("skirt"),
                Comment(rawValue: text))
    }

    /// 缺多个 → 一次说清，而不是让用户补一样再来一次。
    @Test func itNamesEveryMissingSlotAtOnce() {
        let pool = [item("t", .top), item("t2", .top), item("t3", .top)]
        let text = CopilotEmptyReason.text(
            candidates: pool, wornCount: 0, anchorCount: 0,
            repeatGateRelaxed: false)
        #expect(text.localizedCaseInsensitiveContains("bottom"))
        #expect(text.localizedCaseInsensitiveContains("shoes"))
    }

    /// 连衣裙能顶替上下装——有裙有鞋就不算缺件（别让用户去买他不需要的东西）。
    @Test func aDressCoversTopAndBottom() {
        let pool = [item("d", .dress), item("s", .shoes)]
        let text = CopilotEmptyReason.text(
            candidates: pool, wornCount: 0, anchorCount: 0,
            repeatGateRelaxed: false)
        #expect(!text.localizedCaseInsensitiveContains("bottom"),
                Comment(rawValue: "有连衣裙还让用户去加下装：\(text)"))
    }

    /// 槽位齐全时不提槽位——那时原因确实是天气/场合，说槽位是新的甩锅。
    @Test func aCompleteClosetFallsBackToTheOldReason() {
        let pool = [item("t", .top), item("b", .bottom), item("s", .shoes)]
        let text = CopilotEmptyReason.text(
            candidates: pool, wornCount: 0, anchorCount: 0,
            repeatGateRelaxed: false)
        #expect(text.localizedCaseInsensitiveContains("occasion")
                || text.localizedCaseInsensitiveContains("weather"))
    }

    /// 槽位齐全**且**全都近期穿过 → 归因防重复（D101 的纪律不变）。
    ///
    /// 注意场景要选对：只有两件的衣柜「全都穿过」时，真正的阻塞是
    /// 它根本凑不出一身——那时说「等一天」是错的，「还缺鞋」才对。
    @Test func theAntiRepeatReasonWinsWhenTheClosetIsOtherwiseComplete() {
        let pool = [item("t", .top), item("b", .bottom), item("s", .shoes)]
        let text = CopilotEmptyReason.text(
            candidates: pool, wornCount: 3, anchorCount: 0,
            repeatGateRelaxed: false)
        #expect(text.localizedCaseInsensitiveContains("week"))
    }

    /// D142：**件数由候选自己数**——此前 `available` 是单独传的，
    /// 于是「available: 5 而 candidates 为空」这种生产上永不发生的状态
    /// 表达得出来，还有一条分支挂在它上面被测绿了（假信心）。
    /// 现在那个矛盾在类型上就写不出来。
    @Test func theCountComesFromTheCandidatesThemselves() {
        let pool = [item("t", .top), item("b", .bottom), item("s", .shoes)]
        #expect(!CopilotEmptyReason.text(
            candidates: pool, wornCount: 0, anchorCount: 0,
            repeatGateRelaxed: false).isEmpty)
        // 空柜说空柜
        #expect(CopilotEmptyReason.text(
            candidates: [], wornCount: 0, anchorCount: 0, repeatGateRelaxed: false)
            .localizedCaseInsensitiveContains("add"))
    }
}

/// D128：**37 处失败文案都是「— try again」**，包括那些重试也没用的。
///
/// 「磁盘满了」重试一百次还是满的；「这不是 Loomies 的导出文件」再点一次
/// 也不会变成。把「重试」当成万能结尾，等于把用户往一条走不通的路上推——
/// 而他会一直点，直到以为 App 坏了。
struct RetryCopyTests {

    /// 能重试的：说重试。
    @Test func aTransientFailureInvitesRetry() {
        #expect(FailureCopy.line(.transient("Couldn't save")).hasSuffix("try again"))
    }

    /// 重试没用的：**不许**说重试，必须给出真正的下一步。
    @Test func aPermanentFailureOffersARealNextStep() {
        let text = FailureCopy.line(.needsUserAction(
            "Couldn't read that file", next: "Pick a Loomies export"))
        #expect(!text.localizedCaseInsensitiveContains("try again"),
                Comment(rawValue: "重试也没用的事却让用户重试：\(text)"))
        #expect(text.contains("Pick a Loomies export"))
    }

    /// 空间不足这类：给的是「腾空间」，不是「再试一次」。
    @Test func outOfSpaceDoesNotSuggestRetrying() {
        let text = FailureCopy.line(.outOfSpace)
        #expect(!text.localizedCaseInsensitiveContains("try again"))
        #expect(text.localizedCaseInsensitiveContains("space"))
    }

    /// 一律不泄露系统错误原文（那是给开发者看的）。
    @Test func systemErrorsNeverLeak() {
        let text = FailureCopy.line(.transient("Couldn't save"))
        for jargon in ["NSError", "Domain=", "Code=", "errno"] {
            #expect(!text.contains(jargon))
        }
    }
}
