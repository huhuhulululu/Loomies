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

    /// Map stored `Item.slotRaw` (+ optional name for dirty labels).
    /// Aligns with paper-doll `displaySlot` so UI/rec/wear share one truth
    /// (e.g. blazer-as-top → outerwear; alias `bomber` → outerwear).
    /// Unknown / accessory-only raws: keep GarmentSlot raw, else fall back to `.top`.
    public static func resolved(_ raw: String, name: String = "") -> GarmentSlot {
        if let body = BodyAvatarComposer.displaySlot(slotRaw: raw, itemName: name),
           let g = GarmentSlot(rawValue: body.rawValue) {
            return g
        }
        return GarmentSlot(rawValue: raw) ?? .top
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
    public static func acceptableWarmth(
        daytimeTempF t: Double, coldBias: Int = 0
    ) -> ClosedRange<Warmth> {
        // 垃圾输入（NaN/±inf）不得落入 default 深冬偏置：返回全温区 = 不做天气过滤
        guard t.isFinite else { return .veryLight ... .veryWarm }
        let base: ClosedRange<Warmth>
        switch t {
        case 80...:   base = .veryLight ... .light
        case 65..<80: base = .veryLight ... .medium
        case 50..<65: base = .light ... .warm
        case 35..<50: base = .medium ... .veryWarm
        default:      base = .warm ... .veryWarm
        }
        return ColdBias.shift(base, by: coldBias)
    }
}

/// 个人冷热偏置（D90）。同样 60°F，怕冷的人要的那档比默认厚。
///
/// 语义：**平移**可接受温区，不是放宽它——放宽会让候选变杂（薄厚都推），
/// 平移是同样精准但对准这个人。天气档位本身仍是硬门（DESIGN §F4 第一条）。
public enum ColdBias {
    /// 允许区间。再宽会把天气门推成全通/全禁，失去它存在的意义。
    public static let allowedRange = -2 ... 2

    public static func clamp(_ raw: Int) -> Int {
        min(max(raw, allowedRange.lowerBound), allowedRange.upperBound)
    }

    /// 平移并在端点**夹紧**——绝不产生空区间（空 = 该温度下无一件可穿）。
    public static func shift(_ range: ClosedRange<Warmth>, by rawBias: Int) -> ClosedRange<Warmth> {
        let bias = clamp(rawBias)
        guard bias != 0 else { return range }
        let lo = Warmth.veryLight.rawValue
        let hi = Warmth.veryWarm.rawValue
        let width = range.upperBound.rawValue - range.lowerBound.rawValue
        var newLo = min(max(range.lowerBound.rawValue + bias, lo), hi - width)
        newLo = min(max(newLo, lo), hi)
        let newHi = min(newLo + width, hi)
        guard let l = Warmth(rawValue: newLo), let u = Warmth(rawValue: newHi), l <= u
        else { return range }
        return l ... u
    }

    public static func title(_ rawBias: Int) -> String {
        switch clamp(rawBias) {
        case ...(-2): return "Runs much warmer"
        case -1:      return "Runs warmer"
        case 1:       return "Runs colder"
        case 2...:    return "Runs much colder"
        default:      return "Average"
        }
    }

    /// 只说做得到的：它只影响温区档位，不改场合过滤，也不改配色打分。
    public static let explainer =
        "Shifts which warmth levels get suggested at a given temperature. "
        + "Occasion and color rules are unchanged."
}
