import Foundation

/// Onboarding 的「场合构成」这一题（D97，补齐缺口 #14）。
///
/// DESIGN §474 点名了个性化三题——**场合构成** / 所在城市 / 可跳过的身体维度。
/// 城市与身体维度一直都在，唯独场合构成没问，而 Today 的默认场合是硬编码的
/// `"work"`：系统替用户假设了他主要为通勤穿衣。衣柜里全是休闲装的人，
/// 打开 App 看到的是按通勤过滤后的空结果。
///
/// **诚实边界**：这一题只决定两件事——Today 的默认场合、冷启动里哪条里程碑打头。
/// 它不改天气门、不改配色打分、不改体型加权，文案不得暗示更多。
public enum OccasionMix {

    /// 与 `CandidateFilter` 实际过滤的场合集**同源**——
    /// 不得另开一套用户选得到、引擎不认的值。
    public static let choices = ["work", "casual", "date", "gala"]

    /// 未答时 Today 仍需要一个场合。这是**系统的中性默认**，不是用户的选择；
    /// 两者必须可区分，否则 UI 会把假设显示成「你选的」。
    public static let neutralDefault = "work"

    public static func displayTitle(_ raw: String) -> String {
        switch raw {
        case "work":   return "Work"
        case "casual": return "Casual"
        case "date":   return "Date"
        case "gala":   return "Events"
        default:       return raw.capitalized
        }
    }

    /// 落库 raw → 合法选项；未答 / 脏值 = nil（**不猜**）。
    public static func parse(_ raw: String?) -> String? {
        guard let key = TextNormalize.blankToNil(raw)?.lowercased() else { return nil }
        return choices.contains(key) ? key : nil
    }

    public static func hasStatedAnswer(_ raw: String?) -> Bool { parse(raw) != nil }

    /// 实际用于过滤的场合：答了用答案，没答用中性默认。
    public static func effectiveOccasion(stated raw: String?) -> String {
        parse(raw) ?? neutralDefault
    }

    // MARK: - 客户文案

    public static let question = "What do you dress for most?"
    /// 只说它真做的两件事。
    public static let hint =
        "Sets the starting filter on Today and which milestone you see first. You can change it any time."
    public static let skipTitle = "Not sure yet"
}
