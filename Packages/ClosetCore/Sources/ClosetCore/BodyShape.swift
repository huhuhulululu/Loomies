import Foundation

/// FFIT（Female Figure Identification Technique）9 类体型。
/// 出处：Simmons/Istook/Devarajan (2004) + Lee et al. (2007) 公式化 + Sokolowski & Bettencourt (2020) plus-size 修正。
/// 见 docs/research/04-body-avatar.md §3.1。
public enum BodyShape: String, CaseIterable, Sendable {
    case hourglass          // 沙漏
    case bottomHourglass    // 下沙漏
    case topHourglass       // 上沙漏
    case spoon              // 勺形
    case triangle           // 三角（梨）
    case invertedTriangle   // 倒三角
    case rectangle          // 矩形
    case diamond            // 菱形
    case oval               // 椭圆（苹果）

    /// 大众 5 类映射（UI 折叠展示，避免过多学术术语）。
    public var popularCategory: PopularShape {
        switch self {
        case .hourglass, .topHourglass:      return .hourglass
        case .triangle, .spoon, .bottomHourglass: return .pear
        case .oval, .diamond:                return .apple
        case .rectangle:                     return .rectangle
        case .invertedTriangle:              return .invertedTriangle
        }
    }
}

/// 面向用户的大众体型 5 类。
public enum PopularShape: String, CaseIterable, Sendable {
    case hourglass, pear, apple, rectangle, invertedTriangle
}

/// FFIT 分类器（纯函数，端侧计算，身体数据不出网——DESIGN §2.2 不变量）。
/// 采用 plus-size 2020 修正版：原版隐含「腰总小于胸臀」，大码体型会被误判为矩形/倒三角。
public enum FFITClassifier {

    /// plus-size 2020 修正版，按顺序判定（首个满足者胜出）。阈值：1 / 3.6 / 9 / 10 / 2 / 7 / 1.193（英寸）。
    public static func classify(_ m: BodyMeasurements) -> BodyShape {
        let bustHip = m.bust - m.hip
        let hipBust = m.hip - m.bust
        let bustWaist = m.bust - m.waist
        let hipWaist = m.hip - m.waist
        let highHipWaistRatio = m.waist == 0 ? .infinity : m.highHip / m.waist

        // 1. Hourglass
        if bustHip <= 1, hipBust < 3.6, (bustWaist >= 9 || hipWaist >= 10) {
            return .hourglass
        }
        // 2. Bottom Hourglass
        if hipBust >= 3.6, hipBust < 10, hipWaist >= 9, highHipWaistRatio < 1.193 {
            return .bottomHourglass
        }
        // 3. Top Hourglass
        if bustHip > 1, bustHip < 10, bustWaist >= 9 {
            return .topHourglass
        }
        // 4. Spoon
        if hipBust > 2, hipWaist >= 7, highHipWaistRatio >= 1.193 {
            return .spoon
        }
        // 5. Triangle（梨，修正版）
        if hipBust >= 3.6, (0 <= hipWaist && hipWaist < 9) || (bustWaist < 0 && hipWaist >= 0) {
            return .triangle
        }
        // 6. Inverted Triangle（修正版）
        if bustHip >= 3.6, bustWaist < 9, hipWaist >= 0 {
            return .invertedTriangle
        }
        // 7. Rectangle（修正版）
        if hipBust < 3.6, bustHip < 3.6, 0 <= bustWaist, bustWaist < 9, 0 <= hipWaist, hipWaist < 10 {
            return .rectangle
        }
        // 8. Diamond（菱形）
        if hipWaist < 0, bustWaist < 0 {
            return .diamond
        }
        // 9. Oval（苹果）
        if hipWaist < 0, bustWaist >= 0 {
            return .oval
        }
        // 兜底：9 类规则在极端边缘可能留缝，回退最不具特异性的矩形（文档化的确定性默认）。
        return .rectangle
    }
}
