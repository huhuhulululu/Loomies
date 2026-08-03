import SwiftUI
import ClosetCore
import ClosetModel
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit) && !os(iOS)
import AppKit
#endif

/// 真人站姿 + **360° 切帧** + **连续 BodyMorph 分条变形**（类游戏滑杆塑形，非 SMPL / 非 VTON）。
public struct BodyAvatarView: View {
    public var shape: PopularShape
    public var morph: BodyMorphParams
    public var layers: [BodyAvatarLayer]
    public var fitCaption: String?
    public var showsFitCaption: Bool
    public var enablesOrbit: Bool
    /// 分条数：越大越平滑，成本略升
    public var morphStripCount: Int

    @State private var yaw: BodyAvatarYaw = .deg0
    @State private var dragOriginYaw: BodyAvatarYaw?

    public init(
        shape: PopularShape = .rectangle,
        morph: BodyMorphParams = .neutral,
        layers: [BodyAvatarLayer] = [],
        fitCaption: String? = nil,
        showsFitCaption: Bool = true,
        enablesOrbit: Bool = true,
        initialYaw: BodyAvatarYaw = .deg0,
        morphStripCount: Int = 48
    ) {
        self.shape = shape
        self.morph = morph
        self.layers = layers
        self.fitCaption = fitCaption
        self.showsFitCaption = showsFitCaption
        self.enablesOrbit = enablesOrbit
        self.morphStripCount = max(16, morphStripCount)
        _yaw = State(initialValue: initialYaw)
    }

    /// 兼容旧 API：整体 scale → morph
    public init(
        shape: PopularShape = .rectangle,
        scale: BodyAvatarScale,
        layers: [BodyAvatarLayer] = [],
        fitCaption: String? = nil,
        showsFitCaption: Bool = true,
        enablesOrbit: Bool = true,
        initialYaw: BodyAvatarYaw = .deg0
    ) {
        self.init(
            shape: shape,
            morph: BodyMorphParams.from(legacy: scale),
            layers: layers,
            fitCaption: fitCaption,
            showsFitCaption: showsFitCaption,
            enablesOrbit: enablesOrbit,
            initialYaw: initialYaw)
    }

    public static func from(
        measurements: BodyMeasurements?,
        shape: PopularShape? = nil,
        fineTune: BodyMorphParams = .neutral,
        slotAssets: [BodyAvatarSlot: String] = [:],
        fitCaption: String? = nil,
        enablesOrbit: Bool = true
    ) -> BodyAvatarView {
        let resolvedShape = shape
            ?? BodyAvatarComposer.resolveShape(from: measurements)
        let morph = BodyMorphParams.resolve(
            measurements: measurements,
            shape: resolvedShape,
            fineTune: fineTune)
        return BodyAvatarView(
            shape: resolvedShape,
            morph: morph,
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
            yaw = .deg0
        }
    }

    // MARK: - Canvas

    private var modelCanvas: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                if croquisImage(for: yaw) != nil {
                    BodyMorphStripView(
                        image: croquisImage(for: yaw)!,
                        morph: morph,
                        stripCount: morphStripCount)
                } else {
                    PlaceholderCroquis(shape: shape)
                        .scaleEffect(x: morph.legacyScale.widthScale, y: morph.height, anchor: .center)
                }

                if yaw == .deg0 {
                    ForEach(layers) { layer in
                        garmentLayer(layer, canvas: size)
                    }
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .transaction { $0.animation = nil }
        }
        .aspectRatio(2 / 3, contentMode: .fit)
        .background(DS.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.radius))
    }

    private var orbitChrome: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(BodyAvatarYaw.allCases, id: \.rawValue) { a in
                    Circle()
                        .fill(a == yaw ? DS.accent : DS.muted.opacity(0.35))
                        .frame(width: a == yaw ? 8 : 6, height: a == yaw ? 8 : 6)
                        .onTapGesture { yaw = a }
                        .accessibilityLabel(a.shortLabel)
                }
            }
            HStack {
                Button { yaw = yaw.stepped(by: -1) } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2).foregroundStyle(DS.accent)
                }
                .buttonStyle(.plain)
                Spacer()
                Text("360° · \(yaw.shortLabel) · \(yaw.rawValue)°")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DS.muted)
                Spacer()
                Button { yaw = yaw.stepped(by: 1) } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2).foregroundStyle(DS.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            Text("Morph C\(fmt(morph.chest)) W\(fmt(morph.waist)) H\(fmt(morph.hip)) · drag to orbit")
                .font(.caption2)
                .foregroundStyle(DS.muted)
        }
    }

    private func fmt(_ v: Double) -> String {
        String(format: "%.2f", v)
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
                Text("Continuous proportion guide — not a photo try-on.")
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

    private var orbitDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                if dragOriginYaw == nil { dragOriginYaw = yaw }
                let origin = dragOriginYaw ?? yaw
                let steps = Int((value.translation.width / 36).rounded())
                let next = origin.stepped(by: -steps)
                if next != yaw { yaw = next }
            }
            .onEnded { _ in dragOriginYaw = nil }
    }

    private func croquisImage(for yaw: BodyAvatarYaw) -> Image? {
        var tried: [BodyAvatarYaw] = [yaw, yaw.stepped(by: 1), yaw.stepped(by: -1)]
        let cardinals: [BodyAvatarYaw] = [.deg0, .deg90, .deg180, .deg270]
        tried.append(contentsOf: cardinals.sorted {
            abs($0.rawValue - yaw.rawValue) < abs($1.rawValue - yaw.rawValue)
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
        // 槽位框随对应 band 水平缩放，避免叠衣与体型脱节
        let midY = f.y + f.height / 2
        let sx = morph.horizontalScale(normalizedY: midY)
        let rect = CGRect(
            x: 0.5 * canvas.width + (f.x - 0.5) * canvas.width * sx,
            y: f.y * canvas.height * morph.height,
            width: f.width * canvas.width * sx,
            height: f.height * canvas.height * morph.height)
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

// MARK: - Strip morph renderer

/// 将 croquis 切成水平条，按 `BodyMorphParams` 剖面做 X 向缩放（脸附近近 1.0）。
struct BodyMorphStripView: View {
    var image: Image
    var morph: BodyMorphParams
    var stripCount: Int

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let n = stripCount
            let stripH = h / CGFloat(n)
            let heightS = CGFloat(morph.clamped().height)
            ZStack(alignment: .top) {
                ForEach(0..<n, id: \.self) { i in
                    let midY = (CGFloat(i) + 0.5) / CGFloat(n)
                    let sx = CGFloat(morph.horizontalScale(normalizedY: Double(midY)))
                    image
                        .resizable()
                        .interpolation(.high)
                        .frame(width: w, height: h)
                        // 只露出第 i 条
                        .mask(
                            VStack(spacing: 0) {
                                Color.clear.frame(height: stripH * CGFloat(i))
                                Color.white.frame(height: stripH + 0.5)
                                Spacer(minLength: 0)
                            }
                        )
                        .scaleEffect(x: sx, y: heightS, anchor: .center)
                        // 高度缩放后条带仍对齐中心
                        .offset(y: (heightS - 1) * h * (midY - 0.5) * 0.15)
                }
            }
            .frame(width: w, height: h)
            .clipped()
        }
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
