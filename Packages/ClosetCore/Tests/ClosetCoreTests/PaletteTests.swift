import Testing
import Foundation
@testable import ClosetCore

/// D115：**整个 app 没有深色模式**——`DS` 是五个硬编码的浅色 sRGB 值。
/// 系统切到深色时，Me 页那些系统组件（Form / List）跟着变深，
/// 其余三个 tab 的自绘底仍是暖骨白：同一个 app 半深半浅。
/// min iOS 26 的产品这样出街，第一眼就输了。
///
/// 调色板做成**纯值**放 Core：对比度是数学，不该依赖 SwiftUI 才能测。
/// DS 只负责按当前配色方案取对应那套。
struct PaletteTests {

    /// WCAG AA：正文 4.5:1，大字/图形 3:1。
    private let bodyMin = 4.5
    private let largeMin = 3.0

    @Test func bothSchemesExist() {
        #expect(Palette.light.scheme == .light)
        #expect(Palette.dark.scheme == .dark)
    }

    /// 深色那套必须真的是深的（不是把浅色抄一遍）。
    @Test func theDarkPaletteIsActuallyDark() {
        #expect(Palette.dark.bg.relativeLuminance < 0.1)
        #expect(Palette.light.bg.relativeLuminance > 0.7)
        #expect(Palette.dark.ink.relativeLuminance > 0.7)
    }

    /// 正文对比度（两套都要过）。
    @Test func bodyTextMeetsAA() {
        for p in [Palette.light, Palette.dark] {
            #expect(Palette.contrastRatio(p.ink, p.bg) >= bodyMin,
                    Comment(rawValue: "\(p.scheme) ink/bg = \(Palette.contrastRatio(p.ink, p.bg))"))
            #expect(Palette.contrastRatio(p.ink, p.surface) >= bodyMin,
                    Comment(rawValue: "\(p.scheme) ink/surface = \(Palette.contrastRatio(p.ink, p.surface))"))
        }
    }

    /// 次要文字也得看得清——`muted` 是全 app 用得最多的说明文字色。
    @Test func mutedTextMeetsAA() {
        for p in [Palette.light, Palette.dark] {
            #expect(Palette.contrastRatio(p.muted, p.bg) >= bodyMin,
                    Comment(rawValue: "\(p.scheme) muted/bg = \(Palette.contrastRatio(p.muted, p.bg))"))
        }
    }

    /// 强调色作为图形/边框元素至少 3:1。
    @Test func accentMeetsLargeElementContrast() {
        for p in [Palette.light, Palette.dark] {
            #expect(Palette.contrastRatio(p.accent, p.bg) >= largeMin,
                    Comment(rawValue: "\(p.scheme) accent/bg = \(Palette.contrastRatio(p.accent, p.bg))"))
        }
    }

    /// **按钮上的字**：浅色下白字压在黏土色上够用，深色下若把强调色提亮、
    /// 白字就掉到 3:1 以下。所以「压在强调色上的字」必须是独立 token，
    /// 而不是各处写死 `.white`。
    @Test func textOnAccentMeetsAA() {
        for p in [Palette.light, Palette.dark] {
            #expect(Palette.contrastRatio(p.onAccent, p.accent) >= bodyMin,
                    Comment(rawValue:
                        "\(p.scheme) onAccent/accent = \(Palette.contrastRatio(p.onAccent, p.accent))"))
        }
    }

    /// 暖调身份要保住：深色不得退化成蓝灰或纯黑（那是「默认 App」的样子）。
    @Test func theDarkPaletteKeepsTheWarmIdentity() {
        let bg = Palette.dark.bg
        #expect(bg.red > bg.blue, "深色底偏冷了 —— 暖骨白的身份没延续下来")
        #expect(bg.red > 0.04, "纯黑底：失去暖调，且 OLED 上与卡片边界糊在一起")
        let ink = Palette.dark.ink
        #expect(ink.red >= ink.blue, "深色下的正文色偏冷")
    }

    /// 对比度公式自检（黑白必为 21:1，同色必为 1:1）。
    @Test func theContrastFormulaIsCorrect() {
        let white = RGB(1, 1, 1), black = RGB(0, 0, 0)
        #expect(abs(Palette.contrastRatio(white, black) - 21.0) < 0.01)
        #expect(abs(Palette.contrastRatio(white, white) - 1.0) < 0.001)
    }

    /// 顺序无关（对比度是对称的）。
    @Test func contrastIsSymmetric() {
        let a = Palette.light.ink, b = Palette.light.bg
        #expect(abs(Palette.contrastRatio(a, b) - Palette.contrastRatio(b, a)) < 0.0001)
    }
}
