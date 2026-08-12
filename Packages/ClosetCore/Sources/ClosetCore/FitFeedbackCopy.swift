import Foundation

/// 打卡后的合身反馈（DESIGN §F2 穿着反馈闭环 / §F5 记录环）。
/// v1.0 只**采集**：不喂 FitEngine、不改推荐——文案不得暗示会影响推荐。
/// 会随 Export my data 导出（`WearRecord.fitFeedback` 在导出快照里），须如实披露。
public enum FitFeedbackCopy {
    /// 显式定序（不用 CaseIterable：紧→合→松 是有语义的排列）。
    public static let options: [FitVerdict] = [.tight, .fitted, .loose]

    public static let prompt = "How did it fit?"
    public static let skipTitle = "Skip"
    public static let exportDisclosure =
        "Fit notes stay on device and are included when you export your data."

    public static func choiceTitle(_ verdict: FitVerdict) -> String {
        switch verdict {
        case .tight: return "Felt tight"
        case .fitted: return "Just right"
        case .loose: return "Felt loose"
        }
    }

    public static func recordedMessage(_ verdict: FitVerdict) -> String {
        switch verdict {
        case .tight: return "Noted — felt tight."
        case .fitted: return "Noted — just right."
        case .loose: return "Noted — felt loose."
        }
    }

    /// 落库 raw → 类型（大小写/空白容错；历史脏值如 "fit" 返回 nil）。
    public static func parse(_ raw: String?) -> FitVerdict? {
        guard let key = TextNormalize.blankToNil(raw)?.lowercased() else { return nil }
        return options.first { $0.rawValue.lowercased() == key }
    }

    /// 历史记录里的一句话回显；未知/无值返回 nil（不编造）。
    public static func logCaption(_ raw: String?) -> String? {
        parse(raw).map { choiceTitle($0) }
    }
}
