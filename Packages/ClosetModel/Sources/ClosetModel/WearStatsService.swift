import Foundation
import SwiftData
import ClosetCore

/// 单品的穿着回读（D119）。
///
/// 每次「Wore it」都落了一条 `WearRecord`，而单品详情页上没有任何一处回答
/// 「这件我穿过几次 / 上次什么时候穿的」——数据写了一年，**从来不给用户看**。
/// DEMAND-VALIDATION §2 记录的 PIVOT 明确点名「记住我哪天穿了什么 /
/// 防重复购买」是研究里的 #1 JTBD（19 次自发提及）。
///
/// 刻意**不做**：CPW（要价格数据）、利用率仪表盘、「最少穿」排行榜——
/// 那些是 FEATURE-GAP 里被否掉的「统计秀」。这里只产出一句
/// 在用户看得见的地方用得上的话。
public enum WearStatsService {

    public struct Stats: Equatable, Sendable {
        public let count: Int
        public let lastWorn: Date?

        public init(count: Int, lastWorn: Date?) {
            self.count = count
            self.lastWorn = lastWorn
        }

        /// 一行摘要。没穿过就说没穿过——不伪造 0 次，也不伪造一个日期。
        public var summary: String {
            guard count > 0, let lastWorn else { return neverWornSummary }
            let times = count == 1 ? "once" : "\(count) times"
            return "Worn \(times) · last \(Self.relative(lastWorn))"
        }

        /// 相对日期（「yesterday」比「Aug 11」更像有人记得你）。
        static func relative(_ date: Date, now: Date = Date()) -> String {
            let cal = Calendar.current
            let days = cal.dateComponents(
                [.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: now)).day ?? 0
            switch days {
            case ..<0:  return "today"      // 时区/时钟漂移，别说「-1 天前」
            case 0:     return "today"
            case 1:     return "yesterday"
            case 2...6: return "\(days) days ago"
            default:
                let f = DateFormatter()
                f.locale = Locale(identifier: "en_US")
                f.setLocalizedDateFormatFromTemplate("MMMd")   // §10.5：en-US MM/DD
                return f.string(from: date)
            }
        }
    }

    public static let neverWornSummary = "Not worn yet"

    /// 单件。
    @MainActor
    public static func stats(for item: Item, in context: ModelContext) -> Stats {
        guard let wardrobeID = item.wardrobe?.id else { return Stats(count: 0, lastWorn: nil) }
        let key = item.id.uuidString
        let records = (try? context.fetch(FetchDescriptor<WearRecord>())) ?? []
        var count = 0
        var last: Date?
        for r in records where r.wardrobeSnapshotID == wardrobeID && r.wornItemIDs.contains(key) {
            count += 1
            if last == nil || r.date > last! { last = r.date }
        }
        return Stats(count: count, lastWorn: last)
    }

    /// 整柜批量。逐件调上面那个会退化成 N 次全表扫描——
    /// 检索页每行都要这条信息，那是百件规模的热路径。
    @MainActor
    public static func stats(
        forItemsIn wardrobe: Wardrobe, in context: ModelContext
    ) -> [UUID: Stats] {
        let records = (try? context.fetch(FetchDescriptor<WearRecord>())) ?? []
        var counts: [String: Int] = [:]
        var lasts: [String: Date] = [:]
        for r in records where r.wardrobeSnapshotID == wardrobe.id {
            for id in r.wornItemIDs {
                counts[id, default: 0] += 1
                if let existing = lasts[id] {
                    if r.date > existing { lasts[id] = r.date }
                } else {
                    lasts[id] = r.date
                }
            }
        }
        var out: [UUID: Stats] = [:]
        for item in wardrobe.items ?? [] {
            let key = item.id.uuidString
            out[item.id] = Stats(count: counts[key] ?? 0, lastWorn: lasts[key])
        }
        return out
    }
}
