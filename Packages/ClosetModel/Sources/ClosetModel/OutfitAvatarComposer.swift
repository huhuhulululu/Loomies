import Foundation
import ClosetCore

/// 从持久化 Item 列表 → 纸娃娃叠衣层（入库本地图优先）。
public enum OutfitAvatarComposer {

    /// 按槽位去重：同槽优先有图；dress 压制 top/bottom。
    /// 使用 `displaySlot` 纠偏 blazer-as-top 等脏数据，保证「能穿上外套+上衣」。
    /// 「有图」= 文件真实存在（stat），不是路径非空——反向孤儿（文件已消失的死路径）
    /// 不得击败真有图的同槽单品把整套 look 渲染成占位块。
    public static func layers(
        from items: [Item],
        imageExists: (String) -> Bool = { ItemImageStore.fileExists(relativePath: $0) }
    ) -> [BodyAvatarLayer] {
        var best: [BodyAvatarSlot: BodyAvatarSlotImage] = [:]
        var bestHasImg: [BodyAvatarSlot: Bool] = [:]
        for item in items {
            guard let slot = BodyAvatarComposer.displaySlot(
                slotRaw: item.slotRaw, itemName: item.name)
            else { continue }
            let path = item.localImageRelativePath
            let hasImg = path.map { !$0.isEmpty && imageExists($0) } ?? false
            let ref = BodyAvatarSlotImage(
                id: item.id.uuidString,
                bundleName: nil,
                localRelativePath: path)
            if best[slot] != nil {
                let existingHas = bestHasImg[slot] ?? false
                // 同槽：有图 > 无图；都有图则后写覆盖（outfit 顺序靠调用方）
                if hasImg && !existingHas {
                    best[slot] = ref; bestHasImg[slot] = hasImg
                } else if hasImg == existingHas {
                    best[slot] = ref; bestHasImg[slot] = hasImg
                }
            } else {
                best[slot] = ref
                bestHasImg[slot] = hasImg
            }
        }
        return BodyAvatarComposer.layers(slotImages: best)
    }

    /// 叠衣是否具备「可识别穿着」的视觉层（至少一件有图）。
    public static func hasVisibleGarments(_ layers: [BodyAvatarLayer]) -> Bool {
        layers.contains { $0.hasVisual }
    }

    /// 简短穿着摘要（无图时仍列槽位，供 UI 提示）。
    public static func wearSummary(of layers: [BodyAvatarLayer]) -> String {
        let order: [BodyAvatarSlot] = [.outerwear, .top, .dress, .bottom, .shoes]
        let labels: [BodyAvatarSlot: String] = [
            .outerwear: "outer", .top: "top", .dress: "dress",
            .bottom: "bottom", .shoes: "shoes"
        ]
        let parts = order.compactMap { slot -> String? in
            layers.contains(where: { $0.slot == slot }) ? labels[slot] : nil
        }
        return parts.isEmpty ? "undressed" : parts.joined(separator: " · ")
    }

    /// 用 ScoredOutfit 的 itemIDs 从柜中取件。
    public static func layers(
        itemIDs: [String],
        in wardrobe: Wardrobe
    ) -> [BodyAvatarLayer] {
        let idSet = Set(itemIDs)
        let items = (wardrobe.items ?? []).filter { idSet.contains($0.id.uuidString) }
        // 确定性顺序：按 outfit 的 itemIDs 排序，同槽 last-writer-wins 才可预期
        let rank = Dictionary(
            itemIDs.enumerated().map { ($0.element, $0.offset) },
            uniquingKeysWith: { first, _ in first })
        let ordered = items.sorted {
            (rank[$0.id.uuidString] ?? 0) < (rank[$1.id.uuidString] ?? 0)
        }
        return layers(from: ordered)
    }
}
