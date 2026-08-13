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
        maxSuggestions: Int,
        isSuperseded: () -> Bool = { Task.isCancelled }
    ) -> [ScoredOutfit] {
        completeDetailed(anchors: anchors, pool: pool, context: context,
                         scoring: scoring, maxSuggestions: maxSuggestions,
                         isSuperseded: isSuperseded).suggestions
    }

    /// 截断前的廉价预排序（D133）。
    ///
    /// 每槽位只有 12 件能进组合枚举，而此前的排序键是「体型 affinity → id」——
    /// 绝大多数用户**没填过身体维度**（那要量三围），affinity 全为 0，
    /// 于是退化成纯 id 前缀截断：`Item.id` 是随机 UUID，
    /// **一个 60 件上装的衣柜，进入枚举的是随机的 12 件**。
    /// 配色最搭的那件、色季最合的那件可能从来没被考虑过——
    /// 打分层里配色和色季的权重只对「碰巧被抽中的那 12 件」起作用。
    ///
    /// 修法不是加大 12（那是指数级代价），是**让截断也看得见配色**。
    public static func preRank(
        _ items: [CandidateItem],
        scoring: ScoringContext,
        recentlyWornIDs: Set<String> = []
    ) -> [CandidateItem] {
        let shape = scoring.bodyShape?.popularCategory
        func pre(_ item: CandidateItem) -> Double {
            var score = 0.0
            if let shape {
                score += BodyShapeStyling.affinity(items: [item], shape: shape)
            }
            if let season = scoring.colorSeason, let color = item.color {
                score += season.colorAffinity(colors: [color])
            }
            // 没有任何上下文时的兜底：**有颜色的排在没颜色的前面**。
            // 打分层的配色维度只能作用在已知颜色的件上——
            // 截断把它们挤掉，那几项权重就等于没有。
            if item.color != nil { score += 0.01 }
            return score
        }
        return items
            .map { (item: $0, pre: pre($0)) }
            .sorted { a, b in
                if let byRecency = CandidateFilter.recencyOrder(
                    a.item.id, b.item.id, recentlyWornIDs: recentlyWornIDs) {
                    return byRecency
                }
                return a.pre != b.pre ? a.pre > b.pre : a.item.id < b.item.id
            }
            .map(\.item)
    }

    public static func completeDetailed(
        anchors: [CandidateItem],
        pool: [CandidateItem],
        context: FilterContext,
        scoring: ScoringContext,
        maxSuggestions: Int
    ,
        isSuperseded: () -> Bool = { Task.isCancelled }
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
        // 截断前的廉价预排序见 `preRank`（D133 起也看配色/色季，
        // 不再是「没体型档案就退化成随机抽样」）。
        func options(_ slot: GarmentSlot) -> [CandidateItem] {
            // 降级时最近穿过的排在后面（降权 = 排序影响，不是二次排除）。
            // 首键与 `rankByRecency` 共用同一段逻辑（D105：此前是两份，
            // 而只有没人用的那份有测试）；次键是预分，生产独有。
            let pool = filtered.filter { $0.slot == slot }
            let ordered = preRank(
                pool, scoring: scoring, recentlyWornIDs: outcome.recentlyWornIDs)
            return Array(ordered.prefix(Self.maxOptionsPerSlot))
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
        // 温度未知时不主动补外套——不知道冷暖就不替用户决定（D130）
        let addOuter = (context.daytimeTempF ?? .infinity) < OutfitAssembler.coldThresholdF
            && !hasOuter
        // 冷天可加外套（也允许不加：+ [nil]）；暖天不补
        let outerOpts: [CandidateItem?] = addOuter ? (options(.outerwear).map { Optional($0) } + [nil]) : [nil]

        var seen = Set<[String]>()
        var results: [ScoredOutfit] = []
        // D159：被取代就当场收手（D152 把计算挪到后台之后，用户点得动第二下了——
        // 九个触发点都不挡并发，旧的那次此前会一路烧到底）。
        var abandoned = false
        // D151：**枚举时只留前 K。**
        //
        // 此前把每一套都物化进 `results`，最后才排序取 `maxSuggestions`——
        // 而冷天 240 件衣柜要枚举 12×12×12×13 ≈ 2.2 万套，每套带成员数组、
        // id 数组和一串理由字符串。实测该路径整整 **3 秒**，同步跑在主线程上：
        // 用户在冬天打开 Today，整个界面冻结三秒，而这个 App 冬天最该有用。
        //
        // `ranksBefore` 是全序（分数 → 近期穿着 → itemIDs 字典序），
        // 所以「边枚举边只留前 K」与「全物化再排序取前 K」**结果完全相同**。
        let keep = max(1, maxSuggestions)
        let wornIDs = outcome.recentlyWornIDs
        func consider(_ picks: [CandidateItem?]) {
            if abandoned { return }
            if isSuperseded() { abandoned = true; return }
            let items = anchors + picks.compactMap { $0 }
            // grammar 仍是最终裁判（拆枝只削去必废组合，不替代校验）
            guard OutfitGrammar.isValid(items) else { return }
            let outfit = Outfit(items: items)
            guard seen.insert(outfit.itemIDs).inserted else { return }
            let scored = ScoredOutfit(
                outfit: outfit, score: OutfitScorer.score(outfit, context: scoring))
            if results.count < keep {
                results.append(scored)
            } else if OutfitScorer.ranksBefore(
                scored, results[keep - 1], recentlyWornIDs: wornIDs) {
                results[keep - 1] = scored
            } else {
                return   // 连当前第 K 名都比不过 —— 直接丢
            }
            results.sort { OutfitScorer.ranksBefore($0, $1, recentlyWornIDs: wornIDs) }
        }
        if dressViaPool {
            // D151：**每个槽位的候选只算一次。** 此前 `options(.bottom)` 写在
            // 内层循环头上——Swift 每进一次内层循环就重新求值一遍，
            // 而 `options` 要过滤全池 + `preRank`（那一步给每件打分）。
            // 12 个上装 = 把整个下装池重新预排 12 遍。实测冷天 240 件衣柜
            // 3013ms 里约一半是这个。提出来即可，结果一个字不变
            //（`options` 对 `filtered`/`scoring` 是纯的，本次 assemble 内不变）。
            let dressOpts = options(.dress)
            let topOpts = options(.top)
            let bottomOpts = options(.bottom)
            // 枝 A：连衣裙替代上下装
            for d in dressOpts { for sh in shoesOpts { for o in outerOpts {
                consider([d, sh, o])
            }}}
            // 枝 B：上装 + 下装
            for t in topOpts { for b in bottomOpts { for sh in shoesOpts { for o in outerOpts {
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
        // D131：比较口径收进 `OutfitScorer.ranksBefore`（含浮点容差）——
        // 散在调用点的两份写法迟早分叉，而分叉那天顺序会随调用点而变。
        // `consider` 已维持前 K 有序（见上）——这里不再全量排序。
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
