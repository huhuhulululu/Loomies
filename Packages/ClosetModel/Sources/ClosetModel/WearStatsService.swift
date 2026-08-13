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
            case 7...364:
                let f = DateFormatter()
                f.locale = Locale(identifier: "en_US")
                f.setLocalizedDateFormatFromTemplate("MMMd")   // §10.5：en-US MM/DD
                return f.string(from: date)
            default:
                // D138：**超过一年要带年份**。此前一律只给「Aug 11」——
                // 去年八月穿的和上周穿的读起来一模一样，
                // 而「上次什么时候穿的」这个问题的全部价值就在于分辨它们
                //（那也是「要不要再买一件」的判断依据）。
                let f = DateFormatter()
                f.locale = Locale(identifier: "en_US")
                f.setLocalizedDateFormatFromTemplate("MMMyyyy")
                return f.string(from: date)
            }
        }
    }

    public static let neverWornSummary = "Not worn yet"

    /// 单件。
    ///
    /// D134：**按单品本身算，不按它现在在哪个柜算**。
    /// 记录挂的是穿着那天的柜快照——把件转移到另一个柜之后，
    /// 旧记录的快照 id 仍是原柜，按当前柜过滤就变成「没穿过」：
    /// 用户刚把冬装挪进「换季箱」，一年的记录当场归零。
    /// 单品 id 全局唯一，用它就够；跨柜聚合正是这里想要的。
    @MainActor
    public static func stats(for item: Item, in context: ModelContext) -> Stats {
        let key = item.id.uuidString
        let records = (try? context.fetch(FetchDescriptor<WearRecord>())) ?? []
        var count = 0
        var last: Date?
        for r in records where r.wornItemIDs.contains(key) {
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
        stats(forItemIDs: Set((wardrobe.items ?? []).map(\.id)), in: context)
    }

    /// 按 id 批量（D141）。
    ///
    /// 跨柜检索此前对结果里出现的**每个柜**各调一次整柜版，而每次都要读全表：
    /// 命中 5 个柜 = 5 次全表扫描，还挂在 0.25s 的防抖上，每敲一个字重来一遍。
    /// 而 `WearRecord` 是这个 App 里增长最快的表（每天至少一条，从不删）。
    /// 要的其实只是「这些件的统计」——一次取完就够。
    @MainActor
    public static func stats(
        forItemIDs ids: Set<UUID>, in context: ModelContext
    ) -> [UUID: Stats] {
        guard !ids.isEmpty else { return [:] }
        let wanted = Set(ids.map(\.uuidString))
        let records = (try? context.fetch(FetchDescriptor<WearRecord>())) ?? []
        var counts: [String: Int] = [:]
        var lasts: [String: Date] = [:]
        // 按单品 id 聚合，不按柜快照过滤——否则转移过的件全成「没穿过」（D134）
        for r in records {
            for id in r.wornItemIDs where wanted.contains(id) {
                counts[id, default: 0] += 1
                if let existing = lasts[id] {
                    if r.date > existing { lasts[id] = r.date }
                } else {
                    lasts[id] = r.date
                }
            }
        }
        // 每个问到的 id 都给一条：缺键会让调用方分不清「没查」和「没穿过」
        var out: [UUID: Stats] = [:]
        for id in ids {
            let key = id.uuidString
            out[id] = Stats(count: counts[key] ?? 0, lastWorn: lasts[key])
        }
        return out
    }
}
