import Foundation
import ClosetCore

/// 推荐垂直切片（DESIGN §F4 copilot）：数据 → 适配 → 补全，封成单一入口。
/// **跨衣柜硬约束在源头强制**：候选池只从传入衣柜的单品取，搭配永不跨柜（用户硬约束）。
/// 同一 API 两用：带 anchors = copilot（你锚定→AI 补全供选）；无 anchors = full-auto（可选模式）。
public enum RecommendationService {

    public static func suggestions(
        for wardrobe: Wardrobe,
        anchors: [Item] = [],
        occasion: String,
        daytimeTempF: Double,
        wornWithin7DaysIDs: Set<String> = [],
        bodyShape: BodyShape? = nil,
        maxSuggestions: Int = 3
    ) -> [ScoredOutfit] {
        let anchorIDs = Set(anchors.map(\.id))
        // 候选池只从**本衣柜**取（跨柜硬约束在源头强制），排除锚定项
        let pool = (wardrobe.items ?? [])
            .filter { !anchorIDs.contains($0.id) }
            .map { $0.toCandidateItem() }
        let anchorCandidates = anchors.map { $0.toCandidateItem() }

        return OutfitCompleter.complete(
            anchors: anchorCandidates,
            pool: pool,
            context: FilterContext(occasion: occasion, daytimeTempF: daytimeTempF,
                                   wornWithin7DaysIDs: wornWithin7DaysIDs),
            scoring: ScoringContext(bodyShape: bodyShape),
            maxSuggestions: maxSuggestions)
    }
}
