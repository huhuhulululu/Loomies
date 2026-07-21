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
    public static func score(_ outfit: Outfit, context: ScoringContext) -> OutfitScore {
        var value = 1.0
        var reasons: [String] = []

        let colors = outfit.items.compactMap(\.color)
        if colors.count >= 2 {
            if ColorHarmony.isHarmonious(colors) {
                value += 0.3
                reasons.append("配色协调")
            } else {
                value -= 0.3
                reasons.append("配色冲突：建议换一件避免撞色")
            }
            if ColorHarmony.followsSixtyThirtyTen(colors) {
                value += 0.1
                reasons.append("遵循 60-30-10 配色平衡")
            } else {
                reasons.append("颜色偏多，建议以一个主色打底")
            }
        }
        // 体型×属性加权（BodyShapeStyling 表）。
        if let shape = context.bodyShape {
            let affinity = BodyShapeStyling.affinity(items: outfit.items, shape: shape.popularCategory)
            if affinity > 0 {
                value += 0.2 * affinity
                reasons.append("适合你的体型：扬长的版型")
            } else if affinity < 0 {
                value += 0.2 * affinity
                reasons.append("这套的版型可能不太衬你的体型")
            }
        }
        return OutfitScore(value: value, reasons: reasons)
    }
}
