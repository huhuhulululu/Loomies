import Foundation

/// 主屏 Widget 要画的那一点点东西（D197）。
///
/// Widget 跑在**另一个进程**里，读不到 App 的 SwiftData store。
/// 与其把整个库搬进共享容器（连带把 D5 的身体维度局域也一起搬），
/// 不如让 App 在 Today 落定时写一份**极小的快照**过去。
///
/// ### 边界：什么可以出这个沙盒
///
/// 快照落在 App Group 共享容器里——同一台设备、只有本 App 组读得到，
/// **不是出网**。但它确实离开了 App 自己的沙盒，所以清单要收得住：
///
/// - **可以**：件名、look 标题、温度、天气来源。那正是 widget 要显示的东西，
///   不给就没有 widget。
/// - **绝不**：身体围度（D5 局域，连主库都不进）、照片、城市名。
///   温度已经够画一行字了，城市名多一分暴露面而不多一分用处。
///
/// `TodayWidgetSnapshotTests` 把这条边界打在**编码后的 JSON 键**上——
/// 那才是真正落进容器的东西，且列举完备。
public struct TodayWidgetSnapshot: Codable, Equatable, Sendable {

    /// 这份快照说的是哪一天（`yyyy-MM-dd`，与 `CalendarPlanService.dayKey` 同口径）。
    public let dayKey: String
    /// look 的名字；没有就 nil（不编一个）。
    public let lookTitle: String?
    /// 这一身有哪几件（顺序即展示顺序）。
    public let pieceNames: [String]
    /// 日间温度（°F）。nil = 今天几度还不知道——**不填默认值**（D130 同款三值语义）。
    public let daytimeTempF: Int?
    /// 温度是哪来的（"Open-Meteo" / 离线气候常模…）。nil = 没有温度就没有来源。
    public let weatherSourceLabel: String?
    /// 今天这身是**已经定了**（打过卡 / 排过计划），还是只是个建议。
    public let isSettled: Bool

    public init(
        dayKey: String, lookTitle: String?, pieceNames: [String],
        daytimeTempF: Int?, weatherSourceLabel: String?, isSettled: Bool
    ) {
        self.dayKey = dayKey
        self.lookTitle = lookTitle
        self.pieceNames = pieceNames
        self.daytimeTempF = daytimeTempF
        self.weatherSourceLabel = weatherSourceLabel
        self.isSettled = isSettled
    }
}

/// Widget 上那几句话。**过期的快照绝不冒充今天**（D188 同一条纪律：
/// 早安提醒把用户带到昨天那套 look，是本仓已经修过一次的病；
/// widget 是它的第二个发作面，而且更隐蔽——用户不点开就看不出来）。
public enum TodayWidgetCopy {
    public static let displayName = "Today's look"
    public static let description = "What you're wearing today, at a glance."

    /// 还没有任何快照（刚装、还没开过 App）。
    public static let noSnapshot = "Open Loomies to get today's look."

    /// 快照说的不是今天。
    public static let stale = "Tap to see today's look."

    public static let emptyPieces = "No pieces yet."

    /// 温度那一行；不知道就不说（不填默认值）。
    public static func weatherLine(_ snapshot: TodayWidgetSnapshot) -> String? {
        guard let t = snapshot.daytimeTempF else { return nil }
        guard let source = snapshot.weatherSourceLabel else { return "\(t)°F" }
        return "\(t)°F · \(source)"
    }

    /// 标题那一行：**已定**与**建议**是两件事，不许混为一谈。
    public static func headline(_ snapshot: TodayWidgetSnapshot) -> String {
        snapshot.isSettled ? "Today" : "Suggested"
    }

    /// 这份快照现在还能不能当「今天」用。
    public static func isFresh(_ snapshot: TodayWidgetSnapshot, todayKey: String) -> Bool {
        snapshot.dayKey == todayKey
    }
}

/// 快照的读写（App 写、Widget 读）。
///
/// `directory` 可注入：真身是 App Group 容器，测试传自己的临时目录——
/// 共享容器在测试环境根本拿不到，而且并行套件互扫是本仓踩过的坑。
public enum TodayWidgetSnapshotStore {

    /// App Group 标识。**App 与 Widget 两个 target 都要挂它**，
    /// 且必须在开发者后台注册——这一步无法由代码完成。
    public static let appGroupIdentifier = "group.com.pinglin.closet"

    public static let fileName = "today-widget.json"

    /// 共享容器目录；拿不到返回 nil（未配 App Group / 测试环境）。
    public static func sharedDirectory(
        _ fileManager: FileManager = .default
    ) -> URL? {
        fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    @discardableResult
    public static func write(_ snapshot: TodayWidgetSnapshot, to directory: URL?) -> Bool {
        guard let directory else { return false }
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: directory.appendingPathComponent(fileName), options: .atomic)
            return true
        } catch {
            AppLog.error("widget snapshot write failed: \(AppLog.errRef(error))", .app)
            return false
        }
    }

    /// 读不到 / 解不开都返回 nil——**不造一份空快照冒充有数据**。
    public static func read(from directory: URL?) -> TodayWidgetSnapshot? {
        guard let directory,
              let data = try? Data(
                contentsOf: directory.appendingPathComponent(fileName))
        else { return nil }
        return try? JSONDecoder().decode(TodayWidgetSnapshot.self, from: data)
    }

    /// 删掉（删库时要一起清——共享容器不在 App 沙盒里，
    /// 「removes everything on this device」不能把它漏了）。
    public static func clear(in directory: URL?) {
        guard let directory else { return }
        try? FileManager.default.removeItem(
            at: directory.appendingPathComponent(fileName))
    }
}
