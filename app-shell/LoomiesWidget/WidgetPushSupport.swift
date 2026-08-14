import Foundation
import WidgetKit
import ClosetCore

/// WidgetKit push 刷新——**客户端半**（A8, HANDOFF §6.6 / DESIGN §10.2）。
///
/// iOS 26（WWDC25）给 widget 加了 push 刷新：服务端数据一变，往 APNs 发一条
/// `apns-push-type: widgets`，WidgetKit 收到就 reload 时间线（等价一次 `reloadTimelines`）。
/// 客户端要做两件事：
///   1. 实现一个 `WidgetPushHandler`（就是下面这个）拿 push token；
///   2. 用 `.pushHandler(_:)` 把它挂到 `WidgetConfiguration` 上（见 `LoomiesWidget.swift`）。
///
/// ### 为什么它**现在不工作**（诚实说明，勿当已上线能力）
///
/// - **服务端触发是 C9，本波不做**——没有任何服务器会发这条 push。客户端半 ≠ 端到端。
/// - **push 需要 Push Notifications entitlement**（widget extension 的 Signing & Capabilities），
///   而 `LoomiesWidget.entitlements` 里没有，本任务又**不许改 entitlements / project.yml**。
///   缺了它，`pushTokenDidChange` 拿到的 token 无效、也到不了 APNs。
///
/// 所以：**权威刷新策略仍是「跨过下一个午夜」`.after`**（`WidgetRefreshPolicy.nextReload`），
/// 跨天后 widget 自己变成「点开看今天」，不依赖任何 push（D188 的病不能靠一个还没接的
/// 服务器来治）。这个类型是**接线预留**：等 C9 落地、entitlement 加上，它即刻生效；
/// 在那之前 `pushTokenDidChange` 里**没有**「上报服务器」这一步——因为没有服务器可报。
struct LoomiesWidgetPushHandler: WidgetPushHandler {
    init() {}

    func pushTokenDidChange(_ pushInfo: WidgetPushInfo, widgets: [WidgetInfo]) {
        // 客户端半到此为止。正常流程本应把 `pushInfo`（含 push token）+ widget 订阅信息
        // 发去服务端登记——但服务端是 C9，**故意不谎称有**。也**不**把 token 写进共享容器
        //（C4：只读快照、不改写格式）。留一行诊断，证明这条回调确实接上了。
        AppLog.info(
            "widget push token changed (\(widgets.count) widget(s)); "
            + "no server sink — C9 not built, push dormant, midnight refresh remains live",
            .app)
    }
}

/// widget 时间线的**权威刷新策略**（单一真相，供 `TodayProvider` 调用）。
///
/// push 到位前（见上），唯一可靠的刷新是「跨过下一个午夜」——那一刻昨天的快照必须
/// 立刻改口成「点开看今天」，不能等用户开 App 才发现它还停在昨天（D188）。
enum WidgetRefreshPolicy {
    /// 下一个 00:01（给 App 写快照留一分钟余量）。算不出就退到一小时后再试，
    /// **绝不返回过去的时间**（那会让系统立刻重刷、空转）。
    static func nextReload(after now: Date, calendar: Calendar = .current) -> Date {
        calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime) ?? now.addingTimeInterval(3600)
    }
}
