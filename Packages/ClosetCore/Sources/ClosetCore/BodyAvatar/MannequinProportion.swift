import Foundation

/// 展示用身体性别（纸娃娃底座；与推荐 FFIT 女性体型分类解耦）。
/// 男性后续扩底座比例，不走 AI 出图。
public enum AvatarBodySex: String, CaseIterable, Sendable {
    case female
    case male

    public var displayTitle: String {
        switch self {
        case .female: return "Female"
        case .male: return "Male"
        }
    }
}

/// 轻量 3D / 2D 假人分段尺度（相对中性女模 1.0；非 SMPL）。
/// 由 `AvatarBodySex` + `BodyMorphParams` + 可选大众体型偏置合成。
public struct MannequinSegmentScales: Equatable, Sendable {
    public var height: Double
    public var shoulderWidth: Double
    public var chestWidth: Double
    public var chestDepth: Double
    public var waistWidth: Double
    public var hipWidth: Double
    public var limbThickness: Double

    public init(
        height: Double = 1,
        shoulderWidth: Double = 1,
        chestWidth: Double = 1,
        chestDepth: Double = 1,
        waistWidth: Double = 1,
        hipWidth: Double = 1,
        limbThickness: Double = 1
    ) {
        self.height = height
        self.shoulderWidth = shoulderWidth
        self.chestWidth = chestWidth
        self.chestDepth = chestDepth
        self.waistWidth = waistWidth
        self.hipWidth = hipWidth
        self.limbThickness = limbThickness
    }

    public static let neutralFemale = MannequinSegmentScales()

    /// 男性底座：肩/胸更宽、臀相对更窄、四肢略粗。
    public static let neutralMale = MannequinSegmentScales(
        height: 1.04,
        shoulderWidth: 1.18,
        chestWidth: 1.12,
        chestDepth: 1.08,
        waistWidth: 1.08,
        hipWidth: 0.92,
        limbThickness: 1.08
    )

    public static func base(for sex: AvatarBodySex) -> MannequinSegmentScales {
        switch sex {
        case .female: return .neutralFemale
        case .male: return .neutralMale
        }
    }

    /// 合成：性别底座 × morph × 体型偏置 × **表型轻量结构偏置**（肤色外的多人种可读差异）。
    public static func resolve(
        sex: AvatarBodySex = .female,
        morph: BodyMorphParams = .neutral,
        shape: PopularShape? = nil,
        phenotype: AvatarBodyPhenotype = .eastAsian
    ) -> MannequinSegmentScales {
        let base = Self.base(for: sex)
        let m = morph.clamped()
        let shapeBias = shape.map { Self.shapeBias(for: $0) } ?? .neutralFemale
        let ph = phenotype.segmentBias
        return MannequinSegmentScales(
            height: base.height * m.height * shapeBias.height * ph.height,
            shoulderWidth: base.shoulderWidth * m.shoulder * shapeBias.shoulderWidth * ph.shoulderWidth,
            chestWidth: base.chestWidth * m.chest * shapeBias.chestWidth * ph.chestWidth,
            chestDepth: base.chestDepth * lerp(1, m.chest, t: 0.35) * shapeBias.chestDepth * ph.chestDepth,
            waistWidth: base.waistWidth * m.waist * shapeBias.waistWidth * ph.waistWidth,
            hipWidth: base.hipWidth * m.hip * shapeBias.hipWidth * ph.hipWidth,
            limbThickness: base.limbThickness * shapeBias.limbThickness * ph.limbThickness
        ).clamped()
    }

    /// 大众体型 → 轻微分段偏置（不再需要 5×8 PNG）。
    public static func shapeBias(for shape: PopularShape) -> MannequinSegmentScales {
        switch shape {
        case .hourglass:
            return MannequinSegmentScales(
                shoulderWidth: 1.0, chestWidth: 1.02, waistWidth: 0.94, hipWidth: 1.04)
        case .pear:
            return MannequinSegmentScales(
                shoulderWidth: 0.98, chestWidth: 0.97, waistWidth: 0.99, hipWidth: 1.08)
        case .apple:
            return MannequinSegmentScales(
                shoulderWidth: 1.01, chestWidth: 1.04, chestDepth: 1.04,
                waistWidth: 1.06, hipWidth: 1.0)
        case .rectangle:
            return .neutralFemale
        case .invertedTriangle:
            return MannequinSegmentScales(
                shoulderWidth: 1.1, chestWidth: 1.05, waistWidth: 1.0, hipWidth: 0.94)
        }
    }

    public func clamped() -> MannequinSegmentScales {
        MannequinSegmentScales(
            height: Self.clamp(height, 0.90, 1.12),
            shoulderWidth: Self.clamp(shoulderWidth, 0.85, 1.30),
            chestWidth: Self.clamp(chestWidth, 0.85, 1.28),
            chestDepth: Self.clamp(chestDepth, 0.88, 1.22),
            waistWidth: Self.clamp(waistWidth, 0.82, 1.28),
            hipWidth: Self.clamp(hipWidth, 0.82, 1.30),
            limbThickness: Self.clamp(limbThickness, 0.90, 1.20)
        )
    }

    private static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        min(hi, max(lo, v))
    }

    private static func lerp(_ a: Double, _ b: Double, t: Double) -> Double {
        a + (b - a) * min(1, max(0, t))
    }
}

/// 叠衣在连续 yaw 下的可见度（正面全显，侧背隐去）。
public enum MannequinGarmentVisibility {
    /// yawDegrees: 0 = 正面，顺时针增加；返回 0…1 opacity。
    public static func opacity(yawDegrees: Double) -> Double {
        // 非有限 yaw 会产生 NaN opacity 并传播到 UI 层；默认回到正面（全显）。
        guard yawDegrees.isFinite else { return 1 }
        var y = yawDegrees.truncatingRemainder(dividingBy: 360)
        if y < 0 { y += 360 }
        // 距正面最短角距
        let dist = min(y, 360 - y)
        // ±55° 内软衰减
        if dist >= 55 { return 0 }
        let t = 1 - dist / 55
        return t * t * (3 - 2 * t)
    }
}

/// 写实正面 PNG ↔ 3D 全 nude 底座混合权重。
///
/// **关键**：仅当 **已认证全裸** photoreal 资源实际可用时才淡出 3D。
/// 门控关闭（PNG 仍含 pastie/brief）时 3D 必须在正面保持不透明，否则身体几乎不可见。
public enum MannequinHybridBlend: Sendable {
    public struct Opacities: Equatable, Sendable {
        public var photoreal: Double
        public var mannequin: Double
        public init(photoreal: Double, mannequin: Double) {
            self.photoreal = photoreal
            self.mannequin = mannequin
        }
    }

    /// - Parameters:
    ///   - yawDegrees: 连续偏航。
    ///   - hasCertifiedPhotorealFront: `true` 仅当 bundle 有 **已认证零遮盖** 写实正面。
    public static func opacities(
        yawDegrees: Double,
        hasCertifiedPhotorealFront: Bool
    ) -> Opacities {
        let yawFade = MannequinGarmentVisibility.opacity(yawDegrees: yawDegrees)
        let photo = hasCertifiedPhotorealFront ? yawFade : 0
        // 有写实时 3D 略透出边缘；无写实时 3D 全显（全 nude 死路径）。
        let mannequin = max(0, 1 - photo * 0.92)
        return Opacities(photoreal: photo, mannequin: mannequin)
    }
}
