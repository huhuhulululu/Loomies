import Foundation
import ClosetCore

/// 体型来源（双轨录入）。
public enum BodyShapeSource: String, Sendable, CaseIterable {
    /// 未设体型、无四围
    case none
    /// 仅 5 类快选
    case visualPick
    /// 四围实测（含上臀实测）
    case measured
    /// 三围 + 推断上臀
    case provisional
    /// 既有实测又有手选覆盖
    case mixed
}

/// 合身/体型置信度（UI 文案）。
public enum BodyFitConfidence: String, Sendable {
    case none
    case visualOnly
    case provisional
    case measured
    case mixed

    public var userLabel: String {
        switch self {
        case .none: return "Incomplete"
        case .visualOnly: return "Visual pick only"
        case .provisional: return "Provisional (high hip estimated)"
        case .measured: return "Measured"
        case .mixed: return "Measured + shape preference"
        }
    }
}

/// 体型门 + FFIT + 双轨快选（DESIGN §2.2 R13）。
/// 身体数据永不出网——本服务只在端侧跑。
public enum BodyProfileService {

    // MARK: - R13 四围门

    /// 四围数字是否齐（含推断上臀）；齐则可跑 FFIT / 合身。
    /// 与 recompute 的 >0 判定同标准：0/负/非有限不算齐——否则 UI 宣称 Measured
    /// 满权重，FFIT 却拒绝脏值静默兜底假体型。
    public static func isComplete(_ profile: PersonBodyProfile) -> Bool {
        [profile.bustInches, profile.waistInches, profile.hipInches, profile.highHipInches]
            .allSatisfy { ($0 ?? 0) > 0 && ($0 ?? 0).isFinite }
    }

    /// 四围均为用户实测（上臀非推断）。
    public static func isFullyMeasured(_ profile: PersonBodyProfile) -> Bool {
        isComplete(profile) && !profile.highHipInferred
    }

    /// 完整 → BodyMeasurements；否则 nil。
    public static func measurements(from profile: PersonBodyProfile) -> BodyMeasurements? {
        guard let b = profile.bustInches, let w = profile.waistInches,
              let h = profile.hipInches, let hh = profile.highHipInches else { return nil }
        return BodyMeasurements(bust: b, waist: w, hip: h, highHip: hh)
    }

    /// 完整 → FFIT BodyShape；否则若有快选则映射代表类；再否则 nil。
    public static func bodyShape(from profile: PersonBodyProfile) -> BodyShape? {
        if let m = measurements(from: profile) {
            return FFITClassifier.classify(m)
        }
        if let pop = popularShape(from: profile) {
            return representativeBodyShape(for: pop)
        }
        return nil
    }

    // MARK: - 大众体型 / 快选

    public static func popularShape(from profile: PersonBodyProfile) -> PopularShape? {
        if isComplete(profile), let m = measurements(from: profile) {
            let fromFFIT = FFITClassifier.classify(m).popularCategory
            // 实测优先；若用户另选手选且不同，仍返回 FFIT 映射（合身以数字为准），
            // 但 displayPopularShape 会反映覆盖意图。
            return fromFFIT
        }
        return parsePopular(profile.popularShapeOverrideRaw)
    }

    /// 驱动 360 / 3D 底座体型：手选覆盖优先，否则 FFIT 映射，否则 nil。
    public static func displayPopularShape(from profile: PersonBodyProfile) -> PopularShape? {
        if let o = parsePopular(profile.popularShapeOverrideRaw) { return o }
        if isComplete(profile), let m = measurements(from: profile) {
            return FFITClassifier.classify(m).popularCategory
        }
        return nil
    }

    public static func parsePopular(_ raw: String?) -> PopularShape? {
        guard let raw else { return nil }
        return PopularShape(rawValue: raw)
    }

    /// 展示用性别底座（全 nude 3D）；缺省 female。
    public static func presentationSex(from profile: PersonBodyProfile?) -> AvatarBodySex {
        guard let raw = profile?.presentationSexRaw,
              let sex = AvatarBodySex(rawValue: raw) else {
            return .female
        }
        return sex
    }

    /// 展示用人种/表型（多人种全 nude）；缺省 eastAsian（可改）。
    public static func presentationPhenotype(from profile: PersonBodyProfile?) -> AvatarBodyPhenotype {
        guard let raw = profile?.presentationPhenotypeRaw,
              let p = AvatarBodyPhenotype(rawValue: raw) else {
            return .eastAsian
        }
        return p
    }

    /// 大众 5 类 → FFIT 代表类（仅用于无四围时的轻量推荐加权）。
    public static func representativeBodyShape(for popular: PopularShape) -> BodyShape {
        switch popular {
        case .hourglass: return .hourglass
        case .pear: return .triangle
        case .apple: return .oval
        case .rectangle: return .rectangle
        case .invertedTriangle: return .invertedTriangle
        }
    }

    /// 推荐体型加权系数：快选 0.5，实测/混合 1.0，无 0。
    public static func styleWeightFactor(for profile: PersonBodyProfile) -> Double {
        switch resolveSource(profile) {
        case .none: return 0
        case .visualPick: return 0.5
        case .provisional: return 0.85
        case .measured, .mixed: return 1.0
        }
    }

    // MARK: - 上臀推断

    /// 启发式：highHip ≈ waist + 0.5×(hip−waist)，夹在腰臀之间。
    public static func inferHighHip(waist: Double, hip: Double) -> Double {
        guard waist > 0, hip > 0 else { return max(waist, 1) }
        let raw = waist + 0.5 * (hip - waist)
        let lo = min(waist, hip)
        let hi = max(waist, hip)
        return min(hi, max(lo, raw))
    }

    /// 从三围构建测量（上臀可推断）。
    public static func measurements(
        bust: Double, waist: Double, hip: Double,
        highHip: Double? = nil, inferIfNeeded: Bool = true
    ) -> (BodyMeasurements, highHipInferred: Bool)? {
        guard bust > 0, waist > 0, hip > 0 else { return nil }
        if let hh = highHip, hh > 0 {
            return (BodyMeasurements(bust: bust, waist: waist, hip: hip, highHip: hh), false)
        }
        guard inferIfNeeded else { return nil }
        let hh = inferHighHip(waist: waist, hip: hip)
        return (BodyMeasurements(bust: bust, waist: waist, hip: hip, highHip: hh), true)
    }

    // MARK: - Source / confidence

    public static func resolveSource(_ profile: PersonBodyProfile) -> BodyShapeSource {
        let hasOverride = parsePopular(profile.popularShapeOverrideRaw) != nil
        let complete = isComplete(profile)
        // 推断上臀优先于覆盖：3 实测 + 推断上臀 + 手选仍是 provisional（上臀只是估计）。
        if complete && profile.highHipInferred { return .provisional }
        if complete && hasOverride { return .mixed }
        if complete { return .measured }
        if hasOverride { return .visualPick }
        return .none
    }

    public static func confidence(for profile: PersonBodyProfile) -> BodyFitConfidence {
        switch resolveSource(profile) {
        case .none: return .none
        case .visualPick: return .visualOnly
        case .provisional: return .provisional
        case .measured: return .measured
        case .mixed: return .mixed
        }
    }

    /// 写入/刷新 shapeSourceRaw 与一致性。
    public static func refreshSource(on profile: PersonBodyProfile) {
        profile.shapeSourceRaw = resolveSource(profile).rawValue
    }

    // MARK: - 单位

    public static func inches(fromCm cm: Double) -> Double { cm / 2.54 }
    public static func cm(fromInches inches: Double) -> Double { inches * 2.54 }

    /// 显示用：步进 0.5 in 或 1 cm。
    public static func clampMeasureInches(_ v: Double) -> Double {
        min(60, max(18, (v * 2).rounded() / 2))
    }
}
