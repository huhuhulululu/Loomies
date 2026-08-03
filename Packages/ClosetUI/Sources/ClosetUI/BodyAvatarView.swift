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
    /// 保留参数以兼容调用方；实际走 `BodyMorphRaster` 像素行变形（非多层 mask）。
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
        morphStripCount: Int = 96
    ) {
        self.shape = shape
        self.morph = morph
        self.layers = layers
        self.fitCaption = fitCaption
        self.showsFitCaption = showsFitCaption
        self.enablesOrbit = enablesOrbit
        self.morphStripCount = max(32, morphStripCount)
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
                if let name = croquisAssetName(for: yaw) {
                    // 单次 CG 栅格变形；中性 morph 直出原图，避免 48 层 mask 碎裂
                    BodyMorphImageView(assetName: name, morph: morph, logicalWidth: size.width)
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
            // 不用 drawingGroup：会再栅格一次，加重「压缩破碎」感；warp 已是位图
            .transaction { $0.animation = nil }
        }
        .aspectRatio(2 / 3, contentMode: .fit)
        // 与 croquis 统一棚灰（≈ RGB 158）对齐，避免画布/图底色差
        .background(Color(red: 158 / 255, green: 158 / 255, blue: 158 / 255))
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

    private func croquisAssetName(for yaw: BodyAvatarYaw) -> String? {
        var tried: [BodyAvatarYaw] = [yaw, yaw.stepped(by: 1), yaw.stepped(by: -1)]
        let cardinals: [BodyAvatarYaw] = [.deg0, .deg90, .deg180, .deg270]
        tried.append(contentsOf: cardinals.sorted {
            abs($0.rawValue - yaw.rawValue) < abs($1.rawValue - yaw.rawValue)
        })
        var seen = Set<Int>()
        for y in tried where seen.insert(y.rawValue).inserted {
            let name = BodyAvatarAsset.croquisName(for: shape, yaw: y)
            if Self.bundleResourceURL(named: name) != nil { return name }
        }
        let legacy = BodyAvatarAsset.legacyFrontName(for: shape)
        return Self.bundleResourceURL(named: legacy) != nil ? legacy : nil
    }

    private func croquisImage(for yaw: BodyAvatarYaw) -> Image? {
        guard let name = croquisAssetName(for: yaw) else { return nil }
        return Self.bundleImage(named: name)
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

    public static func bundleResourceURL(named name: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "BodyAvatar")
            ?? Bundle.module.url(forResource: name, withExtension: "png")
    }

    public static func bundleImage(named name: String) -> Image? {
        guard let url = bundleResourceURL(named: name),
              let data = try? Data(contentsOf: url) else { return nil }
        #if canImport(UIKit)
        if let ui = UIImage(data: data, scale: 1) { return Image(uiImage: ui) }
        #elseif canImport(AppKit)
        if let ns = NSImage(data: data) { return Image(nsImage: ns) }
        #endif
        return nil
    }

    #if canImport(UIKit)
    /// 原图 UIImage（scale=1，避免系统二次压缩缩放）。
    public static func bundleUIImage(named name: String) -> UIImage? {
        guard let url = bundleResourceURL(named: name),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data, scale: 1)
    }
    #endif

    #if canImport(AppKit) && !os(iOS)
    public static func bundleNSImage(named name: String) -> NSImage? {
        guard let url = bundleResourceURL(named: name),
              let data = try? Data(contentsOf: url) else { return nil }
        return NSImage(data: data)
    }
    #endif
}

// MARK: - Legacy strip view (保留类型名，委托栅格)

/// 旧 API 名；内部已改为 `BodyMorphImageView` 路径时不应再叠 48 层 mask。
struct BodyMorphStripView: View {
    var image: Image
    var morph: BodyMorphParams
    var stripCount: Int

    var body: some View {
        // 无 asset 名时的降级：仅整体 scale，绝不多层 mask
        image
            .resizable()
            .interpolation(.high)
            .scaleEffect(
                x: CGFloat(morph.clamped().legacyScale.widthScale),
                y: CGFloat(morph.clamped().height),
                anchor: .center)
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
