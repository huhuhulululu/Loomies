import Testing
import Foundation
@testable import ClosetCore

struct PublicAPITests {

    @Test func openMeteoGeocodeParsesFixture() throws {
        let json = """
        {"results":[{"id":1,"name":"New York","latitude":40.7128,"longitude":-74.006,"country_code":"US"}]}
        """.data(using: .utf8)!
        let place = try OpenMeteoJSON.parseGeocode(json)
        #expect(place.name == "New York")
        #expect(abs(place.latitude - 40.7128) < 0.001)
        #expect(place.countryCode == "US")
    }

    @Test func openMeteoDailyMaxParsesFixture() throws {
        let json = """
        {"daily":{"time":["2026-08-06"],"temperature_2m_max":[78.4],"precipitation_probability_max":[62]}}
        """.data(using: .utf8)!
        let t = try OpenMeteoJSON.parseDailyMaxF(json)
        #expect(t == 78)
        let day = try OpenMeteoJSON.parseForecastDay(json)
        #expect(day.precipProbabilityPercent == 62)
    }

    @Test func weatherSnapshotSuggestsOuterwearWhenWetOrCool() {
        #expect(WeatherDaySnapshot(daytimeTempF: 72, sourceLabel: "x", precipProbabilityPercent: 55)
            .suggestsOuterwearCue)
        #expect(WeatherDaySnapshot(daytimeTempF: 55, sourceLabel: "x", precipProbabilityPercent: 10)
            .suggestsOuterwearCue)
        #expect(!WeatherDaySnapshot(daytimeTempF: 75, sourceLabel: "x", precipProbabilityPercent: 20)
            .suggestsOuterwearCue)
    }

    @Test func openMeteoProviderUsesTransportFixtures() async throws {
        let geo = """
        {"results":[{"name":"Miami","latitude":25.76,"longitude":-80.19,"country_code":"US"}]}
        """.data(using: .utf8)!
        let fc = """
        {"daily":{"time":["2026-08-06"],"temperature_2m_max":[89.0]}}
        """.data(using: .utf8)!
        let transport = FixtureTransport(fixtures: [
            "geocoding-api.open-meteo.com": geo,
            "api.open-meteo.com": fc,
        ])
        let p = OpenMeteoWeatherProvider(transport: transport)
        let t = try await p.daytimeTemperatureF(forCity: "Miami", on: Date())
        #expect(t == 89)
    }

    /// Nested Open-Meteo hosts: short key `api.open-meteo.com` is a substring of
    /// `geocoding-api.open-meteo.com`. Longest-match must win so geocode never
    /// gets the forecast body (decodeFailed flake under Dictionary iteration order).
    @Test func fixtureTransportPrefersLongestHostMatch() async throws {
        let geo = #"{"results":[{"name":"X","latitude":1.0,"longitude":2.0}]}"#.data(using: .utf8)!
        let fc = #"{"daily":{"temperature_2m_max":[70.0]}}"#.data(using: .utf8)!
        let transport = FixtureTransport(fixtures: [
            "api.open-meteo.com": fc,
            "geocoding-api.open-meteo.com": geo,
        ])
        let geoURL = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=X")!
        let fcURL = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=1")!
        let geoData = try await transport.get(url: geoURL)
        let fcData = try await transport.get(url: fcURL)
        #expect(geoData == geo)
        #expect(fcData == fc)
        // Geocode path must parse (would throw decodeFailed if forecast body matched).
        let place = try OpenMeteoJSON.parseGeocode(geoData)
        #expect(place.latitude == 1.0)
        let t = try OpenMeteoJSON.parseDailyMaxF(fcData)
        #expect(t == 70)
    }

    @Test func compositeFallsBackWhenPrimaryFails() async throws {
        let bad = FixtureTransport(fixtures: [:])
        let primary = OpenMeteoWeatherProvider(transport: bad)
        let composite = CompositeWeatherProvider(
            primary: primary,
            fallback: FixedWeatherProvider(temperatureF: 61))
        let t = try await composite.daytimeTemperatureF(forCity: "Nowhere", on: Date())
        #expect(t == 61)
    }

    /// G2: captures request URLs so we can assert the day label without network.
    private final class CapturingTransport: PublicAPITransport, @unchecked Sendable {
        var urls: [URL] = []
        let geocodeTimezone: String?
        init(geocodeTimezone: String? = nil) { self.geocodeTimezone = geocodeTimezone }
        func get(url: URL) async throws -> Data {
            urls.append(url)
            if url.host()?.contains("geocoding") == true {
                let tz = geocodeTimezone.map { #","timezone":"\#($0)""# } ?? ""
                return #"{"results":[{"name":"X","latitude":40.0,"longitude":-74.0\#(tz)}]}"#
                    .data(using: .utf8)!
            }
            return #"{"daily":{"temperature_2m_max":[70.0]}}"#.data(using: .utf8)!
        }
    }

    /// 「今天」按衣柜城市时区取日，不随设备时区变：设备在上海查纽约衣柜，
    /// 不得因设备已过午夜请求到纽约「明天」的最高温。
    @Test func forecastDateUsesCityTimezoneCalendar() async throws {
        let transport = CapturingTransport(geocodeTimezone: "Asia/Tokyo")
        let p = OpenMeteoWeatherProvider(transport: transport)
        // 2026-03-10 16:00 GMT：东京已是 3/11 01:00，GMT/美洲仍是 3/10。
        var gmt = Calendar(identifier: .gregorian)
        gmt.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = gmt.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 16))!
        _ = try await p.daytimeTemperatureF(forCity: "X", on: date)
        let forecastURL = transport.urls.first { $0.host() == "api.open-meteo.com" }
        let qs = try #require(forecastURL?.query)
        #expect(qs.contains("start_date=2026-03-11"))
        #expect(qs.contains("end_date=2026-03-11"))
        // 日界口径两端一致：请求显式带城市时区，而非 auto
        #expect(qs.contains("timezone=Asia%2FTokyo") || qs.contains("timezone=Asia/Tokyo"))
    }

    /// Geocode 未返回 timezone（历史 fixture / 罕见响应）→ 退回设备本地历 + auto。
    @Test func forecastDateFallsBackToDeviceCalendarWithoutCityTimezone() async throws {
        let transport = CapturingTransport(geocodeTimezone: nil)
        let p = OpenMeteoWeatherProvider(transport: transport)
        var gmt = Calendar(identifier: .gregorian)
        gmt.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = gmt.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 2))!
        _ = try await p.daytimeTemperatureF(forCity: "X", on: date)
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let expected = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        let forecastURL = transport.urls.first { $0.host() == "api.open-meteo.com" }
        let qs = try #require(forecastURL?.query)
        #expect(qs.contains("start_date=\(expected)"))
        #expect(qs.contains("end_date=\(expected)"))
        #expect(qs.contains("timezone=auto"))
    }

    /// parseGeocode 提取 IANA timezone 字段（Open-Meteo geocoding 文档化字段）。
    @Test func parseGeocodeExtractsTimezone() throws {
        let with = #"{"results":[{"name":"Tokyo","latitude":35.7,"longitude":139.7,"timezone":"Asia/Tokyo"}]}"#
        let place = try OpenMeteoJSON.parseGeocode(with.data(using: .utf8)!)
        #expect(place.timezone == "Asia/Tokyo")
        let without = #"{"results":[{"name":"X","latitude":1.0,"longitude":2.0}]}"#
        #expect(try OpenMeteoJSON.parseGeocode(without.data(using: .utf8)!).timezone == nil)
    }

    /// G3: cancellation must propagate, not silently fall back offline.
    private struct CancellingPrimary: WeatherProviding {
        func daytimeTemperatureF(forCity city: String?, on date: Date) async throws -> Double {
            throw CancellationError()
        }
    }

    @Test func compositeRethrowsCancellationError() async {
        let composite = CompositeWeatherProvider(
            primary: CancellingPrimary(),
            fallback: FixedWeatherProvider(temperatureF: 61))
        await #expect(throws: CancellationError.self) {
            _ = try await composite.daytimeTemperatureF(forCity: "X", on: Date())
        }
    }

    @Test func openProductFactsParsesHit() throws {
        let json = """
        {"status":1,"product":{"product_name":"Classic Tee","brands":"Acme","quantity":"M","categories":"Clothing"}}
        """.data(using: .utf8)!
        let hit = try OpenProductFactsJSON.parse(json, barcode: "0123456789012", source: "world.openproductsfacts.org")
        #expect(hit?.name == "Classic Tee")
        #expect(hit?.brand == "Acme")
        #expect(hit?.suggestedItemName == "Acme Classic Tee")
    }

    @Test func openProductFactsStatusZeroIsNil() throws {
        let json = #"{"status":0,"status_verbose":"product not found"}"#.data(using: .utf8)!
        let hit = try OpenProductFactsJSON.parse(json, barcode: "000", source: "x")
        #expect(hit == nil)
    }

    @Test func productLookupClientUsesFirstHostHit() async throws {
        let body = """
        {"status":1,"product":{"product_name":"Linen Shirt","brands":"DemoCo"}}
        """.data(using: .utf8)!
        let transport = FixtureTransport(fixtures: [
            "openproductsfacts.org": body,
        ])
        let client = OpenProductFactsClient(transport: transport)
        let hit = try await client.lookup(barcode: "123 456")
        #expect(hit?.name == "Linen Shirt")
        #expect(OpenProductFactsClient.normalizeBarcode("123 456") == "123456")
    }

    /// C1: 首 host 瞬态故障（5xx）不应中断目录回退链——继续尝试下一 host。
    private struct FirstHostBombsTransport: PublicAPITransport {
        let body: Data
        func get(url: URL) async throws -> Data {
            if url.host() == "world.openproductsfacts.org" {
                throw PublicAPIError.httpStatus(500)
            }
            return body
        }
    }

    @Test func productLookupFallsBackOnTransientHostError() async throws {
        let body = """
        {"status":1,"product":{"product_name":"Silk Scarf","brands":"DemoCo"}}
        """.data(using: .utf8)!
        let client = OpenProductFactsClient(transport: FirstHostBombsTransport(body: body))
        let hit = try await client.lookup(barcode: "123456")
        #expect(hit?.name == "Silk Scarf")
        #expect(hit?.source == "world.openbeautyfacts.org")
    }

    @Test func publicSizeReferenceAlphaHint() {
        let hint = PublicSizeReference.displayHint(forLabel: "M")
        #expect(hint?.contains("US") == true)
        #expect(hint?.contains("not brand-true") == true)
    }

    @Test func publicSizeReferenceMensChest() {
        #expect(PublicSizeReference.mensChestInchesToAlpha(40) == "M")
        #expect(PublicSizeReference.womensNumericBridge(us: 8)?.eu == 38)
    }

    @Test func looksLikeApparelSizeRejectsPackAndWeight() {
        #expect(PublicSizeReference.looksLikeApparelSize("M"))
        #expect(PublicSizeReference.looksLikeApparelSize("xl"))
        #expect(PublicSizeReference.looksLikeApparelSize("8"))
        #expect(PublicSizeReference.looksLikeApparelSize("US 10"))
        #expect(PublicSizeReference.looksLikeApparelSize("EU 38"))
        #expect(PublicSizeReference.looksLikeApparelSize("W32"))
        #expect(!PublicSizeReference.looksLikeApparelSize("3 pack"))
        #expect(!PublicSizeReference.looksLikeApparelSize("500g"))
        #expect(!PublicSizeReference.looksLikeApparelSize("12 fl oz"))
        #expect(!PublicSizeReference.looksLikeApparelSize(""))
    }
}
