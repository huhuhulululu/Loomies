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
    /// Measurement confidence from the same profile that produced `bodyShape`.
    public var bodyShapeWeight: Double = 0
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

    /// 用户翻看候选。**不是采纳**——D116：这里此前发 `copilotAccepted`，
    /// 于是「翻一下轮播」就被记成「照着穿了」。MARKET §8.1 的上线判定
    /// （GO/PIVOT/KILL）建立在这个数上，而 D20 跳过真人验证之后它是唯一的裁决装置：
    /// 量错等于没量。采纳只在 `recordWear` 发。
    public func selectSuggestion(at index: Int) {
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
        self.openSource = DailyRitualScheduler.consumeOpenSource()
        self.wardrobe = wardrobe
        self.occasion = occasion
        self.daytimeTempF = daytimeTempF
    }

    /// Sync scorer bodyShape from Me → Body profile (FFIT or quick-pick).
    /// Returns `true` when the effective shape changed (caller may re-refresh looks).
    @discardableResult
    public func applyBodyProfile(_ profile: PersonBodyProfile?) -> Bool {
        let next = profile.flatMap { BodyProfileService.bodyShape(from: $0) }
        let nextWeight = profile.map { BodyProfileService.styleWeightFactor(for: $0) } ?? 0
        let changed = next != bodyShape || nextWeight != bodyShapeWeight
        bodyShape = next
        bodyShapeWeight = nextWeight
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

    /// D126：刚发生的锚定替换（「Chinos replaced Jeans」）。nil = 上一次没有替换。
    /// 静默替换会让用户以为自己点漏了。
    public private(set) var anchorNote: String?

    public func toggleAnchor(_ item: Item) {
        if anchorIDs.contains(item.id) {
            anchorIDs.remove(item.id)
            anchorNote = nil
        } else {
            // D126：锚定曾可以选出一个**永远拼不出**的组合——两条下装、
            // 裙 + 上装、两双鞋。`OutfitGrammar` 早把这些定为非法，
            // 而这里一条都不查：用户选完看到一片空白，没人告诉他
            // 是自己选的组合本身不成立。copilot 的核心机制就是
            // 「用户挑几件、App 补齐」，挑的那一步给死局等于机制在最关键处失灵。
            //
            // 不禁止点击——用户的意图（「我今天就想穿这条裙子」）比规则重要。
            // 取「后选的替换先选的同类」：那正是他真实的意思。
            let replaced = Self.conflicts(with: item, among: availableItems, anchored: anchorIDs)
            anchorIDs.subtract(replaced.map(\.id))
            anchorIDs.insert(item.id)
            anchorNote = replaced.isEmpty
                ? nil
                : "\(item.name) replaced \(replaced.map(\.name).sorted().joined(separator: ", "))"
        }
        AppLog.debug("anchor toggle item=\(AppLog.ref(item.id)) now=\(anchorIDs.count)", .copilot)
        // 换某件/重配 = tweak（只记模式，不记是哪件）
        TelemetryGate.shared.track(.copilotTweaked,
                                   payload: ["mode": fullAuto ? "auto" : "anchored"])
    }

    /// 与新选的这件互斥的已锚定件。
    ///
    /// 判据直接问 `OutfitGrammar`——**不在这里另写一套规则**：
    /// 两处规则迟早会分叉，而分叉的那天用户看到的是「明明合法却被换掉了」。
    static func conflicts(
        with item: Item, among items: [Item], anchored: Set<UUID>
    ) -> [Item] {
        let candidate = item.toCandidateItem()
        return items
            .filter { anchored.contains($0.id) && $0.id != item.id }
            .filter { existing in
                let pair = [existing.toCandidateItem(), candidate]
                // 只看**互斥**类违规：缺件是补全器的活儿，不算冲突
                return OutfitGrammar.violations(pair).contains {
                    switch $0 {
                    case .missingTop, .missingBottom, .missingShoes: return false
                    case .dressWithSeparates, .duplicate, .duplicateSubtype: return true
                    }
                }
            }
            .sorted { ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString) }
    }

    public func clearAnchors() {
        anchorIDs = []
        anchorNote = nil
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
            hasResolvedWeather = true          // D116：只有成功分支才算取到
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

    // MARK: - 今天穿了什么（D116）

    /// 今天已打卡的单品名。空 = 今天还没定。
    ///
    /// 此前打完卡只有一条 3.5 秒的 flash chip，然后 `runRefresh()` 立刻把
    /// **一套你没穿的**衣服摆回 Today——用户当天最后一个动作被当场抹掉，
    /// 中午再打开更是完全看不出自己已经定过了。
    /// 从库里回读，所以它扛得住重启，而不是活在一个计时器里。
    public private(set) var todayWornNames: [String] = []

    /// 是否真的取到过天气。
    ///
    /// `daytimeTempF` 有个 70 的默认值供打分用，但那不是「今天 70 度」——
    /// 没取到就印 70°F，用户会拿这个数决定要不要带外套。
    public private(set) var hasResolvedWeather = false

    /// 温度 pill 文案（纯函数，可断言）。
    public static func tempPillText(resolved: Bool, temp: Double) -> String {
        resolved ? "\(Int(temp.rounded()))°F" : "—°F"
    }

    /// 本次会话的来源（提醒 / 自发）。VM 建立时定一次，整段会话沿用。
    /// （`@Observable` 的宏不接受 `lazy`，所以在 init 里取。）
    public let openSource: String

    /// 回读今天的打卡（本柜、当天）。
    public func reloadToday(in context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<WearRecord>())) ?? []
        let cal = Calendar.current
        let ids = Set(all
            .filter { $0.wardrobeSnapshotID == wardrobe.id && cal.isDateInToday($0.date) }
            .flatMap(\.wornItemIDs))
        guard !ids.isEmpty else { todayWornNames = []; return }
        todayWornNames = (wardrobe.items ?? [])
            .filter { ids.contains($0.id.uuidString) }
            .map(\.name)
            .sorted()
    }

    /// 真的穿了这套（唯一的「采纳」信号，也是 §8.1 判定协议量的那件事）。
    ///
    /// `wearAsIs` 区分「原样穿」与「改过再穿」——copilot 机制成立与否
    /// 靠的正是这个区分，只数「打了卡」量不出来。
    @discardableResult
    func recordWearDetailed(
        _ scored: ScoredOutfit, in context: ModelContext, wearAsIs: Bool = true
    ) -> CopilotWoreIt.Result {
        let result = CopilotWoreIt.perform(
            itemIDs: scored.outfit.itemIDs, wardrobe: wardrobe, context: context)
        guard case .checkedIn = result else {
            AppLog.notice("recordWear not committed \(result)", .copilot)
            return result
        }
        TelemetryGate.shared.track(.copilotAccepted, payload: [
            "mode": fullAuto ? "auto" : "anchored",
            "wear_as_is": String(wearAsIs),
            // D118：这一次是被早上那条提醒带进来的，还是用户自己打开的。
            // 没有这个分母就答不了「加通知到底有没有用」——而那是加它的全部理由。
            "source": openSource,
        ])
        reloadToday(in: context)
        return result
    }

    /// 便利包装（测试与非 Today 入口用）。
    @discardableResult
    public func recordWear(
        _ scored: ScoredOutfit, in context: ModelContext, wearAsIs: Bool = true
    ) -> Bool {
        if case .checkedIn = recordWearDetailed(scored, in: context, wearAsIs: wearAsIs) {
            return true
        }
        return false
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
                    ? CopilotColdStartCopy.emptyClosetPrompt
                    : CopilotColdStartCopy.pickOnePrompt
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
                bodyShapeWeight: bodyShapeWeight,
                colorSeason: PersonalColorSeason.parse(wardrobe.owner?.personalColorSeasonRaw),
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
        CopilotEmptyReason.text(
            available: available, wornCount: wornCount,
            anchorCount: anchors.count, repeatGateRelaxed: repeatGateRelaxed)
    }
}

/// 空态理由（D101）。两条纪律：
/// 1. **不甩锅给已经放宽的门**——D89 之后防重复会在会清空候选时自动降级，
///    此时空结果的原因不在它，却对用户说「都在近 7 天穿过」，还让他去关
///    一个已经没在起作用的开关，是双重误导；
/// 2. **用用户的语言**——「grammar filters」「toggle off in Debug」是开发者词汇，
///    却在 release 里直接显示给真实用户看。每条理由都要带一个能做的下一步。
public enum CopilotEmptyReason {
    public static func text(
        available: Int, wornCount: Int, anchorCount: Int, repeatGateRelaxed: Bool
    ) -> String {
        if available == 0 {
            return "Nothing available in this closet yet — add a few pieces to get picks."
        }
        if available < 3 {
            return "Add a top, a bottom and shoes and you'll get a full look."
        }
        // 只有防重复**真的**在起作用时才归因于它
        if !repeatGateRelaxed, wornCount > 0, wornCount >= available {
            return "You've worn everything here in the past week — wait a day, "
                + "or add something new."
        }
        if anchorCount > 0 {
            return "Nothing in this closet finishes that pick for today's weather "
                + "and occasion — try a different piece."
        }
        return "Nothing here fits today's weather and occasion — "
            + "try another occasion, or add pieces for this one."
    }
}
