import Foundation

/// 场合枚举（DESIGN §F4：映射到 formal~casual 正式度档）。
public enum Occasion: String, Sendable, CaseIterable {
    case businessFormal, businessCasual, commute, date, gala, casual, workFromHome
}

/// 正式度序级（1 最休闲 → 5 最正式）。
public enum FormalityLevel: Int, Sendable, CaseIterable, Comparable {
    case veryCasual = 1, casual, smart, business, formal
    public static func < (l: FormalityLevel, r: FormalityLevel) -> Bool { l.rawValue < r.rawValue }
}

/// 场合正式度规则（纯函数，DESIGN §F4）。
public enum DressCode {

    /// 场合 → 可接受正式度带。
    public static func expectedFormality(_ occasion: Occasion) -> ClosedRange<FormalityLevel> {
        switch occasion {
        case .gala:           return .formal ... .formal
        case .businessFormal: return .business ... .formal
        case .businessCasual: return .smart ... .business
        case .commute:        return .smart ... .business
        case .date:           return .smart ... .formal
        case .casual:         return .veryCasual ... .casual
        case .workFromHome:   return .veryCasual ... .casual
        }
    }

    /// 单品正式度是否契合场合。
    public static func fits(itemFormality: FormalityLevel, occasion: Occasion) -> Bool {
        expectedFormality(occasion).contains(itemFormality)
    }

    /// 整套正式度：由最休闲的单品决定（正式西装配运动鞋整体读作休闲）。空返回 nil。
    public static func outfitFormality(_ levels: [FormalityLevel]) -> FormalityLevel? {
        levels.min()
    }

    /// 整套是否契合场合（按整套正式度判定）。
    public static func outfitFits(_ levels: [FormalityLevel], occasion: Occasion) -> Bool {
        guard let overall = outfitFormality(levels) else { return false }
        return expectedFormality(occasion).contains(overall)
    }
}
