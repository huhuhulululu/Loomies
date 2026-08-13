import Foundation
import SwiftData
import ClosetCore

/// 「距上次洗涤已穿几次」（D106；DESIGN §219）。
/// MARKET 记录这是 Reddit 用户点名、**竞品无人做**的需求，而数据基础本就齐备
/// （打卡记录 + 状态机），此前只是没人把它算出来。
///
/// **诚实边界**：这是**显性化**，不是建议。不得说「该洗了」——
/// 多久该洗取决于面料、体感、季节，App 没有这些信息。
public enum LaundryTracking {

    /// 洗衣类状态（从这些状态回到可用 = 洗完了）。
    public static func isWashState(_ statusRaw: String) -> Bool {
        statusRaw == "inWash" || statusRaw == "dryCleaning"
    }

    /// 上次洗完之后穿过几次；从没洗过则是入库以来的总次数。
    @MainActor
    public static func wearsSinceWash(_ item: Item, in context: ModelContext) -> Int {
        wearsSinceWash(item, records: (try? context.fetch(FetchDescriptor<WearRecord>())) ?? [])
    }

    /// 按**已经取好的**记录算（D156）——详情页与穿着统计共用同一次取表。
    @MainActor
    public static func wearsSinceWash(_ item: Item, records: [WearRecord]) -> Int {
        let key = item.id.uuidString
        return records.filter { record in
            guard record.wornItemIDs.contains(key) else { return false }
            guard let washed = item.lastWashedAt else { return true }
            return record.date > washed
        }.count
    }

    /// 展示文案；0 次返回 nil（没有信息量，只是噪音）。
    /// 从没洗过时**换一句话**说——不得谎称「距上次洗涤」。
    @MainActor
    public static func caption(_ item: Item, in context: ModelContext) -> String? {
        caption(item, records: (try? context.fetch(FetchDescriptor<WearRecord>())) ?? [])
    }

    /// 同上，按已取记录。
    @MainActor
    public static func caption(_ item: Item, records: [WearRecord]) -> String? {
        let n = wearsSinceWash(item, records: records)
        guard n > 0 else { return nil }
        let times = n == 1 ? "once" : "\(n) times"
        return item.lastWashedAt == nil
            ? "Worn \(times) — not washed yet"
            : "Worn \(times) since the last wash"
    }
}
