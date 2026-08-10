import Foundation
import ClosetCore

/// ClosetModel（SwiftData 实体）→ ClosetCore（纯逻辑值类型）适配层。
/// 让 copilot 补全器/推荐引擎跑在真实持久化单品上。单向依赖：ClosetModel → ClosetCore。
public extension Item {
    func toCandidateItem() -> CandidateItem {
        // 与纸娃娃 `displaySlot` 对齐：blazer-as-top / 别名 → outerwear，否则 work look 补不出 tee
        let slot = GarmentSlot.resolved(slotRaw, name: name)
        let status = ClosetCore.ItemStatus(rawValue: statusRaw) ?? .available
        let warmth = warmthRaw.flatMap { Warmth(rawValue: $0) }
        let color = colorHue.map { GarmentColor(hueDegrees: $0, isNeutral: colorIsNeutral) }
        let attrs = Set(attributesRaw.compactMap { StyleAttribute(rawValue: $0) })
        return CandidateItem(
            id: id.uuidString, slot: slot, subtype: subtype,
            occasions: Set(occasionsRaw), warmth: warmth,
            status: status, color: color, attributes: attrs)
    }
}
