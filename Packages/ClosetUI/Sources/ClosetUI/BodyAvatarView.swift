import SwiftUI
import ClosetCore
import ClosetModel
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit) && !os(iOS)
import AppKit
#endif

/// 人体表达层：**真实写实真人照片** catalog basewear 底座（D64：♀ pasties+thong / ♂ thong）。
/// 主路径：认证 photoreal + BodyMorph + 多角切帧；缺侧角时正面软转，不跳程序化栅格。
/// `usesMannequin3D` 仅 interim 调试，**不得**当最终产品视觉。
/// 见 `NudeBodyBaseSpec`。`backdrop` 在底层；可选景深。
public struct BodyAvatarView: View {
    public var shape: PopularShape
    public var morph: BodyMorphParams
    public var layers: [BodyAvatarLayer]
    public var fitCaption: String?
    public var showsFitCaption: Bool
    public var enablesOrbit: Bool
    /// Today 英雄区：只保留点阵 + 轻提示，隐藏 morph 调试字
    public var compactChrome: Bool
    /// 保留参数以兼容调用方（旧分条 morph 路径）。
    public var morphStripCount: Int
    /// 场合/棚灰背景（UI 层，可换）
    public var backdrop: AvatarBackdrop
    /// 景深立体强度；`nil` = compactChrome → cinematic，否则 subtle
    public var depthIntensity: DepthParallaxIntensity?
    /// 展示性别底座（男性可扩；默认女）
    public var bodySex: AvatarBodySex
    /// 多人种/表型
    public var bodyPhenotype: AvatarBodyPhenotype
    /// `true` = 3D 网格模拟（interim only）；**默认 false** — 真人人照片路径
    public var usesMannequin3D: Bool

    @State private var yaw: BodyAvatarYaw = .deg0
    /// 连续偏航（度）；3D 真旋转 + 照片路径侧角叠衣淡出。离散 yaw 仅作切帧/chrome。
    @State private var yawDegrees: Double = 0
    @State private var dragOriginDegrees: Double?
    @StateObject private var depthMotion = DepthParallaxMotion()
    /// onChange(reduceMotion) 的可见性守卫：离屏视图树不得重启传感器。
    @State private var isOnScreen = false
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
        depthIntensity: DepthParallaxIntensity? = nil,
        bodySex: AvatarBodySex = .female,
        bodyPhenotype: AvatarBodyPhenotype = .eastAsian,
        /// 默认 **false**：真人照片路径。true 仅 interim 网格模拟。
        usesMannequin3D: Bool = false
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
        self.bodySex = bodySex
        self.bodyPhenotype = bodyPhenotype
        // 死要求：最终不得以网格模拟为主；未认证写实前也默认照片路径
        // （认证前用 FullNudeBodyRaster 占位，仍标 interim）
        self.usesMannequin3D = usesMannequin3D
            && NudeBodyBaseSpec.allowsMeshOrSimulationAsFinalVisual
        _yaw = State(initialValue: initialYaw)
        _yawDegrees = State(initialValue: Double(initialYaw.rawValue))
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
        backdrop: AvatarBackdrop = .studio,
        bodySex: AvatarBodySex = .female,
        bodyPhenotype: AvatarBodyPhenotype = .eastAsian
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
            backdrop: backdrop,
            bodySex: bodySex,
            bodyPhenotype: bodyPhenotype,
            usesMannequin3D: false)
    }

    public var body: some View {
        VStack(spacing: 10) {
            modelCanvas
                .gesture(canvasDrag)
                .accessibilityHint(
                    enablesOrbit
                        ? "Swipe up or down with one finger to rotate; tilt device for depth"
                        : "Tilt device for depth parallax")

            if enablesOrbit {
                orbitChrome
            }

            if showsFitCaption {
                captionBlock
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Self.heroAccessibilityLabel(
                yawLabel: Self.orbitAccessibilityLabel(
                    sexTitle: bodySex.displayTitle,
                    shapeRaw: shape.rawValue,
                    yawLabel: yaw.shortLabel,
                    isSoftHold: isPhotorealSoftHold),
                fitCaption: showsFitCaption ? fitCaption : nil))
        // A11Y: .combine swallows orbit chevrons/dots; give VO an executable
        // rotate path (one-finger swipe up/down) that mirrors the chevrons.
        .accessibilityValue(
            enablesOrbit
                ? Self.orbitAccessibilityLabel(
                    sexTitle: bodySex.displayTitle,
                    shapeRaw: shape.rawValue,
                    yawLabel: yaw.shortLabel,
                    isSoftHold: isPhotorealSoftHold)
                : "")
        .accessibilityAdjustableAction { direction in
            guard enablesOrbit else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                snapYaw(to: yaw.stepped(
                    by: Self.orbitAdjustableStep(increment: direction == .increment)))
            }
        }
        .onChange(of: shape) { _, _ in
            snapYaw(to: .deg0)
        }
        // 换 look 时回正面（叠衣只在正面附近）
        .onChange(of: layers.map(\.id).joined(separator: ",")) { _, _ in
            snapYaw(to: .deg0)
        }
        .onAppear {
            // Cache key is versioned (v3); do NOT clear on every appear —
            // hero + Other looks + Favorites would thrash warp and feel janky.
            isOnScreen = true
            if resolvedDepth != .off, !reduceMotion { depthMotion.start() }
        }
        .onDisappear {
            isOnScreen = false
            depthMotion.stop()
        }
        .onChange(of: reduceMotion) { _, reduced in
            // 可见性守卫：TabView 保留离屏视图树，disappear 后收到 reduceMotion
            // 变化不得重启传感器（否则无 onDisappear 配对，30Hz 永转耗电）。
            if reduced { depthMotion.stop() }
            else if isOnScreen, resolvedDepth != .off { depthMotion.start() }
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
                    // Far：位图场合（.id 仅换底，保留 yaw/morph 状态）
                    AvatarBackdropView(
                        backdrop: backdrop,
                        depthBlur: resolvedDepth.backgroundBlur,
                        parallaxScale: resolvedDepth.backdropScale,
                        lightShift: CGSize(width: sample.x, height: sample.y))
                    .id(backdrop)
                    .frame(width: size.width, height: size.height)
                    .offset(bgOff)
                    .transition(.opacity)

                    // Mid：脚底影贴地（随 morph）+ 人体 + 叠衣
                    ZStack {
                        let shadowSize = AvatarContactShadowLayout.size(canvas: size, morph: morph)
                        AvatarContactShadow(phenotype: bodyPhenotype)
                            .frame(width: shadowSize.width, height: shadowSize.height)
                            .offset(y: AvatarContactShadowLayout.offsetY(
                                canvasHeight: size.height, morph: morph))
                            .opacity(resolvedDepth == .off ? 0.32 : 0.48)

                        figureStack(canvas: size)
                            .shadow(
                                color: Color.black.opacity(resolvedDepth == .cinematic ? 0.14 : 0.08),
                                radius: resolvedDepth == .cinematic ? 6 : 3,
                                y: 2)
                    }
                    .offset(figOff)
                    // 景深仅平移/微倾；过大 3D 会让乳贴看起来「脱离」躯干
                    .scaleEffect(1 + 0.008 * sample.y * tiltScale)
                    .rotation3DEffect(
                        .degrees(Double(sample.x) * 1.6 * Double(tiltScale)),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .center,
                        perspective: 0.75)
                    .rotation3DEffect(
                        .degrees(Double(sample.y) * -0.8 * Double(tiltScale)),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .center,
                        perspective: 0.75)

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
        // 主路径 = 认证 catalog 真人照片；网格永不作最终态。
        // 有专用 yaw 帧 → 真切帧；仅有正面 → 软转 hold；都无 → interim 栅格。
        let exactFrame = certifiedPhotorealFrameName()
        let frontHold = exactFrame == nil ? certifiedPhotorealFrontName() : nil
        let photoName = exactFrame ?? frontHold
        let simulatedYaw = frontHold != nil
        let garmentFade = MannequinGarmentVisibility.opacity(yawDegrees: yawDegrees)
        let bodyOpacity: Double = {
            if exactFrame != nil { return 1 }
            if simulatedYaw {
                // 缺侧角时仍可读，略压暗表示「非真侧帧」
                return max(0.72, 0.55 + 0.45 * garmentFade)
            }
            return 1
        }()
        let holdWidth = simulatedYaw ? FullNudeBodyRaster.yawWidthFactor(yaw) : 1
        let holdTurn = simulatedYaw && !reduceMotion
            ? Self.photoHoldTurnDegrees(yawDegrees) : 0
        // 真体型图命中时旁路 shape preset warp（照片已编码体型，双重效果会变形）
        let effectiveMorph = (photoName.map(BodyAvatarAsset.photorealNameCarriesShape) ?? false)
            ? morph.removingShapePreset(shape) : morph
        ZStack {
            if let name = photoName {
                BodyMorphImageView(assetName: name, morph: effectiveMorph, logicalWidth: size.width)
                    .colorMultiply(Self.photorealPhenotypeMultiply(
                        assetName: name, phenotype: bodyPhenotype))
                    .scaleEffect(x: holdWidth, y: 1, anchor: .center)
                    .rotation3DEffect(
                        .degrees(holdTurn),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .center,
                        perspective: 0.72)
                    .opacity(bodyOpacity)
            } else {
                // Interim only when catalog photoreal gate closed / assets missing
                FullNudeBodyImageView(
                    sex: bodySex,
                    phenotype: bodyPhenotype,
                    morph: morph,
                    shape: shape,
                    yaw: yaw,
                    logicalWidth: size.width)
                .frame(width: size.width, height: size.height)
            }
            // 叠衣仅正面附近；|yaw|≥55° 全隐时整组跳过（不付布局/阴影开销）。
            if garmentYawOpacity > 0 {
                ForEach(Self.onCanvasGarmentLayers(layers)) { layer in
                    garmentLayer(layer, canvas: size)
                        .opacity(garmentYawOpacity)
                        .scaleEffect(garmentYawOpacity > 0.5 ? 1 : 0.985, anchor: .center)
                        .allowsHitTesting(false)
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: yaw)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: yawDegrees)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.22),
            value: layers.map(\.id).joined(separator: ","))
    }

    /// 认证 catalog 真人多角帧（shape 专属 → phenotype×yaw → sex×yaw）；门控关闭或缺帧时 `nil`。
    private func certifiedPhotorealFrameName() -> String? {
        BodyAvatarAsset.resolvePhotorealFrameName(
            sex: bodySex,
            phenotype: bodyPhenotype,
            shape: shape,
            yaw: yaw,
            available: {
                NudeBodyBaseSpec.mayUsePhotorealFrontAsset(named: $0)
                    && Self.bundleResourceURL(named: $0) != nil
            })
    }

    /// 认证 catalog 正面（deg0 解析，shape 专属优先）；用于缺侧角时的 soft hold。
    private func certifiedPhotorealFrontName() -> String? {
        BodyAvatarAsset.resolvePhotorealFrameName(
            sex: bodySex,
            phenotype: bodyPhenotype,
            shape: shape,
            yaw: .deg0,
            available: {
                NudeBodyBaseSpec.mayUsePhotorealFrontAsset(named: $0)
                    && Self.bundleResourceURL(named: $0) != nil
            })
    }

    /// 缺专用 yaw 帧、正用本表型正面 soft-hold 时为 true（勿冒充真侧/背帧）。
    private var isPhotorealSoftHold: Bool {
        guard !usesMannequin3D else { return false }
        return certifiedPhotorealFrameName() == nil && certifiedPhotorealFrontName() != nil
    }

    /// 缺专用 yaw 帧时，用 sin 驱动的卡片翻转感（±48°），不冒充真侧视像素。
    private static func photoHoldTurnDegrees(_ yawDegrees: Double) -> Double {
        var y = yawDegrees.truncatingRemainder(dividingBy: 360)
        if y < 0 { y += 360 }
        return sin(y * .pi / 180) * 48
    }

    /// 通用 sex 帧（front / yaw###，无 phenotype token）缺表型专用贴图时 soft-tint。
    private static func photorealPhenotypeMultiply(
        assetName: String,
        phenotype: AvatarBodyPhenotype
    ) -> Color {
        let isGenericSexFrame =
            AvatarBodyPhenotype.isGenericPhotorealFrontName(assetName)
            || BodyAvatarYaw.allCases.contains {
                assetName == BodyAvatarAsset.photorealFrameName(sex: .female, yaw: $0)
                    || assetName == BodyAvatarAsset.photorealFrameName(sex: .male, yaw: $0)
            }
        guard isGenericSexFrame else { return Color.white }
        let m = phenotype.skinTintMultiplier(relativeTo: .eastAsian)
        return Color(red: min(1, m.r), green: min(1, m.g), blue: min(1, m.b))
    }

    /// 真人照片路径：正面附近叠衣；侧角软隐（无侧角衣物资产）。
    private var garmentYawOpacity: Double {
        MannequinGarmentVisibility.opacity(yawDegrees: yawDegrees)
    }

    private func snapYaw(to discrete: BodyAvatarYaw) {
        yaw = discrete
        yawDegrees = Double(discrete.rawValue)
    }

    private func setYawDegrees(_ degrees: Double) {
        var d = degrees.truncatingRemainder(dividingBy: 360)
        if d < 0 { d += 360 }
        yawDegrees = d
        yaw = Self.nearestDiscreteYaw(d)
    }

    private static func nearestDiscreteYaw(_ degrees: Double) -> BodyAvatarYaw {
        let all = BodyAvatarYaw.allCases
        return all.min(by: {
            angularDistance(Double($0.rawValue), degrees)
                < angularDistance(Double($1.rawValue), degrees)
        }) ?? .deg0
    }

    private static func angularDistance(_ a: Double, _ b: Double) -> Double {
        var d = abs(a - b).truncatingRemainder(dividingBy: 360)
        if d > 180 { d = 360 - d }
        return d
    }

    private var orbitChrome: some View {
        VStack(spacing: compactChrome ? 6 : 8) {
            HStack(spacing: 6) {
                ForEach(BodyAvatarYaw.allCases, id: \.rawValue) { a in
                    Circle()
                        .fill(a == yaw ? DS.accent : DS.muted.opacity(0.28))
                        .frame(width: a == yaw ? 7 : 5, height: a == yaw ? 7 : 5)
                        // A11Y: 5–7pt visual, but dots are the only discrete
                        // steppers in compactChrome — grow the tap target.
                        .frame(width: Self.orbitDotHitArea, height: Self.orbitDotHitArea)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                                snapYaw(to: a)
                            }
                        }
                        .accessibilityLabel(a.shortLabel)
                }
            }
            if compactChrome {
                // hasRenderableVisual: path-only / failed-decode layers are not dressed.
                // isSoftHold: missing dedicated yaw frame → front pixels, not a real side photo.
                Text(Self.compactOrbitHint(
                    hasLayers: layers.contains(where: Self.hasRenderableVisual),
                    garmentYawOpacity: garmentYawOpacity,
                    yawLabel: yaw.shortLabel,
                    isSoftHold: isPhotorealSoftHold))
                    .font(.caption2)
                    .foregroundStyle(DS.muted)
            } else {
                HStack {
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                            snapYaw(to: yaw.stepped(by: -1))
                        }
                    } label: {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.title2).foregroundStyle(DS.accent)
                            // A11Y: grow tap target to 44pt without changing the .title2 visual.
                            .frame(width: Self.orbitChevronHitArea, height: Self.orbitChevronHitArea)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Self.orbitStepAccessibilityLabel(direction: .previous))
                    Spacer()
                    Text(Self.orbitAngleCaption(
                        yawLabel: yaw.shortLabel,
                        yawDegrees: yawDegrees,
                        usesMannequin3D: usesMannequin3D,
                        isSoftHold: isPhotorealSoftHold))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(DS.muted)
                    Spacer()
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                            snapYaw(to: yaw.stepped(by: 1))
                        }
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.title2).foregroundStyle(DS.accent)
                            // A11Y: grow tap target to 44pt without changing the .title2 visual.
                            .frame(width: Self.orbitChevronHitArea, height: Self.orbitChevronHitArea)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Self.orbitStepAccessibilityLabel(direction: .next))
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
                if NudeBodyBaseSpec.isHardRequirementMet {
                    Text(NudeBodyBaseSpec.basewearDescription(for: bodySex))
                        .font(.caption2)
                        .foregroundStyle(DS.muted)
                        .multilineTextAlignment(.center)
                } else {
                    Text(NudeBodyBaseSpec.invariant)
                        .font(.caption2)
                        .foregroundStyle(DS.muted)
                    Text("Waiting for certified real-human catalog photos (♀ pasties+thong / ♂ thong).")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
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
                    if dragOriginDegrees == nil { dragOriginDegrees = yawDegrees }
                    let origin = dragOriginDegrees ?? yawDegrees
                    let next: Double
                    if usesMannequin3D {
                        // 连续旋转（写实 3D nude 底座）
                        next = origin - Double(value.translation.width) * 0.45
                    } else {
                        // 照片路径：连续 degrees → 叠衣侧角淡出平滑；离散 yaw 仍 nearest 切帧
                        // （旧逻辑每 36px/45° snapYaw，fade 阶梯跳变）
                        next = Self.photoOrbitYawDegrees(
                            originDegrees: origin,
                            translationWidth: Double(value.translation.width))
                    }
                    var t = Transaction()
                    t.animation = nil
                    withTransaction(t) { setYawDegrees(next) }
                }
                let sx: CGFloat = enablesOrbit ? 120 : 100
                let sy: CGFloat = enablesOrbit ? 140 : 120
                dragParallax = DepthParallaxSample(
                    x: value.translation.width / sx,
                    y: value.translation.height / sy)
            }
            .onEnded { _ in
                dragOriginDegrees = nil
                withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                    dragParallax = DepthParallaxSample()
                    // Photo path: spring continuous degrees onto nearest catalog 45° so
                    // chrome shortLabel and garment fade don't disagree mid-angle.
                    if !usesMannequin3D {
                        snapYaw(to: BodyAvatarYaw.nearest(degrees: yawDegrees))
                    }
                }
            }
    }

    /// Photo-path orbit: continuous degrees from drag (36px ≈ one 45° catalog step).
    /// Frame snaps still via `nearestDiscreteYaw`; garment fade tracks mid-drag degrees.
    static func photoOrbitYawDegrees(originDegrees: Double, translationWidth: Double) -> Double {
        originDegrees - translationWidth * (45.0 / 36.0)
    }

    /// Photo drag end settle: map continuous residual degrees → catalog angle degrees.
    /// Keeps chrome `shortLabel` and garment fade on the same post-drag angle.
    /// Uses Core `BodyAvatarYaw.nearest` (single truth with snap / chrome labels).
    static func photoOrbitSettledDegrees(_ continuousDegrees: Double) -> Double {
        Double(BodyAvatarYaw.nearest(degrees: continuousDegrees).rawValue)
    }

    /// compactChrome orbit caption: never claim garments when undressed;
    /// dressed copy says layered preview (not photo try-on).
    /// When `isSoftHold`, never claim a real multi-angle photo for the body.
    static func compactOrbitHint(
        hasLayers: Bool,
        garmentYawOpacity: Double,
        yawLabel: String,
        isSoftHold: Bool = false
    ) -> String {
        if isSoftHold {
            // Front pixels held under a turn — say so; clothes still front-only.
            if hasLayers {
                return garmentYawOpacity > 0.5
                    ? "Drag to turn · front hold · layered preview"
                    : "\(yawLabel) · front hold · clothes on front only"
            }
            return garmentYawOpacity > 0.5
                ? "Drag to turn · front hold"
                : "\(yawLabel) · front hold"
        }
        if hasLayers {
            return garmentYawOpacity > 0.5
                ? "Drag to turn · front shows layered preview"
                : "\(yawLabel) · layered preview on front only"
        }
        return garmentYawOpacity > 0.5
            ? "Drag to turn"
            : yawLabel
    }

    /// Full (non-compact) orbit center caption — no "360°" while soft-holding front pixels.
    static func orbitAngleCaption(
        yawLabel: String,
        yawDegrees: Double,
        usesMannequin3D: Bool,
        isSoftHold: Bool
    ) -> String {
        if usesMannequin3D {
            return String(format: "360° · %.0f°", yawDegrees)
        }
        if isSoftHold {
            // Missing dedicated yaw frame: same front photo + soft turn, not a side/back capture.
            if yawLabel == BodyAvatarYaw.deg0.shortLabel {
                return "Front"
            }
            return "\(yawLabel) · front hold (no side photo)"
        }
        return "360° · \(yawLabel)"
    }

    /// VoiceOver for figure — soft-hold must not claim a real side/back photo.
    static func orbitAccessibilityLabel(
        sexTitle: String,
        shapeRaw: String,
        yawLabel: String,
        isSoftHold: Bool
    ) -> String {
        if isSoftHold, yawLabel != BodyAvatarYaw.deg0.shortLabel {
            return "\(sexTitle) body \(shapeRaw), front hold approximating \(yawLabel)"
        }
        return "\(sexTitle) body \(shapeRaw), \(yawLabel) view"
    }

    /// 显式 accessibilityLabel 会覆盖 `.combine` 合并出的子标签 —— 必须把
    /// wear/fit caption 折进来，否则 VO 只念角度、吞掉 wearSummary（orbit 点阵
    /// 标签与 yawLabel 本就同义，不重复追加）。
    static func heroAccessibilityLabel(yawLabel: String, fitCaption: String?) -> String {
        guard let fitCaption, !fitCaption.isEmpty else { return yawLabel }
        return yawLabel + ", " + fitCaption
    }

    /// Full-chrome orbit chevrons (icon-only) — VoiceOver; not look carousel.
    enum OrbitStepDirection: Sendable {
        case previous, next
    }

    static func orbitStepAccessibilityLabel(direction: OrbitStepDirection) -> String {
        switch direction {
        case .previous: return "Previous angle"
        case .next: return "Next angle"
        }
    }

    /// A11Y: VoiceOver adjustable action on the combined hero element —
    /// increment rotates to the next catalog angle (same as chevron-right),
    /// decrement to the previous. `nonisolated` so tests can pin the mapping
    /// without MainActor hops.
    nonisolated static func orbitAdjustableStep(increment: Bool) -> Int {
        increment ? 1 : -1
    }

    /// A11Y: orbit dots stay 5–7pt visually but are the only discrete steppers
    /// in compactChrome — the tap target must be at least this large (pt).
    nonisolated static let orbitDotHitArea: CGFloat = 24

    /// A11Y: hero orbit chevrons stay .title2 visually but are the primary
    /// angle steppers — the tap target meets the 44pt HIG minimum (same
    /// floor as lookPagerChevronHitArea). `nonisolated` so tests can pin
    /// without MainActor hops.
    nonisolated static let orbitChevronHitArea: CGFloat = 44

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
        // Render truth = decode success, not path presence (failed load → slot placeholder).
        let img = Self.layerImage(layer)
        let showsVisual = img != nil
        // Path/name present but unreadable still hasVisual=true; layout as placeholder frame.
        let layoutLayer = showsVisual ? layer : Self.placeholderLayoutLayer(from: layer)
        let nr = BodyAvatarGarmentLayout.displayFrame(
            layer: layoutLayer,
            canvasWidth: Double(canvas.width),
            canvasHeight: Double(canvas.height),
            morph: morph)
        let rect = CGRect(x: nr.x, y: nr.y, width: nr.width, height: nr.height)
        Group {
            if let img {
                img
                    .resizable()
                    .interpolation(.high)
                    // 全身 2:3 画布直接铺满 displayFrame（勿再 aspectFit 进小槽）
                    .frame(width: rect.width, height: rect.height)
            } else {
                slotPlaceholder(layer.slot)
                    .frame(width: rect.width, height: rect.height, alignment: garmentAlignment(layer.slot))
            }
        }
        .frame(width: rect.width, height: rect.height)
        .clipped()
        // 轻接触影：叠衣贴身、减「贴纸浮空」(HIG depth / paper-doll)
        .shadow(
            color: Color.black.opacity(showsVisual ? 0.12 : 0),
            radius: showsVisual ? 3 : 2.5, y: 1.5)
        .position(x: rect.midX, y: rect.midY)
        .zIndex(Double(layer.zIndex))
        .opacity(showsVisual ? 0.98 : 0.72)
    }

    private func garmentAlignment(_ slot: BodyAvatarSlot) -> Alignment {
        switch slot {
        case .top, .outerwear, .dress: return .top
        case .bottom: return .top
        case .shoes: return .bottom
        }
    }

    /// Clears asset refs so `displayFrame` / `hasVisual` treat the layer as a slot placeholder.
    private static func placeholderLayoutLayer(from layer: BodyAvatarLayer) -> BodyAvatarLayer {
        BodyAvatarLayer(
            id: layer.id,
            slot: layer.slot,
            frame: layer.frame,
            zIndex: layer.zIndex,
            fitScale: layer.fitScale,
            fitOffsetY: layer.fitOffsetY)
    }

    /// True only when an image actually decodes — path/name presence alone is not enough.
    /// Use for chrome, captions, and any copy that claims garments are on-canvas.
    public static func hasRenderableVisual(_ layer: BodyAvatarLayer) -> Bool {
        layerImage(layer) != nil
    }

    /// 任一 layer 解码成功 → 保留全部（失败槽仍渲染彩块占位，提示「此槽有单品」）；
    /// 全失败 → 返回空，让「Undressed」capsule 独占空态 —— 彩块占位 + Undressed 自相矛盾。
    /// for-loop（非 contains/closure）—— 本类型 MainActor 假定下闭包转换会在
    /// 非 Main 调用方（测试/exporter）触发 checkIsolated 陷阱。
    static func onCanvasGarmentLayers(_ layers: [BodyAvatarLayer]) -> [BodyAvatarLayer] {
        for layer in layers where hasRenderableVisual(layer) { return layers }
        return []
    }

    /// 本地入库图优先，其次 bundle / UIImage named。
    /// 结果按 path/name 备忘（含失败 nil）—— 30fps hero tick 不得每层重读盘重解码。
    /// if-let（非 Optional.map）—— 同上，避免 MainActor 闭包转换陷阱。
    public static func layerImage(_ layer: BodyAvatarLayer) -> Image? {
        let key: String
        if let rel = layer.localRelativePath {
            key = "local|\(rel)"
        } else if let name = layer.imageAssetName {
            key = "layer-asset|\(name)"
        } else {
            key = "empty|\(layer.id)"
        }
        if let cached = BodyAvatarImageCache.shared.cachedImage(forKey: key) { return cached }
        let (img, cost) = loadLayerImage(layer)
        BodyAvatarImageCache.shared.storeImage(img, forKey: key, cost: cost)
        return img
    }

    private static func loadLayerImage(_ layer: BodyAvatarLayer) -> (image: Image?, cost: Int) {
        if let rel = layer.localRelativePath,
           let data = ItemImageStore.loadData(relativePath: rel) {
            #if canImport(UIKit)
            if let ui = UIImage(data: data) {
                return (Image(uiImage: ui), Int(ui.size.width * ui.size.height * 4))
            }
            #elseif canImport(AppKit) && !os(iOS)
            if let ns = NSImage(data: data) {
                return (Image(nsImage: ns), Int(ns.size.width * ns.size.height * 4))
            }
            #endif
        }
        if let name = layer.imageAssetName, let img = bundleImage(named: name) {
            // bundleImage 已按自身 key 计费；此处外层 key 记名义成本即可
            return (img, 1)
        }
        if let name = layer.imageAssetName {
            #if canImport(UIKit)
            if let ui = UIImage(named: name) {
                return (Image(uiImage: ui), Int(ui.size.width * ui.size.height * 4))
            }
            #endif
        }
        return (nil, 1)
    }

    /// Empty-layer placeholder VoiceOver: human title, never raw `slotRaw` / enum string.
    public static func slotAccessibilityLabel(_ slot: BodyAvatarSlot) -> String {
        GarmentSlot(rawValue: slot.rawValue)?.displayTitle ?? slot.rawValue.capitalized
    }

    /// 无入库图时：软渐变色块 + SF Symbol（勿暴露 raw slot 字符串）。
    private func slotPlaceholder(_ slot: BodyAvatarSlot) -> some View {
        let c = slotColor(slot)
        return RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [c.opacity(0.72), c.opacity(0.38)],
                    startPoint: .top, endPoint: .bottom))
            .overlay {
                Image(systemName: slotSymbol(slot))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .symbolRenderingMode(.hierarchical)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5))
            .accessibilityLabel(Self.slotAccessibilityLabel(slot))
    }

    private func slotSymbol(_ slot: BodyAvatarSlot) -> String {
        switch slot {
        case .outerwear: return "coat.fill"
        case .top: return "tshirt.fill"
        case .dress: return "figure.stand.dress"
        case .bottom: return "rectangle.portrait.fill"
        case .shoes: return "shoe.fill"
        }
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

    /// Probe 结果按名字备忘（含 miss）—— photoreal 帧解析每 tick 不再打 Bundle。
    public static func bundleResourceURL(named name: String) -> URL? {
        BodyAvatarImageCache.shared.resourceURL(named: name)
    }

    public static func bundleImage(named name: String) -> Image? {
        let key = "bundle|\(name)"
        if let cached = BodyAvatarImageCache.shared.cachedImage(forKey: key) { return cached }
        let (img, cost) = loadBundleImage(named: name)
        BodyAvatarImageCache.shared.storeImage(img, forKey: key, cost: cost)
        return img
    }

    private static func loadBundleImage(named name: String) -> (image: Image?, cost: Int) {
        guard let url = bundleResourceURL(named: name),
              let data = try? Data(contentsOf: url) else { return (nil, 1) }
        #if canImport(UIKit)
        if let ui = UIImage(data: data, scale: 1) {
            return (Image(uiImage: ui), Int(ui.size.width * ui.size.height * 4))
        }
        #elseif canImport(AppKit)
        if let ns = NSImage(data: data) {
            return (Image(nsImage: ns), Int(ns.size.width * ns.size.height * 4))
        }
        #endif
        return (nil, 1)
    }

    #if canImport(UIKit)
    /// 原图 UIImage（scale=1，避免系统二次压缩缩放）。
    /// 经 NSCache 备忘：morph render 每次重走读盘 + 全量解码（539KB PNG →
    /// 6.3MB 位图）会与滑杆 30fps 叠加成主线程热点。
    public static func bundleUIImage(named name: String) -> UIImage? {
        if let hit = BodyAvatarImageCache.shared.cachedPlatformImage(named: name) {
            return hit
        }
        guard let url = bundleResourceURL(named: name),
              let data = try? Data(contentsOf: url),
              let ui = UIImage(data: data, scale: 1) else { return nil }
        BodyAvatarImageCache.shared.storePlatformImage(
            ui, named: name, cost: Int(ui.size.width * ui.size.height * 4))
        return ui
    }
    #endif

    #if canImport(AppKit) && !os(iOS)
    public static func bundleNSImage(named name: String) -> NSImage? {
        if let hit = BodyAvatarImageCache.shared.cachedPlatformImage(named: name) {
            return hit
        }
        guard let url = bundleResourceURL(named: name),
              let data = try? Data(contentsOf: url),
              let ns = NSImage(data: data) else { return nil }
        BodyAvatarImageCache.shared.storePlatformImage(
            ns, named: name, cost: Int(ns.size.width * ns.size.height * 4))
        return ns
    }
    #endif
}

// MARK: - Decode / probe memoization

/// 内存缓存：hero 30fps TimelineView 每 tick 重走 figureStack → layerImage /
/// bundle probe，不能每帧读盘 + 解码。键 = path/name；**失败（nil）也缓存**，
/// 否则缺失资产每 tick 照样打盘。
/// 位图走 NSCache：按字节 cost 限额（条目数限容会让 96 张解码位图峰值 ~600MB
/// → jetsam），近似 LRU（旧「随机半清」按 Dictionary hash 序丢，当前帧 50% 中枪），
/// 内存压力下系统自动清；NSCache 天然线程安全（exporter / 测试在非 Main 调用）。
final class BodyAvatarImageCache: @unchecked Sendable {
    static let shared = BodyAvatarImageCache()

    /// 缓存值盒：image == nil 表示「已知失败」（负缓存）。
    final class ImageBox {
        let image: Image?
        init(_ image: Image?) { self.image = image }
    }

    private let lock = NSLock()
    /// Bundle probe 结果（含 miss）；key = 资源名。
    private var resourceURLs: [String: URL?] = [:]
    /// probe 表上限：key 域可被数据驱动（资产名来自调用方），miss 永久占条会变泄漏。
    /// 越界整表清空——probe 重跑廉价（Bundle.url），无需 LRU。
    private let maxResourceEntries = 512

    private let images: NSCache<NSString, ImageBox> = {
        let c = NSCache<NSString, ImageBox>()
        c.totalCostLimit = 128 * 1024 * 1024   // 约 20 张 1024×1536 解码位图
        c.countLimit = 256                     // cost 误报兜底
        return c
    }()

    /// 平台原图（UIImage/NSImage，morph render 输入）单独计费。
    #if canImport(UIKit)
    private let platformImages: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.totalCostLimit = 64 * 1024 * 1024
        c.countLimit = 128
        return c
    }()
    func cachedPlatformImage(named name: String) -> UIImage? {
        platformImages.object(forKey: name as NSString)
    }
    func storePlatformImage(_ image: UIImage, named name: String, cost: Int) {
        platformImages.setObject(image, forKey: name as NSString, cost: max(1, cost))
    }
    #elseif canImport(AppKit)
    private let platformImages: NSCache<NSString, NSImage> = {
        let c = NSCache<NSString, NSImage>()
        c.totalCostLimit = 64 * 1024 * 1024
        c.countLimit = 128
        return c
    }()
    func cachedPlatformImage(named name: String) -> NSImage? {
        platformImages.object(forKey: name as NSString)
    }
    func storePlatformImage(_ image: NSImage, named name: String, cost: Int) {
        platformImages.setObject(image, forKey: name as NSString, cost: max(1, cost))
    }
    #endif

    /// 测试探针：probe 表当前条数。
    var resourceProbeCount: Int {
        lock.lock(); defer { lock.unlock() }
        return resourceURLs.count
    }

    func resourceURL(named name: String) -> URL? {
        lock.lock()
        defer { lock.unlock() }
        if let hit = resourceURLs[name] { return hit }
        if resourceURLs.count >= maxResourceEntries { resourceURLs.removeAll() }
        let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "BodyAvatar")
            ?? Bundle.module.url(forResource: name, withExtension: "png")
        resourceURLs[name] = url
        return url
    }

    /// `.some(nil)` = 已知失败；`nil` = 从未加载。
    func cachedImage(forKey key: String) -> Image?? {
        guard let box = images.object(forKey: key as NSString) else { return nil }
        return .some(box.image)
    }

    func storeImage(_ image: Image?, forKey key: String, cost: Int = 1) {
        images.setObject(ImageBox(image), forKey: key as NSString, cost: max(1, cost))
    }
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
