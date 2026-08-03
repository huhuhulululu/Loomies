import SwiftUI
import ClosetCore
import ClosetModel
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit) && !os(iOS)
import AppKit
#endif

/// 真人站姿体型参考 + **360° 静态多角度** + 槽位叠衣（DESIGN §F6，非 VTON）。
/// 拖拽/点选切换偏航角（每 45° 一帧）；**无插值动画**。
/// 资产：`Resources/BodyAvatar/croquis_{shape}_yaw{000…315}.png`
public struct BodyAvatarView: View {
    public var shape: PopularShape
    public var scale: BodyAvatarScale
    public var layers: [BodyAvatarLayer]
    public var fitCaption: String?
    public var showsFitCaption: Bool
    public var enablesOrbit: Bool

    @State private var yaw: BodyAvatarYaw = .deg0
    @State private var dragOriginYaw: BodyAvatarYaw?

    public init(
        shape: PopularShape = .rectangle,
        scale: BodyAvatarScale = BodyAvatarScale(widthScale: 1, hipScale: 1, waistScale: 1),
        layers: [BodyAvatarLayer] = [],
        fitCaption: String? = nil,
        showsFitCaption: Bool = true,
        enablesOrbit: Bool = true,
        initialYaw: BodyAvatarYaw = .deg0
    ) {
        self.shape = shape
        self.scale = scale
        self.layers = layers
        self.fitCaption = fitCaption
        self.showsFitCaption = showsFitCaption
        self.enablesOrbit = enablesOrbit
        _yaw = State(initialValue: initialYaw)
    }

    /// 从测量 + 单品槽位构建。
    public static func from(
        measurements: BodyMeasurements?,
        slotAssets: [BodyAvatarSlot: String] = [:],
        fitCaption: String? = nil,
        enablesOrbit: Bool = true
    ) -> BodyAvatarView {
        let shape = BodyAvatarComposer.resolveShape(from: measurements)
        let scale = measurements.map { BodyAvatarScaler.scale(from: $0) }
            ?? BodyAvatarScale(widthScale: 1, hipScale: 1, waistScale: 1)
        return BodyAvatarView(
            shape: shape,
            scale: scale,
            layers: BodyAvatarComposer.layers(slots: slotAssets),
            fitCaption: fitCaption,
            enablesOrbit: enablesOrbit)
    }

    public var body: some View {
        VStack(spacing: 10) {
            modelCanvas
                .gesture(enablesOrbit ? orbitDrag : nil)
                .accessibilityHint(enablesOrbit ? "Drag left or right to rotate view" : "")

            if enablesOrbit {
                orbitChrome
            }

            if showsFitCaption {
                captionBlock
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Body shape \(shape.rawValue), \(yaw.shortLabel) view")
        .onChange(of: shape) { _, _ in
            // 换体型时回到正面（瞬时，无动画）
            yaw = .deg0
        }
    }

    // MARK: - Canvas

    private var modelCanvas: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let displayWidth = w * min(max(scale.widthScale, 0.92), 1.08) * 0.94
            ZStack {
                Group {
                    if let img = croquisImage(for: yaw) {
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
                // 叠衣锚点按正面标定；仅正面显示槽位层
                if yaw == .deg0 {
                    ForEach(layers) { layer in
                        garmentLayer(layer, canvas: geo.size)
                    }
                }
            }
            .frame(width: w, height: geo.size.height)
            .clipped()
            // 禁止隐式动画：换帧瞬时
            .transaction { $0.animation = nil }
        }
        .aspectRatio(2 / 3, contentMode: .fit)
        .background(DS.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.radius))
    }

    private var orbitChrome: some View {
        VStack(spacing: 8) {
            // 8 点方位指示
            HStack(spacing: 6) {
                ForEach(BodyAvatarYaw.allCases, id: \.rawValue) { a in
                    Circle()
                        .fill(a == yaw ? DS.accent : DS.muted.opacity(0.35))
                        .frame(width: a == yaw ? 8 : 6, height: a == yaw ? 8 : 6)
                        .onTapGesture {
                            yaw = a
                        }
                        .accessibilityLabel(a.shortLabel)
                }
            }
            HStack {
                Button {
                    yaw = yaw.stepped(by: -1)
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2)
                        .foregroundStyle(DS.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Previous angle")

                Spacer()
                Text("360° · \(yaw.shortLabel) · \(yaw.rawValue)°")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DS.muted)
                Spacer()

                Button {
                    yaw = yaw.stepped(by: 1)
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(DS.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Next angle")
            }
            .padding(.horizontal, 4)

            Text("Swipe or tap dots · static frames, no spin animation")
                .font(.caption2)
                .foregroundStyle(DS.muted)
        }
    }

    private var captionBlock: some View {
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

    private var displayShapeTitle: String {
        switch shape {
        case .hourglass: return "Hourglass"
        case .pear: return "Pear"
        case .apple: return "Apple"
        case .rectangle: return "Rectangle"
        case .invertedTriangle: return "Inverted triangle"
        }
    }

    /// 水平拖拽：约每 36pt 切一档（8 档覆盖 360°）。
    private var orbitDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                if dragOriginYaw == nil { dragOriginYaw = yaw }
                let origin = dragOriginYaw ?? yaw
                let stepPx: CGFloat = 36
                let steps = Int((value.translation.width / stepPx).rounded())
                // 向右拖 → 看左侧（角度减小）；向左拖 → 向右转
                let next = origin.stepped(by: -steps)
                if next != yaw { yaw = next }
            }
            .onEnded { _ in
                dragOriginYaw = nil
            }
    }

    // MARK: - Images

    private func croquisImage(for yaw: BodyAvatarYaw) -> Image? {
        // 精确角 → 相邻 45° → 主方位(0/90/180/270) → 正面 / 旧名
        var tried: [BodyAvatarYaw] = [yaw]
        tried.append(yaw.stepped(by: 1))
        tried.append(yaw.stepped(by: -1))
        let cardinals: [BodyAvatarYaw] = [.deg0, .deg90, .deg180, .deg270]
        tried.append(contentsOf: cardinals.sorted {
            abs($0.rawValue - yaw.rawValue) < abs($1.rawValue - yaw.rawValue)
                || (abs($0.rawValue - yaw.rawValue) == abs($1.rawValue - yaw.rawValue) && $0.rawValue < $1.rawValue)
        })
        var seen = Set<Int>()
        for y in tried where seen.insert(y.rawValue).inserted {
            let name = BodyAvatarAsset.croquisName(for: shape, yaw: y)
            if let img = Self.bundleImage(named: name) { return img }
        }
        return Self.bundleImage(named: BodyAvatarAsset.legacyFrontName(for: shape))
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

    public static func bundleImage(named name: String) -> Image? {
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

/// 无 PNG 时的程序化剪影。
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
