import Foundation
import Observation
import SwiftData
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
    /// User-facing weather source after last successful fetch (W1.3).
    public private(set) var weatherSourceLabel: String = "—"
    /// 0…100 when Open-Meteo provides it.
    public private(set) var precipProbabilityPercent: Int?
    public var fullAuto: Bool = false
    public var wornWithin7DaysIDs: Set<String> = []
    /// 上次刷新时防重复硬门是否被降级为降权（UI 出诚实说明）。
    public private(set) var repeatGateRelaxed: Bool = false
    public var bodyShape: BodyShape?
    public var coldStartThreshold: Int = 8
    public private(set) var anchorIDs: Set<UUID> = []
    public private(set) var suggestions: [ScoredOutfit] = []
    /// 当前展示在首屏大 Avatar 上的建议索引。
    public private(set) var selectedSuggestionIndex: Int = 0
    /// 最近一次 refresh 的人话状态（空结果原因 / 成功摘要）。
    public private(set) var statusMessage: String = ""
    /// 最近一次 refresh 耗时 ms。
    public private(set) var lastRefreshMS: Double = 0
    public private(set) var lastRefreshAt: Date?
    public private(set) var isRefreshing: Bool = false

    public var selectedSuggestion: ScoredOutfit? {
        guard !suggestions.isEmpty else { return nil }
        let i = min(max(0, selectedSuggestionIndex), suggestions.count - 1)
        return suggestions[i]
    }

    public var lookCount: Int { suggestions.count }

    /// 用户选定某个候选（wear-as-is 路径入口）。
    public func selectSuggestion(at index: Int) {
        TelemetryGate.shared.track(.copilotAccepted,
                                   payload: ["mode": fullAuto ? "auto" : "anchored"])
        guard !suggestions.isEmpty else {
            selectedSuggestionIndex = 0
            return
        }
        selectedSuggestionIndex = min(max(0, index), suggestions.count - 1)
    }

    public func selectNextLook() {
        guard lookCount > 1 else { return }
        selectSuggestion(at: (selectedSuggestionIndex + 1) % lookCount)
    }

    public func selectPreviousLook() {
        guard lookCount > 1 else { return }
        selectSuggestion(at: (selectedSuggestionIndex - 1 + lookCount) % lookCount)
    }

    /// Today 的构造入口（D98）。默认场合的推导只此一处——
    /// 此前 View 里内联推导、测试里再实现一遍同样的表达式，
    /// 于是 View 若退回硬编码，测试照样绿（回归门守不住它要守的东西）。
    @MainActor
    public static func forToday(wardrobe: Wardrobe, daytimeTempF: Double = 70) -> CopilotViewModel {
        CopilotViewModel(
            wardrobe: wardrobe,
            occasion: OccasionMix.effectiveOccasion(stated: wardrobe.owner?.primaryOccasionRaw),
            daytimeTempF: daytimeTempF)
    }

    public init(wardrobe: Wardrobe, occasion: String = "work", daytimeTempF: Double = 70) {
        self.wardrobe = wardrobe
        self.occasion = occasion
        self.daytimeTempF = daytimeTempF
    }

    /// Sync scorer bodyShape from Me → Body profile (FFIT or quick-pick).
    /// Returns `true` when the effective shape changed (caller may re-refresh looks).
    @discardableResult
    public func applyBodyProfile(_ profile: PersonBodyProfile?) -> Bool {
        let next = profile.flatMap { BodyProfileService.bodyShape(from: $0) }
        let changed = next != bodyShape
        bodyShape = next
        return changed
    }

    /// Load owner profile from context and apply (bootstrap / tab return / pre-refresh).
    @discardableResult
    public func loadBodyShape(in context: ModelContext) -> Bool {
        guard let pid = wardrobe.owner?.id else {
            return applyBodyProfile(nil)
        }
        let all = (try? context.fetch(FetchDescriptor<PersonBodyProfile>())) ?? []
        return applyBodyProfile(all.first { $0.personID == pid })
    }

    public var availableItems: [Item] {
        (wardrobe.items ?? []).filter { $0.statusRaw == "available" }
            .sorted { ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString) }
    }

    public var isColdStart: Bool {
        DebugSettings.shared.forceColdStart || availableItems.count < coldStartThreshold
    }

    public func isAnchored(_ item: Item) -> Bool { anchorIDs.contains(item.id) }

    public func toggleAnchor(_ item: Item) {
        if anchorIDs.contains(item.id) { anchorIDs.remove(item.id) }
        else { anchorIDs.insert(item.id) }
        AppLog.debug("anchor toggle item=\(AppLog.ref(item.id)) now=\(anchorIDs.count)", .copilot)
        // 换某件/重配 = tweak（只记模式，不记是哪件）
        TelemetryGate.shared.track(.copilotTweaked,
                                   payload: ["mode": fullAuto ? "auto" : "anchored"])
    }

    public func clearAnchors() {
        anchorIDs = []
        AppLog.debug("anchors cleared", .copilot)
    }

    /// 在途天气请求代际号：bootstrap 与城市变更可并发调 applyWeather（两次 HTTP 耗时
    /// 方差大，乱序返回是常态），旧代结果落地会覆盖新代——last-call-wins。
    private var weatherGeneration = 0

    public func applyWeather(_ provider: any WeatherProviding) async {
        weatherGeneration &+= 1
        let generation = weatherGeneration
        do {
            let snap: WeatherDaySnapshot
            if let rich = provider as? any WeatherSnapshotProviding {
                snap = try await rich.daySnapshot(forCity: wardrobe.locationCity, on: Date())
            } else {
                let t = try await provider.daytimeTemperatureF(
                    forCity: wardrobe.locationCity, on: Date())
                snap = WeatherDaySnapshot(daytimeTempF: t, sourceLabel: "Weather")
            }
            guard generation == weatherGeneration else { return }  // 已被更新调用取代
            daytimeTempF = snap.daytimeTempF
            weatherSourceLabel = snap.sourceLabel
            precipProbabilityPercent = snap.precipProbabilityPercent
            AppLog.info(
                "weather \(daytimeTempF)°F src=\(weatherSourceLabel) precip=\(precipProbabilityPercent.map(String.init) ?? "-") hasCity=\(wardrobe.locationCity != nil)",
                .weather)
        } catch {
            guard generation == weatherGeneration else { return }  // 陈旧失败不得吞新成功
            // Honest source chip — do not leave "—" or stale Open-Meteo after a hard fail.
            // Keep last daytimeTempF for scoring continuity; clear rain cue (unknown).
            weatherSourceLabel = Self.weatherUnavailableSourceLabel
            precipProbabilityPercent = nil
            AppLog.error("weather failed: \(AppLog.errRef(error))", .weather)
        }
    }

    /// Shown on Today temp pill when every provider throws (Composite rarely; tests / bad DI).
    public static let weatherUnavailableSourceLabel = "Unavailable"

    /// Short dress cue under temp pill (rain/cool → outerwear), not a hard filter.
    /// Suppressed when weather hard-failed (`Unavailable`) so stale °F cannot claim rain/cool.
    public var weatherDressCue: String? {
        // Source honesty: hard fail clears precip, but keeps last temp for scoring —
        // do not surface dress cues from that retained number while the pill says Unavailable.
        if weatherSourceLabel == Self.weatherUnavailableSourceLabel {
            return nil
        }
        if let p = precipProbabilityPercent, p >= 50 {
            return "Rain likely (\(p)%) · consider a layer"
        }
        if daytimeTempF < 60 {
            return "Cool day · outerwear may help"
        }
        return nil
    }

    public func refresh() {
        isRefreshing = true
        defer {
            isRefreshing = false
            // 遥测：模式 / 场合 / 候选数——都是非身份字段（白名单外的键会被丢弃）
            TelemetryGate.shared.track(.copilotRefresh, payload: [
                "mode": fullAuto ? "auto" : "anchored",
                "occasion": occasion,
                "suggestion_count": String(suggestions.count),
            ])
        }
        let t0 = CFAbsoluteTimeGetCurrent()
        let dbg = DebugSettings.shared
        let forceAnchor = isColdStart || !fullAuto
        let anchors: [Item]
        if forceAnchor {
            anchors = (wardrobe.items ?? [])
                .filter { anchorIDs.contains($0.id) && $0.statusRaw == "available" }
            if isColdStart && anchors.isEmpty {
                suggestions = []
                selectedSuggestionIndex = 0
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
        let result = AppLog.timed("copilot.refresh", .copilot) {
            RecommendationService.detailed(
                for: wardrobe, anchors: anchors, occasion: occasion,
                daytimeTempF: daytimeTempF,
                wornWithin7DaysIDs: worn,
                bodyShape: bodyShape,
                coldBias: wardrobe.owner?.coldBias ?? 0,
                maxSuggestions: 3)
        }
        suggestions = result.suggestions
        // 防重复被降级（本柜今天能穿的都在近 7 天穿过）→ 必须说出来，
        // 否则建议与「de-prioritized 7 days」的打卡回执自相矛盾
        repeatGateRelaxed = result.repeatGateRelaxed
        lastRefreshMS = (CFAbsoluteTimeGetCurrent() - t0) * 1000
        lastRefreshAt = Date()

        selectedSuggestionIndex = 0
        if suggestions.isEmpty {
            // wornWithin7DaysIDs is a global WearRecord fetch — intersect with THIS
            // closet's available pieces so another wardrobe's wears can't trigger
            // the "All pieces worn in last 7 days" message here.
            let availableIDs = Set(availableItems.map { $0.id.uuidString })
            let wornHere = worn.intersection(availableIDs)
            statusMessage = emptyReason(
                anchors: anchors, wornCount: wornHere.count, available: availableItems.count)
        } else {
            statusMessage = "Look \(selectedSuggestionIndex + 1) of \(suggestions.count)"
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
