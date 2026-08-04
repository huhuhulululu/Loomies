import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit) && !os(iOS)
import AppKit
#endif

/// 体型画布底层场景。Croquis 为透明 PNG；场合底在 UI 层叠，不烤进 croquis。
public enum AvatarBackdrop: String, CaseIterable, Sendable, Equatable {
    case studio
    case work
    case date
    case gala
    case casual

    /// 从 occasion 字符串解析；未知 → studio（棚灰默认）。
    public static func resolved(from occasion: String?) -> AvatarBackdrop {
        guard let raw = occasion?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return .studio }
        switch raw.lowercased() {
        case "work", "office", "business", "businesscasual", "business_casual":
            return .work
        case "date", "night", "evening":
            return .date
        case "gala", "formal", "party", "blacktie", "black_tie":
            return .gala
        case "casual", "weekend", "everyday", "daily":
            return .casual
        default:
            if let exact = AvatarBackdrop(rawValue: raw.lowercased()) { return exact }
            return .studio
        }
    }

    public var accessibilityLabel: String {
        switch self {
        case .studio: return "Studio backdrop"
        case .work: return "Work backdrop"
        case .date: return "Date backdrop"
        case .gala: return "Gala backdrop"
        case .casual: return "Casual backdrop"
        }
    }

    /// Resources/Backdrops/backdrop_{raw}.png
    public var imageResourceName: String { "backdrop_\(rawValue)" }
}

/// 电影感场合背景：优先位图场景 + 程序化光雾托底；支持景深视差放大/虚化。
struct AvatarBackdropView: View {
    var backdrop: AvatarBackdrop
    var depthBlur: CGFloat = 0
    var parallaxScale: CGFloat = 1.12
    var lightShift: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                proceduralBase
                if let photo = Self.bundleImage(named: backdrop.imageResourceName) {
                    photo
                        .resizable()
                        .scaledToFill()
                        .frame(width: w, height: h)
                        .clipped()
                        .overlay {
                            // 上半提亮、下半压脚区，给人体站位
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(topWash),
                                    .clear,
                                    Color.black.opacity(floorVeil)
                                ],
                                startPoint: .top,
                                endPoint: .bottom)
                        }
                }
                atmosphericLight(width: w, height: h)
                floatingBokeh(width: w, height: h)
                filmGrain
                vignette
            }
            .frame(width: w, height: h)
            .scaleEffect(parallaxScale)
            .blur(radius: depthBlur)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Bundle

    static func bundleImage(named name: String) -> Image? {
        if let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Backdrops")
            ?? Bundle.module.url(forResource: name, withExtension: "png") {
            #if canImport(UIKit)
            if let ui = UIImage(contentsOfFile: url.path) { return Image(uiImage: ui) }
            #elseif canImport(AppKit) && !os(iOS)
            if let ns = NSImage(contentsOf: url) { return Image(nsImage: ns) }
            #endif
        }
        return nil
    }

    // MARK: - Layers

    @ViewBuilder
    private var proceduralBase: some View {
        switch backdrop {
        case .studio:
            LinearGradient(
                colors: [
                    Color(red: 0.72, green: 0.72, blue: 0.73),
                    Color(red: 0.60, green: 0.60, blue: 0.61),
                    Color(red: 0.48, green: 0.48, blue: 0.50)
                ],
                startPoint: .top, endPoint: .bottom)
        case .work:
            LinearGradient(
                colors: [
                    Color(red: 0.82, green: 0.86, blue: 0.90),
                    Color(red: 0.58, green: 0.64, blue: 0.72),
                    Color(red: 0.40, green: 0.46, blue: 0.54)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .date:
            LinearGradient(
                colors: [
                    Color(red: 0.36, green: 0.16, blue: 0.32),
                    Color(red: 0.48, green: 0.20, blue: 0.30),
                    Color(red: 0.12, green: 0.08, blue: 0.14)
                ],
                startPoint: .top, endPoint: .bottom)
        case .gala:
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.10, blue: 0.16),
                    Color(red: 0.26, green: 0.16, blue: 0.34),
                    Color(red: 0.04, green: 0.04, blue: 0.08)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .casual:
            LinearGradient(
                colors: [
                    Color(red: 0.93, green: 0.95, blue: 0.90),
                    Color(red: 0.74, green: 0.84, blue: 0.80),
                    Color(red: 0.58, green: 0.72, blue: 0.70)
                ],
                startPoint: .top, endPoint: .bottom)
        }
    }

    private func atmosphericLight(width: CGFloat, height: CGFloat) -> some View {
        let cx = 0.5 + lightShift.width * 0.12
        let cy = lightY + lightShift.height * 0.08
        return ZStack {
            RadialGradient(
                colors: [keyLightColor.opacity(keyLightOpacity), .clear],
                center: UnitPoint(x: cx, y: cy),
                startRadius: 6,
                endRadius: max(width, height) * 0.75)
            LinearGradient(
                colors: [rimColor.opacity(rimOpacity), .clear],
                startPoint: .top,
                endPoint: .center)
        }
        .blendMode(backdrop == .gala || backdrop == .date ? .screen : .plusLighter)
        .allowsHitTesting(false)
    }

    /// 额外浮动光斑（date/gala 加强电影感）
    private func floatingBokeh(width: CGFloat, height: CGFloat) -> some View {
        Group {
            if backdrop == .date || backdrop == .gala {
                ZStack {
                    Circle().fill(keyLightColor.opacity(0.22))
                        .frame(width: 36, height: 36)
                        .blur(radius: 8)
                        .offset(
                            x: width * 0.28 + lightShift.width * 20,
                            y: -height * 0.18 + lightShift.height * 12)
                    Circle().fill(rimColor.opacity(0.18))
                        .frame(width: 22, height: 22)
                        .blur(radius: 6)
                        .offset(
                            x: -width * 0.22 + lightShift.width * 14,
                            y: -height * 0.08 + lightShift.height * 10)
                    Circle().fill(Color.white.opacity(0.12))
                        .frame(width: 14, height: 14)
                        .blur(radius: 4)
                        .offset(x: width * 0.12, y: height * 0.05)
                }
                .blendMode(.screen)
            }
        }
        .allowsHitTesting(false)
    }

    private var filmGrain: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.025),
                        Color.black.opacity(0.04),
                        Color.white.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing)
            )
            .blendMode(.overlay)
            .allowsHitTesting(false)
    }

    private var vignette: some View {
        RadialGradient(
            colors: [.clear, Color.black.opacity(vignetteOpacity)],
            center: .center,
            startRadius: 28,
            endRadius: 250)
        .blendMode(.multiply)
        .allowsHitTesting(false)
    }

    private var topWash: Double {
        switch backdrop {
        case .studio: return 0.06
        case .work: return 0.08
        case .date: return 0.04
        case .gala: return 0.03
        case .casual: return 0.07
        }
    }

    private var floorVeil: Double {
        switch backdrop {
        case .studio: return 0.10
        case .work: return 0.12
        case .date: return 0.28  // 压蜡烛前景
        case .gala: return 0.22
        case .casual: return 0.10
        }
    }

    private var lightY: CGFloat {
        switch backdrop {
        case .studio, .work, .casual: return 0.20
        case .date, .gala: return 0.16
        }
    }

    private var keyLightColor: Color {
        switch backdrop {
        case .studio: return Color(red: 1, green: 0.98, blue: 0.96)
        case .work: return Color(red: 0.85, green: 0.92, blue: 1.0)
        case .date: return Color(red: 1.0, green: 0.55, blue: 0.45)
        case .gala: return Color(red: 0.85, green: 0.72, blue: 1.0)
        case .casual: return Color(red: 0.95, green: 1.0, blue: 0.9)
        }
    }

    private var keyLightOpacity: Double {
        switch backdrop {
        case .studio: return 0.22
        case .work: return 0.28
        case .date: return 0.32
        case .gala: return 0.36
        case .casual: return 0.24
        }
    }

    private var rimColor: Color {
        switch backdrop {
        case .date: return Color(red: 1, green: 0.45, blue: 0.38)
        case .gala: return Color(red: 0.7, green: 0.55, blue: 1)
        case .work: return Color(red: 0.7, green: 0.85, blue: 1)
        default: return .white
        }
    }

    private var rimOpacity: Double {
        switch backdrop {
        case .studio: return 0.10
        case .work: return 0.16
        case .date: return 0.24
        case .gala: return 0.28
        case .casual: return 0.12
        }
    }

    private var vignetteOpacity: Double {
        switch backdrop {
        case .studio: return 0.16
        case .work: return 0.18
        case .date: return 0.30
        case .gala: return 0.36
        case .casual: return 0.14
        }
    }
}

/// 脚底接触阴影。
struct AvatarContactShadow: View {
    var body: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        Color.black.opacity(0.42),
                        Color.black.opacity(0.14),
                        .clear
                    ],
                    center: .center,
                    startRadius: 2,
                    endRadius: 52)
            )
            .frame(width: 128, height: 30)
            .blur(radius: 3.5)
            .accessibilityHidden(true)
    }
}

/// 地面镜像反射（人体层下方，弱透明度）。
struct AvatarFloorReflection<Content: View>: View {
    var heightFraction: CGFloat = 0.14
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .scaleEffect(x: 1, y: -1, anchor: .bottom)
            .mask(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.28),
                        Color.black.opacity(0.08),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom)
            )
            .opacity(0.35)
            .blur(radius: 1.2)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// 轮廓分离光（让透明 croquis 从复杂背景中弹出）。
struct AvatarRimLight: View {
    var backdrop: AvatarBackdrop
    var intensity: DepthParallaxIntensity

    var body: some View {
        if intensity != .off {
            LinearGradient(
                colors: rimColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing)
            .blendMode(.screen)
            .opacity(intensity == .cinematic ? 0.22 : 0.12)
            .mask(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.9), .clear],
                    startPoint: .leading,
                    endPoint: .trailing)
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private var rimColors: [Color] {
        switch backdrop {
        case .date:
            return [Color(red: 1, green: 0.5, blue: 0.4), .clear, Color(red: 1, green: 0.7, blue: 0.5)]
        case .gala:
            return [Color(red: 0.7, green: 0.5, blue: 1), .clear, Color(red: 1, green: 0.85, blue: 0.6)]
        case .work:
            return [Color(red: 0.6, green: 0.8, blue: 1), .clear, Color.white]
        default:
            return [Color.white, .clear, Color.white.opacity(0.6)]
        }
    }
}

/// 前景景深雾。
struct AvatarDepthFog: View {
    var intensity: DepthParallaxIntensity

    var body: some View {
        if intensity != .off {
            LinearGradient(
                colors: [
                    .clear,
                    .clear,
                    Color.black.opacity(intensity == .cinematic ? 0.16 : 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
