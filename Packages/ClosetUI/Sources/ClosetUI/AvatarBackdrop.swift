import SwiftUI

/// 体型画布底层场景。Croquis 为透明 PNG；场合底在 UI 层叠，不烤进资源。
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
}

/// 程序化场合背景（效果优先：体积光 + 地坪 + 可随视差放大裁切）。
struct AvatarBackdropView: View {
    var backdrop: AvatarBackdrop
    /// 景深虚化（背景层）；0 = 实
    var depthBlur: CGFloat = 0
    /// 视差时放大，避免露边
    var parallaxScale: CGFloat = 1.12
    /// 归一化光心偏移（随视差，强化立体）
    var lightShift: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                baseFill
                atmosphericLight(width: w, height: h)
                floorPlate(width: w, height: h)
                filmGrain
                vignette
            }
            .scaleEffect(parallaxScale)
            .blur(radius: depthBlur)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var baseFill: some View {
        switch backdrop {
        case .studio:
            LinearGradient(
                colors: [
                    Color(red: 0.72, green: 0.72, blue: 0.73),
                    Color(red: 0.60, green: 0.60, blue: 0.61),
                    Color(red: 0.48, green: 0.48, blue: 0.50)
                ],
                startPoint: .top,
                endPoint: .bottom)
        case .work:
            LinearGradient(
                colors: [
                    Color(red: 0.82, green: 0.86, blue: 0.90),
                    Color(red: 0.58, green: 0.64, blue: 0.72),
                    Color(red: 0.40, green: 0.46, blue: 0.54)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing)
        case .date:
            LinearGradient(
                colors: [
                    Color(red: 0.36, green: 0.16, blue: 0.32),
                    Color(red: 0.48, green: 0.20, blue: 0.30),
                    Color(red: 0.12, green: 0.08, blue: 0.14)
                ],
                startPoint: .top,
                endPoint: .bottom)
        case .gala:
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.10, blue: 0.16),
                    Color(red: 0.26, green: 0.16, blue: 0.34),
                    Color(red: 0.04, green: 0.04, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing)
        case .casual:
            LinearGradient(
                colors: [
                    Color(red: 0.93, green: 0.95, blue: 0.90),
                    Color(red: 0.74, green: 0.84, blue: 0.80),
                    Color(red: 0.58, green: 0.72, blue: 0.70)
                ],
                startPoint: .top,
                endPoint: .bottom)
        }
    }

    /// 体积光 / 窗光 / 聚光（随 lightShift 微移）
    private func atmosphericLight(width: CGFloat, height: CGFloat) -> some View {
        let cx = width * 0.5 + lightShift.width * 36
        let cy = height * lightY + lightShift.height * 28
        return ZStack {
            RadialGradient(
                colors: [keyLightColor.opacity(keyLightOpacity), .clear],
                center: UnitPoint(x: cx / max(width, 1), y: cy / max(height, 1)),
                startRadius: 8,
                endRadius: max(width, height) * 0.72)
            // 顶部天光
            LinearGradient(
                colors: [rimColor.opacity(rimOpacity), .clear],
                startPoint: .top,
                endPoint: .center)
        }
        .blendMode(backdrop == .gala || backdrop == .date ? .screen : .plusLighter)
        .allowsHitTesting(false)
    }

    private func floorPlate(width: CGFloat, height: CGFloat) -> some View {
        // 下 38% 地坪透视感，托住脚底
        VStack {
            Spacer()
            LinearGradient(
                colors: [
                    .clear,
                    floorColor.opacity(0.15),
                    floorColor.opacity(0.42)
                ],
                startPoint: .top,
                endPoint: .bottom)
            .frame(height: height * 0.38)
            .blur(radius: 0.5)
        }
        .allowsHitTesting(false)
    }

    private var filmGrain: some View {
        // 极轻噪点感：用半透明网格近似，避免真图资源
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.02),
                        Color.black.opacity(0.03),
                        Color.white.opacity(0.015)
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
            startRadius: 30,
            endRadius: 240)
        .blendMode(.multiply)
        .allowsHitTesting(false)
    }

    private var lightY: CGFloat {
        switch backdrop {
        case .studio, .work, .casual: return 0.22
        case .date, .gala: return 0.18
        }
    }

    private var keyLightColor: Color {
        switch backdrop {
        case .studio: return Color(red: 1, green: 0.98, blue: 0.96)
        case .work: return Color(red: 0.85, green: 0.92, blue: 1.0)
        case .date: return Color(red: 1.0, green: 0.55, blue: 0.45)
        case .gala: return Color(red: 0.75, green: 0.65, blue: 1.0)
        case .casual: return Color(red: 0.95, green: 1.0, blue: 0.9)
        }
    }

    private var keyLightOpacity: Double {
        switch backdrop {
        case .studio: return 0.35
        case .work: return 0.40
        case .date: return 0.45
        case .gala: return 0.50
        case .casual: return 0.32
        }
    }

    private var rimColor: Color {
        switch backdrop {
        case .date: return Color(red: 1, green: 0.4, blue: 0.35)
        case .gala: return Color(red: 0.6, green: 0.5, blue: 1)
        default: return .white
        }
    }

    private var rimOpacity: Double {
        switch backdrop {
        case .studio: return 0.12
        case .work: return 0.18
        case .date: return 0.28
        case .gala: return 0.32
        case .casual: return 0.14
        }
    }

    private var floorColor: Color {
        switch backdrop {
        case .studio: return Color(red: 0.25, green: 0.25, blue: 0.26)
        case .work: return Color(red: 0.2, green: 0.22, blue: 0.26)
        case .date: return Color(red: 0.08, green: 0.04, blue: 0.08)
        case .gala: return Color.black
        case .casual: return Color(red: 0.25, green: 0.35, blue: 0.32)
        }
    }

    private var vignetteOpacity: Double {
        switch backdrop {
        case .studio: return 0.18
        case .work: return 0.16
        case .date: return 0.32
        case .gala: return 0.38
        case .casual: return 0.12
        }
    }
}

/// 脚底接触阴影（随人体层位移，增强「站在场景里」）。
struct AvatarContactShadow: View {
    var body: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        Color.black.opacity(0.38),
                        Color.black.opacity(0.12),
                        .clear
                    ],
                    center: .center,
                    startRadius: 2,
                    endRadius: 48)
            )
            .frame(width: 120, height: 28)
            .blur(radius: 3)
            .accessibilityHidden(true)
    }
}

/// 前景景深雾（最前层，视差最大）——电影感压暗边角。
struct AvatarDepthFog: View {
    var intensity: DepthParallaxIntensity

    var body: some View {
        if intensity != .off {
            LinearGradient(
                colors: [
                    .clear,
                    .clear,
                    Color.black.opacity(intensity == .cinematic ? 0.14 : 0.07)
                ],
                startPoint: .top,
                endPoint: .bottom)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
