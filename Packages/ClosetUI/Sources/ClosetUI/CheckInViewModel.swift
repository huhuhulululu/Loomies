import Foundation
import Observation
import SwiftData
import ClosetModel
import ClosetCore

/// 穿着打卡 UI 逻辑（DESIGN §F5「记录」环）：选单品 → 一键打卡 + 可选合身反馈。
/// 打卡后 WearHistory 可喂 RecommendationService 防重复。
@MainActor
@Observable
public final class CheckInViewModel {
    public let wardrobe: Wardrobe
    public var selectedIDs: Set<UUID> = []
    public var fitFeedback: String?   // tight / fitted / loose raw
    public private(set) var lastRecord: WearRecord?

    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    public var availableItems: [Item] {
        (wardrobe.items ?? []).filter { $0.statusRaw == "available" }.sorted { $0.name < $1.name }
    }

    public func isSelected(_ item: Item) -> Bool { selectedIDs.contains(item.id) }

    public func toggle(_ item: Item) {
        if selectedIDs.contains(item.id) { selectedIDs.remove(item.id) }
        else { selectedIDs.insert(item.id) }
    }

    public var canCheckIn: Bool { !selectedIDs.isEmpty }

    @discardableResult
    public func checkIn(on date: Date = Date(), in context: ModelContext) -> WearRecord? {
        guard canCheckIn else { return nil }
        let items = (wardrobe.items ?? []).filter { selectedIDs.contains($0.id) }
        let rec = CheckInService.recordWear(
            items: items, on: date, in: wardrobe,
            fitFeedback: fitFeedback, in: context)
        lastRecord = rec
        selectedIDs = []
        fitFeedback = nil
        return rec
    }

    /// 近 days 天穿过的单品 id（uuidString），供 copilot 防重复。
    public static func recentlyWornIDs(
        within days: Int = 7, asOf date: Date = Date(), in context: ModelContext
    ) -> Set<String> {
        WearHistory.recentlyWornItemIDs(within: days, asOf: date, in: context)
    }
}
