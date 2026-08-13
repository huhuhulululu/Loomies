import Foundation
import ClosetModel
import ClosetCore

/// 从主人档案推导**头像要画成什么样**（D175）。
///
/// 此前这段推导在四个视图里各写一份——试衣间 / 日历 / 收藏三份**逐字节相同**，
/// Today 第四份的兜底略有不同。四份都是 view-private，**一条测试都没有**，
/// 而它决定的是用户在四块屏幕上看到的身体长什么样。
///
/// 本仓已经为这种重复付过账（D144 披露两处走岔、D148 排序手抄 19 遍、
/// D165 两张手工表各自过期）。收成一处，并让它可测。
///
/// **语义一个字不变**：
/// - 形状 = 展示口径（手选覆盖优先，其次实测 FFIT），都没有则矩形；
///   注意这与**打分口径**（`bodyShape(from:)`，实测优先）是**有意分开**的——
///   「画的是你说的样子，建议用量的数据」（`BodyProfileServiceTests`
///   的 `mixedWhenMeasuredAndOverride` 早就把这条分工钉住了）。
/// - 形变 = 有档案则按实测+快选+精调合成，无档案则按形状取预设。
public enum OwnerBodyDerivation {

    /// 无档案时的身体。矩形是最中性的一个，不替用户假设。
    public static let fallbackShape: PopularShape = .rectangle

    public static func shape(from profile: PersonBodyProfile?) -> PopularShape {
        guard let profile,
              let s = BodyProfileService.displayPopularShape(from: profile)
        else { return fallbackShape }
        return s
    }

    public static func morph(from profile: PersonBodyProfile?) -> BodyMorphParams {
        guard let profile else {
            return BodyMorphParams.preset(for: fallbackShape)
        }
        let measurements = BodyProfileService.measurements(from: profile)
        let popular = BodyProfileService.popularShape(from: profile)
        let fine = BodyMorphParams(
            chest: profile.fineChest, waist: profile.fineWaist,
            hip: profile.fineHip, shoulder: 1, height: profile.fineHeight)
        return BodyMorphParams.resolve(
            measurements: measurements, shape: popular, fineTune: fine)
    }
}
