import SwiftUI

/// 设计 tokens（DESIGN §10）：暖中性底 + 单一低饱和 accent（muted clay）。
/// Liquid Glass 由标准 SwiftUI 组件在 iOS 26 SDK 下自动获得；自定义玻璃 ≤2 处（真机 target 加）。
public enum DS {
    public static let bg      = Color(red: 0.957, green: 0.941, blue: 0.910) // warm bone
    public static let surface = Color(red: 0.984, green: 0.976, blue: 0.957)
    public static let ink     = Color(red: 0.169, green: 0.149, blue: 0.133)
    public static let muted   = Color(red: 0.431, green: 0.392, blue: 0.353)
    public static let accent  = Color(red: 0.620, green: 0.333, blue: 0.251) // muted clay
    /// BodyAvatar 默认棚灰（≈ RGB 158）；croquis 已透明，棚灰走 `AvatarBackdrop.studio`
    public static let studioGray = Color(red: 158 / 255, green: 158 / 255, blue: 158 / 255)
    public static let radius: CGFloat = 12
    public static let radiusLg: CGFloat = 18
    public static let heroMinHeight: CGFloat = 360
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
