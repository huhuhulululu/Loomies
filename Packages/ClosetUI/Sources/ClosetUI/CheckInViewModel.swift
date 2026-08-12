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
    /// Last customer flash (success or save-fail); empty when idle.
    public private(set) var message: String = ""

    /// Customer toast when ModelSave fails (selection kept for retry).
    public static let saveFailedMessage = CheckInService.saveFailedMessage

    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    /// 洗衣/外借件默认不在可选列表（打卡的是「今天穿了」）；用户可显式包含。
    public var includesUnavailableItems: Bool = false

    /// 类型安全的合身反馈桥接（Picker 绑定用；脏 raw 读作 nil，不编造）。
    public var fitVerdict: FitVerdict? {
        get { FitFeedbackCopy.parse(fitFeedback) }
        set { fitFeedback = newValue?.rawValue }
    }

    public var availableItems: [Item] {
        (wardrobe.items ?? []).filter { $0.statusRaw == "available" }
            .sorted { ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString) }
    }

    /// 手动打卡的可选列表（含/不含非可用件）。
    public var selectableItems: [Item] {
        guard includesUnavailableItems else { return availableItems }
        return (wardrobe.items ?? [])
            .sorted { ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString) }
    }

    public func isSelected(_ item: Item) -> Bool { selectedIDs.contains(item.id) }

    public func toggle(_ item: Item) {
        if selectedIDs.contains(item.id) { selectedIDs.remove(item.id) }
        else { selectedIDs.insert(item.id) }
    }

    public var canCheckIn: Bool { !selectedIDs.isEmpty }

    /// 落库前选中项解析不到任何在柜单品时的诚实提示（无静默零件打卡）。
    public nonisolated static let staleSelectionMessage = "Couldn't check in — selected pieces no longer in this closet"

    /// Logs wear. On save fail: keeps selection + fitFeedback, sets `message`, returns nil.
    /// Stale selection (items transferred/deleted since) is dropped first; if nothing
    /// resolves, no zero-item WearRecord is written and an honest message is set.
    @discardableResult
    public func checkIn(on date: Date = Date(), in context: ModelContext) -> WearRecord? {
        guard canCheckIn else { return nil }
        let items = (wardrobe.items ?? []).filter { selectedIDs.contains($0.id) }
        // Drop stale IDs (transferred away / deleted since selection).
        selectedIDs = Set(items.map { $0.id })
        guard !items.isEmpty else {
            message = Self.staleSelectionMessage
            AppLog.notice("check-in skipped: selection resolved to zero items", .app)
            return nil
        }
        // 合身反馈不随 recordWear 传入：统一走 setFitFeedback 的校验 + 原子路径
        //（两条 UI 路径共用同一守卫，脏值不会绕过）。
        guard let rec = CheckInService.recordWear(
            items: items, on: date, in: wardrobe, in: context)
        else {
            message = Self.saveFailedMessage
            return nil
        }
        if fitFeedback != nil {
            // 反馈写失败不回滚打卡本身（打卡已成功，谎报失败反而不诚实）
            _ = CheckInService.setFitFeedback(fitFeedback, on: rec, in: context)
        }
        lastRecord = rec
        selectedIDs = []
        fitFeedback = nil
        message = ""
        return rec
    }

    /// 近 days 天穿过的单品 id（uuidString），供 copilot 防重复。
    public static func recentlyWornIDs(
        within days: Int = 7, asOf date: Date = Date(), in context: ModelContext
    ) -> Set<String> {
        WearHistory.recentlyWornItemIDs(within: days, asOf: date, in: context)
    }
}
