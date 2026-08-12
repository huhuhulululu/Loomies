import Foundation

/// 候选硬过滤上下文（当前衣柜 + 场合 + 日间温度 + 近 7 天已穿）。
public struct FilterContext: Sendable {
    public let occasion: String
    public let daytimeTempF: Double
    public let wornWithin7DaysIDs: Set<String>
    /// 个人冷热偏置（D90）：平移可接受温区，不放宽它。
    public let coldBias: Int

    public init(occasion: String, daytimeTempF: Double,
                wornWithin7DaysIDs: Set<String> = [], coldBias: Int = 0) {
        self.occasion = occasion
        self.daytimeTempF = daytimeTempF
        self.wornWithin7DaysIDs = wornWithin7DaysIDs
        self.coldBias = ColdBias.clamp(coldBias)
    }
}

/// 候选硬过滤（DESIGN §F4 四条正确性 gate；三值属性未知不硬过滤）。
public enum CandidateFilter {

    /// 过滤结果 + 防重复是否被降级（D89）。
    public struct Outcome: Sendable, Equatable {
        public let items: [CandidateItem]
        /// 硬门会清空候选 → 已降级为「降权」。UI 必须如实说明，
        /// 否则用户看到的建议与「de-prioritized 7 days」的打卡回执自相矛盾。
        public let repeatGateRelaxed: Bool
        /// 降级时传给排序层的「最近穿过」集合（排后而不是排除）。
        public let recentlyWornIDs: Set<String>
    }

    /// 放宽后的诚实文案（说清为什么这几件又出现了）。
    public static let repeatRelaxedCaption =
        "Everything that fits today was worn recently — showing your best options anyway."

    /// 防重复的**定夺语义**（D89）。DESIGN 自相矛盾：§193/§379 写「近期重复降权」，
    /// §200 把它列为硬门。取「默认硬门 + 会清空时降级为降权」——
    /// 硬门来自竞品差评实证（有真实价值），但小衣柜里三件上装本周都穿过时
    /// 交出空结果是更糟的产品行为（DESIGN §199 对同类问题已给同一处方：
    /// 覆盖率低于门槛就自动切模式）。
    ///
    /// 降级**只放宽防重复**——场合、天气、可用状态仍是硬门（那三条无分歧）。
    public static func filterWithRepeatFallback(
        _ items: [CandidateItem], context: FilterContext
    ) -> Outcome {
        let strict = filter(items, context: context)
        guard strict.isEmpty, !context.wornWithin7DaysIDs.isEmpty else {
            return Outcome(items: strict, repeatGateRelaxed: false, recentlyWornIDs: [])
        }
        // 只摘掉防重复这一条，其余门原样
        let relaxedContext = FilterContext(
            occasion: context.occasion,
            daytimeTempF: context.daytimeTempF,
            wornWithin7DaysIDs: [],
            coldBias: context.coldBias)
        let relaxed = filter(items, context: relaxedContext)
        guard !relaxed.isEmpty else {
            // 放宽了也没有 → 空结果的原因不是防重复，别对用户说反话
            return Outcome(items: [], repeatGateRelaxed: false, recentlyWornIDs: [])
        }
        return Outcome(
            items: relaxed,
            repeatGateRelaxed: true,
            recentlyWornIDs: Set(relaxed.map(\.id)).intersection(context.wornWithin7DaysIDs))
    }

    /// 降权 = **排序**影响，不是二次排除：最近穿过的排在没穿过的后面。
    /// 同类内部按 id 决胜（排序确定性，禁止依赖数组偶然顺序）。
    public static func rankByRecency(
        _ items: [CandidateItem], recentlyWornIDs: Set<String>
    ) -> [CandidateItem] {
        items.sorted { a, b in
            let aWorn = recentlyWornIDs.contains(a.id)
            let bWorn = recentlyWornIDs.contains(b.id)
            return aWorn != bWorn ? (!aWorn && bWorn) : a.id < b.id
        }
    }

    public static func filter(_ items: [CandidateItem], context: FilterContext) -> [CandidateItem] {
        let band = WeatherFit.acceptableWarmth(
            daytimeTempF: context.daytimeTempF, coldBias: context.coldBias)
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
