import Foundation

/// 搭配槽位。{上装+下装 | 连衣裙} 为基底，鞋必选，外套按温区条件加层（DESIGN §F4 outfit 语法）。
public enum GarmentSlot: String, Sendable, CaseIterable {
    case top, bottom, dress, outerwear, shoes, accessory

    /// User-facing label (never expose raw `slotRaw` in UI).
    public var displayTitle: String {
        switch self {
        case .top: return "Top"
        case .bottom: return "Bottom"
        case .dress: return "Dress"
        case .outerwear: return "Outerwear"
        case .shoes: return "Shoes"
        case .accessory: return "Accessory"
        }
    }

    /// SF Symbol for empty / missing-image placeholders.
    public var systemImageName: String {
        switch self {
        case .top: return "tshirt.fill"
        case .bottom: return "rectangle.portrait.fill"
        case .dress: return "figure.stand.dress"
        case .outerwear: return "coat.fill"
        case .shoes: return "shoe.fill"
        case .accessory: return "sparkles"
        }
    }

    /// Map stored `Item.slotRaw`; unknown values fall back to `.top`.
    public static func resolved(_ raw: String) -> GarmentSlot {
        GarmentSlot(rawValue: raw) ?? .top
    }
}

/// 单品状态机（DESIGN §2.2）。推荐候选只取 available。
public enum ItemStatus: String, Sendable {
    case available, inWash, dryCleaning, lent, idle, pending
}

/// 保暖度序级（1 最薄 → 5 最厚）。用于天气硬过滤。
public enum Warmth: Int, Sendable, CaseIterable, Comparable {
    case veryLight = 1, light, medium, warm, veryWarm
    public static func < (l: Warmth, r: Warmth) -> Bool { l.rawValue < r.rawValue }
}

/// 推荐候选单品（值类型，与持久化 Item 解耦——RulesEngine 禁依赖 SwiftData）。
/// 三值属性语义：occasions 空集 = 场合未知；warmth == nil = 温区未知。未知不硬过滤（否则冷启动空候选）。
public struct CandidateItem: Sendable, Equatable, Identifiable {
    public let id: String
    public let slot: GarmentSlot
    public let subtype: String?          // 如 "blazer"，供互斥规则
    public let occasions: Set<String>    // 空 = 未知
    public let warmth: Warmth?           // nil = 未知
    public let status: ItemStatus
    public let color: GarmentColor?      // nil = 未知
    public let attributes: Set<StyleAttribute>  // 版型属性，供体型加权

    public init(id: String, slot: GarmentSlot, subtype: String? = nil,
                occasions: Set<String> = [], warmth: Warmth? = nil,
                status: ItemStatus = .available, color: GarmentColor? = nil,
                attributes: Set<StyleAttribute> = []) {
        self.id = id
        self.slot = slot
        self.subtype = subtype
        self.occasions = occasions
        self.warmth = warmth
        self.status = status
        self.color = color
        self.attributes = attributes
    }
}

/// 温区→可接受保暖度映射（英制 °F）。gate #1 用日间时段温度查此表。
public enum WeatherFit {
    public static func acceptableWarmth(daytimeTempF t: Double) -> ClosedRange<Warmth> {
        switch t {
        case 80...:   return .veryLight ... .light
        case 65..<80: return .veryLight ... .medium
        case 50..<65: return .light ... .warm
        case 35..<50: return .medium ... .veryWarm
        default:      return .warm ... .veryWarm
        }
    }
}
