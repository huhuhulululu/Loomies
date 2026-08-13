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
        daytimeTempF: Double?,
        wornWithin7DaysIDs: Set<String> = [],
        bodyShape: BodyShape? = nil,
        bodyShapeWeight: Double = 1.0,
        colorSeason: PersonalColorSeason? = nil,
        coldBias: Int = 0,
        maxSuggestions: Int = 3
    ) -> [ScoredOutfit] {
        detailed(for: wardrobe, anchors: anchors, occasion: occasion,
                 daytimeTempF: daytimeTempF, wornWithin7DaysIDs: wornWithin7DaysIDs,
                 bodyShape: bodyShape, bodyShapeWeight: bodyShapeWeight,
                 colorSeason: colorSeason, coldBias: coldBias,
                 maxSuggestions: maxSuggestions).suggestions
    }

    /// 带降级事实的版本（D89）：防重复硬门若会清空候选，会降级为降权，
    /// UI 必须据此说明「这些最近都穿过」，不得静默给出与打卡回执矛盾的结果。
    public static func detailed(
        for wardrobe: Wardrobe,
        anchors: [Item] = [],
        occasion: String,
        daytimeTempF: Double?,
        wornWithin7DaysIDs: Set<String> = [],
        bodyShape: BodyShape? = nil,
        bodyShapeWeight: Double = 1.0,
        colorSeason: PersonalColorSeason? = nil,
        coldBias: Int = 0,
        maxSuggestions: Int = 3
    ) -> OutfitCompleter.Result {
        // 锚定项同样强制同柜：外来衣柜的锚定直接丢弃，绝不流入建议（跨柜硬约束）
        let validAnchors = anchors.filter { $0.wardrobe?.id == wardrobe.id }
        let anchorIDs = Set(validAnchors.map(\.id))
        // 候选池只从**本衣柜**取（跨柜硬约束在源头强制），排除锚定项
        let pool = (wardrobe.items ?? [])
            .filter { !anchorIDs.contains($0.id) }
            .map { $0.toCandidateItem() }
        let anchorCandidates = validAnchors.map { $0.toCandidateItem() }

        return OutfitCompleter.completeDetailed(
            anchors: anchorCandidates,
            pool: pool,
            context: FilterContext(occasion: occasion, daytimeTempF: daytimeTempF,
                                   wornWithin7DaysIDs: wornWithin7DaysIDs,
                                   coldBias: coldBias),
            scoring: ScoringContext(
                bodyShape: bodyShape,
                bodyShapeWeight: bodyShapeWeight,
                colorSeason: colorSeason,
                // D130：冷天偏好带外套的那身；温度未知时不表态
                daytimeTempF: daytimeTempF),
            maxSuggestions: maxSuggestions)
    }
}
