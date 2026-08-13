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
    /// message 是成功回执还是失败提示。View 靠它决定关不关表单——
    /// 绝不让 UI 靠关键词嗅探判断成败（润色文案就会静默失效）。
    public private(set) var didFail: Bool = false

    /// Customer toast when ModelSave fails (selection kept for retry).
    public static let saveFailedMessage = CheckInService.saveFailedMessage

    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    /// 洗衣/外借件默认不在可选列表（打卡的是「今天穿了」）；用户可显式包含。
    /// 含在洗/外借件。**关掉时要把已勾中的那些一并取消**（D189）——
    /// 此前只有列表跟着变，选中集原样留着：屏幕上一个勾都看不见，
    /// Log 按钮仍可点，落库的是被「取消显示」的那件。
    public var includesUnavailableItems: Bool = false {
        didSet {
            guard !includesUnavailableItems, oldValue else { return }
            let stillVisible = Set(availableItems.map(\.id))
            selectedIDs.formIntersection(stillVisible)
        }
    }

    /// 类型安全的合身反馈桥接（Picker 绑定用；脏 raw 读作 nil，不编造）。
    public var fitVerdict: FitVerdict? {
        get { FitFeedbackCopy.parse(fitFeedback) }
        set { fitFeedback = newValue?.rawValue }
    }

    public var availableItems: [Item] {
        (wardrobe.items ?? []).filter { $0.statusRaw == "available" }
            .sortedByName()
    }

    /// 手动打卡的可选列表（含/不含非可用件）。
    public var selectableItems: [Item] {
        guard includesUnavailableItems else { return availableItems }
        return (wardrobe.items ?? [])
            .sortedByName()
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
        didFail = false
        let items = (wardrobe.items ?? []).filter { selectedIDs.contains($0.id) }
        // Drop stale IDs (transferred away / deleted since selection).
        selectedIDs = Set(items.map { $0.id })
        guard !items.isEmpty else {
            message = Self.staleSelectionMessage
            didFail = true
            AppLog.notice("check-in skipped: selection resolved to zero items", .app)
            return nil
        }
        // 合身反馈不随 recordWear 传入：统一走 setFitFeedback 的校验 + 原子路径
        //（两条 UI 路径共用同一守卫，脏值不会绕过）。
        guard let rec = CheckInService.recordWear(
            items: items, on: date, in: wardrobe, in: context)
        else {
            message = Self.saveFailedMessage
            didFail = true
            return nil
        }
        // 反馈写失败不回滚打卡本身（打卡已成功，谎报整体失败反而不诚实），
        // 但**必须说出**备注没保存——此前这里丢弃返回值 + 清空 message，
        // 表单干净关闭，用户无从察觉自己选的合身档位没落库。
        var feedbackFailed = false
        let verdict = FitFeedbackCopy.parse(fitFeedback)
        if fitFeedback != nil {
            feedbackFailed = !CheckInService.setFitFeedback(fitFeedback, on: rec, in: context)
        }
        lastRecord = rec
        TelemetryGate.shared.track(.checkInRecorded, payload: [
            "item_count": String(items.count),
            "has_fit_feedback": String(verdict != nil),
        ])
        selectedIDs = []
        fitFeedback = nil
        if feedbackFailed {
            message = CheckInService.fitFeedbackSaveFailedMessage
            didFail = true
        } else if let verdict {
            message = FitFeedbackCopy.recordedMessage(verdict)
        } else {
            // 与 Today「Wore it」共用同一条回执文案（两条打卡路径口径一致）
            message = CopilotWoreIt.flashMessage(
                .checkedIn(pieceCount: items.count),
                antiRepeatEnabled: !DebugSettings.shared.disableAntiRepeat)
        }
        return rec
    }

    /// 近 days 天穿过的单品 id（uuidString），供 copilot 防重复。
    public static func recentlyWornIDs(
        within days: Int = 7, asOf date: Date = Date(), in context: ModelContext
    ) -> Set<String> {
        WearHistory.recentlyWornItemIDs(within: days, asOf: date, in: context)
    }
}
