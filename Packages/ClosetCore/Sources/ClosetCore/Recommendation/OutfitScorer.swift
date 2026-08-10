import Foundation

/// outfit 打分结果，附「为什么推荐」（DESIGN §F4：每条推荐可解释）。
public struct OutfitScore: Sendable, Equatable {
    public let value: Double
    public let reasons: [String]
    public init(value: Double, reasons: [String]) {
        self.value = value
        self.reasons = reasons
    }
}

public struct ScoringContext: Sendable {
    public let bodyShape: BodyShape?
    public init(bodyShape: BodyShape? = nil) { self.bodyShape = bodyShape }
}

/// outfit 打分（纯函数，透明可解释）。当前含配色协调 + 60-30-10 平衡；
/// 体型×属性加权待属性表建成后接入（下一步，reason 已预留位）。
public enum OutfitScorer {
    /// 打分值域：钳在 [0, 2]（基准 1.0 ± 配色/体型加权）。
    /// affinity 是各单品属性权重之和、本身无界，故最终分必须有界，
    /// 推荐排序才可跨 outfit 比较。
    public static let scoreRange: ClosedRange<Double> = 0...2

    public static func score(_ outfit: Outfit, context: ScoringContext) -> OutfitScore {
        var value = 1.0
        var reasons: [String] = []

        let colors = outfit.items.compactMap(\.color)
        if colors.count >= 2 {
            if ColorHarmony.isHarmonious(colors) {
                value += 0.3
                reasons.append("Colors work well together")
            } else {
                value -= 0.3
                reasons.append("Color clash — swap one piece")
            }
            if ColorHarmony.followsSixtyThirtyTen(colors) {
                value += 0.1
                reasons.append("Balanced 60-30-10 color mix")
            } else {
                reasons.append("Many colors — try one main color")
            }
        }
        // 体型×属性加权（BodyShapeStyling 表）。en-US 理由文案（首发美区）。
        if let shape = context.bodyShape {
            let affinity = BodyShapeStyling.affinity(items: outfit.items, shape: shape.popularCategory)
            if affinity > 0 {
                value += 0.2 * affinity
                reasons.append("Flatters your body shape")
            } else if affinity < 0 {
                value += 0.2 * affinity
                reasons.append("Cut may not suit your shape")
            }
        }
        return OutfitScore(
            value: min(Self.scoreRange.upperBound, max(Self.scoreRange.lowerBound, value)),
            reasons: reasons)
    }
}
