import Foundation

/// outfit 打分结果，附「为什么推荐」（DESIGN §F4：每条推荐可解释）。
public struct OutfitScore: Sendable, Equatable {
    public let value: Double
    public let reasons: [String]
    public init(value: Double, reasons: [String]) {
        self.value = value
        self.reasons = reasons
    }
}

public struct ScoringContext: Sendable {
    public let bodyShape: BodyShape?
    /// 0 = guessed-absent, 0.5 = visual pick, 0.85 = provisional, 1.0 = measured.
    public let bodyShapeWeight: Double
    public let colorSeason: PersonalColorSeason?
    /// 日间温度。**nil = 未知**——不知道冷暖就不对「要不要外套」表态（D130）。
    public let daytimeTempF: Double?
    public init(
        bodyShape: BodyShape? = nil,
        bodyShapeWeight: Double = 1.0,
        colorSeason: PersonalColorSeason? = nil,
        daytimeTempF: Double? = nil
    ) {
        self.daytimeTempF = daytimeTempF
        self.bodyShape = bodyShape
        self.bodyShapeWeight = bodyShapeWeight
        self.colorSeason = (colorSeason == .unknown) ? nil : colorSeason
    }
}

/// outfit 打分（纯函数，透明可解释）。当前含配色协调 + 60-30-10 平衡；
/// 体型×属性加权待属性表建成后接入（下一步，reason 已预留位）。
public enum OutfitScorer {
    /// 打分值域：钳在 [0, 2]（基准 1.0 ± 配色/体型加权）。
    /// affinity 是各单品属性权重之和、本身无界，故最终分必须有界，
    /// 推荐排序才可跨 outfit 比较。
    public static let scoreRange: ClosedRange<Double> = 0...2

    /// 体型项能贡献的**上限**（正负各一半值域，D127）。
    ///
    /// affinity 是各单品属性权重之和、本身无界——12 件全带加分属性就能加到
    /// +2 以上，把最终分顶到值域上界。那时配色好不好、色季合不合
    /// **对排序完全不起作用**：配色维度在大衣柜上直接消失，
    /// 而配色恰恰是用户一眼能验证对错的那一维。
    ///
    /// 0.35 略小于配色项的合计幅度（±0.4），保证「两套体型都很合适时，
    /// 配色仍然能决定谁排前面」。
    public static let maxBodyShapeContribution = 0.35

    /// 视为同分的容差（D131）。
    ///
    /// 排序此前用 `a.value != b.value` 精确比较：两套分数本质相同、
    /// 只因加法顺序不同差了 1e-16 时，**那个噪声就成了名次的决定因素**，
    /// 后面的稳定决胜键（近期穿着、itemIDs 字典序）根本轮不到。
    /// 用户看到的是同一个衣柜同一天，两次打开推荐顺序不一样。
    ///
    /// 取 1e-9：远大于浮点噪声，又远小于产品里最小的一档加成（0.1）。
    public static let scoreTolerance = 1e-9

    public static func isEffectivelyTied(_ a: Double, _ b: Double) -> Bool {
        abs(a - b) < scoreTolerance
    }

    /// 推荐名次的**唯一**比较口径：分数（带容差）→ 近期穿过的更少 → itemIDs 字典序。
    /// 放在这里而不是散在调用点：两处写法迟早分叉，而分叉那天顺序会随调用点而变。
    public static func ranksBefore(
        _ a: ScoredOutfit, _ b: ScoredOutfit, recentlyWornIDs: Set<String>
    ) -> Bool {
        if !isEffectivelyTied(a.score.value, b.score.value) {
            return a.score.value > b.score.value
        }
        if !recentlyWornIDs.isEmpty {
            let wa = a.outfit.itemIDs.count { recentlyWornIDs.contains($0) }
            let wb = b.outfit.itemIDs.count { recentlyWornIDs.contains($0) }
            if wa != wb { return wa < wb }
        }
        return a.outfit.itemIDs.joined(separator: ",")
            < b.outfit.itemIDs.joined(separator: ",")
    }

    public static func score(_ outfit: Outfit, context: ScoringContext) -> OutfitScore {
        var value = 1.0
        var reasons: [String] = []
        /// 每条理由**对最终分的实际贡献**。UI 只显示第一条，
        /// 而排序键必须与用户看到的名次同源——否则展示的不是拉开差距的那一项（D127）。
        var contributions: [(reason: String, magnitude: Double)] = []
        func note(_ reason: String, _ delta: Double) {
            reasons.append(reason)
            contributions.append((reason, abs(delta)))
        }

        let colors = outfit.items.compactMap(\.color)
        if colors.count >= 2 {
            let harmonious = ColorHarmony.isHarmonious(colors)
            if harmonious {
                value += 0.3
                note("Colors work well together", 0.3)
            } else {
                value -= 0.3
                note("Color clash — swap one piece", 0.3)
            }
            // D131：**撞色的一身不得同时被夸「配色平衡」**。
            //
            // 两个判据各自成立（色族 ≤3 与色相是否冲突是两回事），
            // 但摆在一起读就是自相矛盾：用户刚被告知「撞色了，换一件」，
            // 下一行却说「60-30-10 平衡得好」——他不知道该信哪句，
            // 也不知道到底要不要换。
            //
            // 分数照旧（平衡确实值那 0.1），只是**撞色时不说这句话**：
            // 那一刻唯一有用的信息是「哪件该换」。
            if ColorHarmony.followsSixtyThirtyTen(colors) {
                value += 0.1
                if harmonious { note("Balanced 60-30-10 color mix", 0.1) }
            } else if harmonious {
                note("Many colors — try one main color", 0)
            }
        }
        // 体型×属性加权（BodyShapeStyling 表）。测量置信度缩放该项，快选不得与实测同权。
        if let shape = context.bodyShape, context.bodyShapeWeight > 0 {
            let affinity = BodyShapeStyling.affinity(items: outfit.items, shape: shape.popularCategory)
            // D127：先钳后缩放——无界的 affinity 必须在这里收口，
            // 否则它会独吞整个值域（见 `maxBodyShapeContribution` 的说明）。
            let raw = 0.2 * affinity
            let capped = min(Self.maxBodyShapeContribution,
                             max(-Self.maxBodyShapeContribution, raw))
            let delta = capped * context.bodyShapeWeight
            // D115：DESIGN §10.4 文案红线——合身语言只评价**衣服**，不评价身体。
            // 「Flatters your body shape」既踩了明令禁止的词，也把主语放在了用户身上；
            // 它还是排第一的推荐理由，等于把项目自己的信任底线摆在最显眼处破掉。
            // 改成描述这套**剪裁**做了什么：主语是衣服，句子仍然说清了为什么被推荐。
            if affinity > 0 {
                value += delta
                note("Cuts that work with your proportions", delta)
            } else if affinity < 0 {
                value += delta
                note("Cut fights your proportions — swap one piece", delta)
            }
        }
        // D130：冷天偏好**带外套**的那身。
        //
        // 补全器在冷天会同时枚举「带外套」和「不带外套」，而打分对外套零加成——
        // 于是 28°F 的早上第一条推荐有没有大衣，**由 UUID 序决定**。
        // 加成给得小（0.12）：它是一条实用提示，不该压过配色与体型。
        if let temp = context.daytimeTempF, temp < OutfitAssembler.coldThresholdF {
            let hasOuter = outfit.items.contains { $0.slot == .outerwear }
            if hasOuter {
                value += 0.12
                note("Layered for a cold day", 0.12)
            }
        }
        if let season = context.colorSeason {
            let affinity = season.colorAffinity(colors: colors)
            if affinity > 0 {
                value += 0.15 * affinity
                note("Colors suit your \(season.displayName.lowercased()) season", 0.15 * affinity)
            } else if affinity < 0 {
                value += 0.15 * affinity
                note("Colors sit outside your \(season.displayName.lowercased()) season", 0.15 * affinity)
            }
        }
        // D127：**把真正拉开分差的那一项排到最前**。
        // UI 只显示 `reasons.first`，而理由此前按「配色 → 体型 → 色季」的
        // 书写顺序追加——于是体型主导的那一套，展示的却是配色的话。
        // 排序键是各项对最终分的**绝对贡献**，跟用户看到的名次同源。
        let ordered = contributions
            .sorted { $0.magnitude != $1.magnitude
                ? $0.magnitude > $1.magnitude
                : $0.reason < $1.reason }
            .map(\.reason)
        return OutfitScore(
            value: min(Self.scoreRange.upperBound, max(Self.scoreRange.lowerBound, value)),
            reasons: ordered.isEmpty ? reasons : ordered)
    }
}
