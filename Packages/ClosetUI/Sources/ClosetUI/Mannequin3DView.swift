import SwiftUI
import SceneKit
import ClosetCore
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit) && !os(iOS)
import AppKit
#endif

/// 写实真人 **全 nude 底座（死要求）**（SceneKit）：零遮盖 + 多人种肤色。
/// 优先 bundle nude USDZ，否则程序化裸身。禁止 pastie/thong/brief/内衣。
/// 非 SMPL / 非自拍 VTON / 不依赖 AI 多帧 croquis 农场。
public struct Mannequin3DView: View {
    public var scales: MannequinSegmentScales
    public var sex: AvatarBodySex
    public var phenotype: AvatarBodyPhenotype
    public var yawDegrees: Double
    public var allowsCameraControl: Bool

    public init(
        scales: MannequinSegmentScales,
        sex: AvatarBodySex = .female,
        phenotype: AvatarBodyPhenotype = .eastAsian,
        yawDegrees: Double = 0,
        allowsCameraControl: Bool = false
    ) {
        self.scales = scales
        self.sex = sex
        self.phenotype = phenotype
        self.yawDegrees = yawDegrees
        self.allowsCameraControl = allowsCameraControl
    }

    public var body: some View {
        MannequinSCNRepresentable(
            scales: scales,
            sex: sex,
            phenotype: phenotype,
            yawDegrees: yawDegrees,
            allowsCameraControl: allowsCameraControl)
        .accessibilityLabel(
            "Fully nude \(phenotype.displayTitle) \(sex.displayTitle.lowercased()) body, zero covering")
        .accessibilityValue(String(format: "Yaw %.0f degrees", yawDegrees))
    }
}

// MARK: - SceneKit bridge

#if os(iOS)
private struct MannequinSCNRepresentable: UIViewRepresentable {
    var scales: MannequinSegmentScales
    var sex: AvatarBodySex
    var phenotype: AvatarBodyPhenotype
    var yawDegrees: Double
    var allowsCameraControl: Bool

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        configure(view, coordinator: context.coordinator)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.apply(
            scales: scales, sex: sex, phenotype: phenotype, yawDegrees: yawDegrees)
        uiView.allowsCameraControl = allowsCameraControl
    }

    func makeCoordinator() -> MannequinSceneCoordinator { MannequinSceneCoordinator() }

    private func configure(_ view: SCNView, coordinator: MannequinSceneCoordinator) {
        view.scene = coordinator.scene
        view.backgroundColor = .clear
        view.isOpaque = false
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.allowsCameraControl = allowsCameraControl
        view.rendersContinuously = false
        view.preferredFramesPerSecond = 30
    }
}
#elseif os(macOS)
private struct MannequinSCNRepresentable: NSViewRepresentable {
    var scales: MannequinSegmentScales
    var sex: AvatarBodySex
    var phenotype: AvatarBodyPhenotype
    var yawDegrees: Double
    var allowsCameraControl: Bool

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = context.coordinator.scene
        view.backgroundColor = .clear
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.allowsCameraControl = allowsCameraControl
        view.rendersContinuously = false
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        context.coordinator.apply(
            scales: scales, sex: sex, phenotype: phenotype, yawDegrees: yawDegrees)
        nsView.allowsCameraControl = allowsCameraControl
    }

    func makeCoordinator() -> MannequinSceneCoordinator { MannequinSceneCoordinator() }
}
#endif

// MARK: - Scene graph（写实皮肤人体；USDZ lock-in + 程序化 fallback）

@MainActor
final class MannequinSceneCoordinator {
    let scene = SCNScene()
    private let bodyRoot = SCNNode()
    private var partNodes: [String: SCNNode] = [:]
    /// Ellipsoid 等非均匀基础 scale；morph 在其上相乘，避免压扁有机体积。
    private var partBaseScale: [String: SCNVector3] = [:]
    private var builtSex: AvatarBodySex?
    private var builtPhenotype: AvatarBodyPhenotype?
    /// Exposed for tests / diagnostics.
    private(set) var activeMeshSource: MannequinMeshCatalog.MeshSource = .procedural
    private weak var keyLightNode: SCNNode?
    private weak var fillLightNode: SCNNode?
    private weak var rimLightNode: SCNNode?
    private weak var ambientLightNode: SCNNode?

    init() {
        #if os(iOS)
        scene.background.contents = UIColor.clear
        #else
        scene.background.contents = NSColor.clear
        #endif

        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 26
        camera.camera?.wantsHDR = true
        camera.camera?.bloomIntensity = 0.05
        camera.position = SCNVector3(0, 0.95, 3.4)
        camera.look(at: SCNVector3(0, 0.95, 0))
        scene.rootNode.addChildNode(camera)

        // 棚拍三点光：主光暖、辅光冷、顶光柔（强度随 phenotype 再调）
        keyLightNode = addLight(
            type: .directional, intensity: 900, color: SkinPalette.keyLight,
            euler: SCNVector3(-0.55, 0.65, 0), name: "key")
        fillLightNode = addLight(
            type: .directional, intensity: 320, color: SkinPalette.fillLight,
            euler: SCNVector3(-0.2, -0.9, 0), name: "fill")
        rimLightNode = addLight(
            type: .omni, intensity: 280, color: SkinPalette.rimLight,
            position: SCNVector3(0, 2.4, 1.2), name: "rim")
        let ambient = SCNNode()
        ambient.name = "ambient"
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 220
        ambient.light?.color = SkinPalette.ambient
        scene.rootNode.addChildNode(ambient)
        ambientLightNode = ambient

        scene.rootNode.addChildNode(bodyRoot)
        rebuild(sex: .female, phenotype: .eastAsian)
    }

    func apply(
        scales: MannequinSegmentScales,
        sex: AvatarBodySex,
        phenotype: AvatarBodyPhenotype = .eastAsian,
        yawDegrees: Double
    ) {
        if builtSex != sex || builtPhenotype != phenotype {
            rebuild(sex: sex, phenotype: phenotype)
        }
        let s = scales.clamped()
        bodyRoot.scale = SCNVector3(1, Float(s.height), 1)
        bodyRoot.eulerAngles = SCNVector3(0, Float(yawDegrees * .pi / 180), 0)

        scaleNode("shoulderBar", x: s.shoulderWidth, y: 1, z: 1)
        scaleNode("clavicleL", x: s.shoulderWidth, y: 1, z: 1)
        scaleNode("clavicleR", x: s.shoulderWidth, y: 1, z: 1)
        scaleNode("chest", x: s.chestWidth, y: 1, z: s.chestDepth)
        scaleNode("rib", x: s.chestWidth, y: 1, z: s.chestDepth)
        scaleNode("breastL", x: s.chestWidth, y: s.chestDepth, z: s.chestDepth)
        scaleNode("breastR", x: s.chestWidth, y: s.chestDepth, z: s.chestDepth)
        scaleNode("breastUnderL", x: s.chestWidth, y: s.chestDepth, z: s.chestDepth)
        scaleNode("breastUnderR", x: s.chestWidth, y: s.chestDepth, z: s.chestDepth)
        scaleNode("pecL", x: s.chestWidth, y: s.chestDepth, z: s.chestDepth)
        scaleNode("pecR", x: s.chestWidth, y: s.chestDepth, z: s.chestDepth)
        scaleNode("waist", x: s.waistWidth, y: 1, z: max(0.9, s.chestDepth * 0.9))
        scaleNode("abdomen", x: s.waistWidth, y: 1, z: max(0.9, s.chestDepth * 0.92))
        scaleNode("hip", x: s.hipWidth, y: 1, z: max(0.92, s.hipWidth * 0.55))
        scaleNode("gluteL", x: s.hipWidth, y: 1, z: s.hipWidth * 0.7)
        scaleNode("gluteR", x: s.hipWidth, y: 1, z: s.hipWidth * 0.7)
        scaleNode("pelvis", x: s.hipWidth, y: 1, z: max(0.9, s.hipWidth * 0.5))
        scaleNode("mons", x: s.hipWidth, y: 1, z: max(0.9, s.hipWidth * 0.45))
        scaleNode("genital", x: s.limbThickness, y: 1, z: s.limbThickness)
        scaleNode("scrotum", x: s.limbThickness, y: 1, z: s.limbThickness)
        for name in [
            "lThigh", "rThigh", "lThighHead", "rThighHead",
            "lShin", "rShin", "lAnkle", "rAnkle",
            "lUpperArm", "rUpperArm", "lForeArm", "rForeArm",
            "lHand", "rHand", "lKnee", "rKnee"
        ] {
            scaleNode(name, x: s.limbThickness, y: 1, z: s.limbThickness)
        }
        scaleNode("lFoot", x: s.limbThickness * 1.05, y: 1, z: 1)
        scaleNode("rFoot", x: s.limbThickness * 1.05, y: 1, z: 1)
        let hairX = max(1, s.shoulderWidth * 0.55 + 0.45)
        scaleNode("hair", x: hairX, y: 1, z: 1)
        scaleNode("hairAfro", x: hairX, y: 1, z: 1)
        scaleNode("hairBack", x: hairX, y: 1, z: 1)
        scaleNode("hairL", x: hairX, y: 1, z: 1)
        scaleNode("hairR", x: hairX, y: 1, z: 1)
    }

    private func scaleNode(_ name: String, x: Double, y: Double, z: Double) {
        guard let n = partNodes[name] else { return }
        let b = partBaseScale[name] ?? SCNVector3(1, 1, 1)
        #if os(macOS)
        n.scale = SCNVector3(CGFloat(x) * b.x, CGFloat(y) * b.y, CGFloat(z) * b.z)
        #else
        n.scale = SCNVector3(Float(x) * b.x, Float(y) * b.y, Float(z) * b.z)
        #endif
    }

    private func rebuild(sex: AvatarBodySex, phenotype: AvatarBodyPhenotype) {
        bodyRoot.childNodes.forEach { $0.removeFromParentNode() }
        partNodes.removeAll()
        partBaseScale.removeAll()
        builtSex = sex
        builtPhenotype = phenotype
        applyPhenotypeLighting(phenotype)

        if let usdzRoot = Self.loadUSDZBody(sex: sex, phenotype: phenotype) {
            activeMeshSource = .usdz
            attachUSDZ(usdzRoot, sex: sex, phenotype: phenotype)
            return
        }

        activeMeshSource = .procedural
        buildProceduralBody(sex: sex, phenotype: phenotype)
    }

    /// 深肤提高 key/fill，避免压成剪影；浅肤保持棚拍基准。
    private func applyPhenotypeLighting(_ phenotype: AvatarBodyPhenotype) {
        let s = phenotype.keyLightIntensityScale
        keyLightNode?.light?.intensity = 900 * CGFloat(s)
        fillLightNode?.light?.intensity = 320 * CGFloat(min(1.25, s * 0.95))
        rimLightNode?.light?.intensity = 280 * CGFloat(min(1.2, 0.9 + s * 0.15))
        ambientLightNode?.light?.intensity = 200 + 80 * CGFloat(1.0 - phenotype.skinLuminance)
    }

    // MARK: - USDZ lock-in

    /// Load `nude_body_{sex}_{phenotype}` → `nude_body_{sex}` → legacy mannequin_body_*.
    /// Asset **must** be fully photoreal nude, zero covering (`NudeBodyBaseSpec`).
    private static func loadUSDZBody(
        sex: AvatarBodySex,
        phenotype: AvatarBodyPhenotype
    ) -> SCNNode? {
        let stems = MannequinMeshCatalog.usdzCandidateStems(sex: sex, phenotype: phenotype)
        var url: URL?
        for name in stems {
            // Prefer BodyAvatar/Meshes/ then flat Resources / main bundle.
            url = Bundle.module.url(forResource: name, withExtension: "usdz", subdirectory: "BodyAvatar/Meshes")
                ?? Bundle.module.url(forResource: name, withExtension: "usd", subdirectory: "BodyAvatar/Meshes")
                ?? Bundle.module.url(forResource: name, withExtension: "usdz")
                ?? Bundle.module.url(forResource: name, withExtension: "usd")
                ?? Bundle.main.url(forResource: name, withExtension: "usdz")
            if url != nil { break }
        }
        guard let url else { return nil }
        do {
            let scene = try SCNScene(url: url, options: [
                .checkConsistency: true,
                .createNormalsIfAbsent: true
            ])
            let root = scene.rootNode.clone()
            root.name = MannequinMeshCatalog.bodyRootNodeName
            return root
        } catch {
            return nil
        }
    }

    private func attachUSDZ(
        _ root: SCNNode,
        sex: AvatarBodySex,
        phenotype: AvatarBodyPhenotype
    ) {
        // Normalize roughly to ~1.72m upright if author used cm / different origin.
        normalizeUSDZHeight(root, targetHeight: 1.72)
        // 单 mesh 入库时仍按表型重着色 → 多人种可读（全 nude 零遮盖不变）。
        Self.applyPhenotypeSkinToUSDZ(root, sex: sex, phenotype: phenotype)
        bodyRoot.addChildNode(root)
        // Map named segments for morph scaling (authors should use catalog names).
        root.enumerateChildNodes { node, _ in
            guard let name = node.name, MannequinMeshCatalog.segmentNodeNames.contains(name) else {
                return
            }
            partNodes[name] = node
        }
        // Also register common aliases if the asset uses BodyRoot children directly.
        if partNodes.isEmpty {
            // Whole-mesh only: still get height + yaw via bodyRoot.
        }
    }

    /// 将 USDZ 几何材质统一为表型肤色 PBR（跳过明显发丝/深色装饰节点名）。
    private static func applyPhenotypeSkinToUSDZ(
        _ root: SCNNode,
        sex: AvatarBodySex,
        phenotype: AvatarBodyPhenotype
    ) {
        let skin = SkinPalette.skinMaterial(sex: sex, phenotype: phenotype)
        let hair = SkinPalette.hairMaterial(sex: sex, phenotype: phenotype)
        let hairTokens = ["hair", "brow", "lash", "beard", "mustache"]
        root.enumerateChildNodes { node, _ in
            guard let geo = node.geometry else { return }
            let name = (node.name ?? "").lowercased()
            let isHair = hairTokens.contains { name.contains($0) }
            let mat = isHair ? hair : skin
            geo.materials = [mat]
        }
        if let geo = root.geometry {
            geo.materials = [skin]
        }
    }

    private func normalizeUSDZHeight(_ root: SCNNode, targetHeight: Float) {
        let (minVec, maxVec) = root.boundingBox
        let h = Float(maxVec.y - minVec.y)
        guard h > 0.01 else { return }
        let s = targetHeight / h
        root.scale = SCNVector3(s, s, s)
        // Sit feet on y=0
        let (min2, _) = root.boundingBox
        root.position = SCNVector3(0, -Float(min2.y) * s, 0)
    }

    // MARK: - Procedural anatomical approximation

    /// 全 nude 程序化人体：零 pastie/thong/brief；肤色/乳晕/发色/五官随 phenotype。
    /// 躯干以 **高细分 ellipsoid 球簇** 代替大 cuboid，减弱胶囊假人感（仍 interim，非认证写实 mesh）。
    private func buildProceduralBody(sex: AvatarBodySex, phenotype: AvatarBodyPhenotype) {
        let skin = SkinPalette.skinMaterial(sex: sex, phenotype: phenotype)
        let softSkin = SkinPalette.softSkinMaterial(sex: sex, phenotype: phenotype)
        let limbSkin = SkinPalette.limbSkinMaterial(sex: sex, phenotype: phenotype)
        let thighSkin = SkinPalette.thighSkinMaterial(sex: sex, phenotype: phenotype)
        let areola = SkinPalette.areolaMaterial(sex: sex, phenotype: phenotype)
        let hairMat = SkinPalette.hairMaterial(sex: sex, phenotype: phenotype)
        let isMale = sex == .male

        // 脚底 y≈0；头顶 ~1.72 — 四肢用 photoreal 无遮盖宏纹理。
        partEllipsoid("lFoot", rx: 0.048, ry: 0.022, rz: 0.095, at: v(-0.1, 0.028, 0.04), mat: limbSkin)
        partEllipsoid("rFoot", rx: 0.048, ry: 0.022, rz: 0.095, at: v(0.1, 0.028, 0.04), mat: limbSkin)
        part("lAnkle", sphere(isMale ? 0.038 : 0.034), at: v(-0.1, 0.08, 0.01), mat: softSkin)
        part("rAnkle", sphere(isMale ? 0.038 : 0.034), at: v(0.1, 0.08, 0.01), mat: softSkin)
        part("lShin", capsule(0.40, isMale ? 0.048 : 0.042), at: v(-0.1, 0.30, 0), mat: limbSkin)
        part("rShin", capsule(0.40, isMale ? 0.048 : 0.042), at: v(0.1, 0.30, 0), mat: limbSkin)
        part("lKnee", sphere(isMale ? 0.048 : 0.042), at: v(-0.1, 0.50, 0.01), mat: softSkin)
        part("rKnee", sphere(isMale ? 0.048 : 0.042), at: v(0.1, 0.50, 0.01), mat: softSkin)
        part("lThigh", capsule(0.44, isMale ? 0.074 : 0.070), at: v(-0.11, 0.72, 0), mat: thighSkin)
        part("rThigh", capsule(0.44, isMale ? 0.074 : 0.070), at: v(0.11, 0.72, 0), mat: thighSkin)
        part("lThighHead", sphere(isMale ? 0.078 : 0.074), at: v(-0.11, 0.92, 0.01), mat: softSkin)
        part("rThighHead", sphere(isMale ? 0.078 : 0.074), at: v(0.11, 0.92, 0.01), mat: softSkin)

        // 臀 / 髋：双球 + 前髋，避免方盒
        partEllipsoid("gluteL", rx: isMale ? 0.10 : 0.115, ry: 0.09, rz: 0.085,
                      at: v(isMale ? -0.07 : -0.08, 0.95, -0.04), mat: softSkin)
        partEllipsoid("gluteR", rx: isMale ? 0.10 : 0.115, ry: 0.09, rz: 0.085,
                      at: v(isMale ? 0.07 : 0.08, 0.95, -0.04), mat: softSkin)
        partEllipsoid("hip", rx: isMale ? 0.16 : 0.175, ry: 0.09, rz: 0.095,
                      at: v(0, 1.02, 0.01), mat: skin)
        partEllipsoid("pelvis", rx: isMale ? 0.09 : 0.08, ry: 0.05, rz: 0.07,
                      at: v(0, 1.00, 0.055), mat: softSkin)
        if isMale {
            part("genital", capsule(0.07, 0.028), at: v(0, 0.97, 0.09), mat: softSkin)
            part("scrotum", sphere(0.032), at: v(0, 0.94, 0.08), mat: softSkin)
        } else {
            part("mons", sphere(0.045), at: v(0, 0.99, 0.08), mat: softSkin)
        }

        // 躯干球簇（腰→腹→肋→胸）— 连续体积，非单盒
        partEllipsoid("waist", rx: isMale ? 0.13 : 0.115, ry: 0.07, rz: 0.085,
                      at: v(0, 1.14, 0.01), mat: skin)
        partEllipsoid("abdomen", rx: isMale ? 0.125 : 0.11, ry: 0.065, rz: 0.08,
                      at: v(0, 1.22, 0.015), mat: softSkin)
        partEllipsoid("rib", rx: isMale ? 0.15 : 0.13, ry: 0.07, rz: 0.095,
                      at: v(0, 1.30, 0.01), mat: skin)
        partEllipsoid("chest", rx: isMale ? 0.17 : 0.15, ry: 0.11, rz: isMale ? 0.10 : 0.09,
                      at: v(0, 1.40, 0.01), mat: skin)

        if isMale {
            part("pecL", sphere(0.058), at: v(-0.08, 1.41, 0.085), mat: softSkin)
            part("pecR", sphere(0.058), at: v(0.08, 1.41, 0.085), mat: softSkin)
            part("nippleL", sphere(0.012), at: v(-0.08, 1.40, 0.13), mat: areola)
            part("nippleR", sphere(0.012), at: v(0.08, 1.40, 0.13), mat: areola)
        } else {
            // 全裸胸型 + 解剖乳晕（皮肤色，非 pastie）
            part("breastL", sphere(0.082), at: v(-0.075, 1.39, 0.105), mat: softSkin)
            part("breastR", sphere(0.082), at: v(0.075, 1.39, 0.105), mat: softSkin)
            part("breastUnderL", sphere(0.05), at: v(-0.07, 1.34, 0.08), mat: softSkin)
            part("breastUnderR", sphere(0.05), at: v(0.07, 1.34, 0.08), mat: softSkin)
            part("areolaL", sphere(0.022), at: v(-0.075, 1.38, 0.16), mat: areola)
            part("areolaR", sphere(0.022), at: v(0.075, 1.38, 0.16), mat: areola)
            part("nippleL", sphere(0.008), at: v(-0.075, 1.38, 0.178), mat: areola)
            part("nippleR", sphere(0.008), at: v(0.075, 1.38, 0.178), mat: areola)
        }

        // 肩带：中央球 + 左右肩头
        partEllipsoid("shoulderBar", rx: isMale ? 0.20 : 0.17, ry: 0.045, rz: 0.065,
                      at: v(0, 1.54, 0), mat: skin)
        let armX: Float = isMale ? 0.31 : 0.27
        part("clavicleL", capsule(0.12, 0.018), at: v(-armX * 0.55, 1.52, 0.02), mat: softSkin)
        part("clavicleR", capsule(0.12, 0.018), at: v(armX * 0.55, 1.52, 0.02), mat: softSkin)
        part("lShoulder", sphere(isMale ? 0.058 : 0.050), at: v(-armX, 1.52, 0), mat: skin)
        part("rShoulder", sphere(isMale ? 0.058 : 0.050), at: v(armX, 1.52, 0), mat: skin)

        part("neck", capsule(0.11, isMale ? 0.048 : 0.042), at: v(0, 1.63, 0), mat: skin)
        // 头略扁椭圆 + 后枕
        partEllipsoid("head",
                      rx: isMale ? 0.112 : 0.106,
                      ry: isMale ? 0.120 : 0.114,
                      rz: isMale ? 0.108 : 0.102,
                      at: v(0, 1.78, 0), mat: skin)
        part("occiput", sphere(isMale ? 0.08 : 0.075), at: v(0, 1.78, -0.04), mat: softSkin)
        part("jaw", sphere(isMale ? 0.07 : 0.062), at: v(0, 1.70, 0.03), mat: softSkin)
        part("earL", sphere(0.022), at: v(isMale ? -0.12 : -0.11, 1.78, 0), mat: skin)
        part("earR", sphere(0.022), at: v(isMale ? 0.12 : 0.11, 1.78, 0), mat: skin)

        // 写实脸投影（仅头，零躯体遮盖）
        let hasFacePlate = attachFacePlate(sex: sex, phenotype: phenotype)
        if !hasFacePlate {
            let feature = SkinPalette.featureMaterial(phenotype: phenotype, sex: sex)
            part("faceShade", sphere(0.095), at: v(0, 1.77, 0.025),
                 mat: SkinPalette.faceShadeMaterial(phenotype: phenotype, sex: sex))
            part("nose", sphere(0.018), at: v(0, 1.76, 0.11), mat: softSkin)
            part("browL", box(0.028, 0.006, 0.008, r: 0.002), at: v(-0.028, 1.805, 0.10), mat: feature)
            part("browR", box(0.028, 0.006, 0.008, r: 0.002), at: v(0.028, 1.805, 0.10), mat: feature)
            part("lip", box(0.032, 0.010, 0.012, r: 0.004), at: v(0, 1.72, 0.105), mat: areola)
        }

        // 腹侧写实皮肤投影（仅无遮盖腹区裁切；不含 pastie/thong/brief）
        attachTorsoSkinPlate(sex: sex, phenotype: phenotype)

        attachHair(sex: sex, phenotype: phenotype, hairMat: hairMat)

        part("lUpperArm", capsule(0.30, isMale ? 0.048 : 0.04), at: v(-armX, 1.38, 0), mat: limbSkin)
        part("rUpperArm", capsule(0.30, isMale ? 0.048 : 0.04), at: v(armX, 1.38, 0), mat: limbSkin)
        part("lForeArm", capsule(0.27, 0.034), at: v(-armX, 1.08, 0.03), mat: limbSkin)
        part("rForeArm", capsule(0.27, 0.034), at: v(armX, 1.08, 0.03), mat: limbSkin)
        part("lHand", sphere(0.035), at: v(-armX, 0.92, 0.04), mat: softSkin)
        part("rHand", sphere(0.035), at: v(armX, 0.92, 0.04), mat: softSkin)

        partNodes["lUpperArm"]?.eulerAngles = SCNVector3(0.05, 0, 0.14)
        partNodes["rUpperArm"]?.eulerAngles = SCNVector3(0.05, 0, -0.14)
        partNodes["clavicleL"]?.eulerAngles = SCNVector3(0, 0, 0.35)
        partNodes["clavicleR"]?.eulerAngles = SCNVector3(0, 0, -0.35)
    }

    /// 从已批准 photoreal 正面裁切的写实脸贴到 3D 头前（不含躯体/遮盖区域）。
    /// - Returns: 是否成功挂上贴图（有则跳过程序化五官）。
    @discardableResult
    private func attachFacePlate(sex: AvatarBodySex, phenotype: AvatarBodyPhenotype) -> Bool {
        guard let mat = SkinPalette.facePlateMaterial(sex: sex, phenotype: phenotype) else {
            return false
        }
        let isMale = sex == .male
        let w: Float = isMale ? 0.195 : 0.185
        let h: Float = isMale ? 0.235 : 0.225
        let plane = SCNPlane(width: CGFloat(w), height: CGFloat(h))
        plane.cornerRadius = CGFloat(min(w, h) * 0.42)
        let n = SCNNode(geometry: plane)
        n.name = "facePlate"
        n.geometry?.materials = [mat]
        // 略贴头球前方；与 bodyRoot 同转，转体仍跟脸。
        n.position = SCNVector3(0, 1.785, isMale ? 0.112 : 0.108)
        n.renderingOrder = 2
        bodyRoot.addChildNode(n)
        partNodes["facePlate"] = n
        return true
    }

    /// 腹侧写实皮肤卡（仅 navel 区、零遮盖裁切）贴到 3D 腹前，提升真人感。
    @discardableResult
    private func attachTorsoSkinPlate(sex: AvatarBodySex, phenotype: AvatarBodyPhenotype) -> Bool {
        guard let mat = SkinPalette.torsoFrontPlateMaterial(sex: sex, phenotype: phenotype) else {
            return false
        }
        let isMale = sex == .male
        let plane = SCNPlane(
            width: CGFloat(isMale ? 0.22 : 0.20),
            height: CGFloat(isMale ? 0.18 : 0.16))
        plane.cornerRadius = 0.06
        let n = SCNNode(geometry: plane)
        n.name = "torsoSkinPlate"
        n.geometry?.materials = [mat]
        n.position = SCNVector3(0, isMale ? 1.24 : 1.22, isMale ? 0.095 : 0.09)
        n.renderingOrder = 1
        bodyRoot.addChildNode(n)
        partNodes["torsoSkinPlate"] = n
        return true
    }

    /// 表型发量/长度差异（全为发色几何，非头饰/遮盖）。
    private func attachHair(
        sex: AvatarBodySex,
        phenotype: AvatarBodyPhenotype,
        hairMat: SCNMaterial
    ) {
        let isMale = sex == .male
        switch phenotype {
        case .african:
            part("hair", sphere(isMale ? 0.128 : 0.132), at: v(0, 1.84, -0.01), mat: hairMat)
            part("hairAfro", sphere(isMale ? 0.145 : 0.152), at: v(0, 1.88, -0.02), mat: hairMat)
        case .european:
            part("hair", sphere(isMale ? 0.120 : 0.126), at: v(0, 1.83, -0.01), mat: hairMat)
            if !isMale {
                part("hairBack", sphere(0.09), at: v(0, 1.70, -0.07), mat: hairMat)
                part("hairL", sphere(0.045), at: v(-0.09, 1.66, 0.0), mat: hairMat)
                part("hairR", sphere(0.045), at: v(0.09, 1.66, 0.0), mat: hairMat)
            }
        case .eastAsian, .southeastAsian:
            part("hair", sphere(isMale ? 0.118 : 0.124), at: v(0, 1.83, -0.02), mat: hairMat)
            if !isMale {
                part("hairBack", sphere(0.11), at: v(0, 1.68, -0.09), mat: hairMat)
                part("hairL", sphere(0.06), at: v(-0.10, 1.64, 0.0), mat: hairMat)
                part("hairR", sphere(0.06), at: v(0.10, 1.64, 0.0), mat: hairMat)
            }
        case .southAsian, .middleEastern, .latinx, .indigenous:
            part("hair", sphere(isMale ? 0.122 : 0.128), at: v(0, 1.84, -0.02), mat: hairMat)
            if !isMale {
                part("hairBack", sphere(0.12), at: v(0, 1.66, -0.10), mat: hairMat)
                part("hairL", sphere(0.07), at: v(-0.11, 1.62, 0.0), mat: hairMat)
                part("hairR", sphere(0.07), at: v(0.11, 1.62, 0.0), mat: hairMat)
            } else if phenotype == .latinx || phenotype == .indigenous {
                part("hairBack", sphere(0.06), at: v(0, 1.72, -0.06), mat: hairMat)
            }
        }
    }

    // MARK: helpers

    @discardableResult
    private func addLight(
        type: SCNLight.LightType,
        intensity: CGFloat,
        color: Any,
        euler: SCNVector3? = nil,
        position: SCNVector3? = nil,
        name: String
    ) -> SCNNode {
        let n = SCNNode()
        n.name = name
        n.light = SCNLight()
        n.light?.type = type
        n.light?.intensity = intensity
        n.light?.color = color
        n.light?.castsShadow = false
        if let euler { n.eulerAngles = euler }
        if let position { n.position = position }
        scene.rootNode.addChildNode(n)
        return n
    }

    private func part(
        _ name: String,
        _ geo: SCNGeometry,
        at: SCNVector3,
        mat: SCNMaterial,
        scale: SCNVector3? = nil
    ) {
        geo.materials = [mat]
        let n = SCNNode(geometry: geo)
        n.name = name
        n.position = at
        let base = scale ?? SCNVector3(1, 1, 1)
        n.scale = base
        partBaseScale[name] = base
        bodyRoot.addChildNode(n)
        partNodes[name] = n
    }

    /// 各向异性球簇节点（有机躯干体积）。
    private func partEllipsoid(
        _ name: String,
        rx: Float, ry: Float, rz: Float,
        at: SCNVector3,
        mat: SCNMaterial
    ) {
        part(name, sphere(1), at: at, mat: mat, scale: SCNVector3(rx, ry, rz))
    }

    private func v(_ x: Float, _ y: Float, _ z: Float) -> SCNVector3 {
        SCNVector3(x, y, z)
    }

    private func capsule(_ h: Float, _ r: Float) -> SCNGeometry {
        SCNCapsule(capRadius: CGFloat(r), height: CGFloat(h))
    }

    private func box(_ w: Float, _ h: Float, _ d: Float, r: Float) -> SCNGeometry {
        SCNBox(width: CGFloat(w), height: CGFloat(h), length: CGFloat(d), chamferRadius: CGFloat(r))
    }

    private func sphere(_ r: Float) -> SCNGeometry {
        let s = SCNSphere(radius: CGFloat(r))
        s.segmentCount = 64
        return s
    }
}

// MARK: - Multi-phenotype photoreal skin (full nude; never plastic ivory)

private enum SkinPalette {
    #if os(iOS)
    static let keyLight: UIColor = UIColor(red: 1.0, green: 0.96, blue: 0.92, alpha: 1)
    static let fillLight: UIColor = UIColor(red: 0.85, green: 0.90, blue: 1.0, alpha: 1)
    static let rimLight: UIColor = UIColor(red: 1.0, green: 0.98, blue: 0.95, alpha: 1)
    static let ambient: UIColor = UIColor(white: 0.88, alpha: 1)

    static func uiColor(_ rgb: (r: Double, g: Double, b: Double), a: CGFloat = 1) -> UIColor {
        UIColor(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: a)
    }

    static func skinMaterial(sex: AvatarBodySex, phenotype: AvatarBodyPhenotype) -> SCNMaterial {
        makeSkin(sex: sex, phenotype: phenotype, soft: false, region: .torso)
    }

    /// 关节/胸腹略软：更高 clearCoat 模拟皮下散射。
    static func softSkinMaterial(sex: AvatarBodySex, phenotype: AvatarBodyPhenotype) -> SCNMaterial {
        makeSkin(sex: sex, phenotype: phenotype, soft: true, region: .torso)
    }

    /// 四肢：优先用从已批准 photoreal **无遮盖** 臂/腿裁切的宏纹理。
    static func limbSkinMaterial(sex: AvatarBodySex, phenotype: AvatarBodyPhenotype) -> SCNMaterial {
        makeSkin(sex: sex, phenotype: phenotype, soft: false, region: .limb)
    }

    static func thighSkinMaterial(sex: AvatarBodySex, phenotype: AvatarBodyPhenotype) -> SCNMaterial {
        makeSkin(sex: sex, phenotype: phenotype, soft: false, region: .thigh)
    }

    private enum SkinRegion { case torso, limb, thigh }

    /// 解剖乳晕/乳头色（压暗肤色，**不是** pastie 贴片材质）。
    static func areolaMaterial(sex: AvatarBodySex, phenotype: AvatarBodyPhenotype) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        let s = phenotype.skinRGB(sex: sex)
        let d = phenotype.areolaDarken
        let base = uiColor((s.r * d, s.g * d * 0.92, s.b * d * 0.88))
        m.diffuse.contents = base
        m.metalness.contents = 0.0
        m.roughness.contents = min(0.72, phenotype.skinRoughness + 0.12)
        m.clearCoat.contents = 0.2
        m.clearCoatRoughness.contents = 0.55
        m.emission.contents = base.withAlphaComponent(0.04)
        m.transparencyMode = .aOne
        return m
    }

    private static func makeSkin(
        sex: AvatarBodySex,
        phenotype: AvatarBodyPhenotype,
        soft: Bool,
        region: SkinRegion
    ) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        let base = uiColor(phenotype.skinRGB(sex: sex))
        // 写实皮肤 tile（宏纹理 / 肢体裁切）+ 表型 tint；全裸零遮盖不变
        if let tile = loadSkinTile(for: phenotype, sex: sex, region: region) {
            m.diffuse.contents = tile
            m.multiply.contents = base
            m.diffuse.wrapS = .repeat
            m.diffuse.wrapT = .repeat
            let s: Float = region == .torso ? 2.4 : 1.8
            m.diffuse.contentsTransform = SCNMatrix4MakeScale(s, s, 1)
        } else {
            m.diffuse.contents = base
        }
        if let bump = loadSkinBump() {
            m.ambientOcclusion.contents = bump
            m.ambientOcclusion.intensity = soft ? 0.28 : 0.38
            m.ambientOcclusion.wrapS = .repeat
            m.ambientOcclusion.wrapT = .repeat
            m.ambientOcclusion.contentsTransform = SCNMatrix4MakeScale(2.4, 2.4, 1)
        }
        if let nrm = loadSkinNormal(for: phenotype) {
            m.normal.contents = nrm
            m.normal.intensity = soft ? 0.35 : 0.55
            m.normal.wrapS = .repeat
            m.normal.wrapT = .repeat
            m.normal.contentsTransform = SCNMatrix4MakeScale(2.4, 2.4, 1)
        }
        m.metalness.contents = 0.0
        let rough = phenotype.skinRoughness
        m.roughness.contents = soft ? max(0.28, rough - 0.06) : rough
        m.clearCoat.contents = soft ? 0.48 : 0.32
        m.clearCoatRoughness.contents = soft ? 0.38 : 0.48
        let emitA: CGFloat = phenotype.skinLuminance < 0.4 ? 0.10 : 0.06
        m.emission.contents = base.withAlphaComponent(emitA)
        m.transparencyMode = .aOne
        return m
    }

    /// 表型/区域 → 皮肤 tile 候选（优先 photoreal 无遮盖裁切）。
    private static func skinTileCandidates(
        phenotype: AvatarBodyPhenotype,
        sex: AvatarBodySex,
        region: SkinRegion
    ) -> [String] {
        var names: [String] = []
        switch region {
        case .limb:
            names.append(sex == .male ? "skin_limb_male" : "skin_limb_female")
            names.append("skin_torso_side")
        case .thigh:
            names.append(sex == .male ? "skin_thigh_male" : "skin_thigh_female")
            names.append(sex == .male ? "skin_limb_male" : "skin_limb_female")
        case .torso:
            names.append("skin_torso_side")
        }
        // 写实宏纹理（从批准 photoreal 臂/腿混合；非全裸 body 图）
        if phenotype.skinLuminance < 0.45 {
            names.append("skin_photoreal_macro_deep")
        } else {
            names.append("skin_photoreal_macro")
        }
        switch phenotype {
        case .european:
            names.append("skin_light_fair")
        case .african:
            names.append("skin_deep_brown")
        case .southAsian, .latinx, .middleEastern, .indigenous:
            names.append("skin_olive_warm")
        case .eastAsian, .southeastAsian:
            names.append("skin_medium_warm")
        }
        return names
    }

    private static func loadSkinTile(
        for phenotype: AvatarBodyPhenotype,
        sex: AvatarBodySex,
        region: SkinRegion
    ) -> UIImage? {
        for name in skinTileCandidates(phenotype: phenotype, sex: sex, region: region) {
            if let img = loadBodyAvatarImage(name: name, subdirectory: "BodyAvatar/Skin") {
                return img
            }
        }
        return nil
    }

    private static func loadSkinBump() -> UIImage? {
        loadBodyAvatarImage(name: "skin_bump", subdirectory: "BodyAvatar/Skin")
    }

    private static func loadSkinNormal(for phenotype: AvatarBodyPhenotype) -> UIImage? {
        let name = phenotype.skinLuminance < 0.45 ? "skin_normal_deep" : "skin_normal"
        return loadBodyAvatarImage(name: name, subdirectory: "BodyAvatar/Skin")
    }

    /// 写实脸投影材质（仅头裁切 PNG；缺省 nil → 程序化五官）。
    static func facePlateMaterial(sex: AvatarBodySex, phenotype: AvatarBodyPhenotype) -> SCNMaterial? {
        guard let name = BodyAvatarAsset.resolveFacePlateName(
            sex: sex,
            phenotype: phenotype,
            available: { facePlateExists($0) }
        ), let img = loadBodyAvatarImage(name: name, subdirectory: "BodyAvatar/Face")
            ?? loadBodyAvatarImage(name: name, subdirectory: nil)
        else { return nil }
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = img
        // SE Asian 略暖 tint；其他匹配 phenotype 的轻量 multiply（仍是东亚脸源）
        if phenotype == .southeastAsian {
            m.multiply.contents = UIColor(red: 0.98, green: 0.94, blue: 0.90, alpha: 1)
        }
        m.metalness.contents = 0.0
        m.roughness.contents = 0.42
        m.clearCoat.contents = 0.22
        m.clearCoatRoughness.contents = 0.5
        m.isDoubleSided = false
        m.transparencyMode = .aOne
        // 轻度自发光避免棚光把脸压成剪影
        m.emission.contents = UIColor.white.withAlphaComponent(0.04)
        return m
    }

    /// 腹侧写实皮肤（navel 区裁切；catalog 路径不依赖 pastie 纹理）。
    static func torsoFrontPlateMaterial(
        sex: AvatarBodySex,
        phenotype: AvatarBodyPhenotype
    ) -> SCNMaterial? {
        let names = [
            "skin_torso_front_\(sex.rawValue)",
            sex == .male ? "skin_torso_front_male" : "skin_torso_front_female",
            "skin_torso_front",
        ]
        var img: UIImage?
        for n in names {
            img = loadBodyAvatarImage(name: n, subdirectory: "BodyAvatar/Skin")
                ?? loadBodyAvatarImage(name: n, subdirectory: nil)
            if img != nil { break }
        }
        guard let img else { return nil }
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = img
        let tint = uiColor(phenotype.skinRGB(sex: sex))
        m.multiply.contents = tint
        m.metalness.contents = 0.0
        m.roughness.contents = phenotype.skinRoughness
        m.clearCoat.contents = 0.28
        m.clearCoatRoughness.contents = 0.45
        m.isDoubleSided = false
        m.transparencyMode = .aOne
        m.writesToDepthBuffer = true
        return m
    }

    private static func facePlateExists(_ name: String) -> Bool {
        Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "BodyAvatar/Face") != nil
            || Bundle.module.url(forResource: name, withExtension: "png") != nil
    }

    private static func loadBodyAvatarImage(name: String, subdirectory: String?) -> UIImage? {
        if let sub = subdirectory,
           let u = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: sub)
        {
            return UIImage(contentsOfFile: u.path)
        }
        if let u = Bundle.module.url(forResource: name, withExtension: "png") {
            return UIImage(contentsOfFile: u.path)
        }
        return UIImage(named: name, in: .module, with: nil)
    }

    static func hairMaterial(sex: AvatarBodySex, phenotype: AvatarBodyPhenotype) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = uiColor(phenotype.hairRGB)
        m.metalness.contents = 0.05
        m.roughness.contents = phenotype == .european ? 0.48 : 0.58
        m.clearCoat.contents = 0.4
        m.clearCoatRoughness.contents = 0.3
        return m
    }

    /// 眉等发色系五官微特征（随 phenotype.hairRGB）。
    static func featureMaterial(phenotype: AvatarBodyPhenotype, sex: AvatarBodySex) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        let h = phenotype.hairRGB
        let s = phenotype.skinRGB(sex: sex)
        // 发色与肤色混合，避免贴片感
        m.diffuse.contents = uiColor((
            h.r * 0.55 + s.r * 0.45,
            h.g * 0.55 + s.g * 0.45,
            h.b * 0.55 + s.b * 0.45
        ))
        m.metalness.contents = 0.0
        m.roughness.contents = 0.65
        return m
    }

    static func faceShadeMaterial(phenotype: AvatarBodyPhenotype, sex: AvatarBodySex) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        let s = phenotype.skinRGB(sex: sex)
        m.diffuse.contents = uiColor((s.r * 0.85, s.g * 0.82, s.b * 0.80), a: 0.35)
        m.transparency = 0.55
        m.roughness.contents = phenotype.skinRoughness + 0.1
        m.metalness.contents = 0
        return m
    }
    #else
    static let keyLight: NSColor = NSColor(red: 1.0, green: 0.96, blue: 0.92, alpha: 1)
    static let fillLight: NSColor = NSColor(red: 0.85, green: 0.90, blue: 1.0, alpha: 1)
    static let rimLight: NSColor = NSColor(red: 1.0, green: 0.98, blue: 0.95, alpha: 1)
    static let ambient: NSColor = NSColor(white: 0.88, alpha: 1)

    static func nsColor(_ rgb: (r: Double, g: Double, b: Double), a: CGFloat = 1) -> NSColor {
        NSColor(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: a)
    }

    static func skinMaterial(sex: AvatarBodySex, phenotype: AvatarBodyPhenotype) -> SCNMaterial {
        makeSkin(sex: sex, phenotype: phenotype, soft: false, region: .torso)
    }

    static func softSkinMaterial(sex: AvatarBodySex, phenotype: AvatarBodyPhenotype) -> SCNMaterial {
        makeSkin(sex: sex, phenotype: phenotype, soft: true, region: .torso)
    }

    static func limbSkinMaterial(sex: AvatarBodySex, phenotype: AvatarBodyPhenotype) -> SCNMaterial {
        makeSkin(sex: sex, phenotype: phenotype, soft: false, region: .limb)
    }

    static func thighSkinMaterial(sex: AvatarBodySex, phenotype: AvatarBodyPhenotype) -> SCNMaterial {
        makeSkin(sex: sex, phenotype: phenotype, soft: false, region: .thigh)
    }

    private enum SkinRegion { case torso, limb, thigh }

    static func areolaMaterial(sex: AvatarBodySex, phenotype: AvatarBodyPhenotype) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        let s = phenotype.skinRGB(sex: sex)
        let d = phenotype.areolaDarken
        let base = nsColor((s.r * d, s.g * d * 0.92, s.b * d * 0.88))
        m.diffuse.contents = base
        m.metalness.contents = 0.0
        m.roughness.contents = min(0.72, phenotype.skinRoughness + 0.12)
        m.clearCoat.contents = 0.2
        m.clearCoatRoughness.contents = 0.55
        m.emission.contents = base.withAlphaComponent(0.04)
        return m
    }

    private static func makeSkin(
        sex: AvatarBodySex,
        phenotype: AvatarBodyPhenotype,
        soft: Bool,
        region: SkinRegion
    ) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        let base = nsColor(phenotype.skinRGB(sex: sex))
        if let tile = loadSkinTile(for: phenotype, sex: sex, region: region) {
            m.diffuse.contents = tile
            m.multiply.contents = base
            m.diffuse.wrapS = .repeat
            m.diffuse.wrapT = .repeat
            let s: CGFloat = region == .torso ? 2.4 : 1.8
            m.diffuse.contentsTransform = SCNMatrix4MakeScale(s, s, 1)
        } else {
            m.diffuse.contents = base
        }
        if let bump = loadSkinBump() {
            m.ambientOcclusion.contents = bump
            m.ambientOcclusion.intensity = soft ? 0.28 : 0.38
            m.ambientOcclusion.wrapS = .repeat
            m.ambientOcclusion.wrapT = .repeat
            m.ambientOcclusion.contentsTransform = SCNMatrix4MakeScale(2.4, 2.4, 1)
        }
        if let nrm = loadSkinNormal(for: phenotype) {
            m.normal.contents = nrm
            m.normal.intensity = soft ? 0.35 : 0.55
            m.normal.wrapS = .repeat
            m.normal.wrapT = .repeat
            m.normal.contentsTransform = SCNMatrix4MakeScale(2.4, 2.4, 1)
        }
        m.metalness.contents = 0.0
        let rough = phenotype.skinRoughness
        m.roughness.contents = soft ? max(0.28, rough - 0.06) : rough
        m.clearCoat.contents = soft ? 0.48 : 0.32
        m.clearCoatRoughness.contents = soft ? 0.38 : 0.48
        let emitA: CGFloat = phenotype.skinLuminance < 0.4 ? 0.10 : 0.06
        m.emission.contents = base.withAlphaComponent(emitA)
        return m
    }

    private static func skinTileCandidates(
        phenotype: AvatarBodyPhenotype,
        sex: AvatarBodySex,
        region: SkinRegion
    ) -> [String] {
        var names: [String] = []
        switch region {
        case .limb:
            names.append(sex == .male ? "skin_limb_male" : "skin_limb_female")
            names.append("skin_torso_side")
        case .thigh:
            names.append(sex == .male ? "skin_thigh_male" : "skin_thigh_female")
            names.append(sex == .male ? "skin_limb_male" : "skin_limb_female")
        case .torso:
            names.append("skin_torso_side")
        }
        if phenotype.skinLuminance < 0.45 {
            names.append("skin_photoreal_macro_deep")
        } else {
            names.append("skin_photoreal_macro")
        }
        switch phenotype {
        case .european:
            names.append("skin_light_fair")
        case .african:
            names.append("skin_deep_brown")
        case .southAsian, .latinx, .middleEastern, .indigenous:
            names.append("skin_olive_warm")
        case .eastAsian, .southeastAsian:
            names.append("skin_medium_warm")
        }
        return names
    }

    private static func loadSkinTile(
        for phenotype: AvatarBodyPhenotype,
        sex: AvatarBodySex,
        region: SkinRegion
    ) -> NSImage? {
        for name in skinTileCandidates(phenotype: phenotype, sex: sex, region: region) {
            if let img = loadBodyAvatarNSImage(name: name, subdirectory: "BodyAvatar/Skin") {
                return img
            }
        }
        return nil
    }

    private static func loadSkinBump() -> NSImage? {
        loadBodyAvatarNSImage(name: "skin_bump", subdirectory: "BodyAvatar/Skin")
    }

    private static func loadSkinNormal(for phenotype: AvatarBodyPhenotype) -> NSImage? {
        let name = phenotype.skinLuminance < 0.45 ? "skin_normal_deep" : "skin_normal"
        return loadBodyAvatarNSImage(name: name, subdirectory: "BodyAvatar/Skin")
    }

    static func facePlateMaterial(sex: AvatarBodySex, phenotype: AvatarBodyPhenotype) -> SCNMaterial? {
        guard let name = BodyAvatarAsset.resolveFacePlateName(
            sex: sex,
            phenotype: phenotype,
            available: { facePlateExists($0) }
        ), let img = loadBodyAvatarNSImage(name: name, subdirectory: "BodyAvatar/Face")
            ?? loadBodyAvatarNSImage(name: name, subdirectory: nil)
        else { return nil }
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = img
        if phenotype == .southeastAsian {
            m.multiply.contents = NSColor(red: 0.98, green: 0.94, blue: 0.90, alpha: 1)
        }
        m.metalness.contents = 0.0
        m.roughness.contents = 0.42
        m.clearCoat.contents = 0.22
        m.clearCoatRoughness.contents = 0.5
        m.isDoubleSided = false
        m.emission.contents = NSColor.white.withAlphaComponent(0.04)
        return m
    }

    static func torsoFrontPlateMaterial(
        sex: AvatarBodySex,
        phenotype: AvatarBodyPhenotype
    ) -> SCNMaterial? {
        let name = sex == .male ? "skin_torso_front_male" : "skin_torso_front_female"
        guard let img = loadBodyAvatarNSImage(name: name, subdirectory: "BodyAvatar/Skin") else {
            return nil
        }
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = img
        m.multiply.contents = nsColor(phenotype.skinRGB(sex: sex))
        m.metalness.contents = 0.0
        m.roughness.contents = phenotype.skinRoughness
        m.clearCoat.contents = 0.28
        m.clearCoatRoughness.contents = 0.45
        m.isDoubleSided = false
        return m
    }

    private static func facePlateExists(_ name: String) -> Bool {
        Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "BodyAvatar/Face") != nil
            || Bundle.module.url(forResource: name, withExtension: "png") != nil
    }

    private static func loadBodyAvatarNSImage(name: String, subdirectory: String?) -> NSImage? {
        if let sub = subdirectory,
           let u = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: sub)
        {
            return NSImage(contentsOf: u)
        }
        if let u = Bundle.module.url(forResource: name, withExtension: "png") {
            return NSImage(contentsOf: u)
        }
        return nil
    }

    static func hairMaterial(sex: AvatarBodySex, phenotype: AvatarBodyPhenotype) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = nsColor(phenotype.hairRGB)
        m.metalness.contents = 0.05
        m.roughness.contents = phenotype == .european ? 0.48 : 0.58
        m.clearCoat.contents = 0.4
        m.clearCoatRoughness.contents = 0.3
        return m
    }

    static func featureMaterial(phenotype: AvatarBodyPhenotype, sex: AvatarBodySex) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        let h = phenotype.hairRGB
        let s = phenotype.skinRGB(sex: sex)
        m.diffuse.contents = nsColor((
            h.r * 0.55 + s.r * 0.45,
            h.g * 0.55 + s.g * 0.45,
            h.b * 0.55 + s.b * 0.45
        ))
        m.metalness.contents = 0.0
        m.roughness.contents = 0.65
        return m
    }

    static func faceShadeMaterial(phenotype: AvatarBodyPhenotype, sex: AvatarBodySex) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        let s = phenotype.skinRGB(sex: sex)
        m.diffuse.contents = nsColor((s.r * 0.85, s.g * 0.82, s.b * 0.80), a: 0.35)
        m.transparency = 0.55
        m.roughness.contents = phenotype.skinRoughness + 0.1
        return m
    }
    #endif
}
