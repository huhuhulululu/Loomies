import Foundation

/// 候选硬过滤上下文（当前衣柜 + 场合 + 日间温度 + 近 7 天已穿）。
public struct FilterContext: Sendable {
    public let occasion: String
    public let daytimeTempF: Double
    public let wornWithin7DaysIDs: Set<String>

    public init(occasion: String, daytimeTempF: Double, wornWithin7DaysIDs: Set<String> = []) {
        self.occasion = occasion
        self.daytimeTempF = daytimeTempF
        self.wornWithin7DaysIDs = wornWithin7DaysIDs
    }
}

/// 候选硬过滤（DESIGN §F4 四条正确性 gate；三值属性未知不硬过滤）。
public enum CandidateFilter {

    public static func filter(_ items: [CandidateItem], context: FilterContext) -> [CandidateItem] {
        let band = WeatherFit.acceptableWarmth(daytimeTempF: context.daytimeTempF)
        // 场合在过滤边界归一化（trim + 小写）：写入端大小写不一致（intake 小写、编辑器仅 trim）。
        let wanted = context.occasion.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return items.filter { item in
            // gate: 状态可用
            guard item.status == .available else { return false }
            // gate #3: ≥7 天防重复
            guard !context.wornWithin7DaysIDs.contains(item.id) else { return false }
            // gate #2: 场合硬过滤（三值：未知不过滤；wanted 空 = 用户未指定场合，同样不硬过滤）
            if !wanted.isEmpty, !item.occasions.isEmpty {
                let normalized = item.occasions.map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                }
                if !normalized.contains(wanted) { return false }
            }
            // gate #1: 天气/温区（三值：未知不过滤）
            if let w = item.warmth, !band.contains(w) { return false }
            return true
        }
    }
}
