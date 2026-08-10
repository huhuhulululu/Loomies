import Foundation

/// 单品颜色。色轮 hue（0-360°）+ 中性标记（黑/白/灰/米/藏青——可与任意色搭）。
public struct GarmentColor: Sendable, Equatable {
    public let hueDegrees: Double
    public let isNeutral: Bool
    public init(hueDegrees: Double, isNeutral: Bool = false) {
        self.hueDegrees = hueDegrees
        self.isNeutral = isNeutral
    }
}

/// 两色在色轮上的关系。
public enum ColorRelation: String, Sendable, Equatable {
    case neutral        // 含中性色，百搭
    case analogous      // 邻近（≤30°）
    case complementary  // 互补（~180°）
    case triadic        // 三分（~120°）
    case clashing       // 冲突
}

/// 色彩搭配规则（纯函数，DESIGN §F4：60-30-10 + 色轮）。
public enum ColorHarmony {

    static func hueDistance(_ a: Double, _ b: Double) -> Double {
        let d = abs(a - b).truncatingRemainder(dividingBy: 360)
        return min(d, 360 - d)
    }

    public static func relation(_ a: GarmentColor, _ b: GarmentColor) -> ColorRelation {
        if a.isNeutral || b.isNeutral { return .neutral }
        // 非有限色相（NaN/±inf）无法判距离 → 按中性处理，不误报「色彩冲突」。
        guard a.hueDegrees.isFinite, b.hueDegrees.isFinite else { return .neutral }
        let d = hueDistance(a.hueDegrees, b.hueDegrees)
        if d <= 30 { return .analogous }
        if abs(d - 180) <= 20 { return .complementary }
        if abs(d - 120) <= 20 { return .triadic }
        return .clashing
    }

    /// 全体两两不冲突（中性色恒和谐）。
    public static func isHarmonious(_ colors: [GarmentColor]) -> Bool {
        guard colors.count >= 2 else { return true }
        for i in 0..<colors.count {
            for j in (i + 1)..<colors.count where relation(colors[i], colors[j]) == .clashing {
                return false
            }
        }
        return true
    }

    /// 60-30-10：非中性色相族 ≤ 3（主/辅/点缀）才算平衡。相距 ≤30° 视为同族。
    /// 非有限色相（NaN/±inf）不计入族数（与 relation 的 nil 化一致：脏数据不产生误判）。
    /// 聚族前按色相排序：贪心聚族对排列不满足交换律，同一套衣服的分数/文案
    /// 不得随输入顺序（SwiftData 关系数组不保序）漂移；环绕邻接由 hueDistance 处理。
    public static func followsSixtyThirtyTen(_ colors: [GarmentColor]) -> Bool {
        let hues = colors.filter { !$0.isNeutral }.map(\.hueDegrees)
            .filter(\.isFinite).sorted()
        var families: [Double] = []
        for h in hues {
            if !families.contains(where: { hueDistance($0, h) <= 30 }) { families.append(h) }
        }
        return families.count <= 3
    }
}
