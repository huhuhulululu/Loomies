import SwiftUI

/// 设计 tokens（DESIGN §10）：暖中性底 + 单一低饱和 accent（muted clay）。
/// Liquid Glass 由标准 SwiftUI 组件在 iOS 26 SDK 下自动获得；自定义玻璃 ≤2 处（真机 target 加）。
public enum DS {
    public static let bg      = Color(red: 0.957, green: 0.941, blue: 0.910) // warm bone
    public static let surface = Color(red: 0.984, green: 0.976, blue: 0.957)
    public static let ink     = Color(red: 0.169, green: 0.149, blue: 0.133)
    public static let muted   = Color(red: 0.431, green: 0.392, blue: 0.353)
    public static let accent  = Color(red: 0.620, green: 0.333, blue: 0.251) // muted clay
    public static let radius: CGFloat = 10
}
