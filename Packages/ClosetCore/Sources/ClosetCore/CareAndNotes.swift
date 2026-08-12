import Foundation

/// 护理符号（D93，缺口 #13；DESIGN §90「结构化：只干洗/手洗/不可烘干等，
/// 可由洗标 OCR 填充」）。存 rawValue 数组（CloudKit 安全，与 occasions/attributes 同法）。
///
/// 它影响的是「洗完多久能再穿、该怎么送洗」，**不进推荐打分**——
/// 文案不得暗示它会改变今天推什么。
public enum CareSymbol: String, CaseIterable, Sendable, Comparable {
    case machineWash
    case handWash
    case dryCleanOnly
    case noTumbleDry
    case lowIron
    case noBleach
    case lineDry

    public static func < (a: CareSymbol, b: CareSymbol) -> Bool { a.rawValue < b.rawValue }

    public var displayTitle: String {
        switch self {
        case .machineWash:  return "Machine wash"
        case .handWash:     return "Hand wash"
        case .dryCleanOnly: return "Dry clean only"
        case .noTumbleDry:  return "No tumble dry"
        case .lowIron:      return "Iron low"
        case .noBleach:     return "No bleach"
        case .lineDry:      return "Line dry"
        }
    }

    public static let entryHint =
        "From the care label. Kept for reference — it does not change what gets suggested."

    /// 落库 raw → 类型；脏值丢弃（历史数据 / OCR 会写进不认识的东西）。
    /// 顺序确定，不依赖输入顺序。
    public static func parse(_ raws: [String]) -> [CareSymbol] {
        persistOrder(Set(raws.compactMap { CareSymbol(rawValue: $0) }))
    }

    /// 落库顺序（禁止依赖 Set 的偶然序 —— 导出与 diff 都要可复现）。
    public static func persistOrder(_ symbols: some Sequence<CareSymbol>) -> [CareSymbol] {
        Array(Set(symbols)).sorted()
    }

    /// 互斥组合的**指出**（不阻止——洗标本身可能就印得矛盾，用户说了算）。
    public static func conflictWarning(_ symbols: some Sequence<CareSymbol>) -> String? {
        let set = Set(symbols)
        guard set.contains(.dryCleanOnly),
              set.contains(.machineWash) || set.contains(.handWash)
        else { return nil }
        return "Dry clean only conflicts with washing at home — keep the one on the label."
    }
}

/// 单品自由备注（DESIGN §95「特殊需求（『需配腰带』『易皱』）」）。
///
/// **DESIGN §321 把单品备注明列为不可信输入**（与自定义标签、OCR 文本同级）：
/// 接 LLM 时必须以结构化字段注入、单字段长度设限、系统提示声明用户字段仅为数据。
/// v1.0 还没有 LLM，但长度上限与控制字符归一现在就立住——
/// 等接了再补，就是又一次「先上线后补门」。
public enum ItemNotes {
    /// 单字段长度上限。够写「需配腰带、易皱、袖口有点松」这类真实备注，
    /// 又不至于让一段长文本被整包塞进任何下游。
    public static let maxLength = 200

    public static let entryHint =
        "Anything you want to remember about this piece — you'll see it here on the detail page."

    /// 归一：trim、控制字符压成空格、超长截断、空白转 nil。
    public static func sanitize(_ raw: String?) -> String? {
        guard let raw else { return nil }
        // 换行/制表压成空格：既避免版式炸开，也避免把结构藏进单行字段
        let flattened = raw.map { ch -> Character in
            ch.isNewline || ch == "\t" ? " " : ch
        }
        var collapsed = ""
        var lastWasSpace = false
        for ch in flattened {
            let isSpace = ch == " "
            if isSpace && lastWasSpace { continue }
            collapsed.append(ch)
            lastWasSpace = isSpace
        }
        let trimmed = collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxLength))
    }

    /// 还能再写多少字（0 = 到顶）。
    public static func remaining(_ current: String) -> Int {
        max(0, maxLength - current.count)
    }
}
