import Foundation

/// 一个可选的城市（D107）。城市此前是**纯自由文本**：没有联想、没有标准名、
/// 拼错了也不告诉你，而 geocoding 一直在跑，只是取第一条、丢掉行政区与国家。
/// 「Springfield」到底是哪一个，用户和 App 都不知道。
public struct CityMatch: Sendable, Equatable, Identifiable {
    public let city: String
    /// 州/省。很多国家没有这一级，故可空。
    public let region: String?
    public let country: String?
    public let countryCode: String?
    public let latitude: Double
    public let longitude: Double
    /// IANA 时区（日界口径用）。
    public let timezone: String?

    public init(
        city: String, region: String?, country: String?, countryCode: String?,
        latitude: Double, longitude: Double, timezone: String?
    ) {
        self.city = city
        self.region = region
        self.country = country
        self.countryCode = countryCode
        self.latitude = latitude
        self.longitude = longitude
        self.timezone = timezone
    }

    /// 稳定 id：坐标 + 名字（同名同区的两个点也分得开）。
    public var id: String {
        "\(city)|\(region ?? "")|\(country ?? "")|\(latitude),\(longitude)"
    }

    /// 标准名：「Austin, Texas, United States」。
    /// 缺行政区时降级为「Singapore, Singapore」，不留悬空逗号。
    public var displayName: String {
        [city, region, country]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

/// 城市辅助输入的纯值规则。
public enum CitySearch {
    /// 少于两个字符不值得发请求——省一次网络，也避免把半个国家列出来。
    public static func isWorthSearching(_ raw: String) -> Bool {
        (TextNormalize.blankToNil(raw)?.count ?? 0) >= 2
    }

    /// 存进衣柜的是**标准名**——下次 geocode 不再有歧义。
    public static func storedValue(for match: CityMatch) -> String { match.displayName }

    /// 候选顺序确定：按标准名，再按坐标决胜（列表不得每次抖动）。
    public static func ordered(_ matches: [CityMatch]) -> [CityMatch] {
        matches.sorted {
            ($0.displayName, $0.latitude, $0.longitude)
                < ($1.displayName, $1.latitude, $1.longitude)
        }
    }

    public static let noMatchMessage = "No city by that name — check the spelling."
    /// D128：网络确实可能恢复，所以「重试」不算错——但离线时用户干等没有意义。
    /// 同时给出**这一刻就能走通**的那条路：天气有离线气候兜底。
    public static let searchFailedMessage =
        "Couldn't reach the city lookup. Try again, or set the city later — "
        + "the forecast falls back to an offline estimate."
    /// 未选中候选时的诚实说明：天气要靠这个名字去查。
    public static let unresolvedHint =
        "Pick a city from the list so the forecast knows where you are."
}
