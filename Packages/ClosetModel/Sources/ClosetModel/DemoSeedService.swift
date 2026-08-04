import Foundation
import SwiftData
import ClosetCore

/// 模拟器 / 空柜演示种子（DESIGN 冷启动：先有几件才能玩 copilot）。
/// 写入一组可组套单品（top/bottom/shoes + 可选 outer），场合 work/casual，温区 light。
public enum DemoSeedService {

    /// 若衣柜已有单品则 no-op 返回 0；否则插入并返回件数。
    @discardableResult
    public static func seedIfEmpty(_ wardrobe: Wardrobe, in context: ModelContext) -> Int {
        if !(wardrobe.items ?? []).isEmpty { return 0 }
        return seed(wardrobe, in: context)
    }

    /// 强制再塞一套演示单品（命名带序号防重名）。
    @discardableResult
    public static func seed(_ wardrobe: Wardrobe, in context: ModelContext) -> Int {
        let existing = (wardrobe.items ?? []).count
        let tag = existing == 0 ? "" : " \(existing / 5 + 1)"

        // name, slot, occasions, hue?, warmth
        let specs: [(String, String, [String], Double?, Warmth)] = [
            ("White tee\(tag)", "top", ["work", "casual"], 0, .light),
            ("Navy blazer\(tag)", "top", ["work"], 220, .medium),
            ("Black trousers\(tag)", "bottom", ["work", "gala"], nil, .light),
            ("Blue jeans\(tag)", "bottom", ["casual"], 210, .medium),
            ("White sneakers\(tag)", "shoes", ["work", "casual"], nil, .light),
            ("Black pumps\(tag)", "shoes", ["work", "date", "gala"], nil, .light),
            ("Camel coat\(tag)", "outerwear", ["work", "casual"], 30, .warm),
            ("Linen shirt\(tag)", "top", ["casual", "date"], 45, .light),
            ("Midi skirt\(tag)", "bottom", ["work", "date"], 15, .light),
        ]

        var count = 0
        for (name, slot, occasions, hue, warmth) in specs {
            let item = Item(name: name)
            item.slotRaw = slot
            item.occasionsRaw = occasions
            item.warmthRaw = warmth.rawValue
            item.statusRaw = "available"
            item.colorIsNeutral = (hue == nil) || (hue == 0)
            item.colorHue = hue
            item.wardrobe = wardrobe
            context.insert(item)
            count += 1
        }
        ModelSave.save(context, label: "demoSeed")
        AppLog.notice("demoSeed +\(count) items into \(wardrobe.name)", .data)
        return count
    }
}
