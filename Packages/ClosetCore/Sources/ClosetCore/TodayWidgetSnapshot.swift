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
/// - **可以（D210 新增）**：每件的**调色板 id**——16 个固定值之一（`"navy"`），
///   不是 hex、更不是照片。它比件名**更少**信息量：件名是自由文本、可能带品牌，
///   `"navy"` 只说得出一个色相。
/// - **绝不**：身体围度（D5 局域，连主库都不进）、**照片**、城市名。
///   照片这条 D197 立的时候只给了「不需要」当理由（那会儿 widget 只画一行字）；
///   D210 要让颜色上主屏，于是重新审了一遍——结论仍是不出去，
///   但**理由换成了「有更省的办法」**：色点要的是色相，而照片带的是全部像素。
///
/// `TodayWidgetSnapshotTests` 把这条边界打在**编码后的 JSON 键**上——
/// 那才是真正落进容器的东西，且列举完备（连 `pieces` 里每件的字段也列举）。
public struct TodayWidgetSnapshot: Codable, Equatable, Sendable {

    /// 一件衣服在 widget 上的全部身份：名字 + 颜色。
    ///
    /// **刻意不做成两个平行数组**（`pieceNames` + `pieceColorIDs`）——
    /// 那种写法只要有一处长度不同步，白衬衫旁边就会画上黑点，
    /// 而错位不会崩、不会红，只会静静地说谎。名字与颜色绑在同一个值里，
    /// 这种错位在类型上就不可能发生（本 session 反复的那条：
    /// **不变式由结构维持，不是由论证维持**）。
    public struct Piece: Codable, Equatable, Sendable {
        public let name: String
        /// `GarmentColorPalette` 的 id；nil = 这件没设颜色（**不猜**）。
        public let colorPaletteID: String?

        public init(name: String, colorPaletteID: String?) {
            self.name = name
            self.colorPaletteID = colorPaletteID
        }

        /// 还原成可画的颜色。认不出的 id → nil（存量快照、将来改调色板都走这条），
        /// 画面上就是留白，**不挑个相近的顶上**。
        public var paletteEntry: GarmentColorPalette.Entry? {
            GarmentColorPalette.entry(id: colorPaletteID)
        }
    }

    /// 这份快照说的是哪一天（`yyyy-MM-dd`，与 `CalendarPlanService.dayKey` 同口径）。
    public let dayKey: String
    /// look 的名字；没有就 nil（不编一个）。
    public let lookTitle: String?
    /// 这一身有哪几件（顺序即展示顺序）。
    public let pieces: [Piece]
    /// 日间温度（°F）。nil = 今天几度还不知道——**不填默认值**（D130 同款三值语义）。
    public let daytimeTempF: Int?
    /// 温度是哪来的（"Open-Meteo" / 离线气候常模…）。nil = 没有温度就没有来源。
    public let weatherSourceLabel: String?
    /// 今天这身是**已经定了**（打过卡 / 排过计划），还是只是个建议。
    public let isSettled: Bool

    public init(
        dayKey: String, lookTitle: String?, pieces: [Piece],
        daytimeTempF: Int?, weatherSourceLabel: String?, isSettled: Bool
    ) {
        self.dayKey = dayKey
        self.lookTitle = lookTitle
        self.pieces = pieces
        self.daytimeTempF = daytimeTempF
        self.weatherSourceLabel = weatherSourceLabel
        self.isSettled = isSettled
    }
}

/// widget 这一刻能不能按**真实颜色**画。
///
/// ClosetCore 不认识 WidgetKit（零 iOS SDK 依赖是硬约束），
/// 所以这里说的是语义，映射那一行留在 widget 里。
public enum TodayWidgetColorRendering: Sendable {
    /// 主屏全彩——画什么颜色就是什么颜色。
    case trueColor
    /// 锁屏 / 去饱和主屏（`accented`、`vibrant`）：系统会把画面里的一切
    /// 染成同一个强调色。
    case monochrome
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

    /// 这一刻**该不该**画色点。
    ///
    /// 单色渲染下不画。系统会把三个色点染成同一个强调色，那时它们在说谎——
    /// 用户会读成「今天这三件是同色系」。宁可只留名字：
    /// **不能诚实显示的时候什么都不显示**，不是显示一个看起来还行的默认值
    ///（D130 三值语义的同一条）。
    public static func showsColorDots(_ rendering: TodayWidgetColorRendering) -> Bool {
        rendering == .trueColor
    }

    /// 色点那一条的 VoiceOver 读法（§10.4 无障碍是硬约束）。
    ///
    /// 读的是**颜色名**，不是「11 个圆点」。没设颜色的件在这里也不编——
    /// 它就是不出现在这句话里（宁可少说，不许编）。
    public static func coloursSpoken(_ pieces: [TodayWidgetSnapshot.Piece]) -> String {
        let names = pieces.compactMap { $0.paletteEntry?.title }
        return names.isEmpty ? "" : "Colours: " + names.joined(separator: ", ")
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
        return decode(data)
    }

    /// 先按当前结构解；解不开再试**旧结构**（`pieceNames` 平行数组）并就地迁移。
    ///
    /// D210 把 `pieceNames:[String]` 换成 `pieces:[Piece]`。存量快照缺 `pieces`
    /// 键、当前解码会直接失败——升级后**第一次**刷新 widget 就退成「Open Loomies…」，
    /// 仿佛从没开过 App（D188 那条「过期快照说谎」的近亲：这次是「有快照却装没有」）。
    /// 认出旧结构、转成无颜色的 pieces，把这唯一一次能避免的谎堵掉。
    ///
    /// 两条路都失败才是 nil——**彻底的垃圾不迁移**，不因为多了条旧解码路径就凭空造快照。
    /// 迁移只发生在**读**：写永远是新结构（`write` 直接编码 `TodayWidgetSnapshot`），
    /// 一次读→写就把旧文件换成新的，平行数组不复活（C4）。
    static func decode(_ data: Data) -> TodayWidgetSnapshot? {
        let decoder = JSONDecoder()
        if let current = try? decoder.decode(TodayWidgetSnapshot.self, from: data) {
            return current
        }
        if let legacy = try? decoder.decode(LegacyTodayWidgetSnapshot.self, from: data) {
            return legacy.migrated
        }
        return nil
    }

    /// 删掉（删库时要一起清——共享容器不在 App 沙盒里，
    /// 「removes everything on this device」不能把它漏了）。
    public static func clear(in directory: URL?) {
        guard let directory else { return }
        try? FileManager.default.removeItem(
            at: directory.appendingPathComponent(fileName))
    }
}

/// D210 之前的快照结构：件是**平行的字符串数组**，没有颜色。
///
/// **只用于读**——一次性把旧文件迁移到 `pieces`（`TodayWidgetSnapshotStore.decode`）。
/// 绝不用于写：C4 冻死「新写永远是 `pieces:[Piece]`」，平行数组正是 D210 特意消灭的
/// 那种「白衬衫旁边画黑点」的错位温床，不许在这里借尸还魂。
///
/// 非可选字段（`dayKey`/`pieceNames`/`isSettled`）是刻意的**存在性闸门**：
/// 缺了它们解码就失败，于是彻底的垃圾落不进迁移路径（`decode` 会继续返回 nil）。
private struct LegacyTodayWidgetSnapshot: Decodable {
    let dayKey: String
    let lookTitle: String?
    let pieceNames: [String]
    let daytimeTempF: Int?
    let weatherSourceLabel: String?
    let isSettled: Bool

    /// 转成当前结构。旧数据没有颜色 → 每件 `colorPaletteID: nil`（**不猜**，
    /// 认不出/没有都在画面上留白，与 `Piece.paletteEntry` 的口径一致）。
    var migrated: TodayWidgetSnapshot {
        TodayWidgetSnapshot(
            dayKey: dayKey,
            lookTitle: lookTitle,
            pieces: pieceNames.map { .init(name: $0, colorPaletteID: nil) },
            daytimeTempF: daytimeTempF,
            weatherSourceLabel: weatherSourceLabel,
            isSettled: isSettled)
    }
}
