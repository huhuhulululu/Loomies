import Foundation

/// 打卡后的合身反馈（DESIGN §F2 穿着反馈闭环 / §F5 记录环）。
///
/// D196：**同一个结论报够两次（且过半）之后，它会成为这件衣服的合身标记**——
/// 用户穿过的结果压过尺寸算出来的预测（`FitFeedbackHistory`）。
/// v1.0 曾刻意「只采集不回流」，那在没有记录的阶段是对的；
/// 有了记录还不用，就成了**问了不用**，比不问更糟。
///
/// 口径要**精确**：它现在影响**合身标记**，还**不影响推荐排序**——
/// 文案不得越过这条线（说大了就是本仓反复在修的那种不诚实）。
/// 会随 Export my data 导出（`WearRecord.fitFeedback` 在导出快照里），须如实披露。
public enum FitFeedbackCopy {
    /// 显式定序（不用 CaseIterable：紧→合→松 是有语义的排列）。
    public static let options: [FitVerdict] = [.tight, .fitted, .loose]

    public static let prompt = "How did it fit?"
    public static let skipTitle = "Skip"
    public static let exportDisclosure =
        "Fit notes stay on device and are included when you export your data."

    /// D196：说清这一问**会被拿去做什么**——问了不用固然糟，
    /// 用了不说同样糟（用户会发现合身标记变了却不知道为什么）。
    /// 只说做得到的：影响合身标记，不影响推荐排序。
    public static let usageDisclosure =
        "Say it twice and it becomes this piece's fit mark, ahead of the measurements. "
        + "It doesn't change which looks get suggested."

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
