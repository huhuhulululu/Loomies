import Foundation

/// 合身判定（最小合身标记，DESIGN §7 v1.0 / F2 Fit 引擎）。
/// ease（放松量）= 服装周长（2 × 平铺宽）− 身体净围；按阈值带判 紧/合/松。
/// 确定性、零数据冷启动；穿着反馈可后续个性化阈值（v1.x）。
public enum FitVerdict: String, Sendable {
    case tight      // 偏紧
    case fitted     // 合身
    case loose      // 偏松
}

/// 某品类/版型的 ease 阈值带（英寸）。ease < minEase → 紧；> maxEase → 松；之间 → 合身。
public struct EaseBand: Equatable, Sendable {
    public let minEase: Double
    public let maxEase: Double
    public init(minEase: Double, maxEase: Double) {
        self.minEase = minEase
        self.maxEase = maxEase
    }
}

public enum FitEngine {

    /// ease = 2 × 平铺宽 − 身体净围。
    public static func ease(garmentFlatWidth: Double, bodyCircumference: Double) -> Double {
        return 2 * garmentFlatWidth - bodyCircumference
    }

    /// 边界值（等于 minEase/maxEase）归入合身（闭区间）。
    public static func verdict(ease: Double, band: EaseBand) -> FitVerdict {
        if ease < band.minEase { return .tight }
        if ease > band.maxEase { return .loose }
        return .fitted
    }
}
