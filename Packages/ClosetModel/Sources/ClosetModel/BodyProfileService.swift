import Foundation
import ClosetCore

/// 体型门 + FFIT（DESIGN §2.2 R13 / D12）：
/// 仅当 bust/waist/hip/highHip 四围录满才计算并展示；缺一 → nil（FFIT 簇整体隐藏）。
/// 身体数据永不出网——本服务只在端侧跑。
public enum BodyProfileService {

    /// 四围是否录满（R13 激活门）。
    public static func isComplete(_ profile: PersonBodyProfile) -> Bool {
        profile.bustInches != nil
            && profile.waistInches != nil
            && profile.hipInches != nil
            && profile.highHipInches != nil
    }

    /// 完整 → BodyMeasurements；否则 nil。
    public static func measurements(from profile: PersonBodyProfile) -> BodyMeasurements? {
        guard let b = profile.bustInches, let w = profile.waistInches,
              let h = profile.hipInches, let hh = profile.highHipInches else { return nil }
        return BodyMeasurements(bust: b, waist: w, hip: h, highHip: hh)
    }

    /// 完整 → FFIT BodyShape；否则 nil。
    public static func bodyShape(from profile: PersonBodyProfile) -> BodyShape? {
        guard let m = measurements(from: profile) else { return nil }
        return FFITClassifier.classify(m)
    }
}
