import Testing
import Foundation
@testable import ClosetCore

/// D91（缺口 #14，MVP critic 标 critical）：冷启动预赋进度 + 场合里程碑。
/// DESIGN §475：「录入激励用预赋进度（答完引导问题即显 20%）+ 按场合里程碑即时兑现推荐
/// （『通勤装满 10 件，已可生成一周通勤搭配』）」。
///
/// 本项目铁律在这里最容易破：里程碑文案是**承诺**。说「已可生成一周通勤搭配」
/// 就必须真的能生成 7 套不重样的——按槽位覆盖算，不是数够 10 件就吹。
struct ActivationProgressTests {

    func item(_ id: String, _ slot: GarmentSlot,
              occasions: Set<String> = ["work"],
              status: ItemStatus = .available) -> CandidateItem {
        CandidateItem(id: id, slot: slot, occasions: occasions, status: status)
    }

    // MARK: - 预赋进度

    /// 答完引导问题即显 20%——零件也不是 0%（预赋效应；DESIGN 明文）。
    @Test func onboardingEndowsTwentyPercent() {
        #expect(ActivationProgress.fraction(itemCount: 0)
                == ActivationProgress.endowedFraction)
        #expect(ActivationProgress.endowedFraction == 0.2)
        // 「没走过引导不预赋」这条不再用参数表达：Today 只在有 active 衣柜时
        // 渲染，而衣柜只在 onboarding 完成后存在——不变量是结构性的（D98）。
    }

    /// 单调递增、夹在 [0,1]，且到目标件数即满。
    @Test func fractionIsMonotonicAndClamped() {
        var last = -1.0
        for n in 0...(ActivationProgress.targetItemCount + 20) {
            let f = ActivationProgress.fraction(itemCount: n)
            #expect(f >= last)
            #expect(f >= 0 && f <= 1)
            last = f
        }
        #expect(ActivationProgress.fraction(
            itemCount: ActivationProgress.targetItemCount) == 1)
    }

    /// 进度文案说人话且不吹牛：不得在没到目标时暗示「完成了」。
    @Test func progressCaptionIsHonest() {
        let early = ActivationProgress.caption(itemCount: 3)
        #expect(early.contains("3"))
        #expect(!early.localizedCaseInsensitiveContains("done"))
        let full = ActivationProgress.caption(
            itemCount: ActivationProgress.targetItemCount)
        #expect(full.localizedCaseInsensitiveContains("ready"))
    }

    // MARK: - 场合里程碑（必须挣来）

    /// 一套都拼不出来时，不得声称任何兑现。
    @Test func noOutfitMeansNoClaim() {
        let items = [item("t1", .top), item("t2", .top)]   // 只有上装
        let m = ActivationProgress.milestone(occasion: "work", items: items)
        #expect(!m.canDressOnce)
        #expect(m.distinctLooks == 0)
        #expect(m.missingSlots.contains(.bottom))
        #expect(m.missingSlots.contains(.shoes))
        #expect(!m.headline.localizedCaseInsensitiveContains("week"))
        // 缺什么要点名，用户才知道下一件该拍什么
        #expect(m.nextStep.localizedCaseInsensitiveContains("bottom")
                || m.nextStep.localizedCaseInsensitiveContains("shoes"))
    }

    /// 上装+下装+鞋 = 能穿一次，但离「一周」还早——文案不得跳级。
    @Test func oneOutfitClaimsExactlyOneOutfit() {
        let items = [item("t", .top), item("b", .bottom), item("s", .shoes)]
        let m = ActivationProgress.milestone(occasion: "work", items: items)
        #expect(m.canDressOnce)
        #expect(m.distinctLooks == 1)
        #expect(!m.headline.localizedCaseInsensitiveContains("week"))
        #expect(m.headline.contains("1"))
    }

    /// 连衣裙可独立成套（不需要上下装齐）。
    @Test func dressCountsAsAFullLook() {
        let items = [item("d", .dress), item("s", .shoes)]
        let m = ActivationProgress.milestone(occasion: "work", items: items)
        #expect(m.canDressOnce)
        #expect(m.distinctLooks == 1)
    }

    /// 「一周」只有真的能凑出 7 套不重样才敢说（防重复窗口就是 7 天）。
    @Test func weekClaimRequiresSevenDistinctLooks() {
        // 3 上 × 3 下 = 9 套 > 7
        var items = [item("s", .shoes)]
        for i in 0..<3 { items.append(item("t\(i)", .top)) }
        for i in 0..<3 { items.append(item("b\(i)", .bottom)) }
        let m = ActivationProgress.milestone(occasion: "work", items: items)
        #expect(m.distinctLooks >= ActivationProgress.weekLooks)
        #expect(m.reachedWeek)
        #expect(m.headline.localizedCaseInsensitiveContains("week"))

        // 2 上 × 3 下 = 6 套 < 7 → 不得说「一周」
        var six = [item("s", .shoes)]
        for i in 0..<2 { six.append(item("t\(i)", .top)) }
        for i in 0..<3 { six.append(item("b\(i)", .bottom)) }
        let m6 = ActivationProgress.milestone(occasion: "work", items: six)
        #expect(m6.distinctLooks == 6)
        #expect(!m6.reachedWeek)
        #expect(!m6.headline.localizedCaseInsensitiveContains("week"))
    }

    /// 只按**该场合**的件算——通勤里程碑不能拿晚宴装凑数。
    @Test func milestoneCountsOnlyThisOccasion() {
        let items = [
            item("t", .top, occasions: ["gala"]),
            item("b", .bottom, occasions: ["work"]),
            item("s", .shoes, occasions: ["work"]),
        ]
        let m = ActivationProgress.milestone(occasion: "work", items: items)
        #expect(!m.canDressOnce)             // work 无上装
        #expect(m.missingSlots.contains(.top))
    }

    /// 场合未标注（空集）= 未知，按「哪都能穿」算——与 CandidateFilter 三值语义一致，
    /// 否则冷启动阶段刚入库、还没标场合的件全被里程碑忽略，进度永远不动。
    @Test func unknownOccasionCountsEverywhere() {
        let items = [
            item("t", .top, occasions: []),
            item("b", .bottom, occasions: []),
            item("s", .shoes, occasions: []),
        ]
        #expect(ActivationProgress.milestone(occasion: "work", items: items).canDressOnce)
    }

    /// 洗衣/外借件不算数（推荐拿不到它们，里程碑就不能拿它们充数）。
    @Test func unavailablePiecesDoNotCount() {
        let items = [
            item("t", .top), item("b", .bottom),
            item("s", .shoes, status: .inWash),
        ]
        let m = ActivationProgress.milestone(occasion: "work", items: items)
        #expect(!m.canDressOnce)
        #expect(m.missingSlots.contains(.shoes))
    }

    /// 组合数封顶，避免大衣柜出现「你能生成 4096 套」这种没意义的数字。
    @Test func distinctLooksAreCapped() {
        var items = [item("s", .shoes)]
        for i in 0..<40 { items.append(item("t\(i)", .top)) }
        for i in 0..<40 { items.append(item("b\(i)", .bottom)) }
        let m = ActivationProgress.milestone(occasion: "work", items: items)
        #expect(m.distinctLooks == ActivationProgress.maxReportedLooks)
        #expect(m.headline.contains("\(ActivationProgress.maxReportedLooks)+"))
    }

    /// 全部场合的里程碑一次算出，顺序确定（UI 直接铺，不得随字典序漂）。
    @Test func allMilestonesAreDeterministicallyOrdered() {
        let items = [item("t", .top, occasions: ["work"]),
                     item("b", .bottom, occasions: ["work"]),
                     item("s", .shoes, occasions: ["work"])]
        let all = ActivationProgress.milestones(items: items)
        #expect(all.map(\.occasion) == ActivationProgress.trackedOccasions)
        #expect(all.first { $0.occasion == "work" }?.canDressOnce == true)
    }
}

/// D97：里程碑衡量的是**衣柜完备度**，不是「今天能不能穿」——
/// 它按槽位覆盖算，而 Today 还过天气门。满柜羊毛装在 30°C 天里，
/// 里程碑若说「3 套 ready」，用户点进去却一套都没有，那就是谎报。
/// 措辞必须把这两件事分开。
struct MilestoneScopeHonestyTests {

    func item(_ id: String, _ slot: GarmentSlot) -> CandidateItem {
        CandidateItem(id: id, slot: slot, occasions: ["work"],
                      warmth: .veryWarm, status: .available)
    }

    /// 兑现文案说的是「衣柜能配出几套」，不得读成「现在就能穿」。
    @Test func headlineIsAboutTheClosetNotTodaysWeather() {
        let items = [item("t", .top), item("b", .bottom), item("s", .shoes)]
        let m = ActivationProgress.milestone(occasion: "work", items: items)
        #expect(m.canDressOnce)
        let words = m.headline.lowercased()
        // 「ready」/「today」会被读成今天就能穿——而天气门可能全过滤掉
        #expect(!words.contains("ready"))
        #expect(!words.contains("today"))
        #expect(!words.contains("wear now"))
        // 必须点明这是衣柜的能力
        #expect(words.contains("closet") || words.contains("can make")
                || words.contains("covers"))
    }

    /// 「一周」同理：说的是衣柜能撑一周不重样，不是这周天气都合适。
    @Test func weekClaimIsAboutRotationDepthNotForecast() {
        var items = [item("s", .shoes)]
        for i in 0..<3 { items.append(item("t\(i)", .top)) }
        for i in 0..<3 { items.append(item("b\(i)", .bottom)) }
        let m = ActivationProgress.milestone(occasion: "work", items: items)
        #expect(m.reachedWeek)
        #expect(m.headline.localizedCaseInsensitiveContains("week"))
        #expect(!m.headline.localizedCaseInsensitiveContains("ready"))
    }
}

/// D98 尾项：里程碑的两处措辞缺陷（对抗审计发现）。
struct MilestoneCopyPrecisionTests {

    func item(_ id: String, _ slot: GarmentSlot, occasions: Set<String> = []) -> CandidateItem {
        CandidateItem(id: id, slot: slot, occasions: occasions, status: .available)
    }

    /// 全是**没标场合**的件时，不得断言「你有一套 work 搭配」——
    /// 未标注按「哪都能穿」参与计数是对的（否则冷启动进度不动），
    /// 但据此点名某个具体场合就是替用户下结论。
    @Test func untaggedPiecesDoNotAssertASpecificOccasion() {
        let items = [item("t", .top), item("b", .bottom), item("s", .shoes)]
        let m = ActivationProgress.milestone(occasion: "work", items: items)
        #expect(m.canDressOnce)
        #expect(!m.headline.localizedCaseInsensitiveContains("work"))
        // 并且要指路：标上场合才算数
        #expect(m.nextStep.localizedCaseInsensitiveContains("tag"))
    }

    /// 有一件标了该场合，就可以点名了（不是一刀切地永远不提场合）。
    @Test func oneTaggedPieceIsEnoughToNameTheOccasion() {
        let items = [item("t", .top, occasions: ["work"]), item("b", .bottom), item("s", .shoes)]
        let m = ActivationProgress.milestone(occasion: "work", items: items)
        #expect(m.headline.localizedCaseInsensitiveContains("work"))
    }

    /// 缺多个槽位时的连接词：不得出现 "bottom and shoes and top" 这种。
    @Test func multipleMissingSlotsReadAsAList() {
        let m = ActivationProgress.milestone(occasion: "work", items: [])
        #expect(m.missingSlots.count >= 2)
        let step = m.nextStep
        #expect(!step.contains("and and"))
        // 三项及以上用逗号 + and，不是全用 and 串起来
        if m.missingSlots.count >= 3 {
            #expect(step.contains(","))
        }
        #expect(step.components(separatedBy: " and ").count <= 2)
    }
}
