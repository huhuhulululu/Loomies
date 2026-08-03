import Foundation

/// 连续体型塑形参数（2D 表达层，类游戏滑杆；非 SMPL）。
/// 各值为相对「中性参考」的水平尺度，1.0 = 不变形。
public struct BodyMorphParams: Equatable, Sendable {
    /// 胸/上躯水平尺度
    public var chest: Double
    /// 腰水平尺度
    public var waist: Double
    /// 臀水平尺度
    public var hip: Double
    /// 肩带区（略独立于 chest，避免脸肩糊）
    public var shoulder: Double
    /// 整体高度尺度（慎用）
    public var height: Double

    public init(
        chest: Double = 1,
        waist: Double = 1,
        hip: Double = 1,
        shoulder: Double = 1,
        height: Double = 1
    ) {
        self.chest = chest
        self.waist = waist
        self.hip = hip
        self.shoulder = shoulder
        self.height = height
    }

    public static let neutral = BodyMorphParams()

    public static let scaleLo: Double = 0.86
    public static let scaleHi: Double = 1.16
    public static let heightLo: Double = 0.94
    public static let heightHi: Double = 1.06

    public func clamped() -> BodyMorphParams {
        BodyMorphParams(
            chest: Self.clamp(chest, Self.scaleLo, Self.scaleHi),
            waist: Self.clamp(waist, Self.scaleLo, Self.scaleHi),
            hip: Self.clamp(hip, Self.scaleLo, Self.scaleHi),
            shoulder: Self.clamp(shoulder, Self.scaleLo, Self.scaleHi),
            height: Self.clamp(height, Self.heightLo, Self.heightHi)
        )
    }

    /// 与微调偏移合成（offset 为相对 1.0 的加减，如 +0.05）。
    public func applying(offsets: BodyMorphParams) -> BodyMorphParams {
        BodyMorphParams(
            chest: chest * offsets.chest,
            waist: waist * offsets.waist,
            hip: hip * offsets.hip,
            shoulder: shoulder * offsets.shoulder,
            height: height * offsets.height
        ).clamped()
    }

    // MARK: - 纵向剖面：归一化 y∈[0,1]（顶→底）→ 水平 scale

    /// 锚点（画布百分比，与 croquis 站姿大致对齐）。
    public enum Band {
        public static let headEnd: Double = 0.16
        public static let shoulder: Double = 0.22
        public static let chest: Double = 0.34
        public static let waist: Double = 0.44
        public static let hip: Double = 0.54
        public static let thigh: Double = 0.68
        public static let ankle: Double = 0.95
    }

    /// 在归一化高度 y 处的水平缩放（脸附近强制接近 1，防崩脸）。
    public func horizontalScale(normalizedY y: Double) -> Double {
        let y = min(1, max(0, y))
        let m = clamped()
        // 头/脸：几乎不变形
        if y < Band.headEnd {
            return Self.lerp(1.0, m.shoulder, t: y / Band.headEnd * 0.25)
        }
        // 肩
        if y < Band.shoulder {
            let t = (y - Band.headEnd) / (Band.shoulder - Band.headEnd)
            return Self.lerp(1.0, m.shoulder, t: t)
        }
        // 肩→胸
        if y < Band.chest {
            let t = (y - Band.shoulder) / (Band.chest - Band.shoulder)
            return Self.lerp(m.shoulder, m.chest, t: t)
        }
        // 胸→腰
        if y < Band.waist {
            let t = (y - Band.chest) / (Band.waist - Band.chest)
            return Self.lerp(m.chest, m.waist, t: t)
        }
        // 腰→臀
        if y < Band.hip {
            let t = (y - Band.waist) / (Band.hip - Band.waist)
            return Self.lerp(m.waist, m.hip, t: t)
        }
        // 臀→大腿
        if y < Band.thigh {
            let t = (y - Band.hip) / (Band.thigh - Band.hip)
            return Self.lerp(m.hip, Self.lerp(m.hip, 1.0, t: 0.35), t: t)
        }
        // 腿→踝：收回中性
        let t = (y - Band.thigh) / (Band.ankle - Band.thigh)
        return Self.lerp(Self.lerp(m.hip, 1.0, t: 0.35), 1.0, t: min(1, t))
    }

    // MARK: - 从测量 / 预设

    public static let refBust: Double = BodyAvatarScaler.refBust
    public static let refWaist: Double = BodyAvatarScaler.refWaist
    public static let refHip: Double = BodyAvatarScaler.refHip

    /// 由四围推导连续塑形（主路径）。
    public static func from(measurements m: BodyMeasurements) -> BodyMorphParams {
        let chest = clamp(m.bust / refBust, scaleLo, scaleHi)
        let waist = clamp(m.waist / refWaist, scaleLo, scaleHi)
        let hip = clamp(m.hip / refHip, scaleLo, scaleHi)
        // 肩随胸略弱联动，避免头肩比例崩
        let shoulder = clamp((chest - 1) * 0.55 + 1, scaleLo, scaleHi)
        return BodyMorphParams(chest: chest, waist: waist, hip: hip, shoulder: shoulder, height: 1)
            .clamped()
    }

    /// 仅大众体型预设（快选无四围时）。
    public static func preset(for shape: PopularShape) -> BodyMorphParams {
        switch shape {
        case .hourglass:
            return BodyMorphParams(chest: 1.02, waist: 0.92, hip: 1.04, shoulder: 1.0, height: 1)
        case .pear:
            return BodyMorphParams(chest: 0.96, waist: 0.98, hip: 1.10, shoulder: 0.97, height: 1)
        case .apple:
            return BodyMorphParams(chest: 1.04, waist: 1.08, hip: 1.02, shoulder: 1.02, height: 1)
        case .rectangle:
            return BodyMorphParams(chest: 1.0, waist: 1.02, hip: 1.0, shoulder: 1.0, height: 1)
        case .invertedTriangle:
            return BodyMorphParams(chest: 1.08, waist: 1.0, hip: 0.94, shoulder: 1.10, height: 1)
        }
    }

    /// 测量优先；否则体型预设；再否则中性。
    public static func resolve(
        measurements: BodyMeasurements?,
        shape: PopularShape?,
        fineTune: BodyMorphParams = .neutral
    ) -> BodyMorphParams {
        let base: BodyMorphParams
        if let m = measurements {
            base = from(measurements: m)
        } else if let shape {
            base = preset(for: shape)
        } else {
            base = .neutral
        }
        // fineTune 字段解释为相对中性的乘数（UI 滑杆 0.9…1.1）
        return base.applying(offsets: fineTune).clamped()
    }

    /// 兼容旧 `BodyAvatarScale`（整体宽 ≈ 胸臀均值）。
    public var legacyScale: BodyAvatarScale {
        let m = clamped()
        let width = (m.chest + m.hip) / 2
        return BodyAvatarScale(widthScale: width, hipScale: m.hip, waistScale: m.waist)
    }

    public static func from(legacy s: BodyAvatarScale) -> BodyMorphParams {
        BodyMorphParams(
            chest: s.widthScale,
            waist: s.waistScale,
            hip: s.hipScale,
            shoulder: s.widthScale,
            height: 1
        ).clamped()
    }

    // MARK: - Math

    public static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        min(hi, max(lo, v))
    }

    public static func lerp(_ a: Double, _ b: Double, t: Double) -> Double {
        a + (b - a) * min(1, max(0, t))
    }
}
