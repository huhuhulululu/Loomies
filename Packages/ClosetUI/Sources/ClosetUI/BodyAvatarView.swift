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
/// Croquis 为透明 PNG；`backdrop` 在底层叠场合场景；**景深视差**（效果优先，非 GIF）。
public struct BodyAvatarView: View {
    public var shape: PopularShape
    public var morph: BodyMorphParams
    public var layers: [BodyAvatarLayer]
    public var fitCaption: String?
    public var showsFitCaption: Bool
    public var enablesOrbit: Bool
    /// Today 英雄区：只保留点阵 + 轻提示，隐藏 morph 调试字
    public var compactChrome: Bool
    /// 保留参数以兼容调用方；实际走 `BodyMorphRaster` 像素行变形（非多层 mask）。
    public var morphStripCount: Int
    /// 场合/棚灰背景（UI 层，可换）
    public var backdrop: AvatarBackdrop
    /// 景深立体强度；`nil` = compactChrome → cinematic，否则 subtle
    public var depthIntensity: DepthParallaxIntensity?

    @State private var yaw: BodyAvatarYaw = .deg0
    @State private var dragOriginYaw: BodyAvatarYaw?
    @StateObject private var depthMotion = DepthParallaxMotion()
    /// 拖拽附加的视差（与 360 水平切帧并存）
    @State private var dragParallax = DepthParallaxSample()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var resolvedDepth: DepthParallaxIntensity {
        let base = depthIntensity ?? (compactChrome ? .cinematic : .subtle)
        // 减弱动态：仍保留静态分层，关掉 ambient/陀螺驱动感
        if reduceMotion, base != .off { return .subtle }
        return base
    }

    public init(
        shape: PopularShape = .rectangle,
        morph: BodyMorphParams = .neutral,
        layers: [BodyAvatarLayer] = [],
        fitCaption: String? = nil,
        showsFitCaption: Bool = true,
        enablesOrbit: Bool = true,
        compactChrome: Bool = false,
        initialYaw: BodyAvatarYaw = .deg0,
        morphStripCount: Int = 96,
        backdrop: AvatarBackdrop = .studio,
        depthIntensity: DepthParallaxIntensity? = nil
    ) {
        self.shape = shape
        self.morph = morph
        self.layers = layers
        self.fitCaption = fitCaption
        self.showsFitCaption = showsFitCaption
        self.enablesOrbit = enablesOrbit
        self.compactChrome = compactChrome
        self.morphStripCount = max(32, morphStripCount)
        self.backdrop = backdrop
        self.depthIntensity = depthIntensity
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
        initialYaw: BodyAvatarYaw = .deg0,
        backdrop: AvatarBackdrop = .studio
    ) {
        self.init(
            shape: shape,
            morph: BodyMorphParams.from(legacy: scale),
            layers: layers,
            fitCaption: fitCaption,
            showsFitCaption: showsFitCaption,
            enablesOrbit: enablesOrbit,
            initialYaw: initialYaw,
            backdrop: backdrop)
    }

    public static func from(
        measurements: BodyMeasurements?,
        shape: PopularShape? = nil,
        fineTune: BodyMorphParams = .neutral,
        slotAssets: [BodyAvatarSlot: String] = [:],
        fitCaption: String? = nil,
        enablesOrbit: Bool = true,
        backdrop: AvatarBackdrop = .studio
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
            enablesOrbit: enablesOrbit,
            backdrop: backdrop)
    }

    public var body: some View {
        VStack(spacing: 10) {
            modelCanvas
                .gesture(canvasDrag)
                .accessibilityHint(
                    enablesOrbit
                        ? "Drag left or right to rotate; tilt device for depth"
                        : "Tilt device for depth parallax")

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
        // 换 look 时回正面（叠衣只在 yaw0）
        .onChange(of: layers.map(\.id).joined(separator: ",")) { _, _ in
            yaw = .deg0
        }
        .onAppear {
            // 资源抛光后清 morph 缓存，避免旧白边帧
            BodyMorphImageCache.shared.clear()
            if resolvedDepth != .off, !reduceMotion { depthMotion.start() }
        }
        .onDisappear { depthMotion.stop() }
        .onChange(of: reduceMotion) { _, reduced in
            if reduced { depthMotion.stop() }
            else if resolvedDepth != .off { depthMotion.start() }
        }
    }

    // MARK: - Canvas

    private var modelCanvas: some View {
        let tick: Double = (resolvedDepth == .off || reduceMotion) ? 120 : (1.0 / 30.0)
        return TimelineView(.animation(minimumInterval: tick)) { timeline in
            let sample = composedParallax(at: timeline.date)
            GeometryReader { geo in
                let size = geo.size
                let bgOff = DepthParallaxLayout.backgroundOffset(sample, intensity: resolvedDepth)
                let figOff = DepthParallaxLayout.figureOffset(sample, intensity: resolvedDepth)
                let fogOff = DepthParallaxLayout.foregroundOffset(sample, intensity: resolvedDepth)
                let tiltScale: CGFloat = reduceMotion ? 0 : (resolvedDepth == .cinematic ? 1 : 0.45)

                ZStack {
                    // Far：位图场合
                    AvatarBackdropView(
                        backdrop: backdrop,
                        depthBlur: resolvedDepth.backgroundBlur,
                        parallaxScale: resolvedDepth.backdropScale,
                        lightShift: CGSize(width: sample.x, height: sample.y))
                    .frame(width: size.width, height: size.height)
                    .offset(bgOff)

                    // Mid：脚底影贴地 + 人体 + 叠衣（反射极弱，避免脚底假影）
                    ZStack {
                        AvatarContactShadow()
                            .frame(width: size.width * 0.36, height: size.height * 0.028)
                            .offset(y: size.height * 0.43)
                            .opacity(resolvedDepth == .off ? 0.32 : 0.48)

                        figureStack(canvas: size)
                            .shadow(
                                color: Color.black.opacity(resolvedDepth == .cinematic ? 0.14 : 0.08),
                                radius: resolvedDepth == .cinematic ? 6 : 3,
                                y: 2)
                    }
                    .offset(figOff)
                    .scaleEffect(1 + 0.014 * sample.y * tiltScale)
                    .rotation3DEffect(
                        .degrees(Double(sample.x) * 3.2 * Double(tiltScale)),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .center,
                        perspective: 0.6)
                    .rotation3DEffect(
                        .degrees(Double(sample.y) * -1.6 * Double(tiltScale)),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .center,
                        perspective: 0.6)

                    AvatarDepthFog(intensity: resolvedDepth)
                        .frame(width: size.width, height: size.height)
                        .offset(fogOff)
                        .allowsHitTesting(false)
                }
                .frame(width: size.width, height: size.height)
                .clipped()
                .transaction { $0.animation = nil }
            }
        }
        .aspectRatio(2 / 3, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: compactChrome ? DS.radiusLg : DS.radius, style: .continuous))
        .shadow(
            color: Color.black.opacity(compactChrome ? 0.12 : 0.07),
            radius: compactChrome ? 16 : 9,
            y: compactChrome ? 8 : 5)
        .accessibilityValue(backdrop.accessibilityLabel + ", depth " + resolvedDepth.rawValue)
    }

    private func composedParallax(at date: Date) -> DepthParallaxSample {
        let intensity = resolvedDepth
        guard intensity != .off else { return DepthParallaxSample() }
        if reduceMotion {
            // 仅保留拖拽视差，无 ambient / 姿态
            return DepthParallaxSample(
                x: dragParallax.x * 0.5,
                y: dragParallax.y * 0.5)
        }
        let ambient = DepthParallaxSample.ambient(
            time: date.timeIntervalSinceReferenceDate,
            amplitude: intensity.ambientAmplitude * 0.75)
        let motionWeight: CGFloat = 0.9
        let dragWeight: CGFloat = 0.85
        let ambientWeight: CGFloat = intensity == .cinematic ? 0.5 : 0.35
        return DepthParallaxSample(
            x: depthMotion.attitude.x * motionWeight
                + dragParallax.x * dragWeight
                + ambient.x * ambientWeight,
            y: depthMotion.attitude.y * motionWeight
                + dragParallax.y * dragWeight
                + ambient.y * ambientWeight)
    }

    @ViewBuilder
    private func figureStack(canvas size: CGSize) -> some View {
        ZStack {
            if let name = croquisAssetName(for: yaw) {
                BodyMorphImageView(assetName: name, morph: morph, logicalWidth: size.width)
            } else {
                PlaceholderCroquis(shape: shape)
                    .scaleEffect(
                        x: morph.legacyScale.widthScale,
                        y: morph.height,
                        anchor: .center)
            }
            if yaw == .deg0 {
                ForEach(layers) { layer in
                    garmentLayer(layer, canvas: size)
                }
            }
        }
    }



    private var orbitChrome: some View {
        VStack(spacing: compactChrome ? 6 : 8) {
            HStack(spacing: 6) {
                ForEach(BodyAvatarYaw.allCases, id: \.rawValue) { a in
                    Circle()
                        .fill(a == yaw ? DS.accent : DS.muted.opacity(0.28))
                        .frame(width: a == yaw ? 7 : 5, height: a == yaw ? 7 : 5)
                        .onTapGesture { yaw = a }
                        .accessibilityLabel(a.shortLabel)
                }
            }
            if compactChrome {
                Text(yaw == .deg0 ? "Drag to turn · front shows layers" : "\(yaw.shortLabel) · layers on front only")
                    .font(.caption2)
                    .foregroundStyle(DS.muted)
            } else {
                HStack {
                    Button { yaw = yaw.stepped(by: -1) } label: {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.title2).foregroundStyle(DS.accent)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text("360° · \(yaw.shortLabel)")
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
            }
        }
    }

    private var captionBlock: some View {
        VStack(spacing: 4) {
            if !compactChrome {
                Text(displayShapeTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.ink)
            }
            if let fitCaption, !fitCaption.isEmpty {
                Text(fitCaption)
                    .font(compactChrome ? .subheadline.weight(.medium) : .caption)
                    .foregroundStyle(compactChrome ? DS.ink : DS.muted)
                    .multilineTextAlignment(.center)
                    .lineLimit(compactChrome ? 2 : 4)
            } else if !compactChrome {
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

    private var canvasDrag: some Gesture {
        DragGesture(minimumDistance: enablesOrbit ? 8 : 4)
            .onChanged { value in
                if enablesOrbit {
                    if dragOriginYaw == nil { dragOriginYaw = yaw }
                    let origin = dragOriginYaw ?? yaw
                    let steps = Int((value.translation.width / 36).rounded())
                    let next = origin.stepped(by: -steps)
                    if next != yaw { yaw = next }
                }
                // 视差：垂直主导深度，水平微调
                let sx: CGFloat = enablesOrbit ? 120 : 100
                let sy: CGFloat = enablesOrbit ? 140 : 120
                dragParallax = DepthParallaxSample(
                    x: value.translation.width / sx,
                    y: value.translation.height / sy)
            }
            .onEnded { _ in
                dragOriginYaw = nil
                withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                    dragParallax = DepthParallaxSample()
                }
            }
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
        // 槽位框随对应 band 水平缩放；外套略放宽贴肩
        let midY = f.y + f.height / 2
        let sx = morph.horizontalScale(normalizedY: midY)
        let pad: CGFloat = layer.slot == .outerwear ? 1.06 : (layer.slot == .top ? 1.02 : 1.0)
        let w = f.width * canvas.width * sx * pad
        let h = f.height * canvas.height * morph.height
        let cx = 0.5 * canvas.width + (f.x + f.width / 2 - 0.5) * canvas.width * sx
        // 高度 morph 时保持锚点区相对 croquis
        let cy = (f.y + f.height / 2) * canvas.height * morph.height
            + (morph.height - 1) * canvas.height * 0.02
        let rect = CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
        Group {
            if let img = Self.layerImage(layer) {
                img
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                slotPlaceholder(layer.slot)
            }
        }
        // 上装/裙顶对齐肩线，鞋贴底，下装略靠上（腰）
        .frame(width: rect.width, height: rect.height, alignment: garmentAlignment(layer.slot))
        .position(x: rect.midX, y: rect.midY)
        .zIndex(Double(layer.zIndex))
        .opacity(layer.hasVisual ? 0.96 : 0.72)
        // 不做白描边阴影，避免叠衣出现纸边
    }

    private func garmentAlignment(_ slot: BodyAvatarSlot) -> Alignment {
        switch slot {
        case .top, .outerwear, .dress: return .top
        case .bottom: return .top
        case .shoes: return .bottom
        }
    }

    /// 本地入库图优先，其次 bundle / UIImage named。
    public static func layerImage(_ layer: BodyAvatarLayer) -> Image? {
        if let rel = layer.localRelativePath,
           let data = ItemImageStore.loadData(relativePath: rel) {
            #if canImport(UIKit)
            if let ui = UIImage(data: data) { return Image(uiImage: ui) }
            #elseif canImport(AppKit) && !os(iOS)
            if let ns = NSImage(data: data) { return Image(nsImage: ns) }
            #endif
        }
        if let name = layer.imageAssetName, let img = bundleImage(named: name) {
            return img
        }
        if let name = layer.imageAssetName {
            #if canImport(UIKit)
            if let ui = UIImage(named: name) { return Image(uiImage: ui) }
            #endif
        }
        return nil
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
