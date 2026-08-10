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

    /// 再收紧：过大剖面差会撕乳贴 / 让人物「融化」。
    public static let scaleLo: Double = 0.92
    public static let scaleHi: Double = 1.08
    public static let heightLo: Double = 0.98
    public static let heightHi: Double = 1.02

    public func clamped() -> BodyMorphParams {
        BodyMorphParams(
            chest: Self.clamp(chest, Self.scaleLo, Self.scaleHi),
            waist: Self.clamp(waist, Self.scaleLo, Self.scaleHi),
            hip: Self.clamp(hip, Self.scaleLo, Self.scaleHi),
            shoulder: Self.clamp(shoulder, Self.scaleLo, Self.scaleHi),
            height: Self.clamp(height, Self.heightLo, Self.heightHi)
        )
    }

    /// 视觉上可直出原图（跳过分条/栅格变形，防压缩感碎裂）。
    public var isVisuallyNeutral: Bool {
        let m = clamped()
        return abs(m.chest - 1) < 0.012
            && abs(m.waist - 1) < 0.012
            && abs(m.hip - 1) < 0.012
            && abs(m.shoulder - 1) < 0.012
            && abs(m.height - 1) < 0.008
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

    /// 锚点（画布百分比，与 croquis 站姿对齐；2026-08 实测乳贴 y≈0.22–0.45）。
    public enum Band {
        public static let headEnd: Double = 0.14
        public static let shoulder: Double = 0.20
        public static let chest: Double = 0.34
        public static let waist: Double = 0.46
        public static let hip: Double = 0.55
        public static let thigh: Double = 0.70
        public static let ankle: Double = 0.95
    }

    /// 乳贴锚点带：盖住实测 y≈0.22–0.45；平坦尺度，禁止行梯度剪切。
    public enum PastieBand {
        public static let start: Double = 0.22
        public static let end: Double = 0.45
    }

    /// 丁字裤/髋锚点带：平坦尺度。
    public enum ThongBand {
        public static let start: Double = 0.48
        public static let end: Double = 0.62
    }

    /// 在归一化高度 y 处的水平缩放（**必须用源图 y**，非输出行）。
    /// 脸≈1；**乳贴带 / 丁字裤带平坦**；过渡区 smoothstep。
    public func horizontalScale(normalizedY y: Double) -> Double {
        let y = min(1, max(0, y))
        let m = clamped()
        // 更强阻尼：胸/臀不全拉满，贴片与体型一起「整块」动
        let chestSoft = Self.lerp(1.0, Self.lerp(m.shoulder, m.chest, t: 0.55), t: 0.72)
        let hipSoft = Self.lerp(1.0, Self.lerp(m.waist, m.hip, t: 0.60), t: 0.72)
        let waistSoft = Self.lerp(1.0, m.waist, t: 0.78)

        if y < Band.headEnd {
            return 1.0
        }
        if y < PastieBand.start {
            let t = Self.smoothstep((y - Band.headEnd) / max(1e-4, PastieBand.start - Band.headEnd))
            return Self.lerp(1.0, chestSoft, t: t * 0.85)
        }
        // 乳贴带：完全平坦
        if y <= PastieBand.end {
            return chestSoft
        }
        // 乳贴下 → 丁字裤上：经腰收到 hipSoft
        if y < ThongBand.start {
            let t = Self.smoothstep((y - PastieBand.end) / max(1e-4, ThongBand.start - PastieBand.end))
            let viaWaist = Self.lerp(chestSoft, waistSoft, t: t)
            return Self.lerp(viaWaist, hipSoft, t: t)
        }
        // 丁字裤带：平坦
        if y <= ThongBand.end {
            return hipSoft
        }
        if y < Band.thigh {
            let t = Self.smoothstep((y - ThongBand.end) / max(1e-4, Band.thigh - ThongBand.end))
            return Self.lerp(hipSoft, Self.lerp(hipSoft, 1.0, t: 0.35), t: t)
        }
        let t = Self.smoothstep((y - Band.thigh) / max(1e-4, Band.ankle - Band.thigh))
        return Self.lerp(Self.lerp(hipSoft, 1.0, t: 0.35), 1.0, t: min(1, t))
    }

    // MARK: - 从测量 / 预设

    public static let refBust: Double = BodyAvatarScaler.refBust
    public static let refWaist: Double = BodyAvatarScaler.refWaist
    public static let refHip: Double = BodyAvatarScaler.refHip

    /// 由四围推导连续塑形（主路径）。
    public static func from(measurements m: BodyMeasurements) -> BodyMorphParams {
        // 无效围度（非有限 / ≤0）视为缺失 → 该字段中性 1.0，
        // 而非默默钳到 scaleLo（极瘦变形）。
        func scale(_ value: Double, ref: Double) -> Double {
            guard value.isFinite, value > 0 else { return 1 }
            return clamp(value / ref, scaleLo, scaleHi)
        }
        let chest = scale(m.bust, ref: refBust)
        let waist = scale(m.waist, ref: refWaist)
        let hip = scale(m.hip, ref: refHip)
        // 肩随胸略弱联动，避免头肩比例崩
        let shoulder = clamp((chest - 1) * 0.55 + 1, scaleLo, scaleHi)
        return BodyMorphParams(chest: chest, waist: waist, hip: hip, shoulder: shoulder, height: 1)
            .clamped()
    }

    /// 仅大众体型预设（快选无四围时）。幅度再收，优先不撕贴/不融化。
    public static func preset(for shape: PopularShape) -> BodyMorphParams {
        switch shape {
        case .hourglass:
            return BodyMorphParams(chest: 1.015, waist: 0.96, hip: 1.02, shoulder: 1.0, height: 1)
        case .pear:
            return BodyMorphParams(chest: 0.98, waist: 0.995, hip: 1.04, shoulder: 0.99, height: 1)
        case .apple:
            return BodyMorphParams(chest: 1.02, waist: 1.03, hip: 1.005, shoulder: 1.01, height: 1)
        case .rectangle:
            return BodyMorphParams(chest: 1.0, waist: 1.005, hip: 1.0, shoulder: 1.0, height: 1)
        case .invertedTriangle:
            return BodyMorphParams(chest: 1.03, waist: 1.0, hip: 0.975, shoulder: 1.04, height: 1)
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

    /// 0…1 smoothstep，过渡区更柔，减少贴身件边缘锯齿感。
    public static func smoothstep(_ t: Double) -> Double {
        let x = min(1, max(0, t))
        return x * x * (3 - 2 * x)
    }
}
