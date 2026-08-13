import WidgetKit
import SwiftUI
import ClosetCore

/// 主屏 Widget（D197）：今天穿什么，不用开 App 就看得见。
///
/// 数据来自 App 写进 App Group 的一份极小快照（`TodayWidgetSnapshot`）——
/// Widget 跑在另一个进程里，读不到 SwiftData store，
/// 而把整个库搬进共享容器会连 D5 的身体维度局域一起搬。
///
/// **过期的快照绝不冒充今天**：D188 修过「早安提醒把用户带到昨天那身」，
/// widget 是同一个病更隐蔽的发作面——用户不点开就看不出来。
struct TodayEntry: TimelineEntry {
    let date: Date
    /// nil = 还没有快照（刚装 / 没开过 App）。
    let snapshot: TodayWidgetSnapshot?
    /// 快照说的不是今天。
    let isStale: Bool
}

struct TodayProvider: TimelineProvider {

    private func load(for date: Date) -> TodayEntry {
        let snapshot = TodayWidgetSnapshotStore.read(
            from: TodayWidgetSnapshotStore.sharedDirectory())
        let todayKey = CalendarPlanService_dayKey(for: date)
        let stale = snapshot.map { !TodayWidgetCopy.isFresh($0, todayKey: todayKey) } ?? false
        return TodayEntry(date: date, snapshot: snapshot, isStale: stale)
    }

    /// `yyyy-MM-dd`，与 App 侧 `CalendarPlanService.dayKey` 同口径。
    /// Widget 依赖不到 ClosetModel（那层拖着 SwiftData），所以在这里同构一份，
    /// 并由 `TodayWidgetSnapshotTests` 那边的 dayKey 用例守住格式。
    private func CalendarPlanService_dayKey(for date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 2026, c.month ?? 1, c.day ?? 1)
    }

    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: Date(), snapshot: nil, isStale: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(load(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let now = Date()
        // 下一次午夜刷新：跨天之后这块必须自己变成「点开看今天」，
        // 不能等用户开 App 才发现它还停在昨天。
        let nextMidnight = Calendar.current.nextDate(
            after: now, matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: [load(for: now)], policy: .after(nextMidnight)))
    }
}

struct TodayWidgetView: View {
    var entry: TodayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let snapshot = entry.snapshot, !entry.isStale {
                Text(TodayWidgetCopy.headline(snapshot))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let title = snapshot.lookTitle {
                    Text(title).font(.headline).lineLimit(1)
                }
                if snapshot.pieceNames.isEmpty {
                    Text(TodayWidgetCopy.emptyPieces)
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(snapshot.pieceNames.joined(separator: " · "))
                        .font(.subheadline)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
                if let weather = TodayWidgetCopy.weatherLine(snapshot) {
                    Text(weather).font(.caption2).foregroundStyle(.secondary)
                }
            } else {
                Text(TodayWidgetCopy.displayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                // 没快照与过期是两句不同的话——都不许把旧数据画出来
                Text(entry.snapshot == nil
                     ? TodayWidgetCopy.noSnapshot
                     : TodayWidgetCopy.stale)
                    .font(.subheadline)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

@main
struct LoomiesWidget: Widget {
    let kind = "LoomiesTodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName(TodayWidgetCopy.displayName)
        .description(TodayWidgetCopy.description)
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
