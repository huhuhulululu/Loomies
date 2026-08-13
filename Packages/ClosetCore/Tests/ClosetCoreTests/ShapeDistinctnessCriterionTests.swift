import Testing
import Foundation
@testable import ClosetCore

/// D202：**一条冻在 DESIGN 里的量化验收，从没被测过——而它现在不成立。**
///
/// `DESIGN.md` §236 与 §393 两处都写着同一条纸娃娃验收：
/// 「两档体型下同一衣物呈现**可辨差异（锚点横向偏移 ≥5%）**」。
///
/// 现有测试查的是 clamp、z-order、槽位映射，以及
/// `garmentLayoutRespectsMorphWidth` 的 `w.width > n.width`——
/// **只验方向，不验量级**。而冻住的是量级。
///
/// ### 实测（400×600 画布，上装槽位，全部体型两两对比）
///
/// | 对 | Δwidth |
/// |---|---|
/// | pear vs invertedTriangle | 3.6%（最大） |
/// | rectangle vs invertedTriangle | 2.5% |
/// | pear vs apple | 2.3% |
/// | **hourglass vs apple** | **0.5%（最小）** |
///
/// **一对都没到 5%。**
///
/// ### 为什么：两个都写死了的立场在打架
///
/// - `DESIGN` 冻的是「≥5% 才叫可辨」；
/// - 而 `BodyMorphParams.preset` 刻意做得很轻（chest 0.98–1.03、hip 0.975–1.04），
///   `BodyAvatarScaler` 的注释写着「避免无界拉伸导致 uncanny」——**那也是设计决定**。
///
/// 更关键的一条：`removingShapePreset` 表明**命中真体型照片时 preset warp 会被旁路**
///（照片已经编码了体型，再叠 warp 是双重效果）。也就是说，用户看到的「两档体型不一样」
/// **主要来自不同的底图，不来自衣物变形**——而 §236 那条量的恰恰是衣物。
///
/// ### 这条测试做什么、不做什么
///
/// **做**：把实测钉住，让任何一次几何改动（无论调大调小）都当场可见。
/// **不做**：不替产品选边。把 preset 调大到满足 5% 会改变所有人看到的画面，
/// 而「调大之后会不会 uncanny」只有在设备上看得出来——那一条已写进
/// `DEVICE-ACCEPTANCE.md`。改标准还是改几何，是产品决定，不是我能在这里定的。
struct ShapeDistinctnessCriterionTests {

    /// DESIGN §236/§393 冻住的那个数。
    static let designCriterion = 0.05

    /// 实测到的最大体型间差异（本波测得 3.6%，留一点浮点余量）。
    static let measuredBest = 0.036

    private func topLayer() -> BodyAvatarLayer {
        BodyAvatarLayer(
            id: "t", slot: .top,
            frame: BodyAvatarAnchors.frame(for: .top),
            zIndex: 3, fitScale: 1.0, fitOffsetY: 0)
    }

    private func widthDelta(_ a: PopularShape, _ b: PopularShape) -> Double {
        let layer = topLayer()
        let fa = BodyAvatarGarmentLayout.pixelFrame(
            layer: layer, canvasWidth: 400, canvasHeight: 600,
            morph: BodyMorphParams.preset(for: a))
        let fb = BodyAvatarGarmentLayout.pixelFrame(
            layer: layer, canvasWidth: 400, canvasHeight: 600,
            morph: BodyMorphParams.preset(for: b))
        return abs(fa.width - fb.width) / fa.width
    }

    private var allPairs: [(PopularShape, PopularShape)] {
        var out: [(PopularShape, PopularShape)] = []
        let all = PopularShape.allCases
        for (i, a) in all.enumerated() {
            for b in all.dropFirst(i + 1) { out.append((a, b)) }
        }
        return out
    }

    /// **实测钉住**：任何一次几何改动都会让这条动。
    @Test func theMeasuredSpreadIsPinned() {
        let deltas = allPairs.map { widthDelta($0.0, $0.1) }
        let best = deltas.max() ?? 0
        #expect(best > 0.02, Comment(rawValue:
            "体型间最大差异掉到 \(String(format: "%.3f", best)) —— 比本波实测的 3.6% 还小，"
            + "纸娃娃已经几乎分不出体型了"))
        #expect(best < 0.05, Comment(rawValue:
            "最大差异 \(String(format: "%.3f", best)) 已经过了 DESIGN 的 5% 门槛 —— "
            + "**这是好消息**：把 §236/§393 那条 ⚠️ 划掉，并在设备上确认没有 uncanny"))
    }

    /// 方向必须对：体型不同，衣物的框就该不同（这条是既有 `garmentLayoutRespectsMorphWidth`
    /// 的加强版——它只比了两个手造 morph，这里比的是**产品真正会用的五个 preset**）。
    @Test func everyShapePairRendersDifferently() {
        for (a, b) in allPairs {
            #expect(widthDelta(a, b) > 0, Comment(rawValue:
                "\(a.rawValue) 与 \(b.rawValue) 的衣物框**完全一样** —— "
                + "这两档体型在纸娃娃上不可区分"))
        }
    }

    /// **最像的那一对**要单独点名——它是这条验收里最弱的一环。
    @Test func theClosestPairIsNamed() {
        let closest = allPairs.min { widthDelta($0.0, $0.1) < widthDelta($1.0, $1.1) }
        let pair = try? #require(closest)
        let delta = pair.map { widthDelta($0.0, $0.1) } ?? 0
        #expect(delta < Self.designCriterion, Comment(rawValue:
            "最像的一对已达标 —— 去更新 DESIGN §236/§393 的状态"))
        #expect(delta > 0.001, Comment(rawValue:
            "最像的一对差异只有 \(String(format: "%.4f", delta)) —— 实质上是同一个渲染"))
    }

    /// 标准本身要留在代码里，改它要改这里（而不是只改文档）。
    @Test func theFrozenCriterionIsRecorded() {
        #expect(Self.designCriterion == 0.05,
                "DESIGN §236/§393 冻的是 5%，改标准要连这里一起改并记 ADR")
        #expect(Self.measuredBest < Self.designCriterion,
                "实测已经超过标准 —— 更新 DESIGN 并删掉这条对照")
    }
}
