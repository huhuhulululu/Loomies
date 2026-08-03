import Foundation

/// 日间温度源（DESIGN §F4 正确性 #1：天气只按日间时段）。
/// 真机接 WeatherKit；测试/离线用 Fixed。协议层隔离，UI 与引擎不绑 SDK。
public protocol WeatherProviding: Sendable {
    /// 日间代表温度（°F），供候选温区过滤。
    func daytimeTemperatureF(forCity city: String?, on date: Date) async throws -> Double
}

/// 固定温度（测试 / 无网 / 用户手动覆盖）。
public struct FixedWeatherProvider: WeatherProviding {
    public let temperatureF: Double
    public init(temperatureF: Double) { self.temperatureF = temperatureF }

    public func daytimeTemperatureF(forCity city: String?, on date: Date) async throws -> Double {
        temperatureF
    }
}

/// 城市气候表 + 月份偏置（离线可用；真机后续可换 WeatherKit 实现同一协议）。
/// 非气象预报——仅给 copilot 温区过滤一个合理日间代表温。
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
        for (k, v) in table where key.contains(k) || k.contains(key) { return v }
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
