import Foundation

/// 日间时段代表温度（DESIGN §F4 正确性#1：只按日间时段计算，避开竞品「拿夜间低温推毛衣」的差评）。
public enum DaytimeTemperature {

    /// 取 [daytimeStart, daytimeEnd) 小时窗内温度的均值；窗内无数据返回 nil。
    public static func representative(
        hourlyF: [(hour: Int, tempF: Double)],
        daytimeStart: Int = 7,
        daytimeEnd: Int = 19
    ) -> Double? {
        // 单个非有限样本（NaN/±inf）不应污染整日均值 → 先过滤；过滤后无数据返回 nil。
        let daytime = hourlyF.filter {
            $0.hour >= daytimeStart && $0.hour < daytimeEnd && $0.tempF.isFinite
        }
        guard !daytime.isEmpty else { return nil }
        return daytime.reduce(0.0) { $0 + $1.tempF } / Double(daytime.count)
    }
}
