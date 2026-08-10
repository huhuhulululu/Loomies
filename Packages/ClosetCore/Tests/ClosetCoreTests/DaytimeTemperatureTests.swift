import Testing
@testable import ClosetCore

struct DaytimeTemperatureTests {

    @Test func ignoresNightLows() {
        // 夜间 30°F，日间 ~75°F：代表温度应贴近日间，不被夜低拖冷（正确性#1 的核心）
        let hourly: [(hour: Int, tempF: Double)] = [
            (2, 30), (5, 32),          // 夜间冷，应被忽略
            (9, 70), (12, 78), (15, 80), (17, 72)  // 日间
        ]
        let rep = DaytimeTemperature.representative(hourlyF: hourly)
        #expect(rep != nil)
        #expect(rep! >= 70) // 若把夜间算进去均值会 <60
    }

    @Test func meanOfDaytimeHours() {
        let hourly: [(hour: Int, tempF: Double)] = [(8, 60), (12, 70), (16, 80)]
        #expect(DaytimeTemperature.representative(hourlyF: hourly) == 70) // (60+70+80)/3
    }

    @Test func nilWhenNoDaytimeData() {
        let hourly: [(hour: Int, tempF: Double)] = [(2, 30), (23, 28)]
        #expect(DaytimeTemperature.representative(hourlyF: hourly) == nil)
    }

    @Test func nonFiniteSamplesAreSkipped() {
        // 单个 NaN/±inf 样本不得污染整日均值；全是脏样本 → nil。
        let hourly: [(hour: Int, tempF: Double)] = [(8, 60), (12, .nan), (16, 80), (10, .infinity)]
        #expect(DaytimeTemperature.representative(hourlyF: hourly) == 70) // (60+80)/2
        let allDirty: [(hour: Int, tempF: Double)] = [(9, .nan), (12, -.infinity)]
        #expect(DaytimeTemperature.representative(hourlyF: allDirty) == nil)
    }
}
