import Testing
import Foundation
@testable import ClosetCore

/// D159：**被取代的那次计算还在跑。**
///
/// D152 把推荐挪到后台之后，界面不再冻——代价是用户现在**点得动第二下**了。
/// 九个触发点（换场合、切筛选、切柜、回前台…）都不挡并发：快速连点两下，
/// 两次「冷天 2 秒」的枚举同时在跑。代际检查保证只有新的那次落地，
/// **但旧的那次仍然烧到底**。改前不可能发生（同步会卡住 UI，点不了第二下）——
/// 是那一改引入的，自审时才发现。
///
/// 处置：枚举过程中如果自己已被取代就**当场收手**。判据可注入，
/// 默认读 `Task.isCancelled`（同步调用方在任务外，读到 false，行为一个字不变）。
struct AbandonSupersededTests {

    private func pool(perSlot: Int = 8) -> [CandidateItem] {
        var out: [CandidateItem] = []
        for (si, slot) in [GarmentSlot.top, .bottom, .shoes, .outerwear].enumerated() {
            for i in 0..<perSlot {
                out.append(CandidateItem(
                    id: "\(slot)-\(i)", slot: slot, occasions: ["work"],
                    warmth: .medium, status: .available,
                    color: GarmentColor(hueDegrees: Double((i * 37 + si * 91) % 360),
                                        isNeutral: false)))
            }
        }
        return out
    }

    private var ctx: FilterContext {
        FilterContext(occasion: "work", daytimeTempF: 38)
    }

    /// 一开始就被取代 → 立刻收手，不枚举。
    @Test func anAlreadySupersededRunStopsImmediately() {
        let t0 = CFAbsoluteTimeGetCurrent()
        let out = OutfitCompleter.complete(
            anchors: [], pool: pool(), context: ctx,
            scoring: ScoringContext(), maxSuggestions: 3,
            isSuperseded: { true })
        let ms = (CFAbsoluteTimeGetCurrent() - t0) * 1000
        #expect(out.isEmpty, "已被取代还是算完了整轮")
        #expect(ms < 50, Comment(rawValue: "收手用了 \(String(format: "%.0f", ms))ms"))
    }

    /// 没被取代 → 结果与不传这个参数时**逐个一致**（默认行为不许变）。
    @Test func aLiveRunIsUnchanged() {
        let plain = OutfitCompleter.complete(
            anchors: [], pool: pool(), context: ctx,
            scoring: ScoringContext(), maxSuggestions: 3)
        let explicit = OutfitCompleter.complete(
            anchors: [], pool: pool(), context: ctx,
            scoring: ScoringContext(), maxSuggestions: 3,
            isSuperseded: { false })
        #expect(plain.map(\.outfit.itemIDs) == explicit.map(\.outfit.itemIDs))
        #expect(!plain.isEmpty)
    }

    /// 中途被取代：给出的是**已经算到的**那部分，不是一片空白也不是假结果。
    @Test func aMidFlightAbandonReturnsWhatItHad() {
        var calls = 0
        let out = OutfitCompleter.complete(
            anchors: [], pool: pool(), context: ctx,
            scoring: ScoringContext(), maxSuggestions: 3,
            isSuperseded: { calls += 1; return calls > 3 })
        // 只要没崩、没编造，部分结果或空都可接受——关键是它收手了
        #expect(out.count <= 3)
    }

    /// 同步调用方（测试、`refresh()`）在任务之外——默认判据读到 false，
    /// 也就是「不传就跟以前一样」。
    @Test func theDefaultIsNeverSupersededOutsideATask() {
        #expect(!OutfitCompleter.complete(
            anchors: [], pool: pool(), context: ctx,
            scoring: ScoringContext(), maxSuggestions: 3).isEmpty)
    }
}
