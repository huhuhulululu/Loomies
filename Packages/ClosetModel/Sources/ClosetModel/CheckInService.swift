import Foundation
import SwiftData

/// 穿着打卡（DESIGN §F5，v1.0「记录」环）：记录当天穿了哪些单品，固化衣柜快照。
public enum CheckInService {
    @discardableResult
    public static func recordWear(
        items: [Item], on date: Date, in wardrobe: Wardrobe,
        fitFeedback: String? = nil, in context: ModelContext
    ) -> WearRecord {
        let rec = WearRecord(date: date)
        rec.wornItemIDs = items.map { $0.id.uuidString }
        rec.wardrobeSnapshotID = wardrobe.id
        rec.fitFeedback = fitFeedback
        context.insert(rec)
        try? context.save()
        return rec
    }
}

/// 穿着历史查询：喂 RecommendationService 的防重复（gate #3）。
public enum WearHistory {
    /// 截至 asOf 的近 days 天内穿过的单品 id 集合（uuidString）。
    public static func recentlyWornItemIDs(
        within days: Int, asOf date: Date, in context: ModelContext
    ) -> Set<String> {
        let cutoff = date.addingTimeInterval(-Double(days) * 86_400)
        let records = (try? context.fetch(FetchDescriptor<WearRecord>())) ?? []
        var result = Set<String>()
        for r in records where r.date >= cutoff && r.date <= date {
            result.formUnion(r.wornItemIDs)
        }
        return result
    }
}
