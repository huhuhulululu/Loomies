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
    /// 0 = guessed-absent, 0.5 = visual pick, 0.85 = provisional, 1.0 = measured.
    public let bodyShapeWeight: Double
    public let colorSeason: PersonalColorSeason?
    public init(
        bodyShape: BodyShape? = nil,
        bodyShapeWeight: Double = 1.0,
        colorSeason: PersonalColorSeason? = nil
    ) {
        self.bodyShape = bodyShape
        self.bodyShapeWeight = bodyShapeWeight
        self.colorSeason = (colorSeason == .unknown) ? nil : colorSeason
    }
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
        // 体型×属性加权（BodyShapeStyling 表）。测量置信度缩放该项，快选不得与实测同权。
        if let shape = context.bodyShape, context.bodyShapeWeight > 0 {
            let affinity = BodyShapeStyling.affinity(items: outfit.items, shape: shape.popularCategory)
            let delta = 0.2 * affinity * context.bodyShapeWeight
            if affinity > 0 {
                value += delta
                reasons.append("Flatters your body shape")
            } else if affinity < 0 {
                value += delta
                reasons.append("Cut may not suit your shape")
            }
        }
        if let season = context.colorSeason {
            let affinity = season.colorAffinity(colors: colors)
            if affinity > 0 {
                value += 0.15 * affinity
                reasons.append("Colors suit your \(season.displayName.lowercased()) season")
            } else if affinity < 0 {
                value += 0.15 * affinity
                reasons.append("Colors sit outside your \(season.displayName.lowercased()) season")
            }
        }
        return OutfitScore(
            value: min(Self.scoreRange.upperBound, max(Self.scoreRange.lowerBound, value)),
            reasons: reasons)
    }
}
