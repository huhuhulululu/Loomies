import Testing
import Foundation
@testable import ClosetCore

/// D174（功能覆盖普查）：`ColorHarmony.hueDistance` 是配色判定的**基础运算**，
/// 而它零直接测试——`relation` 被测了 11 处，但都在它的下游，
/// 环绕（359° 与 1°）这种边界从没被单独钉过。
struct HueDistanceTests {

    @Test func itMeasuresTheShorterWayAroundTheWheel() {
        #expect(ColorHarmony.hueDistance(10, 40) == 30)
        // 环绕：359 与 1 相差 2 度，不是 358
        #expect(ColorHarmony.hueDistance(359, 1) == 2)
        #expect(ColorHarmony.hueDistance(1, 359) == 2)
    }

    /// 对径最远 180，不会更大。
    @Test func theMaximumIsHalfTheWheel() {
        #expect(ColorHarmony.hueDistance(0, 180) == 180)
        #expect(ColorHarmony.hueDistance(90, 270) == 180)
        for a in stride(from: 0.0, to: 360.0, by: 17) {
            for b in stride(from: 0.0, to: 360.0, by: 23) {
                let d = ColorHarmony.hueDistance(a, b)
                #expect(d >= 0 && d <= 180, Comment(rawValue: "\(a)/\(b) → \(d)"))
            }
        }
    }

    /// 同色距离为 0；超出 [0,360) 的输入按环绕处理（不 trap、不给负数）。
    @Test func itNormalisesOutOfRangeInput() {
        #expect(ColorHarmony.hueDistance(0, 0) == 0)
        #expect(ColorHarmony.hueDistance(0, 360) == 0)
        #expect(ColorHarmony.hueDistance(370, 10) == 0)
        #expect(ColorHarmony.hueDistance(-10, 350) == 0)
    }

    /// 对称：a→b 与 b→a 相同（否则配色判定会随成员顺序变）。
    @Test func itIsSymmetric() {
        for (a, b) in [(15.0, 200.0), (0.0, 359.0), (123.0, 45.0)] {
            #expect(ColorHarmony.hueDistance(a, b) == ColorHarmony.hueDistance(b, a))
        }
    }
}
