import Foundation

/// 合身标记文案（DESIGN §7 最小合身标记 / H3 合身判断优先）。
/// en-US 主市场；UI 直接展示，不绑 SwiftUI。
public enum FitMarkCopy {
    public static func label(_ verdict: FitVerdict) -> String {
        switch verdict {
        case .tight:  return "Runs tight"
        case .fitted: return "True to size"
        case .loose:  return "Runs loose"
        }
    }

    /// Measurement/ease guide only — not photo try-on or “how it looks on you.”
    public static func detail(_ verdict: FitVerdict) -> String {
        switch verdict {
        case .tight:
            return "From your measures vs flat widths, ease may feel snug (proportion guide)."
        case .fitted:
            return "From your measures vs flat widths, ease looks balanced (proportion guide)."
        case .loose:
            return "From your measures vs flat widths, ease may feel roomy (proportion guide)."
        }
    }
}
