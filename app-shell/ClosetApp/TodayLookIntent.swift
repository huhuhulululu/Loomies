import Foundation
import AppIntents
import SwiftUI
import ClosetCore

/// App Intent「Today's look / 今日搭配」(A7, HANDOFF §6.6 / DESIGN §10.2)。
///
/// 让用户**不开 App** 就在 Shortcuts / Siri / Spotlight 里看到今天这身——
/// 和主屏 widget（D197）同一份数据、同一条纪律：**过期的快照绝不冒充今天**
///（D188：早安提醒把用户带到昨天那套 look，是本仓修过的病；这是它的第三个发作面）。
///
/// ### 为什么用 `AppIntent + ShowsSnippetView`，不用 `SnippetIntent`
///
/// iOS 26 的 `SnippetIntent` 是给**交互式**快照用的（卡片里放按钮/开关去跑别的 intent，
/// 外加 `reload()` 循环）。这里是 copilot 原则下的**纯展示**——「看见今天穿什么」就够了，
/// **没有「就穿它」这类副作用**（用户掌舵；要不要落定由他在 App 里自己决定）。
/// 纯展示不需要交互式协议。
///
/// 而 DESIGN §10.2 / HANDOFF §6.6 明确警告：updates 页 June 2026 段的 `SnippetIntent` 增补
/// 可能属 **iOS 27 SDK**，本 App min iOS 26 **不可依赖**。经典的
/// `AppIntent` + `.result(dialog:view:)`（`ProvidesDialog & ShowsSnippetView`）自 iOS 16 就在，
/// iOS 26 上无疑可用；且「返回 dialog+snippet 的普通 intent」在 Shortcuts / Spotlight
/// **自动可发现**——正好覆盖 §6.6 要的「今日搭配快捷卡」，又完全避开 iOS 27 面。
struct TodayLookIntent: AppIntent {
    static let title: LocalizedStringResource = "Today's look"
    static let description: IntentDescription =
        "See what you're wearing today — from Shortcuts, Siri, or Spotlight."

    // copilot：**不**把 App 拉到前台。看见快照就够了，「就穿它」不是这里的职责。
    // （`openAppWhenRun` 默认就是 false；显式写出来是把「无副作用」这条落到字面。）
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some ProvidesDialog & ShowsSnippetView {
        // 唯一数据源：App 写进 App Group 的那份极小快照（与 widget 同一读法）。
        // 读不到 / 解不开 → nil；**绝不造一份空快照冒充有数据**，更不凭空编一套 look。
        let snapshot = TodayWidgetSnapshotStore.read(
            from: TodayWidgetSnapshotStore.sharedDirectory())
        let fresh = snapshot.map {
            TodayWidgetCopy.isFresh($0, todayKey: Self.dayKey(for: Date()))
        } ?? false

        // dialog 给 Siri 念/显示，snippet 给 Spotlight/Shortcuts 画卡——两条都走同一判断。
        return .result(
            dialog: "\(Self.spokenDialog(snapshot, isFresh: fresh))",
            view: TodayLookSnippetView(
                snapshot: fresh ? snapshot : nil,
                hasStaleSnapshot: snapshot != nil && !fresh))
    }

    /// Siri 念的那句话。过期/无快照两种情形复用 `TodayWidgetCopy`（与 widget 唯一真相同源）；
    /// 有当天快照时按「已定 vs 建议」起头，只陈述快照里**真有**的字段，不补默认值、不编。
    private static func spokenDialog(
        _ snapshot: TodayWidgetSnapshot?, isFresh: Bool
    ) -> String {
        guard let snapshot, isFresh else {
            return snapshot == nil ? TodayWidgetCopy.noSnapshot : TodayWidgetCopy.stale
        }
        var parts: [String] = [TodayWidgetCopy.headline(snapshot)]   // Today / Suggested
        if let title = snapshot.lookTitle { parts.append(title) }
        parts.append(snapshot.pieces.isEmpty
            ? TodayWidgetCopy.emptyPieces
            : snapshot.pieces.map(\.name).joined(separator: ", "))
        if let weather = TodayWidgetCopy.weatherLine(snapshot) { parts.append(weather) }
        return parts.joined(separator: " — ")
    }

    /// "yyyy-MM-dd"，与 `CalendarPlanService.dayKey` / widget 同口径。
    /// 这里就地同构一份而**不** `import ClosetModel`：C4 要求 intent **碰不到 SwiftData**，
    /// 而 ClosetModel 正是那一层——只为算个日期字符串把它引进来，会让「无 SwiftData」这条
    /// 从「结构上成立」退化成「靠自觉」。widget 也是同样理由自带一份。
    private static func dayKey(for date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 2026, c.month ?? 1, c.day ?? 1)
    }
}

/// Spotlight / Siri 快照卡的内容。
///
/// 复用 widget 的展示纪律，但**不能**直接引用 `TodayWidgetView`（那在另一个 target）——
/// 于是在这里同构一份精简版。判断规则仍住在 `TodayWidgetCopy`（可测），这里只画。
private struct TodayLookSnippetView: View {
    /// 当天且新鲜的快照；nil = 没有可显示的今天（见 `hasStaleSnapshot` 区分文案）。
    let snapshot: TodayWidgetSnapshot?
    /// 有快照但过期——要显示的是「点开看今天」，不是「还没有」。
    let hasStaleSnapshot: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let snapshot {
                Text(TodayWidgetCopy.headline(snapshot))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let title = snapshot.lookTitle {
                    Text(title).font(.headline).lineLimit(1)
                }
                if snapshot.pieces.isEmpty {
                    Text(TodayWidgetCopy.emptyPieces)
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    // 快照卡按**全彩**渲染（不像锁屏 widget 会被系统去饱和），
                    // 所以颜色可以当主角（DESIGN §10.1：衣物是唯一的色彩来源）。
                    SnippetColorStrip(pieces: snapshot.pieces)
                    Text(snapshot.pieces.map(\.name).joined(separator: " · "))
                        .font(.subheadline).lineLimit(2)
                }
                if let weather = TodayWidgetCopy.weatherLine(snapshot) {
                    Text(weather).font(.caption2).foregroundStyle(.secondary)
                }
            } else {
                Text(TodayWidgetCopy.displayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                // 没快照与过期是两句不同的话——都不许把旧数据画出来。
                Text(hasStaleSnapshot ? TodayWidgetCopy.stale : TodayWidgetCopy.noSnapshot)
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

/// 今天这身的配色，一件一个点（与 widget `PieceColorStrip` 同构，D210）。
private struct SnippetColorStrip: View {
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
                    // 没设颜色 / 认不出的 id：画空圈占位，**不跳过**——
                    // 跳过会让点数与件数对不上，用户会以为漏了一件。
                    Circle()
                        .strokeBorder(.tertiary, lineWidth: 1)
                        .frame(width: 11, height: 11)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(TodayWidgetCopy.coloursSpoken(pieces))
    }
}
