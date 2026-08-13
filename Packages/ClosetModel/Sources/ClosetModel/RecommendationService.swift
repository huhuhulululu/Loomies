import Foundation
import ClosetCore

/// 推荐垂直切片（DESIGN §F4 copilot）：数据 → 适配 → 补全，封成单一入口。
/// **跨衣柜硬约束在源头强制**：候选池只从传入衣柜的单品取，搭配永不跨柜（用户硬约束）。
/// 同一 API 两用：带 anchors = copilot（你锚定→AI 补全供选）；无 anchors = full-auto（可选模式）。
///
/// ⚠️ **生产路径不走这里**（D192）。Today 的刷新在 `CopilotViewModel.makeRefreshRequest`
/// 里自己做同一套映射——那是为了把快照摊成 `Sendable` 值再扔去后台算（D152 三段式），
/// 这个函数持 `Wardrobe` 模型，跨不了 actor 边界。
///
/// 后果要说清：本文件的测试验的是**产品不走的那条路**——改坏 VM 里那份映射，
/// 它们一条都不会红。两份已经分叉（VM 侧对锚定多加了 `statusRaw == "available"`，
/// 方向是更严，且那条更严的在 `CopilotViewModelTests` 有覆盖）。
///
/// 保留而不是删（对比 `filterWithRepeatFallback` 的处置）：它是 D89 之前就定下的
/// 垂直切片契约，`CheckInService` 与 `CopilotViewModel` 的注释都在引用它描述语义。
/// 但**新代码勿用**，且看它的测试时要记得那不是 shipped path 的证据。
///
/// 收口条件：`makeRefreshRequest` 改成先摊平快照、再由本函数吃纯值——
/// 那时两份合一，这些测试才重新成为生产证据。
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
