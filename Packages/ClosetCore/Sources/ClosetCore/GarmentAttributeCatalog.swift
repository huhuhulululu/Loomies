import Foundation

// MARK: - Warmth 录入

extension Warmth {
    /// 由薄到厚，供 UI 直接铺 5 档。
    public static var ordered: [Warmth] { allCases.sorted { $0.rawValue < $1.rawValue } }

    /// 人话档位名（en-US，首发美区）。
    public var displayTitle: String {
        switch self {
        case .veryLight: return "Very light"
        case .light: return "Light"
        case .medium: return "Medium"
        case .warm: return "Warm"
        case .veryWarm: return "Very warm"
        }
    }

    /// 一句话锚定，用户不必猜「medium 是什么」——温区是天气硬过滤的输入。
    public var entryHint: String {
        switch self {
        case .veryLight: return "Camisole, linen, sheer"
        case .light: return "Tee, thin shirt, summer dress"
        case .medium: return "Long sleeve, light knit, jeans"
        case .warm: return "Sweater, jacket, heavy knit"
        case .veryWarm: return "Winter coat, down, wool overcoat"
        }
    }
}

// MARK: - StyleAttribute 录入

extension StyleAttribute {
    /// 人话属性名（体型加权表的输入；用户看的是版型语言，不是 rawValue）。
    public var displayTitle: String {
        switch self {
        case .wrap: return "Wrap"
        case .belt: return "Belted"
        case .highWaist: return "High waist"
        case .straightNoWaist: return "Straight, no waist"
        case .boatNeck: return "Boat neck"
        case .structuredTop: return "Structured top"
        case .aLine: return "A-line"
        case .lowRise: return "Low rise"
        case .vNeck: return "V-neck"
        case .empireWaist: return "Empire waist"
        case .draping: return "Draped"
        case .peplum: return "Peplum"
        case .wideLeg: return "Wide leg"
        case .paddedShoulder: return "Padded shoulder"
        }
    }

    /// 录入分区（UI 分组展示）。必须覆盖全部 case 且不重复——有测试守。
    public struct EntryGroup: Sendable, Equatable {
        public let title: String
        public let attributes: [StyleAttribute]
        public init(title: String, attributes: [StyleAttribute]) {
            self.title = title
            self.attributes = attributes
        }
    }

    public static var entryGroups: [EntryGroup] {
        [
            EntryGroup(title: "Waist", attributes: [.wrap, .belt, .highWaist, .empireWaist, .straightNoWaist, .lowRise]),
            EntryGroup(title: "Neckline & shoulder", attributes: [.vNeck, .boatNeck, .structuredTop, .paddedShoulder]),
            EntryGroup(title: "Silhouette", attributes: [.aLine, .peplum, .draping, .wideLeg]),
        ]
    }
}

// MARK: - 颜色调色板（录入 → GarmentColor）

/// 颜色录入调色板：把「选一个色块」映射到打分引擎需要的 `GarmentColor`（hue + 中性）。
/// 纯 Swift（rgb 为 0…1 分量，UI 侧自行转 Color），id 稳定可落库/回读。
public enum GarmentColorPalette {

    public struct Entry: Sendable, Equatable, Identifiable {
        public let id: String
        public let title: String
        public let hueDegrees: Double
        public let isNeutral: Bool
        public let red: Double
        public let green: Double
        public let blue: Double

        public var color: GarmentColor {
            GarmentColor(hueDegrees: hueDegrees, isNeutral: isNeutral)
        }
    }

    /// 中性在前（衣橱里占多数），彩色按色轮顺序。
    public static let entries: [Entry] = [
        Entry(id: "black", title: "Black", hueDegrees: 0, isNeutral: true, red: 0.12, green: 0.12, blue: 0.13),
        Entry(id: "grey", title: "Grey", hueDegrees: 30, isNeutral: true, red: 0.55, green: 0.55, blue: 0.57),
        Entry(id: "white", title: "White", hueDegrees: 60, isNeutral: true, red: 0.96, green: 0.96, blue: 0.94),
        Entry(id: "beige", title: "Beige", hueDegrees: 90, isNeutral: true, red: 0.85, green: 0.78, blue: 0.66),
        Entry(id: "brown", title: "Brown", hueDegrees: 150, isNeutral: true, red: 0.42, green: 0.30, blue: 0.22),
        Entry(id: "navy", title: "Navy", hueDegrees: 220, isNeutral: true, red: 0.13, green: 0.19, blue: 0.35),
        Entry(id: "denim", title: "Denim", hueDegrees: 280, isNeutral: true, red: 0.36, green: 0.47, blue: 0.62),
        Entry(id: "red", title: "Red", hueDegrees: 0, isNeutral: false, red: 0.78, green: 0.18, blue: 0.20),
        Entry(id: "orange", title: "Orange", hueDegrees: 28, isNeutral: false, red: 0.88, green: 0.48, blue: 0.19),
        Entry(id: "yellow", title: "Yellow", hueDegrees: 52, isNeutral: false, red: 0.92, green: 0.79, blue: 0.28),
        Entry(id: "olive", title: "Olive", hueDegrees: 80, isNeutral: false, red: 0.51, green: 0.53, blue: 0.30),
        Entry(id: "green", title: "Green", hueDegrees: 130, isNeutral: false, red: 0.24, green: 0.55, blue: 0.36),
        Entry(id: "teal", title: "Teal", hueDegrees: 178, isNeutral: false, red: 0.16, green: 0.53, blue: 0.55),
        Entry(id: "blue", title: "Blue", hueDegrees: 212, isNeutral: false, red: 0.22, green: 0.45, blue: 0.78),
        Entry(id: "purple", title: "Purple", hueDegrees: 272, isNeutral: false, red: 0.45, green: 0.32, blue: 0.67),
        Entry(id: "pink", title: "Pink", hueDegrees: 330, isNeutral: false, red: 0.87, green: 0.50, blue: 0.62),
    ]

    /// id 查表（大小写/空白容错——落库脏值回读）。
    public static func entry(id rawID: String?) -> Entry? {
        guard let key = TextNormalize.blankToNil(rawID)?.lowercased() else { return nil }
        return entries.first { $0.id == key }
    }

    /// 最近色板（回读已存单品 → 选中态）。中性与彩色互不串台；脏值/未知返回 nil。
    public static func nearest(to color: GarmentColor?) -> Entry? {
        guard let color, color.hueDegrees.isFinite else { return nil }
        let pool = entries.filter { $0.isNeutral == color.isNeutral }
        guard !pool.isEmpty else { return nil }
        return pool.min { a, b in
            let da = ColorHarmony.hueDistance(a.hueDegrees, color.hueDegrees)
            let db = ColorHarmony.hueDistance(b.hueDegrees, color.hueDegrees)
            // 等距按 id 决胜——排序确定性（禁止依赖数组偶然顺序）
            return da != db ? da < db : a.id < b.id
        }
    }
}
