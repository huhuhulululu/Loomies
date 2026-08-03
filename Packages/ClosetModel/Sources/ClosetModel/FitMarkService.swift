import Foundation
import ClosetCore

/// 最小合身标记（DESIGN §7 / F2）：有平铺宽 + 对应身体围 → 紧/合/松。
/// 缺任一测值 → nil（UI 不展示标记，非报错）。
public enum FitMarkService {

    /// 上装默认 ease 带（英寸，闭区间合身）。
    public static let defaultTopBand = EaseBand(minEase: 1, maxEase: 5)
    /// 下装默认 ease 带。
    public static let defaultBottomBand = EaseBand(minEase: 0.5, maxEase: 3)

    /// 按槽位选平铺宽 × 身体围：top→胸；bottom→腰；dress→胸（兜底）。
    public static func mark(item: Item, profile: PersonBodyProfile) -> FitVerdict? {
        let slot = item.slotRaw
        switch slot {
        case "top", "outer", "dress":
            guard let flat = item.chestFlatWidthInches, let body = profile.bustInches else { return nil }
            let e = FitEngine.ease(garmentFlatWidth: flat, bodyCircumference: body)
            return FitEngine.verdict(ease: e, band: defaultTopBand)
        case "bottom":
            guard let flat = item.waistFlatWidthInches, let body = profile.waistInches else { return nil }
            let e = FitEngine.ease(garmentFlatWidth: flat, bodyCircumference: body)
            return FitEngine.verdict(ease: e, band: defaultBottomBand)
        default:
            return nil   // shoes/accessory 无合身标记
        }
    }
}
