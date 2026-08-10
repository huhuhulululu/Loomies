import Foundation
import SwiftData
import ClosetCore

/// 模拟器 / 空柜演示种子（DESIGN 冷启动：先有几件才能玩 copilot）。
/// 写入一组可组套单品（top/bottom/shoes + 可选 outer），场合 work/casual，温区 light。
public enum DemoSeedService {

    /// Customer toast when ModelSave fails on sample load (no silent “Added N samples”).
    public static let saveFailedMessage = "Couldn't load samples — try again"

    /// Me → Demo / empty-grid Load samples button VoiceOver hint.
    public static let loadButtonAccessibilityHint =
        "Adds demo pieces to this closet for trying copilot. Not from your photos."

    /// Outcome of seed / seedIfEmpty — distinguishes no-op, success, and save fail.
    public enum Outcome: Equatable {
        case alreadyPopulated
        case added(Int)
        case saveFailed

        /// Customer flash for Today cold-start / Closet empty “Load samples”.
        public var flashMessage: String {
            switch self {
            case .alreadyPopulated:
                return "Closet already has pieces."
            case .added(let n):
                return "Added \(n) samples."
            case .saveFailed:
                return DemoSeedService.saveFailedMessage
            }
        }

        /// Customer flash for Me → Demo force seed button.
        public var meDemoFlashMessage: String {
            switch self {
            case .alreadyPopulated:
                return "Already seeded."
            case .added(let n):
                return "Added \(n) sample pieces."
            case .saveFailed:
                return DemoSeedService.saveFailedMessage
            }
        }

        /// Committed piece count (0 when skipped or save failed).
        public var committedCount: Int {
            if case .added(let n) = self { return n }
            return 0
        }
    }

    /// 若衣柜已有单品则 no-op；否则插入。Save fail → `.saveFailed`（inserts rolled back）。
    @discardableResult
    public static func seedIfEmpty(_ wardrobe: Wardrobe, in context: ModelContext) -> Outcome {
        if !(wardrobe.items ?? []).isEmpty { return .alreadyPopulated }
        return seed(wardrobe, in: context)
    }

    /// 强制再塞一套演示单品（命名带序号防重名）。Save fail → `.saveFailed` + rollback.
    @discardableResult
    public static func seed(_ wardrobe: Wardrobe, in context: ModelContext) -> Outcome {
        let existing = wardrobe.items ?? []
        // 去重序号取现存名称的最大数字后缀 +1（删过一批再 seed 也不会重名；
        // existing / specs.count 在删批场景会重算出已用过的序号）
        let maxSuffix = existing.compactMap { Self.trailingNumber(in: $0.name) }.max() ?? 0
        let tag = existing.isEmpty ? "" : " \(maxSuffix + 1)"

        // name, slot, occasions, hue?, warmth
        let specs: [(String, String, [String], Double?, Warmth)] = [
            // slot 必须与 BodyAvatar 叠衣槽一致：外套用 outerwear，才能与 tee 同穿
            ("White tee\(tag)", "top", ["work", "casual"], 0, .light),
            ("Navy blazer\(tag)", "outerwear", ["work"], 220, .medium),
            ("Black trousers\(tag)", "bottom", ["work", "gala"], nil, .light),
            ("Blue jeans\(tag)", "bottom", ["casual"], 210, .medium),
            ("White sneakers\(tag)", "shoes", ["work", "casual"], nil, .light),
            ("Black pumps\(tag)", "shoes", ["work", "date", "gala"], nil, .light),
            ("Camel coat\(tag)", "outerwear", ["work", "casual"], 30, .warm),
            ("Linen shirt\(tag)", "top", ["casual", "date"], 45, .light),
            ("Midi skirt\(tag)", "bottom", ["work", "date"], 15, .light),
        ]

        var inserted: [Item] = []
        for (name, slot, occasions, hue, warmth) in specs {
            let item = Item(name: name)
            item.slotRaw = slot
            item.occasionsRaw = occasions
            item.warmthRaw = warmth.rawValue
            item.statusRaw = "available"
            item.colorIsNeutral = (hue == nil) || (hue == 0)
            item.colorHue = hue
            item.wardrobe = wardrobe
            // 纸娃娃层：程序化剪影；槽与 displaySlot 同真相（含名称纠偏，非 mapSlot alone）
            if let avatarSlot = BodyAvatarComposer.displaySlot(slotRaw: slot, itemName: name),
               let png = DemoGarmentSilhouette.pngData(
                slot: avatarSlot,
                name: name,
                hue: hue,
                isNeutral: item.colorIsNeutral),
               let rel = ItemImageStore.save(data: png, for: item.id, ext: "png") {
                item.localImageRelativePath = rel
            }
            context.insert(item)
            inserted.append(item)
        }
        let count = inserted.count
        guard ModelSave.save(context, label: "demoSeed") else {
            // 剪影文件先于 rollback 清理——回滚只还上下文状态，磁盘文件须手动删
            for item in inserted {
                if let path = item.localImageRelativePath {
                    ItemImageStore.delete(relativePath: path)
                }
            }
            // rollback 一并丢弃 pending inserts（delete 只删行，脏标记会滞留）
            context.rollback()   // 失败变更不得滞留，否则污染下一次无关 save
            AppLog.error("demoSeed save failed wardrobe=\(wardrobe.name)", .data)
            return .saveFailed
        }
        AppLog.notice("demoSeed +\(count) items into \(wardrobe.name)", .data)
        return .added(count)
    }

    /// 名称尾部 " N" 去重序号；无数字后缀 → nil。
    static func trailingNumber(in name: String) -> Int? {
        guard let space = name.lastIndex(of: " ") else { return nil }
        return Int(name[name.index(after: space)...])
    }
}
