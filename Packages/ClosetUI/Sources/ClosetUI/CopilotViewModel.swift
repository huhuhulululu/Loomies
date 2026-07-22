import Foundation
import Observation
import ClosetModel
import ClosetCore

/// copilot 交互的 UI 逻辑（DESIGN §F4 copilot）：用户锚定单品 → 求 AI 补全候选。
/// 纯逻辑、可 swift test 验证（不含渲染）。full-auto 为可选模式。
@MainActor
@Observable
public final class CopilotViewModel {
    public let wardrobe: Wardrobe
    public var occasion: String
    public var daytimeTempF: Double
    public var fullAuto: Bool = false
    public private(set) var anchorIDs: Set<UUID> = []
    public private(set) var suggestions: [ScoredOutfit] = []

    public init(wardrobe: Wardrobe, occasion: String = "work", daytimeTempF: Double = 70) {
        self.wardrobe = wardrobe
        self.occasion = occasion
        self.daytimeTempF = daytimeTempF
    }

    /// 本柜可用单品（供用户挑选锚定）。
    public var availableItems: [Item] {
        (wardrobe.items ?? []).filter { $0.statusRaw == "available" }.sorted { $0.name < $1.name }
    }

    public func isAnchored(_ item: Item) -> Bool { anchorIDs.contains(item.id) }

    public func toggleAnchor(_ item: Item) {
        if anchorIDs.contains(item.id) { anchorIDs.remove(item.id) }
        else { anchorIDs.insert(item.id) }
    }

    /// 求补全候选：copilot（用锚定）或 full-auto（无锚定）。跨柜隔离由 RecommendationService 源头强制。
    public func refresh() {
        let anchors = fullAuto ? [] : (wardrobe.items ?? []).filter { anchorIDs.contains($0.id) }
        suggestions = RecommendationService.suggestions(
            for: wardrobe, anchors: anchors, occasion: occasion,
            daytimeTempF: daytimeTempF, maxSuggestions: 3)
    }
}
