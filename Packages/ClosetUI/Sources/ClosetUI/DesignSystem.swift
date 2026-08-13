import SwiftUI
import ClosetCore
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 设计 tokens（DESIGN §10）：暖中性底 + 单一低饱和 accent（muted clay）。
/// Liquid Glass 由标准 SwiftUI 组件在 iOS 26 SDK 下自动获得；自定义玻璃 ≤2 处（真机 target 加）。
public enum DS {
    /// D115：语义色**跟随系统配色方案**。
    ///
    /// 此前这里是五个硬编码的浅色值——系统切深色时，Me 页那些系统组件
    /// （Form / List）跟着变深，其余三个 tab 的自绘底仍是暖骨白：
    /// 同一个 app 半深半浅。min iOS 26 的产品这样出街，第一眼就输了。
    ///
    /// 取值与对比度由 `ClosetCore.Palette` 定义并**在 Core 里测**
    /// （对比度是数学，不该非得起个 SwiftUI 环境才能验）。
    static func adaptive(_ keyPath: KeyPath<Palette, RGB>) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { traits in
            let p: Palette = traits.userInterfaceStyle == .dark ? .dark : .light
            let c = p[keyPath: keyPath]
            return UIColor(red: c.red, green: c.green, blue: c.blue, alpha: 1)
        })
        #elseif canImport(AppKit)
        return Color(NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let c = (isDark ? Palette.dark : Palette.light)[keyPath: keyPath]
            return NSColor(srgbRed: c.red, green: c.green, blue: c.blue, alpha: 1)
        })
        #else
        let c = Palette.light[keyPath: keyPath]
        return Color(red: c.red, green: c.green, blue: c.blue)
        #endif
    }

    public static let bg      = adaptive(\.bg)       // warm bone / warm charcoal
    public static let surface = adaptive(\.surface)
    public static let ink     = adaptive(\.ink)
    public static let muted   = adaptive(\.muted)
    public static let accent  = adaptive(\.accent)   // muted clay
    /// 压在 `accent` 上的文字色。深色下强调色要提亮才够对比，
    /// 一提亮再写死 `.white` 就掉到 3:1 以下——所以它是独立 token。
    public static let onAccent = adaptive(\.onAccent)
    /// 分隔线 / 描边（此前各处写 `Color.white.opacity(0.12)`，深色下等于没有）
    public static let hairline = adaptive(\.hairline)
    /// BodyAvatar 默认棚灰（≈ RGB 158）；croquis 已透明，棚灰走 `AvatarBackdrop.studio`
    public static let studioGray = Color(red: 158 / 255, green: 158 / 255, blue: 158 / 255)
    /// 间距尺度（D129）。
    ///
    /// 全 app 实际用的是 **2pt 网格**，但混着 3 / 9 / 11 这三个离格值——
    /// 它们不来自任何判断，只是当时手感调出来的。离格值本身不致命，
    /// 致命的是没有尺度：下一个人照着旁边那行写 13，再下一个写 7，
    /// 「拼装感」就是这么一步步攒出来的。
    ///
    /// **刻意不重排已经在格上的四十处间距**——那种改动我无法目视验证，
    /// 盲改只会把「不确定」摊到全 app。这里只做三件事：
    /// 命名尺度、修掉离格值、加门挡住新的。
    public enum Space {
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
        public static let xl: CGFloat = 24
    }

    public static let radius: CGFloat = 12
    public static let radiusLg: CGFloat = 18
    public static let heroMinHeight: CGFloat = 360

    /// 语义字阶（D121）。
    ///
    /// 此前全 app **没有层级**：`caption` + `caption2` 占了全部字号调用的 **83%**
    /// （230/276），`headline`（17pt）以上只有 6 处——每一行都在小声说话，
    /// 读起来像设置页而不是一个产品。
    ///
    /// DESIGN §462 早就写明审美参照是「高端时尚电商的排版气质
    /// （SSENSE 黑白克制、NAP/Sézane 的 serif 编辑感）」，§566 还要求
    /// 「serif 标题也须缩放」——**规范写了，实现从来没做**。
    ///
    /// 每一档都从 Dynamic Type 的**文本样式**派生（不是 `.system(size:)` 固定值），
    /// 所以全档缩放天然成立，那是 §566 的硬要求。
    public enum Text {
        /// 主视觉标题（Today 的那身、毕业时刻）。编辑感 serif。
        public static let display = Font.system(.title, design: .serif).weight(.semibold)
        /// 卡片 / 区块标题。
        public static let sectionTitle = Font.system(.title3, design: .serif).weight(.medium)
        /// 列表行主标题。
        public static let rowTitle = Font.headline
        /// 正文。
        public static let body = Font.subheadline
        /// 次要信息（说明、状态）。
        public static let meta = Font.caption
        /// 最次级（角标、单位）——**只**用于真正次要的东西，
        /// 不是「懒得想层级就用它」。
        public static let micro = Font.caption2
    }

    /// 类别色（槽位 / 场合）。同样按配色方案解析——这些此前是散在两个视图里的
    /// sRGB 字面量，深色下调不动，也没人知道全套有几个。
    public static func slotWash(_ slotRaw: String) -> Color {
        adaptiveCategory { $0.slotWash(slotRaw) }
    }

    public static func occasionGlow(_ backdropRaw: String) -> Color {
        adaptiveCategory { $0.occasionGlow(backdropRaw) }
    }

    private static func adaptiveCategory(_ pick: @escaping @Sendable (Palette) -> RGB) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { traits in
            let c = pick(traits.userInterfaceStyle == .dark ? .dark : .light)
            return UIColor(red: c.red, green: c.green, blue: c.blue, alpha: 1)
        })
        #elseif canImport(AppKit)
        return Color(NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let c = pick(isDark ? .dark : .light)
            return NSColor(srgbRed: c.red, green: c.green, blue: c.blue, alpha: 1)
        })
        #else
        let c = pick(.light)
        return Color(red: c.red, green: c.green, blue: c.blue)
        #endif
    }
}

/// Today / Favorites / Calendar / Closet flash chips — fail must not paint as accent “success.”
public enum CustomerFlashStyle {
    public static func isFailure(_ text: String) -> Bool {
        let t = text.lowercased()
        return t.contains("couldn't")
            || t.contains("failed")
            || t.contains("missing from closet")
    }

    /// Bottom overlay / list toast chip (Favorites · Calendar · Closet seed).
    @ViewBuilder
    public static func overlayChip(_ text: String) -> some View {
        let fail = isFailure(text)
        Text(text)
            .font(.caption.weight(fail ? .medium : .regular))
            .foregroundStyle(fail ? Color.orange : DS.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(fail ? Color.orange.opacity(0.12) : DS.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel(text)
    }
}
