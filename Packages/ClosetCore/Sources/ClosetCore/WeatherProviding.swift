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
