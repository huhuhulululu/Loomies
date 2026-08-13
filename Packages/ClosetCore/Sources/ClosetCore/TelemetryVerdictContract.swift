import Foundation

/// `MARKET.md` §8 预注册判定协议 ↔ 遥测事件的**对账契约**（D201）。
///
/// §8 把上线判定**现在就冻结**了（「只能按 §8.5 规则修改」），理由写得很清楚：
/// 没有预先固定的协议，「前 4 周收分布再校准」等于确认偏误许可证。
///
/// 但协议冻结了，**没有任何东西检查它算不算得出来**。
/// 少一个事件、白名单里少一个字段，到第 6 周首判那天才发现——那时数据已经没了。
///
/// 这份契约把「每条门槛需要哪些事件、哪些字段」写成**数据**，
/// 由 `TelemetryVerdictContractTests` 逐条对着 `TelemetryEvent` 校验。
/// 删事件、改白名单、改门槛，都会当场红。
public enum TelemetryVerdictContract {

    /// §8.1 的一条判定门槛，以及它**依赖什么才算得出来**。
    public struct Metric: Sendable, Equatable {
        /// §8.1 表里的指标名（改名要连同 MARKET.md 一起改）。
        public let name: String
        /// 算这条指标必须存在的事件。
        public let events: [TelemetryEvent]
        /// 事件上必须存在的字段（键必须在该事件的 `allowedKeys` 里）。
        public let fields: [TelemetryEvent: Set<String>]
        /// 还没有数据通路的原因；nil = 现在就算得出来。
        public let blockedBy: String?

        public init(
            name: String, events: [TelemetryEvent],
            fields: [TelemetryEvent: Set<String>] = [:],
            blockedBy: String? = nil
        ) {
            self.name = name
            self.events = events
            self.fields = fields
            self.blockedBy = blockedBy
        }
    }

    /// **sink 必须自己提供的两样东西**——App 这一层刻意不提供。
    ///
    /// `TelemetryGate.track` 只发 `(event, payload)`：没有装机标识，也没有时间戳。
    /// 那是**有意的**——装机标识是准 PII，白名单把它挡在外面，
    /// 而本仓的隐私姿态（不运营账号、没有你的副本）是对外承诺过的。
    ///
    /// 代价是：**留存类指标全靠 sink 补这两样**。接 sink 的人必须知道这条，
    /// 否则 §8 的五条门槛里有三条会在第 6 周悄悄变成算不出来。
    public static let sinkRequirements = [
        "按装机的匿名标识（跨会话稳定、可跨 30 天关联；由 sink 生成，不由 App 传）",
        "事件时间戳（判定 D30 / 7 天激活窗口都要它）",
    ]

    /// §8.1 的五条门槛。**顺序与表格一致**，便于逐行对照。
    public static let metrics: [Metric] = [
        Metric(
            name: "D30 留存(全体)",
            events: [.appLaunch],
            blockedBy: nil),
        Metric(
            name: "激活率(7 天≥40 件)",
            // 件数从 `item_confirmed` 的**事件条数**数出来，不另发一个「当前件数」——
            // 那会让每次入库都携带一个随时间增长的计数，白白多一条可指纹化的信息。
            events: [.appLaunch, .itemConfirmed],
            blockedBy: nil),
        Metric(
            name: "激活层 D30",
            events: [.appLaunch, .itemConfirmed],
            blockedBy: nil),
        Metric(
            name: "每日推送 wear-as-is 率",
            // D116 就是为这条建的：`wear_as_is` 区分「原样穿」与「改过再穿」，
            // `source` 区分「从推送进来的」与「自己打开的」——
            // 红队把这条定为 copilot 机制的**真裁决器**，两个字段缺一不可。
            events: [.copilotAccepted, .copilotTweaked],
            fields: [.copilotAccepted: ["wear_as_is", "source"]],
            blockedBy: nil),
        Metric(
            name: "买断 CVR(paywall 曝光→购)",
            events: [],
            // 诚实标注而不是假装有：没有 IAP 就没有 paywall，也就没有曝光事件。
            // 留在这里是为了**不让它被忘掉**——建 paywall 那一波必须回来补事件。
            blockedBy: "IAP / paywall 未建（FEATURE-GAP v1.x 明确后置）"),
    ]
}
