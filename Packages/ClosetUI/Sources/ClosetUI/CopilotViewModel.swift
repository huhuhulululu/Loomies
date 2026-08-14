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

    /// 回到前台时该不该重算天气与推荐（D188）。
    ///
    /// 判据是**跨了日历日**，不是「过了多久」：
    /// - 跨天必须重算——早安提醒把用户导向 Today，而进程只要没被系统回收，
    ///   温度 pill、`weatherSourceLabel`、降水概率、整页建议全停在昨天，
    ///   `hasResolvedWeather` 仍为 true，于是那个昨天的温度会被当成今天的印出来。
    ///   D136 修的是同一条路上的「今天已定」那一条带，天气与推荐没跟上。
    /// - 同一天内**不重算**：用户切去相册查个东西再回来，
    ///   建议在他眼皮底下换一批是更糟的体验（而温度一天内的漂移不改穿衣决策）。
    ///
    /// 比 `lastRefreshAt` 本身是不行的——同一天的两个时刻也不相等。
    public func needsNewDayRefresh(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let last = lastRefreshAt else { return false }
        return !calendar.isDate(last, inSameDayAs: now)
    }
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
    /// 「Look 3 of 5」这句话的**唯一出处**（D192）。
    /// 越界索引收敛到区间内；没有建议时返回空串——那行字要留给空态理由。
    public static func lookCounter(index: Int, total: Int) -> String {
        guard total > 0 else { return "" }
        let i = min(max(0, index), total - 1)
        return "Look \(i + 1) of \(total)"
    }

    public func selectSuggestion(at index: Int) {
        guard !suggestions.isEmpty else {
            selectedSuggestionIndex = 0
            return
        }
        selectedSuggestionIndex = min(max(0, index), suggestions.count - 1)
        // D192：这行字此前只在刷新落地时写一次（且刚把 index 置 0），
        // 翻页一个都不写它——于是 hero 印「3/3」，它还写着「Look 1 of 3」。
        statusMessage = Self.lookCounter(
            index: selectedSuggestionIndex, total: suggestions.count)
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
    /// D130：`daytimeTempF` 默认 **nil = 还不知道今天几度**。
    /// 生产路径由 `applyWeather` 填上；在那之前不按任何温度筛衣服。
    @MainActor
    public static func forToday(wardrobe: Wardrobe, daytimeTempF: Double? = nil) -> CopilotViewModel {
        CopilotViewModel(
            wardrobe: wardrobe,
            occasion: OccasionMix.effectiveOccasion(stated: wardrobe.owner?.primaryOccasionRaw),
            daytimeTempF: daytimeTempF)
    }

    /// `daytimeTempF: nil` = **今天几度未知**（天气还没取到）。
    ///
    /// D130：显式传一个温度的调用方**就是在断言温度**（测试、预览），
    /// 那时照常按它筛；生产走 `forToday` 不传，等 `applyWeather` 填。
    /// 二者的区别不能靠事后推断——推断出来的「未知」会把断言过温度的
    /// 调用方也一起当成未知。
    public init(
        wardrobe: Wardrobe, occasion: String = "work", daytimeTempF: Double? = nil
    ) {
        self.wardrobe = wardrobe
        self.occasion = occasion
        // 打分与 pill 需要一个具体值兜底；「知不知道」由 hasResolvedWeather 表达
        self.daytimeTempF = daytimeTempF ?? 70
        self.hasResolvedWeather = daytimeTempF != nil
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
            .sortedByName()
    }

    /// 衣柜里一共有多少件（含在洗/外借）。
    ///
    /// D138：激活阶梯问的是「数字化到什么程度了」，那是总数——
    /// 用可用件数的话，送洗 6 件就把 25 件的柜推回「再加几件」，
    /// 而用户什么都没少。`isColdStart` 问的是另一个问题（今天拼不拼得出），
    /// 那才该看可用件。
    public var totalItemCount: Int { (wardrobe.items ?? []).count }

    public var isColdStart: Bool {
        DebugSettings.shared.forceColdStart || availableItems.count < coldStartThreshold
    }

    public func isAnchored(_ item: Item) -> Bool { anchorIDs.contains(item.id) }

    /// D126：刚发生的锚定替换（「Chinos replaced Jeans」）。nil = 上一次没有替换。
    /// 静默替换会让用户以为自己点漏了。
    public private(set) var anchorNote: String?

    /// D131：锚定件与今天**不搭**时的如实提示（不是过滤）。
    ///
    /// 锚定的那件直接进结果、不过场合/温区门——这本身是对的：
    /// 用户说「我今天就要穿这件」，产品不该反过来教育他（同 D126 的判断）。
    /// 错的是**不吭声**：85°F 锚了件厚大衣，App 照常端出带大衣的搭配，
    /// 一句「今天这个温度它偏厚」都没有——用户要么以为 App 觉得合适，
    /// 要么以为温区过滤坏了。
    public private(set) var anchorAdvisory: String?

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

    /// 锚定件与今天不搭时说的那句话。都合适 → nil（不造噪声）。
    ///
    /// 三值语义照旧：**未标温区/场合的件不算「不合适」**，温度未知时
    /// 不对冷暖表态（D130 的纪律）。
    static func advisory(
        for anchors: [Item], occasion: String, daytimeTempF: Double?, coldBias: Int
    ) -> String? {
        let band = daytimeTempF.map {
            WeatherFit.acceptableWarmth(daytimeTempF: $0, coldBias: coldBias)
        }
        let wanted = occasion.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var offBand: [String] = []
        var offOccasion: [String] = []
        for item in anchors.sortedByName() {
            let candidate = item.toCandidateItem()
            if let band, let w = candidate.warmth, !band.contains(w) {
                offBand.append(item.name)
            }
            if !wanted.isEmpty, !candidate.occasions.isEmpty {
                let normalized = candidate.occasions.map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                }
                if !normalized.contains(wanted) { offOccasion.append(item.name) }
            }
        }
        var parts: [String] = []
        if !offBand.isEmpty {
            parts.append("\(ActivationProgress.listJoin(offBand)) sits outside today's range")
        }
        if !offOccasion.isEmpty {
            parts.append("\(ActivationProgress.listJoin(offOccasion)) isn't tagged \(wanted)")
        }
        guard !parts.isEmpty else { return nil }
        // 「仍然照你说的用」——这句不能省：否则读起来像在劝退
        return parts.joined(separator: " · ") + " — keeping it in anyway."
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
            .sortedByName()
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
        // D204：阈值与措辞在 `OuterwearCue`（规则层）——这里只留**这一层该管的事**：
        // 数据可不可信。此前这两条阈值在这里内联了一份，而规则层那份零调用点。
        return WeatherDaySnapshot(
            daytimeTempF: daytimeTempF,
            sourceLabel: weatherSourceLabel,
            precipProbabilityPercent: precipProbabilityPercent
        ).outerwearCue?.text
    }

    // MARK: - 今天穿了什么（D116）

    /// 今天已打卡的单品名。空 = 今天还没定。
    ///
    /// 此前打完卡只有一条 3.5 秒的 flash chip，然后 `runRefresh()` 立刻把
    /// **一套你没穿的**衣服摆回 Today——用户当天最后一个动作被当场抹掉，
    /// 中午再打开更是完全看不出自己已经定过了。
    /// 从库里回读，所以它扛得住重启，而不是活在一个计时器里。
    public private(set) var todayWornNames: [String] = []

    /// 今天打卡的是**哪几件**（不是名字）。
    ///
    /// D210：widget 要画每件的颜色，而颜色只能跟着 item 本体走——
    /// 按名字回查在衣橱里有两件「白 T」时就会串色。
    private var todayWornItemIDs: Set<String> = []

    /// item → widget 上那一件。颜色走 `ItemDetailViewModel.paletteID` 那一份口径，
    /// **不另抄一遍**（本 session 数次栽在「同一条规则的第 N 份手抄」上）。
    static func widgetPiece(_ item: Item) -> TodayWidgetSnapshot.Piece {
        .init(name: item.name,
              colorPaletteID: ItemDetailViewModel.paletteID(
                hue: item.colorHue, isNeutral: item.colorIsNeutral))
    }

    /// 是否真的取到过天气。
    ///
    /// `daytimeTempF` 有个 70 的默认值供打分用，但那不是「今天 70 度」——
    /// 没取到就印 70°F，用户会拿这个数决定要不要带外套。
    public private(set) var hasResolvedWeather: Bool

    /// 温度 pill 文案（纯函数，可断言）。
    public static func tempPillText(resolved: Bool, temp: Double) -> String {
        resolved ? "\(Int(temp.rounded()))°F" : "—°F"
    }

    /// 温度的 VoiceOver 读法（D137）。
    ///
    /// 此前无障碍标签直接读 `daytimeTempF`，绕过了 D116 的诚实闸：
    /// 天气取不到时，明眼人看到「—°F」，视障用户听到「70 degrees」——
    /// **同一屏两层互相矛盾**，而后者拿到的还是那个伪造值。
    /// 可见与可听必须同源（DESIGN §10.4 无障碍硬约束）。
    public static func tempAccessibilityPhrase(resolved: Bool, temp: Double) -> String {
        resolved ? "\(Int(temp.rounded())) degrees Fahrenheit" : "Temperature unavailable"
    }

    /// 本次会话的来源（提醒 / 自发）。VM 建立时定一次，整段会话沿用。
    /// （`@Observable` 的宏不接受 `lazy`，所以在 init 里取。）
    /// D134：来源在**发事件那一刻**取，不在 VM 建立时取。
    ///
    /// 此前是 `init` 里 `consumeOpenSource()`——而点通知进来时 App 多半
    /// 已经在内存里（暖启动，VM 早就建好了），标记永远等不到人读；
    /// 反过来，冷启动时任何一个临时 VM 都可能把它先消费掉。
    /// 加通知的全部理由就是量「它到底有没有用」，量不到等于没加。
    public var openSource: String { DailyRitualScheduler.peekOpenSource() }

    /// 回读今天的打卡（本柜、当天）。
    /// 用户反复说过「紧」的件（D200）。跟着 `reloadToday` 那一次取表算出来，
    /// 不另取一遍（D156 的纪律）。
    public private(set) var reportedTightItemIDs: Set<String> = []

    public func reloadToday(in context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<WearRecord>())) ?? []
        reportedTightItemIDs = Set(
            FitMarkService.reportedFits(from: all)
                .filter { $0.value.verdict == .tight }
                .keys)
        let cal = Calendar.current
        let ids = Set(all
            .filter { $0.wardrobeSnapshotID == wardrobe.id && cal.isDateInToday($0.date) }
            .flatMap(\.wornItemIDs))
        guard !ids.isEmpty else {
            todayWornNames = []
            todayWornItemIDs = []
            publishWidgetSnapshot()
            return
        }
        let worn = (wardrobe.items ?? []).filter { ids.contains($0.id.uuidString) }
        todayWornNames = worn.map(\.name).sorted()
        todayWornItemIDs = Set(worn.map { $0.id.uuidString })
        publishWidgetSnapshot()
    }

    /// 把「今天穿什么」写进 App Group，主屏 Widget 读它（D197）。
    ///
    /// 已经打过卡就写**已定**那身；否则写当前选中的建议。
    /// 都没有就写一份空的——**空快照也要写**，否则 widget 会一直显示昨天那份，
    /// 而那正是 D188 修过的病在新表面上的复发（更隐蔽：用户不点开就看不出来）。
    public func publishWidgetSnapshot(
        directory: URL? = TodayWidgetSnapshotStore.sharedDirectory()
    ) {
        let settled = !todayWornItemIDs.isEmpty
        let ids = settled
            ? todayWornItemIDs.sorted()
            : (selectedSuggestion?.outfit.itemIDs ?? [])
        let byID = Dictionary(
            (wardrobe.items ?? []).map { ($0.id.uuidString, $0) },
            uniquingKeysWith: { a, _ in a })   // D147：重复 id 不许直接终止进程
        var pieces = ids.compactMap { byID[$0].map(Self.widgetPiece) }
        // 已定那身按名字排（与 `todayWornNames` 同序），建议那身保持槽位顺序
        if settled { pieces.sort { $0.name < $1.name } }
        let snapshot = TodayWidgetSnapshot(
            dayKey: CalendarPlanService.dayKey(for: Date()),
            lookTitle: settled ? nil : selectedSuggestion.map { _ in occasion.capitalized },
            pieces: pieces,
            // 温度未知就不写——widget 那边同样是三值语义（不填默认值）
            daytimeTempF: hasResolvedWeather ? Int(daytimeTempF.rounded()) : nil,
            weatherSourceLabel: hasResolvedWeather ? weatherSourceLabel : nil,
            isSettled: settled)
        TodayWidgetSnapshotStore.write(snapshot, to: directory)
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
            // 读完即清：一次打开只归因一次
            "source": DailyRitualScheduler.consumeOpenSource(),
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

    /// 一次刷新的**纯值快照**（D152）。
    ///
    /// 主线程只做这一步：把 SwiftData 的 `Wardrobe` 摊成 `[CandidateItem]`
    /// 与两个上下文——全是 `Sendable`，之后的计算与 SwiftData 再无关系。
    /// 带**代际号**：慢的那次回来时若已被新的一次取代，结果必须丢弃
    ///（D125 搜索、D116 天气各栽过一次，不能再栽第三次）。
    public struct RefreshRequest: Sendable {
        let generation: Int
        let anchorCandidates: [CandidateItem]
        let pool: [CandidateItem]
        let filter: FilterContext
        let scoring: ScoringContext
        let maxSuggestions: Int
        /// 落地时算空态文案要用（主线程侧的 `anchors` 不能穿过并发边界）。
        let anchorIDs: [UUID]
        let wornHereCount: Int
    }

    /// 在途代际号。
    private var refreshGeneration = 0

    /// 快照 + 领代号。返回 nil = **不需要算**（冷启动早退分支已就地给出空态）。
    ///
    /// 那条路一个组合都不用枚举，扔进后台只会让空态晚一帧出现。
    public func makeRefreshRequest() -> RefreshRequest? {
        refreshGeneration &+= 1
        let generation = refreshGeneration
        let dbg = DebugSettings.shared
        let forceAnchor = isColdStart || !fullAuto
        let anchors: [Item]
        if forceAnchor {
            anchors = (wardrobe.items ?? [])
                .filter { anchorIDs.contains($0.id) && $0.statusRaw == "available" }
            anchorAdvisory = Self.advisory(
                for: anchors, occasion: occasion,
                daytimeTempF: hasResolvedWeather ? daytimeTempF : nil,
                coldBias: wardrobe.owner?.coldBias ?? 0)
            if isColdStart && anchors.isEmpty {
                suggestions = []
                selectedSuggestionIndex = 0
                statusMessage = availableItems.isEmpty
                    ? CopilotColdStartCopy.emptyClosetPrompt
                    : CopilotColdStartCopy.pickOnePrompt
                lastRefreshMS = 0
                lastRefreshAt = Date()
                isRefreshing = false
                AppLog.notice("refresh empty: \(statusMessage)", .copilot)
                return nil
            }
        } else {
            // D188：全自动模式下锚定件根本不参与枚举——那就别让 chip 与
            // 「— keeping it in anyway.」继续留在屏上说反话。
            //
            // 可达路径不止手动切 toggle：冷启动下锚定一件 → 点「Load samples」
            // 会把 fullAuto 置 true 并刷新，播完 9 件后 isColdStart 转 false，
            // 锚定就被静默丢弃，而那句 advisory 还在。D131 加它的理由正是
            // 「不吭声会让用户以为过滤坏了」，这条路把它变成主动说反话。
            //
            // 清掉而不是「照样用」：用户按下「Just decide for me」本身就是一次
            // 掌舵动作，把它的效果如实呈现（chip 消失）比偷偷保留更诚实。
            anchors = []
            if !anchorIDs.isEmpty {
                anchorIDs = []
                anchorNote = nil
                AppLog.notice("anchors dropped: full auto", .copilot)
            }
            anchorAdvisory = nil
        }
        isRefreshing = true
        let worn: Set<String> = dbg.disableAntiRepeat ? [] : wornWithin7DaysIDs
        // 跨柜的穿着记录不得触发本柜的「都穿过了」（与旧实现同口径）
        let availableIDs = Set(availableItems.map { $0.id.uuidString })

        // 与 `RecommendationService.detailed` **同一套映射**：锚定强制同柜、
        // 候选只从本柜取并排除锚定项。抄一份会让两条路迟早给出不同的推荐。
        let validAnchors = anchors.filter { $0.wardrobe?.id == wardrobe.id }
        let anchorIDSet = Set(validAnchors.map(\.id))
        return RefreshRequest(
            generation: generation,
            anchorCandidates: validAnchors.map { $0.toCandidateItem() },
            pool: (wardrobe.items ?? [])
                .filter { !anchorIDSet.contains($0.id) }
                .map { $0.toCandidateItem() },
            filter: FilterContext(
                occasion: occasion,
                // D130：天气没取到就别按伪造的温度筛衣服
                daytimeTempF: hasResolvedWeather ? daytimeTempF : nil,
                wornWithin7DaysIDs: worn,
                coldBias: wardrobe.owner?.coldBias ?? 0),
            scoring: ScoringContext(
                bodyShape: bodyShape,
                bodyShapeWeight: bodyShapeWeight,
                colorSeason: PersonalColorSeason.parse(wardrobe.owner?.personalColorSeasonRaw),
                daytimeTempF: hasResolvedWeather ? daytimeTempF : nil,
                // D200：你穿过之后反复说过「紧」的件往后排（降权，不排除）。
                reportedTightItemIDs: reportedTightItemIDs),
            maxSuggestions: 3,
            anchorIDs: validAnchors.map(\.id),
            wornHereCount: worn.intersection(availableIDs).count)
    }

    /// **纯计算**——`nonisolated`，可以在任何线程上跑（输入输出全是 Sendable）。
    public nonisolated static func computeRefresh(
        _ request: RefreshRequest
    ) -> OutfitCompleter.Result {
        OutfitCompleter.completeDetailed(
            anchors: request.anchorCandidates,
            pool: request.pool,
            context: request.filter,
            scoring: request.scoring,
            maxSuggestions: request.maxSuggestions)
    }

    /// 落地。**代际对不上就丢**——慢的那次回来时状态可能已经变了
    ///（切了柜、换了场合、改了锚定），把旧结果盖上去等于给用户看一个
    /// 他刚刚离开的世界。
    public func applyRefresh(_ result: OutfitCompleter.Result, for request: RefreshRequest) {
        guard request.generation == refreshGeneration else {
            AppLog.debug("refresh dropped stale gen=\(request.generation)", .copilot)
            return
        }
        isRefreshing = false
        suggestions = result.suggestions
        // 防重复被降级（本柜今天能穿的都在近 7 天穿过）→ 必须说出来，
        // 否则建议与「de-prioritized 7 days」的打卡回执自相矛盾
        repeatGateRelaxed = result.repeatGateRelaxed
        lastRefreshAt = Date()
        selectedSuggestionIndex = 0
        if suggestions.isEmpty {
            let anchorItems = (wardrobe.items ?? []).filter { request.anchorIDs.contains($0.id) }
            statusMessage = emptyReason(
                anchors: anchorItems, wornCount: request.wornHereCount)
        } else {
            statusMessage = Self.lookCounter(
                index: selectedSuggestionIndex, total: suggestions.count)
        }
        // D197：建议换了，主屏那块也要跟着换（否则 widget 停在上一批）。
        publishWidgetSnapshot()
        TelemetryGate.shared.track(.copilotRefresh, payload: [
            "mode": fullAuto ? "auto" : "anchored",
            "occasion": occasion,
            "suggestion_count": String(suggestions.count),
        ])
        AppLog.info(
            "refresh occasion=\(occasion) anchors=\(request.anchorCandidates.count) out=\(suggestions.count) \(String(format: "%.1fms", lastRefreshMS))",
            .copilot)
    }

    /// 同步刷新（测试与不介意阻塞的调用方）。**与异步路径共用同一组三段**——
    /// 各写一份的那天，两条路会给出不同的推荐。
    public func refresh() {
        guard let request = makeRefreshRequest() else { return }
        let t0 = CFAbsoluteTimeGetCurrent()
        let result = Self.computeRefresh(request)
        lastRefreshMS = (CFAbsoluteTimeGetCurrent() - t0) * 1000
        applyRefresh(result, for: request)
    }

    /// 在途的那次后台计算。新的一次开始时取消它（D159）。
    private var computeTask: Task<OutfitCompleter.Result, Never>?

    /// 后台刷新（Today 走这条）。计算不快，但界面不冻。
    ///
    /// D159：**开新的一次就取消旧的。** D152 把计算挪到后台之后界面不再冻，
    /// 代价是用户点得动第二下了——而九个触发点（换场合/切筛选/切柜/回前台…）
    /// 都不挡并发。代际检查保证只有新的落地，但旧的那次此前会一路烧到底。
    /// `OutfitCompleter` 在枚举过程中读 `Task.isCancelled`，收到就收手。
    public func refreshOffMain() async {
        guard let request = makeRefreshRequest() else { return }
        computeTask?.cancel()
        let t0 = CFAbsoluteTimeGetCurrent()
        let task = Task.detached(priority: .userInitiated) {
            Self.computeRefresh(request)
        }
        computeTask = task
        let result = await task.value
        lastRefreshMS = (CFAbsoluteTimeGetCurrent() - t0) * 1000
        // 自己被取消了就不落地——代际检查是第二道，这是第一道
        guard !task.isCancelled else { return }
        applyRefresh(result, for: request)
    }

    private func emptyReason(anchors: [Item], wornCount: Int) -> String {
        CopilotEmptyReason.text(
            // D128：把候选传进去，空态才说得出**缺的是哪个槽位**——
            // 缺鞋时让用户「换个场合试试」是一条走不通的路。
            // D142：件数由它自己数，不再另传一个可能对不上的数。
            candidates: availableItems.map { $0.toCandidateItem() },
            wornCount: wornCount,
            anchorCount: anchors.count)
    }
}

/// 空态理由（D101）。两条纪律：
/// 1. **不甩锅给已经放宽的门**——D89 之后防重复会在会清空候选时自动降级，
///    此时空结果的原因不在它，却对用户说「都在近 7 天穿过」，还让他去关
///    一个已经没在起作用的开关，是双重误导；
/// 2. **用用户的语言**——「grammar filters」「toggle off in Debug」是开发者词汇，
///    却在 release 里直接显示给真实用户看。每条理由都要带一个能做的下一步。
public enum CopilotEmptyReason {
    /// D128：`candidates` 让空态能**点名缺的是哪个槽位**。
    ///
    /// 一个有 12 件上装、8 条下装、一双鞋都没有的衣柜今天拼不出任何一套——
    /// 而用户此前看到的是「换个场合试试」。换场合当然没用：缺的是鞋。
    /// 他会一个一个场合试过去，然后以为 App 坏了。
    /// `OutfitGrammar` 早把这些算出来了，空态只要问一句。
    /// D142：件数**从候选推出**，不再单独传。
    ///
    /// 两者本来就来自同一个集合（`availableItems`），分开传就造出一个
    /// **表达得出、却永远不会发生**的状态：`candidates.isEmpty && available > 0`。
    /// 而旧代码正有一条分支挂在它上面（`candidates.isEmpty, available < 3`）——
    /// 生产路径永远走不到，测试却靠传入矛盾入参把它测绿了：**假信心**。
    /// 那句话本身也已被 `missingSlotSentence` 说得更好（点名缺哪个槽位）。
    /// D188：**删掉了「你这周把这里穿遍了」那条归因，连同它的 `repeatGateRelaxed` 入参。**
    ///
    /// `OutfitCompleter` 保证：拼不出任何一套时，防重复的放宽重试**已经试过并失败**，
    /// 于是它把 `repeatGateRelaxed` 重置为 false（`EmptyResultNeverBlamesRepeatTests`
    /// 把这条不变式钉在引擎上）。而本函数只在 `suggestions.isEmpty` 时被调用——
    /// 也就是说那条分支的前置在空态里**恒真**，而它给的下一步（「等一天」）**恒无用**。
    ///
    /// 只要它出现就一定是错的，所以不是收紧条件，是整条拿掉。
    /// 入参一并删除：留着一个没人读的开关，下一个人会以为它还管着什么。
    public static func text(
        candidates: [CandidateItem], wornCount: Int, anchorCount: Int
    ) -> String {
        let available = candidates.count
        if available == 0 {
            return "Nothing available in this closet yet — add a few pieces to get picks."
        }
        // D128：**缺件优先**——它是最可行动的一条，而且旧的 `available < 3`
        // 捷径在这里会说错话：对一个「有裙有鞋」的用户说
        // 「去加上装和下装」，那两件他根本不需要。
        if let missing = missingSlotSentence(candidates) { return missing }
        if anchorCount > 0 {
            return "Nothing in this closet finishes that pick for today's weather "
                + "and occasion — try a different piece."
        }
        return "Nothing here fits today's weather and occasion — "
            + "try another occasion, or add pieces for this one."
    }

    /// 缺件的那句话。槽位齐全 → nil（那时原因确实是天气/场合，
    /// 说槽位就成了新的甩锅）。
    static func missingSlotSentence(_ candidates: [CandidateItem]) -> String? {
        guard !candidates.isEmpty else { return nil }
        // 判据直接问 `OutfitGrammar`——不在这里另写一套「什么算齐全」，
        // 两处规则分叉的那天，用户会被要求去补一件他并不需要的衣服。
        let violations = OutfitGrammar.violations(candidates)
        var missing: [String] = []
        if violations.contains(.missingTop) { missing.append("a top") }
        if violations.contains(.missingBottom) { missing.append("a bottom") }
        if violations.contains(.missingShoes) { missing.append("shoes") }
        guard !missing.isEmpty else { return nil }
        let list = ActivationProgress.listJoin(missing)
        // D142：写成祈使句。此前是「it needs …」——只报告状态不给下一步，
        // 而那句「Add a top, a bottom and shoes」原本挂在一条**永远走不到**的
        // 分支上：件数少的用户真正看到的一直是没有动作的那句。
        return "This closet can't finish a look yet — add \(list)."
    }
}
