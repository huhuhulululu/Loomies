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
    /// 防止全枚举 top×bottom×shoes×outer 在中等衣柜规模下爆炸（~50 万 scorer 调用/请求）；
    /// N=12 时最坏 12×12×12×13 ≈ 2.2 万，且 prefix 截断保证确定性。
    public static let maxOptionsPerSlot = 12

    public static func complete(
        anchors: [CandidateItem],
        pool: [CandidateItem],
        context: FilterContext,
        scoring: ScoringContext,
        maxSuggestions: Int
    ) -> [ScoredOutfit] {
        let anchorIDs = Set(anchors.map(\.id))
        // 候选池：过四条正确性 + 去掉已锚定项（防重复用）
        let filtered = CandidateFilter.filter(pool, context: context).filter { !anchorIDs.contains($0.id) }
        func options(_ slot: GarmentSlot) -> [CandidateItem] {
            // 组合前封顶：只取 id 升序前 maxOptionsPerSlot 个（确定性截断）
            Array(filtered.filter { $0.slot == slot }.sorted { $0.id < $1.id }.prefix(Self.maxOptionsPerSlot))
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
        // 用户未锚定上身任何件时，池内连衣裙可替代 top+bottom：
        // 把 dress 与「空上装/空下装」并列枚举，非法组合（裙+上下装）由 OutfitGrammar 过滤。
        let dressViaPool = !hasDress && !hasTop && !hasBottom
        let dressOpts: [CandidateItem?] = dressViaPool
            ? ([nil] + options(.dress).map { Optional($0) })
            : [nil]
        let topOpts: [CandidateItem?]
        let bottomOpts: [CandidateItem?]
        if dressViaPool {
            topOpts = options(.top).map { Optional($0) } + [nil]
            bottomOpts = options(.bottom).map { Optional($0) } + [nil]
        } else {
            topOpts = opt(hasDress || hasTop, .top)
            bottomOpts = opt(hasDress || hasBottom, .bottom)
        }
        let shoesOpts  = opt(hasShoes, .shoes)
        let addOuter   = context.daytimeTempF < OutfitAssembler.coldThresholdF && !hasOuter
        // 冷天可加外套（也允许不加：+ [nil]）；暖天不补
        let outerOpts: [CandidateItem?] = addOuter ? (options(.outerwear).map { Optional($0) } + [nil]) : [nil]

        var seen = Set<[String]>()
        var results: [ScoredOutfit] = []
        for d in dressOpts { for t in topOpts { for b in bottomOpts { for sh in shoesOpts { for o in outerOpts {
            let picks = [d, t, b, sh, o].compactMap { $0 }
            let items = anchors + picks
            guard OutfitGrammar.isValid(items) else { continue }
            let outfit = Outfit(items: items)
            guard seen.insert(outfit.itemIDs).inserted else { continue }
            results.append(ScoredOutfit(outfit: outfit, score: OutfitScorer.score(outfit, context: scoring)))
        }}}}}

        // 按分降序；同分按 itemIDs 稳定排序
        results.sort {
            $0.score.value != $1.score.value
                ? $0.score.value > $1.score.value
                : $0.outfit.itemIDs.joined(separator: ",") < $1.outfit.itemIDs.joined(separator: ",")
        }
        return Array(results.prefix(max(0, maxSuggestions)))
    }
}
