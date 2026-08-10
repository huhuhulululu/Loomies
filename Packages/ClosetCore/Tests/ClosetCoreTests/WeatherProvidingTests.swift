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
}
