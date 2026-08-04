import Foundation
import ClosetCore

/// 从持久化 Item 列表 → 纸娃娃叠衣层（入库本地图优先）。
public enum OutfitAvatarComposer {

    /// 按槽位去重：同槽优先有图；dress 压制 top/bottom。
    public static func layers(from items: [Item]) -> [BodyAvatarLayer] {
        var best: [BodyAvatarSlot: BodyAvatarSlotImage] = [:]
        for item in items {
            guard let slot = BodyAvatarComposer.mapSlot(item.slotRaw) else { continue }
            let path = item.localImageRelativePath
            let hasImg = path?.isEmpty == false
            let ref = BodyAvatarSlotImage(
                id: item.id.uuidString,
                bundleName: nil,
                localRelativePath: path)
            if let existing = best[slot] {
                let existingHas = existing.localRelativePath?.isEmpty == false
                if hasImg && !existingHas { best[slot] = ref }
            } else {
                best[slot] = ref
            }
        }
        return BodyAvatarComposer.layers(slotImages: best)
    }

    /// 用 ScoredOutfit 的 itemIDs 从柜中取件。
    public static func layers(
        itemIDs: [String],
        in wardrobe: Wardrobe
    ) -> [BodyAvatarLayer] {
        let idSet = Set(itemIDs)
        let items = (wardrobe.items ?? []).filter { idSet.contains($0.id.uuidString) }
        return layers(from: items)
    }
}
