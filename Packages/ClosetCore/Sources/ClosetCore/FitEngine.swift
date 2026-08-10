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
    /// 输入非有限或 ≤0（缺失/脏测值）→ nil：脏数据当缺失，不产出 ease
    /// （否则 ease(0,0)=0 会落进阈值带误报「合身」，负围度会误报「偏松」）。
    public static func ease(garmentFlatWidth: Double, bodyCircumference: Double) -> Double? {
        guard garmentFlatWidth.isFinite, garmentFlatWidth > 0,
              bodyCircumference.isFinite, bodyCircumference > 0 else { return nil }
        return 2 * garmentFlatWidth - bodyCircumference
    }

    /// 边界值（等于 minEase/maxEase）归入合身（闭区间）。
    /// ease 为 nil（脏输入，见 ease(garmentFlatWidth:bodyCircumference:)）
    /// 或非有限值（NaN/±inf）→ nil：UI 不展示标记，不误报「合身」。
    public static func verdict(ease: Double?, band: EaseBand) -> FitVerdict? {
        guard let ease, ease.isFinite else { return nil }
        if ease < band.minEase { return .tight }
        if ease > band.maxEase { return .loose }
        return .fitted
    }
}
