import Foundation
import Observation
import ClosetModel
import ClosetCore

/// copilot 交互的 UI 逻辑（DESIGN §F4 copilot）：用户锚定单品 → 求 AI 补全候选。
/// 增强：empty reason / 耗时 / 日志 / DebugSettings 钩子。
@MainActor
@Observable
public final class CopilotViewModel {
    public let wardrobe: Wardrobe
    public var occasion: String
    public var daytimeTempF: Double
    public var fullAuto: Bool = false
    public var wornWithin7DaysIDs: Set<String> = []
    public var bodyShape: BodyShape?
    public var coldStartThreshold: Int = 8
    public private(set) var anchorIDs: Set<UUID> = []
    public private(set) var suggestions: [ScoredOutfit] = []
    /// 最近一次 refresh 的人话状态（空结果原因 / 成功摘要）。
    public private(set) var statusMessage: String = ""
    /// 最近一次 refresh 耗时 ms。
    public private(set) var lastRefreshMS: Double = 0
    public private(set) var lastRefreshAt: Date?

    public init(wardrobe: Wardrobe, occasion: String = "work", daytimeTempF: Double = 70) {
        self.wardrobe = wardrobe
        self.occasion = occasion
        self.daytimeTempF = daytimeTempF
    }

    public var availableItems: [Item] {
        (wardrobe.items ?? []).filter { $0.statusRaw == "available" }.sorted { $0.name < $1.name }
    }

    public var isColdStart: Bool {
        DebugSettings.shared.forceColdStart || availableItems.count < coldStartThreshold
    }

    public func isAnchored(_ item: Item) -> Bool { anchorIDs.contains(item.id) }

    public func toggleAnchor(_ item: Item) {
        if anchorIDs.contains(item.id) { anchorIDs.remove(item.id) }
        else { anchorIDs.insert(item.id) }
        AppLog.debug("anchor toggle \(item.name) now=\(anchorIDs.count)", .copilot)
    }

    public func clearAnchors() {
        anchorIDs = []
        AppLog.debug("anchors cleared", .copilot)
    }

    public func applyWeather(_ provider: any WeatherProviding) async {
        do {
            daytimeTempF = try await provider.daytimeTemperatureF(
                forCity: wardrobe.locationCity, on: Date())
            AppLog.info("weather \(daytimeTempF)°F city=\(wardrobe.locationCity ?? "-")", .weather)
        } catch {
            AppLog.error("weather failed: \(error)", .weather)
        }
    }

    public func refresh() {
        let t0 = CFAbsoluteTimeGetCurrent()
        let dbg = DebugSettings.shared
        let forceAnchor = isColdStart || !fullAuto
        let anchors: [Item]
        if forceAnchor {
            anchors = (wardrobe.items ?? []).filter { anchorIDs.contains($0.id) }
            if isColdStart && anchors.isEmpty {
                suggestions = []
                statusMessage = availableItems.isEmpty
                    ? "Empty closet — load samples in Closet or Me."
                    : "Cold start: anchor at least one piece first."
                lastRefreshMS = (CFAbsoluteTimeGetCurrent() - t0) * 1000
                lastRefreshAt = Date()
                AppLog.notice("refresh empty: \(statusMessage)", .copilot)
                return
            }
        } else {
            anchors = []
        }

        let worn: Set<String> = dbg.disableAntiRepeat ? [] : wornWithin7DaysIDs
        suggestions = AppLog.timed("copilot.refresh", .copilot) {
            RecommendationService.suggestions(
                for: wardrobe, anchors: anchors, occasion: occasion,
                daytimeTempF: daytimeTempF,
                wornWithin7DaysIDs: worn,
                bodyShape: bodyShape,
                maxSuggestions: 3)
        }
        lastRefreshMS = (CFAbsoluteTimeGetCurrent() - t0) * 1000
        lastRefreshAt = Date()

        if suggestions.isEmpty {
            statusMessage = emptyReason(
                anchors: anchors, wornCount: worn.count, available: availableItems.count)
        } else {
            statusMessage = "\(suggestions.count) suggestion(s) · \(String(format: "%.0f", lastRefreshMS))ms"
        }
        AppLog.info(
            "refresh occasion=\(occasion) temp=\(daytimeTempF) anchors=\(anchors.count) worn=\(worn.count) out=\(suggestions.count) \(String(format: "%.1fms", lastRefreshMS))",
            .copilot)
    }

    private func emptyReason(anchors: [Item], wornCount: Int, available: Int) -> String {
        if available == 0 { return "No available pieces in this closet." }
        if available < 3 { return "Need more pieces (top/bottom/shoes) to complete a look." }
        if wornCount > 0 && wornCount >= available {
            return "All pieces worn in last 7 days — toggle off anti-repeat in Debug, or wait."
        }
        if !anchors.isEmpty {
            return "No legal completion for these anchors + occasion/weather filters."
        }
        return "No outfits matched occasion/weather/grammar filters."
    }
}
