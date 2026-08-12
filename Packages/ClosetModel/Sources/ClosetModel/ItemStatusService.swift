import Foundation
import SwiftData
import ClosetCore

/// 单品状态机（DESIGN §2.2）：可用/在洗/干洗/外借/闲置/待处理。
public enum ItemStatusService {
    public static let allowed: Set<String> = [
        "available", "inWash", "dryCleaning", "lent", "idle", "pending"
    ]

    public static func setStatus(_ item: Item, to statusRaw: String, in context: ModelContext) -> Bool {
        guard allowed.contains(statusRaw) else {
            AppLog.error("invalid status \(statusRaw)", .data)
            return false
        }
        let old = item.statusRaw
        let previousWashedAt = item.lastWashedAt
        item.statusRaw = statusRaw
        // D106：**洗完**才算——从洗衣/干洗回到可用的那一刻打锚点。
        // 送洗当刻不算（否则当天就清零），外借/闲置回来也不算（那不是洗）。
        if LaundryTracking.isWashState(old), statusRaw == "available" {
            item.lastWashedAt = Date()
        }
        item.revision += 1
        guard ModelSave.save(context, label: "itemStatus") else {
            // rollback() 不清内存值只清脏标记 → 先手动还原字段（TransferService 同款），再 rollback
            item.statusRaw = old
            item.lastWashedAt = previousWashedAt
            item.revision -= 1
            context.rollback()   // 失败变更不得滞留，否则污染下一次无关 save
            AppLog.error("status save failed item=\(AppLog.ref(item.id)): \(old)→\(statusRaw)", .data)
            return false
        }
        AppLog.info("status item=\(AppLog.ref(item.id)): \(old)→\(statusRaw)", .data)
        return true
    }

    public static func displayName(_ statusRaw: String) -> String {
        switch statusRaw {
        case "available": return "Available"
        case "inWash": return "In wash"
        case "dryCleaning": return "Dry cleaning"
        case "lent": return "Lent out"
        case "idle": return "Idle"
        case "pending": return "Pending"
        // Never dump raw camelCase / corrupt storage into Closet chips or Search meta.
        default: return "Unknown"
        }
    }
}
