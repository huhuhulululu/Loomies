import Testing
import Foundation
import SwiftData
@testable import ClosetUI
import ClosetModel
import ClosetCore

/// D116：**每日循环说真话**——四条互相独立、但都属于「App 对自己或对用户不诚实」。
///
/// 1. 翻一下候选轮播就记一次「copilot 被采纳」——MARKET §8.1 的上线判定
///    （GO/PIVOT/KILL）建立在这个数上，而它量的根本不是「用户照着穿了」。
///    D20 跳过真人验证之后，这个预注册协议是**唯一**的裁决装置，量错等于没有。
/// 2. 天气没取到时仍按**伪造的 70°F** 显示并硬过滤——用户会拿这个数决定要不要带外套。
/// 3. 冷启动时最大的那个按钮说的是开发者的话（"Cold start: anchor at least one piece first."）。
/// 4. 打卡完，Today 立刻换成一套**你没穿的**衣服——用户当天最后一个动作被当场抹掉。
@MainActor
struct DailyLoopHonestyTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    private func seededWardrobe(_ ctx: ModelContext) throws -> Wardrobe {
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        // ≥8 件才越过冷启动阈值（否则 refresh 走「先挑一件」分支，没有候选）
        for (name, slot) in [("Tee", "top"), ("Tee2", "top"), ("Shirt", "top"),
                             ("Jeans", "bottom"), ("Chinos", "bottom"), ("Skirt", "bottom"),
                             ("Sneakers", "shoes"), ("Boots", "shoes"), ("Loafers", "shoes")] {
            let i = Item(name: name)
            i.slotRaw = slot; i.statusRaw = "available"; i.wardrobe = w
            i.occasionsRaw = ["work"]; i.warmthRaw = Warmth.light.rawValue
            ctx.insert(i)
        }
        try ctx.save()
        return w
    }

    // MARK: - 1. 采纳率量的必须是「真穿了」

    /// 翻轮播不算采纳。
    @Test func pagingTheCarouselIsNotAcceptance() throws {
        let ctx = try makeContext()
        let w = try seededWardrobe(ctx)
        let spy = RecordingTelemetrySink()
        TelemetryGate.shared.configure(sink: spy)
        TelemetryGate.shared.setEnabled(true)
        defer { TelemetryGate.shared.configure(sink: nil); TelemetryGate.shared.setEnabled(false) }

        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 70)
        vm.refresh()
        vm.selectSuggestion(at: 1)
        vm.selectSuggestion(at: 2)
        vm.selectSuggestion(at: 0)

        #expect(spy.count(of: TelemetryEvent.copilotAccepted.rawValue) == 0,
                "翻了三次轮播就记了采纳 —— 上线判定的关键指标量的不是「穿了」")
    }

    /// 真穿了才算一次采纳。
    @Test func wearingTheLookIsAcceptance() throws {
        let ctx = try makeContext()
        let w = try seededWardrobe(ctx)
        let spy = RecordingTelemetrySink()
        TelemetryGate.shared.configure(sink: spy)
        TelemetryGate.shared.setEnabled(true)
        defer { TelemetryGate.shared.configure(sink: nil); TelemetryGate.shared.setEnabled(false) }

        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 70)
        vm.refresh()
        let look = try #require(vm.selectedSuggestion)
        _ = vm.recordWear(look, in: ctx)

        #expect(spy.count(of: TelemetryEvent.copilotAccepted.rawValue) == 1)
    }

    /// 打卡事件必须带 `wear_as_is`——「原样穿」与「改过再穿」是两件事，
    /// §8.1 判定 copilot 机制成立与否靠的正是这个区分。
    @Test func checkInReportsWhetherItWasWornAsIs() throws {
        #expect(TelemetryEvent.checkInRecorded.allowedKeys.contains("wear_as_is"))
    }

    // MARK: - 2. 天气没取到就别编

    @Test func aFreshViewModelHasNotResolvedWeather() throws {
        let ctx = try makeContext()
        let w = try seededWardrobe(ctx)
        // D130：不传温度 = 还不知道今天几度（显式传一个值的调用方
        // 就是在断言温度，那种情况该照常按它筛）
        let vm = CopilotViewModel(wardrobe: w, occasion: "work")
        #expect(!vm.hasResolvedWeather, "还没取过天气就说取到了")
        #expect(CopilotViewModel.tempPillText(resolved: false, temp: 70) == "—°F",
                "没取到却印了一个用户会拿来决定穿不穿外套的数字")
    }

    @Test func aFailedFetchDoesNotCountAsResolved() async throws {
        let ctx = try makeContext()
        let w = try seededWardrobe(ctx)
        let vm = CopilotViewModel(wardrobe: w, occasion: "work")
        await vm.applyWeather(AlwaysFailingWeather())
        #expect(!vm.hasResolvedWeather)
    }

    @Test func aSuccessfulFetchResolves() async throws {
        let ctx = try makeContext()
        let w = try seededWardrobe(ctx)
        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 70)
        await vm.applyWeather(FixedWeatherProvider(temperatureF: 58))
        #expect(vm.hasResolvedWeather)
        #expect(CopilotViewModel.tempPillText(resolved: true, temp: 58) == "58°F")
    }

    // MARK: - 3. 冷启动那句话说人话

    @Test func theColdStartLineIsCustomerLanguage() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Empty"); ctx.insert(w)
        let i = Item(name: "Tee"); i.slotRaw = "top"; i.statusRaw = "available"; i.wardrobe = w
        ctx.insert(i); try ctx.save()

        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 70)
        vm.refresh()
        let msg = vm.statusMessage ?? ""
        for jargon in ["cold start", "anchor at least", "full-auto", "candidate"] {
            #expect(!msg.localizedCaseInsensitiveContains(jargon),
                    Comment(rawValue: "冷启动文案里漏了开发者用语：\(msg)"))
        }
        #expect(!msg.isEmpty, "什么都不说也是一种不诚实")
    }

    // MARK: - 4. 打卡之后 Today 记得你穿了什么

    @Test func todayRemembersWhatYouWore() throws {
        let ctx = try makeContext()
        let w = try seededWardrobe(ctx)
        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 70)
        vm.refresh()
        let look = try #require(vm.selectedSuggestion)
        #expect(vm.recordWear(look, in: ctx))
        #expect(!vm.todayWornNames.isEmpty, "打完卡，Today 立刻忘了你穿的是什么")
    }

    /// 跨启动仍记得（活在 3.5 秒的 flash chip 里不算记得）。
    @Test func itSurvivesARestart() throws {
        let ctx = try makeContext()
        let w = try seededWardrobe(ctx)
        let first = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 70)
        first.refresh()
        _ = first.recordWear(try #require(first.selectedSuggestion), in: ctx)

        let second = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 70)
        second.refresh()
        second.reloadToday(in: ctx)
        #expect(!second.todayWornNames.isEmpty, "重开 App 就忘了今天穿的是什么")
    }

    /// 昨天穿的不算今天（否则这条带永远不散）。
    @Test func yesterdaysWearDoesNotCountAsToday() throws {
        let ctx = try makeContext()
        let w = try seededWardrobe(ctx)
        let items = (w.items ?? []).prefix(2).map(\.id)
        let record = WearRecord(date: Date().addingTimeInterval(-86_400 * 2))
        record.wornItemIDs = items.map(\.uuidString)
        record.wardrobeSnapshotID = w.id
        ctx.insert(record)
        try ctx.save()

        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 70)
        vm.refresh()
        vm.reloadToday(in: ctx)
        #expect(vm.todayWornNames.isEmpty, "前天穿的被当成了今天")
    }
}

/// 收集发射事件的测试 sink。
final class RecordingTelemetrySink: TelemetrySink, @unchecked Sendable {
    private let lock = NSLock()
    private var events: [(String, [String: String])] = []

    func send(_ event: TelemetryEvent, payload: [String: String]) {
        lock.lock(); events.append((event.rawValue, payload)); lock.unlock()
    }

    func count(of event: String) -> Int {
        lock.lock(); defer { lock.unlock() }
        return events.filter { $0.0 == event }.count
    }

    func payloads(of event: String) -> [[String: String]] {
        lock.lock(); defer { lock.unlock() }
        return events.filter { $0.0 == event }.map(\.1)
    }
}

struct AlwaysFailingWeather: WeatherProviding {
    struct Boom: Error {}
    func daytimeTemperatureF(forCity city: String?, on date: Date) async throws -> Double {
        throw Boom()
    }
}

/// D118：来源归因。没有它就答不了「加通知到底有没有用」——而那是加它的全部理由。
@MainActor
struct NudgeAttributionTests {

    /// 没点通知进来 = 自发打开。
    @Test func aPlainLaunchIsOrganic() {
        #expect(DailyRitualScheduler.consumeOpenSource() == "organic")
    }

    /// 点通知进来 = nudge，且**只算这一次**（读取即清零）。
    @Test func theNudgeMarkIsConsumedOnce() {
        DailyRitualScheduler.markOpenedFromNudge()
        #expect(DailyRitualScheduler.consumeOpenSource() == "nudge")
        #expect(DailyRitualScheduler.consumeOpenSource() == "organic",
                "标记没被清零 —— 之后每一次打开都会被算成通知带来的")
    }

    /// 采纳事件必须带得上这个键（白名单外的键会被静默丢弃）。
    @Test func theAcceptedEventCarriesSource() {
        #expect(TelemetryEvent.copilotAccepted.allowedKeys.contains("source"))
    }
}

/// D137：可见与可听必须同源。天气取不到时明眼人看到「—°F」，
/// 而视障用户此前听到的是「70 degrees」——同一屏两层互相矛盾，
/// 且后者拿到的正是那个伪造值。
@MainActor
struct WeatherAccessibilityTests {

    @Test func anUnresolvedTemperatureIsNeverSpoken() {
        let phrase = CopilotViewModel.tempAccessibilityPhrase(resolved: false, temp: 70)
        #expect(!phrase.contains(where: { $0.isNumber }),
                Comment(rawValue: "念出了一个虚构的温度：\(phrase)"))
    }

    /// 取到时数字要与 pill 完全一致（四舍五入口径也要同源）。
    @Test func theSpokenNumberMatchesThePill() {
        for temp in [58.4, 69.6, 70.5, 85.0] {
            let pill = CopilotViewModel.tempPillText(resolved: true, temp: temp)
            let spoken = CopilotViewModel.tempAccessibilityPhrase(resolved: true, temp: temp)
            let pillDigits = pill.filter(\.isNumber)
            let spokenDigits = spoken.filter(\.isNumber)
            #expect(pillDigits == spokenDigits,
                    Comment(rawValue: "看到 \(pill)，听到 \(spoken)"))
        }
    }
}
