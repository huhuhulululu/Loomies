import Foundation

/// 日间温度源（DESIGN §F4 正确性 #1：天气只按日间时段）。
/// 生产：`CompositeWeatherProvider` = Open-Meteo（公开 API，免 key）→ `CityClimateWeatherProvider` 离线表。
/// 可选 WeatherKit 可再实现本协议。UI/引擎只依赖协议，不绑 SDK。
public protocol WeatherProviding: Sendable {
    /// 日间代表温度（°F），供候选温区过滤。
    func daytimeTemperatureF(forCity city: String?, on date: Date) async throws -> Double
}

/// Richer day snapshot for UI honesty + light dress hints (rain → outerwear).
public struct WeatherDaySnapshot: Equatable, Sendable {
    public var daytimeTempF: Double
    /// Short user-facing source, e.g. "Open-Meteo" / "Offline estimate".
    public var sourceLabel: String
    /// 0…100 max precipitation probability for the day when known.
    public var precipProbabilityPercent: Int?
    public init(
        daytimeTempF: Double,
        sourceLabel: String,
        precipProbabilityPercent: Int? = nil
    ) {
        self.daytimeTempF = daytimeTempF
        self.sourceLabel = sourceLabel
        self.precipProbabilityPercent = precipProbabilityPercent
    }

    /// Prefer outerwear hint when cool or likely wet (practical dress cue, not a hard filter).
    public var suggestsOuterwearCue: Bool {
        if daytimeTempF < 60 { return true }
        if let p = precipProbabilityPercent, p >= 50 { return true }
        return false
    }
}

/// Optional richer fetch; default synthesizes snapshot from temperature only.
public protocol WeatherSnapshotProviding: WeatherProviding {
    func daySnapshot(forCity city: String?, on date: Date) async throws -> WeatherDaySnapshot
}

extension FixedWeatherProvider: WeatherSnapshotProviding {
    public func daySnapshot(forCity city: String?, on date: Date) async throws -> WeatherDaySnapshot {
        WeatherDaySnapshot(
            daytimeTempF: try await daytimeTemperatureF(forCity: city, on: date),
            sourceLabel: "Fixed",
            precipProbabilityPercent: nil)
    }
}

extension CityClimateWeatherProvider: WeatherSnapshotProviding {
    public func daySnapshot(forCity city: String?, on date: Date) async throws -> WeatherDaySnapshot {
        WeatherDaySnapshot(
            daytimeTempF: try await daytimeTemperatureF(forCity: city, on: date),
            sourceLabel: "Offline estimate",
            precipProbabilityPercent: nil)
    }
}

/// 固定温度（测试 / 无网 / 用户手动覆盖）。
public struct FixedWeatherProvider: WeatherProviding {
    public let temperatureF: Double
    public init(temperatureF: Double) { self.temperatureF = temperatureF }

    public func daytimeTemperatureF(forCity city: String?, on date: Date) async throws -> Double {
        temperatureF
    }
}

/// 城市气候表 + 月份偏置（离线 / Open-Meteo 失败回退）。
/// 非实时预报——粗日间代表温；实时路径见 `OpenMeteoWeatherProvider`。
public struct CityClimateWeatherProvider: WeatherProviding, Sendable {
    public init() {}

    public func daytimeTemperatureF(forCity city: String?, on date: Date) async throws -> Double {
        let base = Self.baseTempF(forCity: city)
        let month = Calendar.current.component(.month, from: date)
        let seasonal = Self.seasonalOffsetF(month: month, forCity: city)
        return (base + seasonal).rounded()
    }

    /// 城市年均日间代表温（°F）粗表。
    public static func baseTempF(forCity city: String?) -> Double {
        let key = (city ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if key.isEmpty { return 70 }
        // 美国主市场 + 常见城市
        let table: [String: Double] = [
            "new york": 62, "nyc": 62, "brooklyn": 62,
            "los angeles": 72, "la": 72, "san francisco": 64, "sf": 64,
            "seattle": 58, "chicago": 55, "boston": 58,
            "miami": 80, "houston": 78, "dallas": 75, "austin": 76,
            "denver": 58, "phoenix": 82, "atlanta": 70,
            "london": 58, "paris": 60, "tokyo": 65,
            "shanghai": 66, "beijing": 58, "hong kong": 76,
            "singapore": 86, "bangkok": 88, "sydney": 70,
        ]
        if let exact = table[key] { return exact }
        // D110：D107 之后存的是**标准名**「Austin, Texas, United States」，
        // 而这张表按裸城市名建——于是用了新选择器的用户离线时统统落到 68°F 默认值，
        // 反而不如 D107 之前手打「Austin」的用户。取第一段（城市名）再查一次。
        // 这样也修好了**已经存进去**的数据，不需要迁移。
        if let cityPart = key.split(separator: ",").first.map(String.init) {
            let bare = cityPart.trimmingCharacters(in: .whitespacesAndNewlines)
            if !bare.isEmpty, bare != key, let exact = table[bare] { return exact }
        }
        // 无子串循环：2 字母键（"la"/"sf"）会吞掉 Orlando/Glasgow 等无关城市，
        // 且多命中时随 Dictionary 迭代序（每进程 hash seed）抖动。
        // 顺序固定为：精确匹配 → 关键字启发式 → 默认。
        // 关键字启发式
        if key.contains("miami") || key.contains("tropic") || key.contains("hawaii") { return 82 }
        if key.contains("seattle") || key.contains("portland") { return 58 }
        return 68
    }

    /// 相对年均的月份偏置（北半球默认；南半球城市略反相）。
    public static func seasonalOffsetF(month: Int, forCity city: String?) -> Double {
        let key = (city ?? "").lowercased()
        let southern = key.contains("sydney") || key.contains("melbourne")
            || key.contains("auckland") || key.contains("buenos") || key.contains("santiago")
        // 北半球：1 月最冷、7 月最热
        let north: [Double] = [0, -18, -14, -6, 2, 10, 16, 18, 14, 6, -2, -10, -16] // index 1…12
        let m = min(12, max(1, month))
        let off = north[m]
        return southern ? -off * 0.85 : off
    }
}

/// 个人色彩季型（R11 可选；UI 存 Person.personalColorSeasonRaw）。
public enum PersonalColorSeason: String, CaseIterable, Sendable {
    case spring, summer, autumn, winter, unknown

    public var displayName: String {
        switch self {
        case .spring: return "Spring"
        case .summer: return "Summer"
        case .autumn: return "Autumn"
        case .winter: return "Winter"
        case .unknown: return "Not set"
        }
    }

    public static func parse(_ raw: String?) -> PersonalColorSeason {
        guard let raw, let v = PersonalColorSeason(rawValue: raw) else { return .unknown }
        return v
    }
}
