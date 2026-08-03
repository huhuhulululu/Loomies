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
        item.statusRaw = statusRaw
        item.revision += 1
        ModelSave.save(context, label: "itemStatus")
        AppLog.info("status \(item.name): \(old)→\(statusRaw)", .data)
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
        default: return statusRaw
        }
    }
}
