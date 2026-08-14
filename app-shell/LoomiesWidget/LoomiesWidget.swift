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

    /// 系统这一刻按什么模式画（主屏全彩 / 锁屏与去饱和主屏的单色）。
    @Environment(\.widgetRenderingMode) private var renderingMode

    /// 语义映射只此一行——判断规则住在 `TodayWidgetCopy`（可测），
    /// ClosetCore 不认识 WidgetKit。
    private var colorRendering: TodayWidgetColorRendering {
        renderingMode == .fullColor ? .trueColor : .monochrome
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let snapshot = entry.snapshot, !entry.isStale {
                Text(TodayWidgetCopy.headline(snapshot))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let title = snapshot.lookTitle {
                    Text(title).font(.headline).lineLimit(1)
                }
                if snapshot.pieces.isEmpty {
                    Text(TodayWidgetCopy.emptyPieces)
                        .font(.caption).foregroundStyle(.secondary)
                } else if TodayWidgetCopy.showsColorDots(colorRendering) {
                    // 全彩：今天这身的**配色**就是这块界面的主角
                    //（DESIGN §10.1：衣物是唯一的色彩来源）
                    PieceColorStrip(pieces: snapshot.pieces)
                    Text(snapshot.pieces.map(\.name).joined(separator: " · "))
                        .font(.subheadline)
                        .lineLimit(2)
                } else {
                    // 单色渲染：色点会被系统全部染成同一个强调色，那时它们在说谎。
                    // 只留名字（`showsColorDots` 那条注释写了为什么）。
                    Text(snapshot.pieces.map(\.name).joined(separator: " · "))
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

/// 今天这身的配色，一件一个点（D210）。
///
/// DESIGN §10.1 把整套设计语言压在一句话上：**衣物是界面唯一的色彩主角**。
/// 而 D197 交付的 widget 从头到尾只有灰字——主屏上那一格里，
/// 这个 App 看不出是做衣服的。
///
/// 照片不能出 App 沙盒（D197 的边界，D210 重新审过仍然维持），
/// 但颜色可以——它只是 16 个调色板 id 之一，比件名还少的信息量。
private struct PieceColorStrip: View {
    let pieces: [TodayWidgetSnapshot.Piece]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(pieces.enumerated()), id: \.offset) { _, piece in
                if let entry = piece.paletteEntry {
                    Circle()
                        .fill(Color(
                            .sRGB, red: entry.red, green: entry.green, blue: entry.blue))
                        .frame(width: 11, height: 11)
                } else {
                    // 没设颜色 / 认不出的 id：画个空圈占位，**不跳过**——
                    // 跳过会让点数与件数对不上，用户会以为漏了一件。
                    Circle()
                        .strokeBorder(.tertiary, lineWidth: 1)
                        .frame(width: 11, height: 11)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        // 文案规则住在 ClosetCore（可测）——app-shell 不参与 swift test，
        // 把判断留在这里等于零覆盖。
        .accessibilityLabel(TodayWidgetCopy.coloursSpoken(pieces))
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
