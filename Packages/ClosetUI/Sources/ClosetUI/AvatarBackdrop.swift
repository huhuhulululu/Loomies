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

/// 程序化场合背景（无位图资产；以后可换真实场景图）。
struct AvatarBackdropView: View {
    var backdrop: AvatarBackdrop

    var body: some View {
        Group {
            switch backdrop {
            case .studio:
                LinearGradient(
                    colors: [
                        Color(red: 0.66, green: 0.66, blue: 0.67),
                        Color(red: 0.58, green: 0.58, blue: 0.59),
                        Color(red: 0.52, green: 0.52, blue: 0.53)
                    ],
                    startPoint: .top,
                    endPoint: .bottom)
            case .work:
                LinearGradient(
                    colors: [
                        Color(red: 0.78, green: 0.82, blue: 0.86),
                        Color(red: 0.62, green: 0.68, blue: 0.74),
                        Color(red: 0.48, green: 0.54, blue: 0.60)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing)
            case .date:
                LinearGradient(
                    colors: [
                        Color(red: 0.28, green: 0.18, blue: 0.28),
                        Color(red: 0.42, green: 0.22, blue: 0.32),
                        Color(red: 0.18, green: 0.12, blue: 0.20)
                    ],
                    startPoint: .top,
                    endPoint: .bottom)
            case .gala:
                LinearGradient(
                    colors: [
                        Color(red: 0.12, green: 0.12, blue: 0.16),
                        Color(red: 0.22, green: 0.18, blue: 0.28),
                        Color(red: 0.08, green: 0.08, blue: 0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing)
            case .casual:
                LinearGradient(
                    colors: [
                        Color(red: 0.90, green: 0.93, blue: 0.88),
                        Color(red: 0.78, green: 0.86, blue: 0.82),
                        Color(red: 0.70, green: 0.80, blue: 0.78)
                    ],
                    startPoint: .top,
                    endPoint: .bottom)
            }
        }
        .overlay {
            // 轻 vignette，让人物更站得住
            RadialGradient(
                colors: [.clear, Color.black.opacity(vignetteOpacity)],
                center: .center,
                startRadius: 40,
                endRadius: 220)
            .blendMode(.multiply)
            .allowsHitTesting(false)
        }
        .accessibilityHidden(true)
    }

    private var vignetteOpacity: Double {
        switch backdrop {
        case .studio: return 0.10
        case .work: return 0.12
        case .date: return 0.22
        case .gala: return 0.28
        case .casual: return 0.08
        }
    }
}
