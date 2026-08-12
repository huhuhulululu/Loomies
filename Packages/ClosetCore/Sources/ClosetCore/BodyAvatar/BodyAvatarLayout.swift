import Foundation

/// 人体 croquis 布局（DESIGN §F6 v1.x 纸娃娃，表达层）。
/// 不写实试穿：比例示意 + 槽位锚点叠衣；隐私数据只驱动缩放，不离端。
public enum BodyAvatarSlot: String, CaseIterable, Sendable {
    case outerwear, top, dress, bottom, shoes
}

/// 画布归一化矩形（0…1，原点左上，y 向下）。
public struct NormalizedRect: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}

/// 槽位锚点表：相对 croquis 画布的固定百分比（设计 brief）。
public enum BodyAvatarAnchors {
    /// 槽位框：中心水平、按人体比例纵向分区（D49：肩线贴合略收紧）。
    public static func frame(for slot: BodyAvatarSlot) -> NormalizedRect {
        switch slot {
        case .outerwear: return NormalizedRect(x: 0.16, y: 0.13, width: 0.68, height: 0.50)
        case .top:       return NormalizedRect(x: 0.21, y: 0.155, width: 0.58, height: 0.30)
        case .dress:     return NormalizedRect(x: 0.19, y: 0.15, width: 0.62, height: 0.54)
        case .bottom:    return NormalizedRect(x: 0.23, y: 0.415, width: 0.54, height: 0.36)
        case .shoes:     return NormalizedRect(x: 0.29, y: 0.815, width: 0.42, height: 0.13)
        }
    }

    /// z-order（大者在上）：鞋 < 下装 < 上装/裙 < 外套
    public static func zIndex(for slot: BodyAvatarSlot) -> Int {
        switch slot {
        case .shoes: return 1
        case .bottom: return 2
        case .top, .dress: return 3
        case .outerwear: return 4
        }
    }
}

/// 由围度推导的 croquis 缩放（避免无界拉伸导致 uncanny）。
public struct BodyAvatarScale: Equatable, Sendable {
    /// 水平缩放（肩/胸/臀综合），限制在 [0.88, 1.14]
    public var widthScale: Double
    /// 臀区额外宽度因子（梨形），限制在 [0.95, 1.12]
    public var hipScale: Double
    /// 腰区收腰因子（沙漏），限制在 [0.90, 1.05]
    public var waistScale: Double

    public init(widthScale: Double, hipScale: Double, waistScale: Double) {
        self.widthScale = widthScale
        self.hipScale = hipScale
        self.waistScale = waistScale
    }
}

public enum BodyAvatarScaler {
    /// 以「中性矩形」参考围度（英寸）为 1.0，再按比例缩放并 clamp。
    public static let refBust: Double = 36
    public static let refWaist: Double = 28
    public static let refHip: Double = 38

    public static func scale(from m: BodyMeasurements) -> BodyAvatarScale {
        // 无效围度（非有限 / ≤0）视为缺失 → 该字段中性 1.0（与 BodyMorphParams.from 一致），
        // 而非默默钳到 scaleLo（极瘦变形）。
        func ratio(_ value: Double, ref: Double) -> Double {
            guard value.isFinite, value > 0 else { return 1 }
            return value / ref
        }
        let bustR = ratio(m.bust, ref: refBust)
        let hipR = ratio(m.hip, ref: refHip)
        let waistR = ratio(m.waist, ref: refWaist)
        // 整体宽取 bust/hip 均值，避免单点畸变（腰用 waistScale 单独表达）
        let width = clamp((bustR + hipR) / 2, 0.88, 1.14)
        // 臀相对胸的富余 → hipScale
        let hipExtra = clamp(hipR / bustR, 0.95, 1.12)
        // 腰相对胸的收紧 → waistScale（越小越收腰）
        let waistTight = clamp(waistR / bustR, 0.90, 1.05)
        return BodyAvatarScale(widthScale: width, hipScale: hipExtra, waistScale: waistTight)
    }

    public static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        min(hi, max(lo, v))
    }
}

/// 360° 体型参考偏航角（每 45° 一帧，静态切帧，不做插值动画）。
public enum BodyAvatarYaw: Int, CaseIterable, Sendable, Comparable {
    case deg0 = 0       // 正面
    case deg45 = 45     // 右前 3/4
    case deg90 = 90     // 右侧
    case deg135 = 135   // 右后 3/4
    case deg180 = 180   // 背面
    case deg225 = 225   // 左后 3/4
    case deg270 = 270   // 左侧
    case deg315 = 315   // 左前 3/4

    public static func < (lhs: BodyAvatarYaw, rhs: BodyAvatarYaw) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// 资源后缀：`yaw000` … `yaw315`
    public var assetSuffix: String {
        String(format: "yaw%03d", rawValue)
    }

    public var shortLabel: String {
        switch self {
        case .deg0: return "Front"
        case .deg45: return "¾ R"
        case .deg90: return "Right"
        case .deg135: return "¾ BR"
        case .deg180: return "Back"
        case .deg225: return "¾ BL"
        case .deg270: return "Left"
        case .deg315: return "¾ L"
        }
    }

    /// 拖拽步进：delta>0 向右转（角度增加）。
    public func stepped(by steps: Int) -> BodyAvatarYaw {
        let all = Self.allCases
        guard let i = all.firstIndex(of: self) else { return self }
        let n = all.count
        let j = ((i + steps) % n + n) % n
        return all[j]
    }

    /// 将任意角度（度）吸附到最近的 45° 档。
    public static func nearest(degrees: Double) -> BodyAvatarYaw {
        // NaN/±inf 会穿过 truncatingRemainder 并在 Int() 处触发运行时 trap；非有限输入吸附到正面。
        guard degrees.isFinite else { return .deg0 }
        var d = degrees.truncatingRemainder(dividingBy: 360)
        if d < 0 { d += 360 }
        let idx = Int((d / 45.0).rounded()) % allCases.count
        return allCases[idx]
    }
}

/// croquis / 写实 nude 资源名（无扩展名，对应 Bundle PNG）。
public enum BodyAvatarAsset {
    /// 兼容旧名：无 yaw 后缀 = 正面（yaw000）。
    public static func croquisName(for shape: PopularShape) -> String {
        croquisName(for: shape, yaw: .deg0)
    }

    public static func croquisName(for shape: PopularShape, yaw: BodyAvatarYaw) -> String {
        "croquis_\(shapeKey(shape))_\(yaw.assetSuffix)"
    }

    /// 旧正面资源名（无 yaw）；加载时作 fallback。
    public static func legacyFrontName(for shape: PopularShape) -> String {
        "croquis_\(shapeKey(shape))"
    }

    /// GPT/锁定写实 **全 nude** 正面（按性别；与 5 体型 croquis 解耦）。
    /// 优先用 `NudeBodyBaseSpec.photorealFrontName(sex:phenotype:)` 多人种变体。
    public static func photorealFrontName(sex: AvatarBodySex) -> String {
        switch sex {
        case .female: return "photoreal_female_front"
        case .male: return "photoreal_male_front"
        }
    }

    /// 真人全裸多角切帧（通用 sex）。`deg0` → `photoreal_{sex}_front`；其余 `photoreal_{sex}_yaw045` …
    public static func photorealFrameName(sex: AvatarBodySex, yaw: BodyAvatarYaw) -> String {
        if yaw == .deg0 { return photorealFrontName(sex: sex) }
        return "photoreal_\(sex.rawValue)_\(yaw.assetSuffix)"
    }

    /// 真人全裸多角切帧（sex×phenotype）。`deg0` → `…_front`；其余 `photoreal_{sex}_{phenotype}_yaw###`。
    public static func photorealFrameName(
        sex: AvatarBodySex,
        phenotype: AvatarBodyPhenotype,
        yaw: BodyAvatarYaw
    ) -> String {
        if yaw == .deg0 {
            return NudeBodyBaseSpec.photorealFrontName(sex: sex, phenotype: phenotype)
        }
        return "photoreal_\(sex.rawValue)_\(phenotype.rawValue)_\(yaw.assetSuffix)"
    }

    /// 体型专属帧（+64 正面档起）：`photoreal_{sex}_{phenotype}_{shape}_front` /
    /// `…_{shape}_yaw###`。体型不再只靠 warp 拉伸单张基础图——shape 真图命中时
    /// View 侧旁路 shape preset warp（防「真体型 + 拉伸」双重效果）。
    public static func photorealFrameName(
        sex: AvatarBodySex,
        phenotype: AvatarBodyPhenotype,
        shape: PopularShape,
        yaw: BodyAvatarYaw
    ) -> String {
        let base = "photoreal_\(sex.rawValue)_\(phenotype.rawValue)_\(shape.rawValue)"
        return yaw == .deg0 ? "\(base)_front" : "\(base)_\(yaw.assetSuffix)"
    }

    /// 名字是否携带 shape token（View 判定是否旁路 shape preset warp）。
    public static func photorealNameCarriesShape(_ name: String) -> Bool {
        PopularShape.allCases.contains { name.contains("_\($0.rawValue)_") }
    }

    /// 正面档导入清单：2 sex × 8 phenotype × 5 shape = 80。
    public static var allPhotorealShapeFrontNames: [String] {
        AvatarBodySex.allCases.flatMap { sex in
            AvatarBodyPhenotype.allCases.flatMap { phenotype in
                PopularShape.allCases.map {
                    photorealFrameName(sex: sex, phenotype: phenotype, shape: $0, yaw: .deg0)
                }
            }
        }
    }

    /// 显式 `yaw000` 别名（与 `_front` 等价；导入管线可任选其一）。
    public static func photorealYaw000Alias(sex: AvatarBodySex) -> String {
        "photoreal_\(sex.rawValue)_yaw000"
    }

    public static func photorealYaw000Alias(
        sex: AvatarBodySex,
        phenotype: AvatarBodyPhenotype
    ) -> String {
        "photoreal_\(sex.rawValue)_\(phenotype.rawValue)_yaw000"
    }

    /// 解析可用写实正面：先 phenotype 专用，再通用 sex 正面。
    public static func resolvePhotorealFrontName(
        sex: AvatarBodySex,
        phenotype: AvatarBodyPhenotype,
        available: (String) -> Bool
    ) -> String? {
        resolvePhotorealFrameName(sex: sex, phenotype: phenotype, yaw: .deg0, available: available)
    }

    /// 解析可用 catalog 真人多角帧（认证门由 `available` 调用方叠加 `mayUsePhotorealFrontAsset`）。
    /// - 正面：phenotype×front → phenotype×yaw000 → sex×front → sex×yaw000
    /// - 非正面：phenotype×yaw 优先；**有表型专用正面时不回退 sex×yaw**（防换人，D69）
    ///   仅 eastAsian / 无表型正面时才用通用 sex×yaw 轨道。
    /// 非正面缺帧时返回 nil，UI soft-hold 本表型正面。
    /// Shape 感知重载：体型专属帧优先（front 与 yaw 皆然），缺帧回退无 shape 链路
    ///（含 D69 防换人守卫）。shape == nil 时与旧签名行为完全一致。
    public static func resolvePhotorealFrameName(
        sex: AvatarBodySex,
        phenotype: AvatarBodyPhenotype,
        shape: PopularShape?,
        yaw: BodyAvatarYaw,
        available: (String) -> Bool
    ) -> String? {
        if let shape {
            let shaped = photorealFrameName(sex: sex, phenotype: phenotype, shape: shape, yaw: yaw)
            if available(shaped) { return shaped }
        }
        return resolvePhotorealFrameName(sex: sex, phenotype: phenotype, yaw: yaw, available: available)
    }

    public static func resolvePhotorealFrameName(
        sex: AvatarBodySex,
        phenotype: AvatarBodyPhenotype,
        yaw: BodyAvatarYaw,
        available: (String) -> Bool
    ) -> String? {
        if yaw == .deg0 {
            let candidates = [
                NudeBodyBaseSpec.photorealFrontName(sex: sex, phenotype: phenotype),
                photorealYaw000Alias(sex: sex, phenotype: phenotype),
                photorealFrontName(sex: sex),
                photorealYaw000Alias(sex: sex),
            ]
            for name in candidates where available(name) {
                return name
            }
            return nil
        }

        let phenotypeYaw = photorealFrameName(sex: sex, phenotype: phenotype, yaw: yaw)
        if available(phenotypeYaw) { return phenotypeYaw }

        // Identity guard (D69): non-default phenotype with its own front must not
        // pick a generic multi-angle of a different person.
        let phenotypeFront = NudeBodyBaseSpec.photorealFrontName(sex: sex, phenotype: phenotype)
        let hasOwnFront = available(phenotypeFront)
        let mayUseGenericOrbit = phenotype == .eastAsian || !hasOwnFront
        if mayUseGenericOrbit {
            let genericYaw = photorealFrameName(sex: sex, yaw: yaw)
            if available(genericYaw) { return genericYaw }
        }
        return nil
    }

    /// 全 sex×phenotype×8yaw 资源名（导入清单 / 测试 inventory）。
    public static var allPhotorealFrameNames: [String] {
        AvatarBodySex.allCases.flatMap { sex in
            AvatarBodyPhenotype.allCases.flatMap { phenotype in
                BodyAvatarYaw.allCases.map {
                    photorealFrameName(sex: sex, phenotype: phenotype, yaw: $0)
                }
            }
        }
    }

    /// 写实脸贴图（仅头部，零躯体遮盖）— 从已批准 photoreal 正面裁切。
    /// 命名：`face_{sex}_{phenotype}`；缺 phenotype 时回退 `face_{sex}_eastAsian`。
    public static func facePlateName(sex: AvatarBodySex, phenotype: AvatarBodyPhenotype) -> String {
        "face_\(sex.rawValue)_\(phenotype.rawValue)"
    }

    /// 当前入库的默认写实脸（东亚洲 F/M 参考脸）。
    public static func facePlateFallbackName(sex: AvatarBodySex) -> String {
        "face_\(sex.rawValue)_eastAsian"
    }

    /// 解析脸贴：phenotype 专用优先 → eastAsian 回退（仅脸；零躯体遮盖）。
    /// 多人种专用脸入库后各表型用专用；缺省才回退东亚参考脸。
    public static func resolveFacePlateName(
        sex: AvatarBodySex,
        phenotype: AvatarBodyPhenotype,
        available: (String) -> Bool
    ) -> String? {
        let specific = facePlateName(sex: sex, phenotype: phenotype)
        if available(specific) { return specific }
        let fallback = facePlateFallbackName(sex: sex)
        if available(fallback) { return fallback }
        return nil
    }

    /// 全部 sex×phenotype 脸贴资源名（2×8）。
    public static var allFacePlateNames: [String] {
        AvatarBodySex.allCases.flatMap { sex in
            AvatarBodyPhenotype.allCases.map { facePlateName(sex: sex, phenotype: $0) }
        }
    }

    public static func shapeKey(_ shape: PopularShape) -> String {
        switch shape {
        case .hourglass: return "hourglass"
        case .pear: return "pear"
        case .apple: return "apple"
        case .rectangle: return "rectangle"
        case .invertedTriangle: return "invertedTriangle"
        }
    }

    /// 全部 5 体型 × 8 角资源名。
    public static var allNames: [String] {
        PopularShape.allCases.flatMap { shape in
            BodyAvatarYaw.allCases.map { croquisName(for: shape, yaw: $0) }
        }
    }

    public static var angleCount: Int { BodyAvatarYaw.allCases.count }
    public static var shapeCount: Int { PopularShape.allCases.count }
}

/// 叠衣层描述（UI 只消费此结构）。
public struct BodyAvatarLayer: Equatable, Sendable, Identifiable {
    public var id: String
    public var slot: BodyAvatarSlot
    public var frame: NormalizedRect
    public var zIndex: Int
    /// Bundle asset 名（可选）
    public var imageAssetName: String?
    /// Application Support 相对路径（入库抠图，可选）
    public var localRelativePath: String?
    /// 用户/归一化微调：1 = 默认；>1 略放大贴肩
    public var fitScale: Double
    /// 归一化垂直偏移（相对画布高，负=上移贴肩）
    public var fitOffsetY: Double

    public init(
        id: String,
        slot: BodyAvatarSlot,
        frame: NormalizedRect,
        zIndex: Int,
        imageAssetName: String? = nil,
        localRelativePath: String? = nil,
        fitScale: Double = 1,
        fitOffsetY: Double = 0
    ) {
        self.id = id
        self.slot = slot
        self.frame = frame
        self.zIndex = zIndex
        self.imageAssetName = imageAssetName
        self.localRelativePath = localRelativePath
        self.fitScale = fitScale
        self.fitOffsetY = fitOffsetY
    }

    public var hasVisual: Bool {
        (imageAssetName?.isEmpty == false) || (localRelativePath?.isEmpty == false)
    }

    /// 槽位默认贴合：上装/外套略放大并上移贴肩。
    public static func defaultFit(for slot: BodyAvatarSlot) -> (scale: Double, offsetY: Double) {
        switch slot {
        case .outerwear: return (1.06, -0.01)
        case .top: return (1.04, -0.012)
        case .dress: return (1.03, -0.008)
        case .bottom: return (1.02, 0.0)
        case .shoes: return (1.0, 0.01)
        }
    }
}

/// 叠衣像素框：UI 与分享导出共用，避免 fitScale / 肩线上移只在一侧生效。
public enum BodyAvatarGarmentLayout {
    /// 槽位框路径：无图占位色块等「紧内容」层。
    public static func pixelFrame(
        layer: BodyAvatarLayer,
        canvasWidth: Double,
        canvasHeight: Double,
        morph: BodyMorphParams
    ) -> NormalizedRect {
        let f = layer.frame
        let m = morph.clamped()
        let midY = f.y + f.height / 2
        let sx = m.horizontalScale(normalizedY: midY)
        let fit = max(0.85, min(1.25, layer.fitScale))
        let w = f.width * canvasWidth * sx * fit
        let h = f.height * canvasHeight * m.height * fit
        let cx = 0.5 * canvasWidth + (f.x + f.width / 2 - 0.5) * canvasWidth * sx
        let cy = (f.y + f.height / 2 + layer.fitOffsetY) * canvasHeight * m.height
            + (m.height - 1) * canvasHeight * 0.015
        return NormalizedRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
    }

    /// 入库/演示层：已铺在 512×768 **全身画布**（肩腰脚已对齐）。
    /// 必须按全身合成，禁止再套槽位框——否则双重缩小成「胸前小贴纸」。
    public static func fullCanvasPixelFrame(
        layer: BodyAvatarLayer,
        canvasWidth: Double,
        canvasHeight: Double,
        morph: BodyMorphParams
    ) -> NormalizedRect {
        let m = morph.clamped()
        let midY = layer.frame.y + layer.frame.height / 2
        let sx = m.horizontalScale(normalizedY: midY)
        let fit = max(0.85, min(1.25, layer.fitScale))
        let w = canvasWidth * sx * fit
        let h = canvasHeight * m.height * fit
        let cx = canvasWidth / 2
        // 与 BodyMorphImageView 一致：height 从中心 scale；fitOffsetY 微调肩线
        let cy = canvasHeight / 2
            + layer.fitOffsetY * canvasHeight * m.height
        return NormalizedRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
    }

    /// 有视觉资产 → 全身画布；否则 → 槽位占位框。
    public static func displayFrame(
        layer: BodyAvatarLayer,
        canvasWidth: Double,
        canvasHeight: Double,
        morph: BodyMorphParams
    ) -> NormalizedRect {
        if layer.hasVisual {
            return fullCanvasPixelFrame(
                layer: layer,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                morph: morph)
        }
        return pixelFrame(
            layer: layer,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            morph: morph)
    }
}

/// 槽位图引用：bundle 名或本地相对路径。
public struct BodyAvatarSlotImage: Equatable, Sendable {
    public var id: String
    public var bundleName: String?
    public var localRelativePath: String?
    public init(id: String, bundleName: String? = nil, localRelativePath: String? = nil) {
        self.id = id
        self.bundleName = bundleName
        self.localRelativePath = localRelativePath
    }
}

public enum BodyAvatarComposer {
    /// 从候选单品槽位生成叠层（同槽取一件；dress 与 top/bottom 互斥时 dress 优先）。
    public static func layers(slots: [BodyAvatarSlot: String]) -> [BodyAvatarLayer] {
        let mapped = slots.mapValues { BodyAvatarSlotImage(id: $0, bundleName: $0) }
        return layers(slotImages: mapped)
    }

    /// 本地图 / bundle 统一入口。
    public static func layers(slotImages: [BodyAvatarSlot: BodyAvatarSlotImage]) -> [BodyAvatarLayer] {
        var active = slotImages
        if active[.dress] != nil {
            active[.top] = nil
            active[.bottom] = nil
        }
        return active.compactMap { slot, ref -> BodyAvatarLayer? in
            let fit = BodyAvatarLayer.defaultFit(for: slot)
            return BodyAvatarLayer(
                id: "\(slot.rawValue)-\(ref.id)",
                slot: slot,
                frame: BodyAvatarAnchors.frame(for: slot),
                zIndex: BodyAvatarAnchors.zIndex(for: slot),
                imageAssetName: ref.bundleName,
                localRelativePath: ref.localRelativePath,
                fitScale: fit.scale,
                fitOffsetY: fit.offsetY)
        }
        // (zIndex, id) 双键：Swift sort 非稳定，「zIndex 表无并列」是隐式前提，显式保证
        .sorted { ($0.zIndex, $0.id) < ($1.zIndex, $1.id) }
    }

    /// `GarmentSlot` / item.slotRaw → 叠衣槽（accessory 不叠）。
    /// 兼容常见别名，避免入库/导入写错导致纸娃娃穿不上。
    public static func mapSlot(_ raw: String) -> BodyAvatarSlot? {
        switch raw.lowercased() {
        case "outerwear", "outer", "coat", "jacket", "blazer", "parka", "cardigan",
             "bomber", "trench", "windbreaker", "puffer", "anorak", "vest", "gilet":
            return .outerwear
        case "top", "shirt", "tee", "tshirt", "blouse", "sweater", "knit",
             "polo", "henley", "tank", "hoodie":
            return .top
        case "dress", "gown", "jumpsuit", "romper":
            return .dress
        case "bottom", "pants", "trousers", "jeans", "skirt", "shorts", "chino",
             "leggings", "joggers", "cargo":
            return .bottom
        case "shoes", "shoe", "sneakers", "boots", "heels", "pumps", "loafers", "sandals",
             "flats", "mules", "oxfords", "oxford", "chelsea", "derby":
            return .shoes
        default:
            return nil
        }
    }

    /// 展示叠衣槽：在 mapSlot 基础上，用名称纠偏「西装写在 top」等历史/脏数据。
    public static func displaySlot(slotRaw: String, itemName: String) -> BodyAvatarSlot? {
        let base = mapSlot(slotRaw)
        // foldedKey：与 DemoGarmentSilhouette 同一折叠标准（大小写 locale 无关 + 变音符号）
        let n = TextNormalize.foldedKey(itemName)
        // 名称强烈暗示外套，但槽位误标 top → 提到 outerwear 以便与 tee 同层
        if base == .top,
           n.contains("blazer") || n.contains("jacket") || n.contains("coat")
            || n.contains("parka") || n.contains("overshirt") || n.contains("cardigan")
            || n.contains("bomber") || n.contains("trench") || n.contains("windbreaker")
            || n.contains("puffer") || n.contains("anorak") || n.contains("gilet")
        {
            return .outerwear
        }
        // 裤/裙误标 top（先于 dress：dress pants 是裤不是裙）
        if base == .top,
           n.contains("pants") || n.contains("trouser") || n.contains("jeans") || n.contains("chino")
            || n.contains("skirt") || n.contains("shorts")
            || n.contains("legging") || n.contains("jogger") || n.contains("cargo")
        {
            return .bottom
        }
        // 鞋误标（flats 复数，避免 flattering / flat-front 误伤）
        // oxford 排除 cloth/shirt（牛津纺衬衫 ≠ 牛津鞋），否则 Search/Type 会错进 Shoes
        if base == .top || base == .bottom {
            let oxfordIsFootwear = n.contains("oxford")
                && !n.contains("shirt") && !n.contains("cloth")
                && !n.contains("blouse") && !n.contains("button")
            let shoeHint = n.contains("shoe") || n.contains("sneaker") || n.contains("boot") || n.contains("heel")
                || n.contains("loafer") || n.contains("pump") || n.contains("sandal")
                || n.contains("flats") || n.contains("mule")
                || n.contains("chelsea") || n.contains("derby")
                || oxfordIsFootwear
            if shoeHint { return .shoes }
        }
        // 连衣裙/连体误标 top（放在裤/鞋之后：dress pants/dress shoes 不算裙）
        if base == .top,
           n.contains("dress") || n.contains("gown")
            || n.contains("jumpsuit") || n.contains("romper")
        {
            return .dress
        }
        return base
    }

    public static func resolveShape(from measurements: BodyMeasurements?) -> PopularShape {
        guard let m = measurements else { return .rectangle }
        // 脏输入（非有限/≤0）= 缺失：与 nil 测量同路，回退文档化默认 .rectangle。
        return FFITClassifier.classifyOrNil(m)?.popularCategory ?? .rectangle
    }
}
