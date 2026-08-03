import SwiftUI
import ClosetCore
import ClosetModel
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit) && !os(iOS)
import AppKit
#endif

/// 真人站姿体型参考 + 槽位叠衣（DESIGN §F6 表达层，非 VTON / 非动画）。
/// 资产：`Resources/BodyAvatar/croquis_*.png`（写实时尚目录 bodysuit 站姿，5 大众体型）。
public struct BodyAvatarView: View {
    public var shape: PopularShape
    public var scale: BodyAvatarScale
    public var layers: [BodyAvatarLayer]
    public var fitCaption: String?
    public var showsFitCaption: Bool

    public init(
        shape: PopularShape = .rectangle,
        scale: BodyAvatarScale = BodyAvatarScale(widthScale: 1, hipScale: 1, waistScale: 1),
        layers: [BodyAvatarLayer] = [],
        fitCaption: String? = nil,
        showsFitCaption: Bool = true
    ) {
        self.shape = shape
        self.scale = scale
        self.layers = layers
        self.fitCaption = fitCaption
        self.showsFitCaption = showsFitCaption
    }

    /// 从测量 + 单品槽位构建（静态；无体型切换动画）。
    public static func from(
        measurements: BodyMeasurements?,
        slotAssets: [BodyAvatarSlot: String] = [:],
        fitCaption: String? = nil
    ) -> BodyAvatarView {
        let shape = BodyAvatarComposer.resolveShape(from: measurements)
        let scale = measurements.map { BodyAvatarScaler.scale(from: $0) }
            ?? BodyAvatarScale(widthScale: 1, hipScale: 1, waistScale: 1)
        return BodyAvatarView(
            shape: shape,
            scale: scale,
            layers: BodyAvatarComposer.layers(slots: slotAssets),
            fitCaption: fitCaption)
    }

    public var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                let w = geo.size.width
                // 真人图只做轻微宽度缩放，避免 scaleEffect 扭脸；体型主要靠 5 套底图切换。
                let displayWidth = w * min(max(scale.widthScale, 0.92), 1.08) * 0.94
                ZStack {
                    Group {
                        if let img = Self.bundleImage(named: BodyAvatarAsset.croquisName(for: shape)) {
                            img
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: displayWidth)
                        } else {
                            PlaceholderCroquis(shape: shape)
                                .frame(width: displayWidth)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    ForEach(layers) { layer in
                        garmentLayer(layer, canvas: geo.size)
                    }
                }
                .frame(width: w, height: geo.size.height)
                .clipped()
            }
            .aspectRatio(2 / 3, contentMode: .fit)
            .background(DS.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.radius))

            if showsFitCaption {
                VStack(spacing: 4) {
                    Text(displayShapeTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.ink)
                    if let fitCaption, !fitCaption.isEmpty {
                        Text(fitCaption)
                            .font(.caption)
                            .foregroundStyle(DS.muted)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Real-body proportion guide — not a photo try-on.")
                            .font(.caption2)
                            .foregroundStyle(DS.muted)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Body shape \(shape.rawValue)")
    }

    private var displayShapeTitle: String {
        switch shape {
        case .hourglass: return "Hourglass"
        case .pear: return "Pear"
        case .apple: return "Apple"
        case .rectangle: return "Rectangle"
        case .invertedTriangle: return "Inverted triangle"
        }
    }

    @ViewBuilder
    private func garmentLayer(_ layer: BodyAvatarLayer, canvas: CGSize) -> some View {
        let f = layer.frame
        let rect = CGRect(
            x: f.x * canvas.width,
            y: f.y * canvas.height,
            width: f.width * canvas.width,
            height: f.height * canvas.height)
        Group {
            if let name = layer.imageAssetName, let img = Self.bundleImage(named: name) {
                img.resizable().aspectRatio(contentMode: .fit)
            } else if let name = layer.imageAssetName {
                #if canImport(UIKit)
                if let ui = UIImage(named: name) {
                    Image(uiImage: ui).resizable().aspectRatio(contentMode: .fit)
                } else {
                    slotPlaceholder(layer.slot)
                }
                #else
                slotPlaceholder(layer.slot)
                #endif
            } else {
                slotPlaceholder(layer.slot)
            }
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .zIndex(Double(layer.zIndex))
    }

    private func slotPlaceholder(_ slot: BodyAvatarSlot) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(slotColor(slot).opacity(0.55))
            .overlay(
                Text(slot.rawValue)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
            )
    }

    private func slotColor(_ slot: BodyAvatarSlot) -> Color {
        switch slot {
        case .outerwear: return Color(red: 0.45, green: 0.35, blue: 0.30)
        case .top: return DS.accent
        case .dress: return Color(red: 0.55, green: 0.40, blue: 0.50)
        case .bottom: return Color(red: 0.30, green: 0.35, blue: 0.45)
        case .shoes: return Color(red: 0.25, green: 0.25, blue: 0.28)
        }
    }

    /// 从 SPM module 加载 `BodyAvatar/<name>.png`（静态，无 asset catalog 依赖）。
    static func bundleImage(named name: String) -> Image? {
        let urls: [URL?] = [
            Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "BodyAvatar"),
            Bundle.module.url(forResource: name, withExtension: "png"),
        ]
        for url in urls {
            guard let url, let data = try? Data(contentsOf: url) else { continue }
            #if canImport(UIKit)
            if let ui = UIImage(data: data) { return Image(uiImage: ui) }
            #elseif canImport(AppKit)
            if let ns = NSImage(data: data) { return Image(nsImage: ns) }
            #endif
        }
        return nil
    }
}

/// 无 PNG 时的程序化剪影（保证无资产也能编 UI）。
struct PlaceholderCroquis: View {
    var shape: PopularShape
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            var path = Path()
            let headR = w * 0.08
            path.addEllipse(in: CGRect(x: w / 2 - headR, y: h * 0.06, width: headR * 2, height: headR * 2))
            let shoulder = w * shoulderFactor
            let waist = w * waistFactor
            let hip = w * hipFactor
            let ySh = h * 0.18
            let yWa = h * 0.38
            let yHi = h * 0.48
            let yAnk = h * 0.92
            path.move(to: CGPoint(x: w / 2 - shoulder, y: ySh))
            path.addLine(to: CGPoint(x: w / 2 + shoulder, y: ySh))
            path.addLine(to: CGPoint(x: w / 2 + waist, y: yWa))
            path.addLine(to: CGPoint(x: w / 2 + hip, y: yHi))
            path.addLine(to: CGPoint(x: w / 2 + hip * 0.35, y: yAnk))
            path.addLine(to: CGPoint(x: w / 2 - hip * 0.35, y: yAnk))
            path.addLine(to: CGPoint(x: w / 2 - hip, y: yHi))
            path.addLine(to: CGPoint(x: w / 2 - waist, y: yWa))
            path.closeSubpath()
            ctx.fill(path, with: .color(Color(white: 0.45).opacity(0.85)))
        }
        .aspectRatio(2 / 3, contentMode: .fit)
    }

    private var shoulderFactor: CGFloat {
        switch shape {
        case .invertedTriangle: return 0.28
        case .pear: return 0.20
        default: return 0.24
        }
    }
    private var waistFactor: CGFloat {
        switch shape {
        case .hourglass: return 0.14
        case .apple: return 0.22
        case .rectangle: return 0.18
        default: return 0.16
        }
    }
    private var hipFactor: CGFloat {
        switch shape {
        case .pear: return 0.28
        case .invertedTriangle: return 0.18
        case .hourglass: return 0.24
        default: return 0.22
        }
    }
}
