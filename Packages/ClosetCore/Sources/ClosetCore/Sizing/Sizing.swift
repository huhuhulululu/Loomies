import Foundation

/// 尺码体系。US 优先展示（en-US 主市场）。
public enum SizeSystem: String, Sendable, CaseIterable {
    case us, eu, uk, jp, cnGBT, intl
}

/// 标称尺码：体系 + 原始标签字符串，**忠实保真、绝不自动跨品牌换算**。
/// 依据 research/07：尺码跨品牌不可比（vanity sizing 实锤），尺码只作品牌语境内展示元数据，
/// 合身判断必须走 measurements。
public struct NominalSize: Sendable, Equatable {
    public let system: SizeSystem
    public let rawLabel: String   // "M" / "8" / "160/84A" — 原样保存
    public init(system: SizeSystem, rawLabel: String) {
        self.system = system
        self.rawLabel = rawLabel
    }
}

/// 品类（决定平铺测量字段集）。
public enum SizingCategory: String, Sendable, CaseIterable {
    case top, bottom, dress, skirt, outerwear
}

/// 平铺测量字段（英寸）。取自二手平台事实标准字段集（research/07）。
public enum MeasurementField: String, Sendable, CaseIterable {
    case chestFlat, garmentLength, shoulder, sleeve      // 上装/外套
    case waistFlat, hipFlat, inseam, riseFront           // 下装
    case skirtLength                                     // 裙
}

/// 品类 → 该录入哪些平铺字段。
public enum MeasurementSchema {
    public static func fields(for category: SizingCategory) -> [MeasurementField] {
        switch category {
        case .top, .outerwear: return [.chestFlat, .garmentLength, .shoulder, .sleeve]
        case .bottom:          return [.waistFlat, .hipFlat, .inseam, .riseFront]
        case .dress:           return [.chestFlat, .waistFlat, .hipFlat, .garmentLength]
        case .skirt:           return [.waistFlat, .hipFlat, .skirtLength]
        }
    }
}

/// 单品平铺实测集（稀疏，可留空渐进补全，每字段带值即视为已测）。
public struct FlatMeasurements: Sendable {
    public var values: [MeasurementField: Double]   // 英寸
    public init(values: [MeasurementField: Double] = [:]) { self.values = values }

    /// 由平铺宽推周长（周长 = 2 × 平铺宽）。字段未填返回 nil。
    public func circumference(_ field: MeasurementField) -> Double? {
        guard let flat = values[field] else { return nil }
        return 2 * flat
    }

    /// 相对某品类必填字段集的完成度（0...1），供渐进补全 UX 与合身置信度。
    public func completeness(for category: SizingCategory) -> Double {
        let required = MeasurementSchema.fields(for: category)
        guard !required.isEmpty else { return 1 }
        let filled = required.filter { values[$0] != nil }.count
        return Double(filled) / Double(required.count)
    }
}
