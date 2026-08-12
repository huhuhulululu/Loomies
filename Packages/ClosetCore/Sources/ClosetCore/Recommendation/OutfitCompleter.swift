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
        // D89：硬门会清空候选时降级为降权（小衣柜本周都穿过 → 给建议而不是空屏），
        // 降级事实由 `lastOutcome` 上报给 UI，不得静默。
        let outcome = CandidateFilter.filterWithRepeatFallback(pool, context: context)
        let filtered = outcome.items.filter { !anchorIDs.contains($0.id) }
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

        // 按分降序；同分按 itemIDs 稳定排序
        results.sort {
            $0.score.value != $1.score.value
                ? $0.score.value > $1.score.value
                : $0.outfit.itemIDs.joined(separator: ",") < $1.outfit.itemIDs.joined(separator: ",")
        }
        return Result(
            suggestions: Array(results.prefix(max(0, maxSuggestions))),
            repeatGateRelaxed: outcome.repeatGateRelaxed)
    }
}
