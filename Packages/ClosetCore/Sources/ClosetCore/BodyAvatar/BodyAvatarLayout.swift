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
    /// 槽位框：中心水平、按人体比例纵向分区。
    public static func frame(for slot: BodyAvatarSlot) -> NormalizedRect {
        switch slot {
        case .outerwear: return NormalizedRect(x: 0.18, y: 0.14, width: 0.64, height: 0.48)
        case .top:       return NormalizedRect(x: 0.22, y: 0.16, width: 0.56, height: 0.28)
        case .dress:     return NormalizedRect(x: 0.20, y: 0.16, width: 0.60, height: 0.52)
        case .bottom:    return NormalizedRect(x: 0.24, y: 0.42, width: 0.52, height: 0.34)
        case .shoes:     return NormalizedRect(x: 0.30, y: 0.82, width: 0.40, height: 0.12)
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
        let bustR = m.bust / refBust
        let hipR = m.hip / refHip
        // 整体宽取 bust/hip 均值，避免单点畸变（腰用 waistScale 单独表达）
        let width = clamp((bustR + hipR) / 2, 0.88, 1.14)
        // 臀相对胸的富余 → hipScale
        let hipExtra = clamp(m.hip / max(m.bust, 1) / (refHip / refBust), 0.95, 1.12)
        // 腰相对胸的收紧 → waistScale（越小越收腰）
        let waistTight = clamp(m.waist / max(m.bust, 1) / (refWaist / refBust), 0.90, 1.05)
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
        var d = degrees.truncatingRemainder(dividingBy: 360)
        if d < 0 { d += 360 }
        let idx = Int((d / 45.0).rounded()) % allCases.count
        return allCases[idx]
    }
}

/// croquis 资源名（无扩展名，对应 Bundle PNG）。
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

    public init(
        id: String,
        slot: BodyAvatarSlot,
        frame: NormalizedRect,
        zIndex: Int,
        imageAssetName: String? = nil,
        localRelativePath: String? = nil
    ) {
        self.id = id
        self.slot = slot
        self.frame = frame
        self.zIndex = zIndex
        self.imageAssetName = imageAssetName
        self.localRelativePath = localRelativePath
    }

    public var hasVisual: Bool {
        (imageAssetName?.isEmpty == false) || (localRelativePath?.isEmpty == false)
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
            BodyAvatarLayer(
                id: "\(slot.rawValue)-\(ref.id)",
                slot: slot,
                frame: BodyAvatarAnchors.frame(for: slot),
                zIndex: BodyAvatarAnchors.zIndex(for: slot),
                imageAssetName: ref.bundleName,
                localRelativePath: ref.localRelativePath)
        }
        .sorted { $0.zIndex < $1.zIndex }
    }

    /// `GarmentSlot` / item.slotRaw → 叠衣槽（accessory 不叠）。
    public static func mapSlot(_ raw: String) -> BodyAvatarSlot? {
        switch raw.lowercased() {
        case "outerwear", "outer": return .outerwear
        case "top": return .top
        case "dress": return .dress
        case "bottom": return .bottom
        case "shoes", "shoe": return .shoes
        default: return nil
        }
    }

    public static func resolveShape(from measurements: BodyMeasurements?) -> PopularShape {
        guard let m = measurements else { return .rectangle }
        return FFITClassifier.classify(m).popularCategory
    }
}
