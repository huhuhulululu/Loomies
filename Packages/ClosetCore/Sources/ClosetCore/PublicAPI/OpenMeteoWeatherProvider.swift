import Foundation

/// Live daytime temperature via **Open-Meteo** (https://open-meteo.com) — free, no API key.
/// Flow: geocode city → hourly °F → `DaytimeTemperature.representative` (7–19 local).
/// Daily max is not a stand-in: night highs must not drive clothing. Network failures
/// should be wrapped by `CompositeWeatherProvider` → offline climate table.
public struct OpenMeteoWeatherProvider: WeatherProviding, Sendable {
    public var transport: any PublicAPITransport
    public var geocodeLimit: Int

    public init(
        transport: any PublicAPITransport = URLSessionTransport(),
        geocodeLimit: Int = 1
    ) {
        self.transport = transport
        self.geocodeLimit = max(1, geocodeLimit)
    }

    public func daytimeTemperatureF(forCity city: String?, on date: Date) async throws -> Double {
        try await daySnapshot(forCity: city, on: date).daytimeTempF
    }

    public func daySnapshot(forCity city: String?, on date: Date) async throws -> WeatherDaySnapshot {
        let name = (city ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw PublicAPIError.unavailable }
        let place = try await geocode(name: name)
        let day = try await forecastDay(
            latitude: place.latitude, longitude: place.longitude, on: date,
            timeZoneIdentifier: place.timezone)
        return WeatherDaySnapshot(
            daytimeTempF: day.maxF,
            sourceLabel: "Open-Meteo",
            precipProbabilityPercent: day.precipProbabilityPercent)
    }

    // MARK: - Geocoding (open-meteo)

    public struct GeoPlace: Equatable, Sendable {
        public var name: String
        public var latitude: Double
        public var longitude: Double
        public var countryCode: String?
        /// IANA 时区标识（Open-Meteo geocoding 文档化字段）；nil 时退回设备本地历 + auto。
        public var timezone: String?
        public init(
            name: String, latitude: Double, longitude: Double,
            countryCode: String? = nil, timezone: String? = nil
        ) {
            self.name = name
            self.latitude = latitude
            self.longitude = longitude
            self.countryCode = countryCode
            self.timezone = timezone
        }
    }

    /// 出网 host 的**唯一真相**——披露清单从这里取值对账，不再在测试里手抄字面量
    /// （手抄的镜像数组与实现互不引用，改 host 或加 endpoint 时对账测试不会红）。
    public static let geocodeHost = "geocoding-api.open-meteo.com"
    public static let forecastHost = "api.open-meteo.com"
    public static let hosts = [geocodeHost, forecastHost]

    public func geocode(name: String) async throws -> GeoPlace {
        var comps = URLComponents(string: "https://\(Self.geocodeHost)/v1/search")
        comps?.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "count", value: String(geocodeLimit)),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "format", value: "json"),
        ]
        guard let url = comps?.url else { throw PublicAPIError.invalidURL }
        let data = try await transport.get(url: url)
        return try OpenMeteoJSON.parseGeocode(data)
    }

    /// 城市候选搜索（D107 辅助输入）。空结果不抛错——没搜到就是没搜到。
    public func searchCities(name: String, limit: Int = 8) async throws -> [CityMatch] {
        var comps = URLComponents(string: "https://\(Self.geocodeHost)/v1/search")
        comps?.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "count", value: String(max(1, limit))),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "format", value: "json"),
        ]
        guard let url = comps?.url else { throw PublicAPIError.invalidURL }
        let data = try await transport.get(url: url)
        return CitySearch.ordered(try OpenMeteoJSON.parseGeocodeMatches(data))
    }

    public struct ForecastDay: Equatable, Sendable {
        public var maxF: Double
        public var precipProbabilityPercent: Int?
    }

    public func forecastDayHighF(latitude: Double, longitude: Double, on date: Date) async throws -> Double {
        try await forecastDay(latitude: latitude, longitude: longitude, on: date).maxF
    }

    public func forecastDay(
        latitude: Double, longitude: Double, on date: Date,
        timeZoneIdentifier: String? = nil
    ) async throws -> ForecastDay {
        var comps = URLComponents(string: "https://\(Self.forecastHost)/v1/forecast")
        // 日界口径两端一致：有城市时区（geocode 返回）→ dayString 与请求都用它，
        // 设备时区 ≠ 城市时区（出差/双城衣柜）不再取错日；无 → 设备本地历 + auto（旧行为）。
        let cityTZ = timeZoneIdentifier.flatMap(TimeZone.init(identifier:))
        let day = Self.dayString(date, timeZone: cityTZ ?? .current)
        comps?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "hourly", value: "temperature_2m"),
            URLQueryItem(name: "daily", value: "precipitation_probability_max"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
            URLQueryItem(name: "timezone", value: cityTZ != nil ? timeZoneIdentifier! : "auto"),
            URLQueryItem(name: "start_date", value: day),
            URLQueryItem(name: "end_date", value: day),
        ]
        guard let url = comps?.url else { throw PublicAPIError.invalidURL }
        let data = try await transport.get(url: url)
        return try OpenMeteoJSON.parseForecastDay(data)
    }

    private static func dayString(_ date: Date, timeZone: TimeZone) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 2026, c.month ?? 1, c.day ?? 1)
    }
}

/// JSON parse helpers (fixtures + live share the same decoder path).
public enum OpenMeteoJSON {
    /// 候选城市列表（D107）。此前只取第一条、丢掉 `admin1`/`country`——
    /// 于是「Springfield 到底是哪个」用户和 App 都不知道。
    /// **空结果不是错误**（没搜到就是没搜到，不得让 UI 显示「网络错误」）。
    public static func parseGeocodeMatches(_ data: Data) throws -> [CityMatch] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw PublicAPIError.decodeFailed }
        guard let results = root["results"] as? [[String: Any]] else { return [] }
        return results.compactMap { entry in
            // 无坐标的条目跳过——进了候选也查不了天气
            guard let lat = entry["latitude"] as? Double,
                  let lon = entry["longitude"] as? Double,
                  let city = TextNormalize.blankToNil(entry["name"] as? String)
            else { return nil }
            return CityMatch(
                city: city,
                region: TextNormalize.blankToNil(entry["admin1"] as? String),
                country: TextNormalize.blankToNil(entry["country"] as? String),
                countryCode: entry["country_code"] as? String,
                latitude: lat, longitude: lon,
                timezone: entry["timezone"] as? String)
        }
    }

    public static func parseGeocode(_ data: Data) throws -> OpenMeteoWeatherProvider.GeoPlace {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = root["results"] as? [[String: Any]],
              let first = results.first,
              let lat = first["latitude"] as? Double,
              let lon = first["longitude"] as? Double
        else { throw PublicAPIError.decodeFailed }
        let name = (first["name"] as? String) ?? "Unknown"
        let cc = first["country_code"] as? String
        let tz = first["timezone"] as? String
        return .init(name: name, latitude: lat, longitude: lon, countryCode: cc, timezone: tz)
    }

    public static func parseDailyMaxF(_ data: Data) throws -> Double {
        try parseForecastDay(data).maxF
    }

    /// Hourly series as (local hour, °F). Hour is taken from the ISO-like `T` field.
    public static func parseHourlyF(_ data: Data) throws -> [(hour: Int, tempF: Double)] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hourly = root["hourly"] as? [String: Any],
              let times = hourly["time"] as? [String],
              let temps = hourly["temperature_2m"] as? [Any],
              times.count == temps.count
        else { throw PublicAPIError.decodeFailed }
        var out: [(hour: Int, tempF: Double)] = []
        out.reserveCapacity(times.count)
        for (stamp, raw) in zip(times, temps) {
            guard let hour = hourComponent(from: stamp) else { continue }
            let temp: Double
            if let d = raw as? Double { temp = d }
            else if let n = raw as? NSNumber { temp = n.doubleValue }
            else { continue }
            out.append((hour, temp))
        }
        return out
    }

    public static func parseForecastDay(_ data: Data) throws -> OpenMeteoWeatherProvider.ForecastDay {
        let series = try parseHourlyF(data)
        guard let daytime = DaytimeTemperature.representative(hourlyF: series) else {
            throw PublicAPIError.decodeFailed
        }
        var precip: Int?
        if let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let daily = root["daily"] as? [String: Any],
           let arr = daily["precipitation_probability_max"] as? [Any],
           let p0 = arr.first {
            if let d = p0 as? Double { precip = Int(d.rounded()) }
            else if let n = p0 as? NSNumber { precip = n.intValue }
            else if let i = p0 as? Int { precip = i }
        }
        return .init(maxF: daytime.rounded(), precipProbabilityPercent: precip)
    }

    static func hourComponent(from stamp: String) -> Int? {
        guard let t = stamp.firstIndex(of: "T") else { return nil }
        let digits = stamp[stamp.index(after: t)...].prefix(while: \.isNumber)
        return Int(digits)
    }
}

extension OpenMeteoWeatherProvider: WeatherSnapshotProviding {}

/// Tries live Open-Meteo first; on any failure uses offline `CityClimateWeatherProvider`.
public struct CompositeWeatherProvider: WeatherProviding, WeatherSnapshotProviding, Sendable {
    public var primary: any WeatherProviding
    public var fallback: any WeatherProviding

    public init(
        primary: any WeatherProviding = OpenMeteoWeatherProvider(),
        fallback: any WeatherProviding = CityClimateWeatherProvider()
    ) {
        self.primary = primary
        self.fallback = fallback
    }

    /// Default production stack: Open-Meteo → city climate table.
    public static var production: CompositeWeatherProvider {
        CompositeWeatherProvider()
    }

    public func daytimeTemperatureF(forCity city: String?, on date: Date) async throws -> Double {
        try await daySnapshot(forCity: city, on: date).daytimeTempF
    }

    public func daySnapshot(forCity city: String?, on date: Date) async throws -> WeatherDaySnapshot {
        do {
            if let snap = primary as? any WeatherSnapshotProviding {
                return try await snap.daySnapshot(forCity: city, on: date)
            }
            let t = try await primary.daytimeTemperatureF(forCity: city, on: date)
            return WeatherDaySnapshot(daytimeTempF: t, sourceLabel: "Live", precipProbabilityPercent: nil)
        } catch is CancellationError {
            // 取消不是“主源失败”——不能静默落离线表，向上传播。
            throw CancellationError()
        } catch {
            AppLog.notice(
                "weather primary failed (\(AppLog.errRef(error))); using offline climate",
                .weather)
            if let snap = fallback as? any WeatherSnapshotProviding {
                return try await snap.daySnapshot(forCity: city, on: date)
            }
            let t = try await fallback.daytimeTemperatureF(forCity: city, on: date)
            return WeatherDaySnapshot(
                daytimeTempF: t, sourceLabel: "Offline estimate", precipProbabilityPercent: nil)
        }
    }
}
