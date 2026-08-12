import Foundation

/// 一个带评分的候选搭配（copilot 补全的输出单元）。
public struct ScoredOutfit: Sendable {
    public let outfit: Outfit
    public let score: OutfitScore
    public init(outfit: Outfit, score: OutfitScore) {
        self.outfit = outfit
        self.score = score
    }
}

/// copilot 补全器（v0.9 核心机制）：用户锚定几件单品 → 从衣柜补全成合规搭配、给打分候选供用户选。
/// 这是方法④证实被爱的「我选几件→AI 补全」流程（DEMAND-VALIDATION §8）。
/// 复用 CandidateFilter（四条正确性）+ OutfitGrammar（语法）+ OutfitScorer（配色/体型/可解释）。
public enum OutfitCompleter {

    /// 每槽位进入组合枚举的最大候选数（取 id 升序前 N）。
    /// 防止全枚举在中等衣柜规模下爆炸。组合骨架已按 grammar 硬规则拆枝：
    /// N=12 冷天最坏 = 裙枝 12×12×13 + 上下装枝 12×12×12×13 ≈ 2.4 万次迭代
    /// （拆枝前 [nil] 并列全乘是 13⁴×12 ≈ 34 万，93% 必废）；prefix 截断保证确定性。
    public static let maxOptionsPerSlot = 12

    /// 建议 + 防重复是否被降级（D89）。UI 靠后者出诚实说明。
    public struct Result: Sendable {
        public let suggestions: [ScoredOutfit]
        public let repeatGateRelaxed: Bool
    }

    public static func complete(
        anchors: [CandidateItem],
        pool: [CandidateItem],
        context: FilterContext,
        scoring: ScoringContext,
        maxSuggestions: Int
    ) -> [ScoredOutfit] {
        completeDetailed(anchors: anchors, pool: pool, context: context,
                         scoring: scoring, maxSuggestions: maxSuggestions).suggestions
    }

    public static func completeDetailed(
        anchors: [CandidateItem],
        pool: [CandidateItem],
        context: FilterContext,
        scoring: ScoringContext,
        maxSuggestions: Int
    ) -> Result {
        let anchorIDs = Set(anchors.map(\.id))
        // 候选池：过四条正确性 + 去掉已锚定项（防重复用）。
        //
        // D112：D89 的降级判在**单品层**（一件都不剩才放宽），而空屏发生在**搭配层**。
        // 只要任一槽位被穿光——小衣柜里通常是那双唯一的鞋——其余槽位的件仍在，
        // 单品集非空 → 不降级 → grammar 拼不出整身 → 0 建议。
        // 触发点正是 App 的主动作：穿着窗口含今天，第一次点「Wore it」当场空屏，
        // 且要等整个衣柜都穿过一遍（单品集终于空了）才自愈，与 D89 本意相反。
        // 所以判定移到这里：**先按严格通道拼，拼不出整身且确有近期穿着记录才放宽**。
        let strictItems = CandidateFilter.filter(pool, context: context)
        var outcome = CandidateFilter.Outcome(
            items: strictItems, repeatGateRelaxed: false, recentlyWornIDs: [])
        var filtered = outcome.items.filter { !anchorIDs.contains($0.id) }
        // 截断前廉价预打分（体型 affinity）：纯 id 前缀截断等于打分前随机抽样
        //（Item.id 是随机 UUID），大衣柜最合体型的单品可能从未进入枚举。
        // (预分降序, id 升序) 保确定性；无体型上下文时退化为原 id 序。
        let preShape = scoring.bodyShape?.popularCategory
        func options(_ slot: GarmentSlot) -> [CandidateItem] {
            let scored = filtered.filter { $0.slot == slot }.map { it in
                (item: it, pre: preShape.map { BodyShapeStyling.affinity(items: [it], shape: $0) } ?? 0)
            }
            // 降级时最近穿过的排在后面（降权 = 排序影响，不是二次排除）。
            // 首键与 `rankByRecency` 共用同一段逻辑（D105：此前是两份，
            // 而只有没人用的那份有测试）；次键是体型预分，生产独有。
            let ordered = scored.sorted { a, b in
                if let byRecency = CandidateFilter.recencyOrder(
                    a.item.id, b.item.id, recentlyWornIDs: outcome.recentlyWornIDs) {
                    return byRecency
                }
                return a.pre != b.pre ? a.pre > b.pre : a.item.id < b.item.id
            }
            return Array(ordered.prefix(Self.maxOptionsPerSlot).map(\.item))
        }

        /// 组装一遍：按当前 `filtered` 枚举出全部合法搭配并排好序。
        /// 严格通道拼不出整身时会被再调一次（放宽防重复后）。
        func assemble() -> [ScoredOutfit] {
        let hasDress  = anchors.contains { $0.slot == .dress }
        let hasTop    = anchors.contains { $0.slot == .top }
        let hasBottom = anchors.contains { $0.slot == .bottom }
        let hasShoes  = anchors.contains { $0.slot == .shoes }
        let hasOuter  = anchors.contains { $0.slot == .outerwear }

        // 缺哪些槽位就补哪些；[nil] 表示该槽位无需补（已由锚定覆盖或不需要）
        let opt: (Bool, GarmentSlot) -> [CandidateItem?] = { covered, slot in
            covered ? [nil] : options(slot).map { Optional($0) }
        }
        // 用户未锚定上身任何件时，池内连衣裙可替代 top+bottom。
        // 组合骨架按 grammar 硬规则拆枝（裙与上下装互斥、无裙必须上下齐）——
        // 旧实现把 [nil] 并列后靠 grammar 过滤，93% 迭代是必废组合
        // （12 项池实际 13⁴×12 ≈ 34 万次迭代，非注释宣称的 2.2 万）。
        let dressViaPool = !hasDress && !hasTop && !hasBottom
        let shoesOpts  = opt(hasShoes, .shoes)
        let addOuter   = context.daytimeTempF < OutfitAssembler.coldThresholdF && !hasOuter
        // 冷天可加外套（也允许不加：+ [nil]）；暖天不补
        let outerOpts: [CandidateItem?] = addOuter ? (options(.outerwear).map { Optional($0) } + [nil]) : [nil]

        var seen = Set<[String]>()
        var results: [ScoredOutfit] = []
        func consider(_ picks: [CandidateItem?]) {
            let items = anchors + picks.compactMap { $0 }
            // grammar 仍是最终裁判（拆枝只削去必废组合，不替代校验）
            guard OutfitGrammar.isValid(items) else { return }
            let outfit = Outfit(items: items)
            guard seen.insert(outfit.itemIDs).inserted else { return }
            results.append(ScoredOutfit(outfit: outfit, score: OutfitScorer.score(outfit, context: scoring)))
        }
        if dressViaPool {
            // 枝 A：连衣裙替代上下装
            for d in options(.dress) { for sh in shoesOpts { for o in outerOpts {
                consider([d, sh, o])
            }}}
            // 枝 B：上装 + 下装
            for t in options(.top) { for b in options(.bottom) { for sh in shoesOpts { for o in outerOpts {
                consider([t, b, sh, o])
            }}}}
        } else {
            let topOpts = opt(hasDress || hasTop, .top)
            let bottomOpts = opt(hasDress || hasBottom, .bottom)
            for t in topOpts { for b in bottomOpts { for sh in shoesOpts { for o in outerOpts {
                consider([t, b, sh, o])
            }}}}
        }

        // 按分降序；分同则**近期穿过的件更少**的排前；再同则按 itemIDs 稳定排序。
        //
        // D112：降权此前只作用在槽位候选列表内部（`options` 的首键），
        // 而用户看到的是**搭配层**的顺序——同分时按字典序，
        // 于是降级后第一条推荐照样可能是刚穿过的那身。
        // 「降权」要在用户真正看到的那一层生效才算数。
        let wornIDs = outcome.recentlyWornIDs
        func wornCount(_ s: ScoredOutfit) -> Int {
            wornIDs.isEmpty ? 0 : s.outfit.itemIDs.count { wornIDs.contains($0) }
        }
        results.sort { a, b in
            if a.score.value != b.score.value { return a.score.value > b.score.value }
            let (wa, wb) = (wornCount(a), wornCount(b))
            if wa != wb { return wa < wb }
            return a.outfit.itemIDs.joined(separator: ",") < b.outfit.itemIDs.joined(separator: ",")
        }
        return results
        }

        var assembled = assemble()
        // 严格通道一身都拼不出、且确有近期穿着记录 → 只摘掉防重复这一条再拼一次。
        // 其余三条门（场合/天气/可用状态）原样——那三条无分歧。
        if assembled.isEmpty, !context.wornWithin7DaysIDs.isEmpty {
            let relaxedItems = CandidateFilter.filter(pool, context: FilterContext(
                occasion: context.occasion,
                daytimeTempF: context.daytimeTempF,
                wornWithin7DaysIDs: [],
                coldBias: context.coldBias))
            outcome = CandidateFilter.Outcome(
                items: relaxedItems,
                repeatGateRelaxed: true,
                recentlyWornIDs: Set(relaxedItems.map(\.id))
                    .intersection(context.wornWithin7DaysIDs))
            filtered = relaxedItems.filter { !anchorIDs.contains($0.id) }
            let retry = assemble()
            if retry.isEmpty {
                // 放宽了也拼不出 → 空结果的原因不是防重复，别对用户说反话（D89 纪律 #2）
                outcome = CandidateFilter.Outcome(
                    items: strictItems, repeatGateRelaxed: false, recentlyWornIDs: [])
            } else {
                assembled = retry
            }
        }
        return Result(
            suggestions: Array(assembled.prefix(max(0, maxSuggestions))),
            repeatGateRelaxed: outcome.repeatGateRelaxed)
    }
}
