import Foundation

/// sRGB 三元组（0…1）。纯值，不依赖任何图形框架。
public struct RGB: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(_ red: Double, _ green: Double, _ blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// 十六进制便利构造（`0x1A1714`）——设计稿里的值可以原样搬过来。
    public init(hex: UInt32) {
        self.init(
            Double((hex >> 16) & 0xFF) / 255,
            Double((hex >> 8) & 0xFF) / 255,
            Double(hex & 0xFF) / 255)
    }

    /// WCAG 相对亮度（sRGB 反伽马后加权）。
    public var relativeLuminance: Double {
        func lin(_ c: Double) -> Double {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(red) + 0.7152 * lin(green) + 0.0722 * lin(blue)
    }
}

/// 配色方案的一整套语义色（D115）。
///
/// 此前 `DS` 是五个硬编码的**浅色** sRGB 值，深色模式下 Me 页的系统组件变深、
/// 其余三个 tab 的自绘底仍是暖骨白——同一个 app 半深半浅。
///
/// 放在 Core 而不是 UI 层，是为了让**对比度可测**：那是数学，不该非得起个
/// SwiftUI 环境才能验。UI 层只负责按当前 `colorScheme` 取对应那套。
public struct Palette: Sendable {

    public enum Scheme: String, Sendable { case light, dark }

    public let scheme: Scheme
    /// 页面底色
    public let bg: RGB
    /// 卡片 / 抬升面
    public let surface: RGB
    /// 正文
    public let ink: RGB
    /// 次要说明文字
    public let muted: RGB
    /// 品牌强调（黏土）
    public let accent: RGB
    /// **压在强调色上**的文字色。独立 token 而不是各处写死 `.white`——
    /// 深色下强调色要提亮才够对比，一提亮白字就掉到 3:1 以下。
    public let onAccent: RGB
    /// 分隔线 / 描边
    public let hairline: RGB

    /// 暖骨白 + 黏土：既有的产品身份，原样保留。
    public static let light = Palette(
        scheme: .light,
        bg:       RGB(0.957, 0.941, 0.910),
        surface:  RGB(0.984, 0.976, 0.957),
        ink:      RGB(0.169, 0.149, 0.133),
        muted:    RGB(0.396, 0.357, 0.318),
        accent:   RGB(0.620, 0.333, 0.251),
        onAccent: RGB(1.0, 1.0, 1.0),
        hairline: RGB(0.855, 0.831, 0.788))

    /// 深色不是把浅色反过来，而是把**同一个暖调**沉下去：
    /// 暖炭底（偏红不偏蓝）、暖白正文、黏土提亮到能在深底上站住。
    /// 不用纯黑：OLED 上纯黑会让卡片边界糊掉，也丢了暖调身份。
    public static let dark = Palette(
        scheme: .dark,
        bg:       RGB(hex: 0x1A1714),
        surface:  RGB(hex: 0x262119),
        ink:      RGB(hex: 0xF2EDE4),
        muted:    RGB(hex: 0xB3A797),
        accent:   RGB(hex: 0xD8916B),
        onAccent: RGB(hex: 0x1A1714),
        hairline: RGB(hex: 0x3A332A))

    /// 槽位色（网格占位、缩略图底纹）。类别色也属于设计系统的一部分——
    /// 散在视图里各写一串 sRGB 字面量，就是「拼装感」的来源，且深色下调不动。
    public func slotWash(_ slot: String) -> RGB {
        let table: [String: (UInt32, UInt32)] = [
            // slot: (light, dark)
            "top":        (0x9E5540, 0xD8916B),
            "bottom":     (0x4C5973, 0x8CA0C4),
            "dress":      (0x8C6680, 0xC79BBB),
            "outerwear":  (0x73594C, 0xC49B85),
            "shoes":      (0x404047, 0x9A9AA6),
            "accessory":  (0x807047, 0xCBB77E),
        ]
        guard let pair = table[slot] else { return muted }
        return RGB(hex: scheme == .dark ? pair.1 : pair.0)
    }

    /// 场合辉光（Today 主视觉的边缘光）。同上：类别色进系统，不散在视图里。
    public func occasionGlow(_ backdrop: String) -> RGB {
        let table: [String: (UInt32, UInt32)] = [
            "studio":  (0xE8E2D6, 0x6E6455),
            "work":    (0x8CB8F2, 0x5E86BF),
            "date":    (0xF27380, 0xBF5563),
            "gala":    (0xB38CFF, 0x8566C4),
            "casual":  (0x8CCCA6, 0x5E9E78),
        ]
        guard let pair = table[backdrop] else { return hairline }
        return RGB(hex: scheme == .dark ? pair.1 : pair.0)
    }

    /// WCAG 对比度（1…21，对称）。
    public static func contrastRatio(_ a: RGB, _ b: RGB) -> Double {
        let la = a.relativeLuminance, lb = b.relativeLuminance
        let hi = max(la, lb), lo = min(la, lb)
        return (hi + 0.05) / (lo + 0.05)
    }
}
