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
}
