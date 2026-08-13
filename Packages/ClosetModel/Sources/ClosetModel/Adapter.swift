import Foundation
import ClosetCore

/// ClosetModel（SwiftData 实体）→ ClosetCore（纯逻辑值类型）适配层。
/// 让 copilot 补全器/推荐引擎跑在真实持久化单品上。单向依赖：ClosetModel → ClosetCore。
public extension Item {
    /// 这件衣服**实际算哪个槽位**——所有读取点的唯一入口（D194）。
    ///
    /// 用户明确设过 Type 就原样用；没设过才让名字纠偏
    ///（「西装写在 top」这类脏数据是纠偏存在的理由）。
    ///
    /// 此前八个读取点各自调 `GarmentSlot.resolved(slotRaw, name:)`，
    /// 名字推断**永远**压过存下来的值：用户在详情页把 Type 改回 Top、保存，
    /// 下次打开还是被改回去——与 copilot 铁律相反。
    var resolvedSlot: GarmentSlot {
        if slotUserSet { return GarmentSlot(rawValue: slotRaw) ?? .top }
        return GarmentSlot.resolved(slotRaw, name: name)
    }

    func toCandidateItem() -> CandidateItem {
        // 与纸娃娃 `displaySlot` 对齐：blazer-as-top / 别名 → outerwear，否则 work look 补不出 tee
        let slot = resolvedSlot
        let status = ClosetCore.ItemStatus(rawValue: statusRaw) ?? .available
        let warmth = warmthRaw.flatMap { Warmth(rawValue: $0) }
        // 「中性」语义必须可达：quick-add 只写 colorIsNeutral 不写 colorHue——
        // 若被 .map 吞掉，全 quick-add 衣柜所有搭配同分 1.0，推荐退化为 UUID 序。
        let color = colorHue.map { GarmentColor(hueDegrees: $0, isNeutral: colorIsNeutral) }
            ?? (colorIsNeutral ? GarmentColor(hueDegrees: 0, isNeutral: true) : nil)
        let attrs = Set(attributesRaw.compactMap { StyleAttribute(rawValue: $0) })
        // D130：`subtype` 生产里没有写入方，于是「不许两件同型外套」的规则
        // 永远不触发。按名字判型给它一个真实来源（同 `GarmentSlot.resolved` 的手法）；
        // 已存的显式值优先——用户/导入给的比推断的可信。
        let resolvedSubtype = subtype ?? GarmentSubtype.inferred(name: name)
        return CandidateItem(
            id: id.uuidString, slot: slot, subtype: resolvedSubtype,
            occasions: Set(occasionsRaw), warmth: warmth,
            status: status, color: color, attributes: attrs)
    }
}
