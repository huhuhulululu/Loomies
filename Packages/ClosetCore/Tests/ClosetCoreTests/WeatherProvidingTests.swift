import Testing
import Foundation
@testable import ClosetCore

struct WeatherProvidingTests {

    @Test func fixedProviderReturnsConfiguredTemp() async throws {
        let p = FixedWeatherProvider(temperatureF: 68)
        let t = try await p.daytimeTemperatureF(forCity: "NYC", on: Date())
        #expect(t == 68)
    }

    @Test func fixedProviderIgnoresCity() async throws {
        let p = FixedWeatherProvider(temperatureF: 40)
        let a = try await p.daytimeTemperatureF(forCity: "Bangkok", on: Date())
        let b = try await p.daytimeTemperatureF(forCity: nil, on: Date())
        #expect(a == 40)
        #expect(b == 40)
    }

    @Test func cityClimateVariesByCity() async throws {
        let p = CityClimateWeatherProvider()
        // 用 4 月减弱季节偏置差异，比的是城市 base
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let april = cal.date(from: DateComponents(year: 2026, month: 4, day: 15))!
        let miami = try await p.daytimeTemperatureF(forCity: "Miami", on: april)
        let seattle = try await p.daytimeTemperatureF(forCity: "Seattle", on: april)
        #expect(miami > seattle)
    }

    @Test func cityClimateSeasonalSummerWarmerThanWinterNorth() {
        let jul = CityClimateWeatherProvider.seasonalOffsetF(month: 7, forCity: "New York")
        let jan = CityClimateWeatherProvider.seasonalOffsetF(month: 1, forCity: "New York")
        #expect(jul > jan)
    }

    @Test func cityClimateBaseNoSubstringSwallow() {
        // G1：2 字母键 "la" 不能再因子串匹配吞掉 Orlando/Glasgow；
        // 顺序固定为精确 → 启发式 → 默认，跨进程确定。
        #expect(CityClimateWeatherProvider.baseTempF(forCity: "la") == 72)
        #expect(CityClimateWeatherProvider.baseTempF(forCity: "Los Angeles") == 72)
        #expect(CityClimateWeatherProvider.baseTempF(forCity: "Portland") == 58) // 启发式可达
        let orlando = CityClimateWeatherProvider.baseTempF(forCity: "Orlando")
        let glasgow = CityClimateWeatherProvider.baseTempF(forCity: "Glasgow")
        #expect(orlando == 68) // 默认值，不再被 "la" 抢成 72
        #expect(glasgow == 68)
        #expect(orlando != CityClimateWeatherProvider.baseTempF(forCity: "la"))
        #expect(CityClimateWeatherProvider.baseTempF(forCity: "Orlando") == orlando) // 确定
    }

    @Test func personalColorSeasonParse() {
        #expect(PersonalColorSeason.parse("autumn") == .autumn)
        #expect(PersonalColorSeason.parse(nil) == .unknown)
        #expect(PersonalColorSeason.spring.displayName == "Spring")
    }

    @Test func personalColorSeasonAffinityPrefersInSeasonHues() {
        let warm = [GarmentColor(hueDegrees: 0, isNeutral: false)]
        let cool = [GarmentColor(hueDegrees: 220, isNeutral: false)]
        #expect(PersonalColorSeason.autumn.colorAffinity(colors: warm) > 0)
        #expect(PersonalColorSeason.winter.colorAffinity(colors: warm) < 0)
        #expect(PersonalColorSeason.winter.colorAffinity(colors: cool) > 0)
        #expect(PersonalColorSeason.unknown.colorAffinity(colors: warm) == 0)
        #expect(PersonalColorSeason.autumn.colorAffinity(colors: [
            GarmentColor(hueDegrees: 0, isNeutral: true)
        ]) == 0)
    }
}

/// D110（输入质量排查 HIGH）：D107 让离线兜底**变差了**。
/// 选择器存的是标准名「Austin, Texas, United States」，而这张气候表按**裸城市名**查，
/// 于是所有用了新选择器的用户在离线时统统落到 68°F 默认值——
/// 而 D107 之前手打「Austin」的用户反而拿到正确的 76°F。
/// 更糟的是界面把它标成「Offline estimate」，看起来像是对这座城市的考量过的猜测。
struct CanonicalCityFallbackTests {

    /// 标准名与裸名必须给出**同一个**估值。
    @Test func canonicalNameResolvesLikeTheBareCity() {
        let cases: [(canonical: String, bare: String)] = [
            ("Austin, Texas, United States", "Austin"),
            ("Tokyo, Tokyo, Japan", "Tokyo"),
            ("Singapore, Singapore", "Singapore"),
            ("Miami, Florida, United States", "Miami"),
            ("Hong Kong, Hong Kong", "Hong Kong"),
        ]
        for (canonical, bare) in cases {
            #expect(CityClimateWeatherProvider.baseTempF(forCity: canonical)
                    == CityClimateWeatherProvider.baseTempF(forCity: bare),
                    Comment(rawValue: "标准名 \(canonical) 落到了默认值"))
        }
    }

    /// 与 D107 的真实产物对齐（不是我手抄的字符串——走同一条生成路径）。
    @Test func matchesWhatThePickerActuallyStores() throws {
        let payload = Data("""
        {"results":[{"name":"Austin","latitude":30.27,"longitude":-97.74,
         "country_code":"US","country":"United States","admin1":"Texas",
         "timezone":"America/Chicago"}]}
        """.utf8)
        let match = try #require(try OpenMeteoJSON.parseGeocodeMatches(payload).first)
        let stored = CitySearch.storedValue(for: match)
        #expect(CityClimateWeatherProvider.baseTempF(forCity: stored)
                == CityClimateWeatherProvider.baseTempF(forCity: "Austin"))
    }

    /// 表里没有的城市仍走启发式/默认——修的是「查不到自己的名字」，不是放宽匹配。
    @Test func unknownCitiesStillFallThrough() {
        #expect(CityClimateWeatherProvider.baseTempF(forCity: "Nowhere, Atlantis") == 68)
        // 关键字启发式不受影响
        #expect(CityClimateWeatherProvider.baseTempF(forCity: "Miami Beach, Florida") == 82)
    }

    /// 不得因为拆逗号而误命中：「Portland, Oregon」取第一段仍是 Portland。
    @Test func firstComponentIsTheCityNotTheRegion() {
        #expect(CityClimateWeatherProvider.baseTempF(forCity: "Portland, Oregon, United States")
                == CityClimateWeatherProvider.baseTempF(forCity: "Portland"))
        // 「Texas, United States」这种没有城市段的输入不该命中 austin
        #expect(CityClimateWeatherProvider.baseTempF(forCity: "Texas, United States") == 68)
    }
}
