import Foundation
import ClosetCore

/// 最小合身标记（DESIGN §7 / F2）：有平铺宽 + 对应身体围 → 紧/合/松。
/// 缺任一测值 → nil（UI 不展示标记，非报错）。
public enum FitMarkService {

    /// 上装默认 ease 带（英寸，闭区间合身）。
    public static let defaultTopBand = EaseBand(minEase: 1, maxEase: 5)
    /// 下装默认 ease 带。
    public static let defaultBottomBand = EaseBand(minEase: 0.5, maxEase: 3)

    /// 按槽位选平铺宽 × 身体围：top/outerwear/dress→胸；bottom→腰。
    /// 槽位经 `GarmentSlot.resolved`（与纸娃娃 displaySlot 同真相）：canonical
    /// `outerwear`、别名 `outer`/`blazer`、脏数据 blazer-as-top 均可标记。
    public static func mark(item: Item, profile: PersonBodyProfile) -> FitVerdict? {
        mark(
            slotRaw: item.slotRaw,
            name: item.name,
            chestFlatWidthInches: item.chestFlatWidthInches,
            waistFlatWidthInches: item.waistFlatWidthInches,
            profile: profile)
    }

    /// Field-level mark for detail form live preview (unsaved flat widths / type / name).
    public static func mark(
        slotRaw: String,
        name: String = "",
        chestFlatWidthInches: Double?,
        waistFlatWidthInches: Double?,
        profile: PersonBodyProfile
    ) -> FitVerdict? {
        let slot = GarmentSlot.resolved(slotRaw, name: name)
        switch slot {
        case .top, .outerwear, .dress:
            // 零/负测值是脏数据——'缺任一测值 → nil' 契约覆盖非正值，不得出自信判定。
            guard let flat = chestFlatWidthInches, let body = profile.bustInches,
                  flat > 0, body > 0 else { return nil }
            let e = FitEngine.ease(garmentFlatWidth: flat, bodyCircumference: body)
            return FitEngine.verdict(ease: e, band: defaultTopBand)
        case .bottom:
            guard let flat = waistFlatWidthInches, let body = profile.waistInches,
                  flat > 0, body > 0 else { return nil }
            let e = FitEngine.ease(garmentFlatWidth: flat, bodyCircumference: body)
            return FitEngine.verdict(ease: e, band: defaultBottomBand)
        case .shoes, .accessory:
            return nil
        }
    }
}
