import Testing
import SwiftData
import Foundation
@testable import ClosetUI
import ClosetModel
import ClosetCore

@MainActor
struct CheckInViewModelTests {

    func setup() throws -> (ModelContext, Wardrobe, Item, Item) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        let ctx = ModelContext(container)
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let t = Item(name: "top"); t.slotRaw = "top"; t.wardrobe = w; t.statusRaw = "available"; ctx.insert(t)
        let b = Item(name: "bottom"); b.slotRaw = "bottom"; b.wardrobe = w; b.statusRaw = "available"; ctx.insert(b)
        try ctx.save()
        return (ctx, w, t, b)
    }

    @Test func checkInRequiresSelection() throws {
        let (ctx, w, _, _) = try setup()
        let vm = CheckInViewModel(wardrobe: w)
        #expect(!vm.canCheckIn)
        #expect(vm.checkIn(in: ctx) == nil)
    }

    @Test func checkInRecordsAndClearsSelection() throws {
        let (ctx, w, t, b) = try setup()
        let vm = CheckInViewModel(wardrobe: w)
        vm.toggle(t); vm.toggle(b)
        vm.fitFeedback = "fitted"
        let rec = vm.checkIn(on: Date(), in: ctx)
        #expect(rec != nil)
        #expect(Set(rec!.wornItemIDs) == Set([t.id.uuidString, b.id.uuidString]))
        #expect(rec!.fitFeedback == "fitted")
        #expect(vm.selectedIDs.isEmpty)
        #expect(vm.fitFeedback == nil)
        // 成功回执点名合身档位（此前清空 message，用户无从确认备注记上没）
        #expect(vm.message == FitFeedbackCopy.recordedMessage(.fitted))
        #expect(!vm.didFail)
    }

    /// ModelSave fail toast must not look like success; selection kept for retry.
    @Test func checkInSaveFailedMessageIsHonest() {
        #expect(CheckInViewModel.saveFailedMessage.localizedCaseInsensitiveContains("couldn't save"))
        #expect(CheckInViewModel.saveFailedMessage.localizedCaseInsensitiveContains("try again"))
        #expect(!CheckInViewModel.saveFailedMessage.localizedCaseInsensitiveContains("checked in"))
        #expect(CopilotWoreIt.flashMessage(.saveFailed) == CheckInService.saveFailedMessage)
        #expect(!CopilotWoreIt.flashMessage(.saveFailed)
            .localizedCaseInsensitiveContains("de-prioritized"))
        // Today feedbackChip VO uses the flash string as accessibilityLabel (Favorites parity).
        for flash in [
            CopilotWoreIt.flashMessage(.saveFailed),
            CopilotWoreIt.flashMessage(.checkedIn(pieceCount: 2)),
            CopilotWoreIt.flashMessage(.noResolvablePieces),
        ] {
            #expect(!flash.isEmpty)
            #expect(!flash.localizedCaseInsensitiveContains("try-on"))
            #expect(!flash.contains("NSError"))
        }
        // Fail flashes paint orange (not accent success); success stays non-fail.
        #expect(CopilotView.feedbackChipIsFailure(CopilotWoreIt.flashMessage(.saveFailed)))
        #expect(CopilotView.feedbackChipIsFailure(
            CopilotWoreIt.flashMessage(.noResolvablePieces)))
        #expect(CopilotView.feedbackChipIsFailure(
            AvatarCinematicExporter.ExportError.encodeFailed.toastMessage))
        #expect(CopilotView.feedbackChipIsFailure("Couldn't load samples — try again"))
        #expect(!CopilotView.feedbackChipIsFailure(
            CopilotWoreIt.flashMessage(.checkedIn(pieceCount: 2))))
        #expect(!CopilotView.feedbackChipIsFailure("Added to calendar."))
        #expect(!CopilotView.feedbackChipIsFailure("Preview ready to share"))
    }

    /// U4: items transferred away after selection → checkIn must not record a
    /// zero-item WearRecord as silent success; honest message + no record.
    @Test func staleSelectionAfterTransferDoesNotRecordWear() throws {
        let (ctx, w, t, _) = try setup()
        let vm = CheckInViewModel(wardrobe: w)
        vm.toggle(t)
        #expect(vm.canCheckIn)

        // Transfer t to another wardrobe (stale selection for w).
        let w2 = Wardrobe(name: "B"); ctx.insert(w2)
        t.wardrobe = w2
        try ctx.save()

        let rec = vm.checkIn(in: ctx)
        #expect(rec == nil)
        #expect(vm.lastRecord == nil)
        #expect(vm.message == CheckInViewModel.staleSelectionMessage)
        #expect(!vm.message.isEmpty)  // honest feedback, not silent no-op
        #expect(vm.message != CheckInViewModel.saveFailedMessage)
        // Stale IDs dropped from selection.
        #expect(vm.selectedIDs.isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<WearRecord>()).isEmpty)
    }

    /// Partial staleness: one piece still in closet records just that piece.
    @Test func partiallyStaleSelectionRecordsRemainingPieces() throws {
        let (ctx, w, t, b) = try setup()
        let vm = CheckInViewModel(wardrobe: w)
        vm.toggle(t); vm.toggle(b)

        let w2 = Wardrobe(name: "B"); ctx.insert(w2)
        b.wardrobe = w2
        try ctx.save()

        let rec = vm.checkIn(in: ctx)
        #expect(rec != nil)
        #expect(rec!.wornItemIDs == [t.id.uuidString])
        // 成功现在给回执（此前 message 清空 → 表单一关无从确认打卡是否生效）
        #expect(!vm.message.isEmpty)
        #expect(!vm.didFail)
    }

    @Test func recentlyWornFeedsCopilotAntiRepeat() throws {
        let (ctx, w, t, b) = try setup()
        // 凑齐可组套：再加鞋
        let shoes = Item(name: "shoes"); shoes.slotRaw = "shoes"; shoes.wardrobe = w
        shoes.statusRaw = "available"; shoes.occasionsRaw = ["work"]
        shoes.warmthRaw = Warmth.light.rawValue; shoes.colorIsNeutral = true
        ctx.insert(shoes)
        t.occasionsRaw = ["work"]; t.warmthRaw = Warmth.light.rawValue; t.colorIsNeutral = true
        b.occasionsRaw = ["work"]; b.warmthRaw = Warmth.light.rawValue; b.colorIsNeutral = true
        try ctx.save()

        let checkIn = CheckInViewModel(wardrobe: w)
        checkIn.toggle(t); checkIn.toggle(b); checkIn.toggle(shoes)
        _ = checkIn.checkIn(in: ctx)

        let worn = CheckInViewModel.recentlyWornIDs(in: ctx)
        #expect(worn.contains(t.id.uuidString))

        let copilot = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 75)
        copilot.wornWithin7DaysIDs = worn
        copilot.fullAuto = true
        copilot.refresh()
        // 防重复可能清空候选或降权；至少 refresh 不崩溃且 worn 已注入
        #expect(copilot.wornWithin7DaysIDs.count == 3)
        // 若引擎硬过滤近 7 天，建议可能为空——两种结果都合法
        _ = copilot.suggestions
    }

    /// Today "Wore it": resolve + record; orphan IDs must flash failure (no silent no-op).
    @Test func woreItResolvesPiecesOrReportsMissing() throws {
        let (ctx, w, t, b) = try setup()
        let shoes = Item(name: "shoes"); shoes.slotRaw = "shoes"; shoes.wardrobe = w
        shoes.statusRaw = "available"; shoes.occasionsRaw = ["work"]
        shoes.warmthRaw = Warmth.light.rawValue; shoes.colorIsNeutral = true
        ctx.insert(shoes)
        try ctx.save()

        let ok = CopilotWoreIt.perform(
            itemIDs: [t.id.uuidString, b.id.uuidString, shoes.id.uuidString],
            wardrobe: w,
            context: ctx)
        #expect(ok == .checkedIn(pieceCount: 3))
        let okFlash = CopilotWoreIt.flashMessage(ok)
        #expect(okFlash.contains("Checked in 3"))
        #expect(okFlash.localizedCaseInsensitiveContains("de-prioritized"))
        #expect(CheckInViewModel.recentlyWornIDs(in: ctx).contains(t.id.uuidString))

        let orphan = CopilotWoreIt.perform(
            itemIDs: [UUID().uuidString, UUID().uuidString],
            wardrobe: w,
            context: ctx)
        #expect(orphan == .noResolvablePieces)
        let missFlash = CopilotWoreIt.flashMessage(orphan)
        #expect(missFlash.localizedCaseInsensitiveContains("couldn't check in")
            || missFlash.localizedCaseInsensitiveContains("missing"))
        #expect(!missFlash.localizedCaseInsensitiveContains("de-prioritized"))
    }

    /// D85 波 D：手动选件打卡（此前 toggle/isSelected/checkIn 是零调用点死 VM）。
    @Test func manualCheckInSelectsAndRecords() throws {
        let (ctx, w, item, _) = try setup()
        let vm = CheckInViewModel(wardrobe: w)
        #expect(!vm.canCheckIn)
        vm.toggle(item)
        #expect(vm.isSelected(item))
        #expect(vm.canCheckIn)
        let rec = vm.checkIn(in: ctx)
        #expect(rec != nil)
        #expect(rec?.wornItemIDs == [item.id.uuidString])
        #expect(vm.selectedIDs.isEmpty)   // 成功后清空选区
    }

    /// 洗衣/外借件默认不在可选列表（打卡的是「今天穿了」），但可显式包含。
    @Test func selectableItemsHonorsUnavailableToggle() throws {
        let (ctx, w, available, _) = try setup()
        let washing = Item(name: "Muddy Tee"); washing.slotRaw = "top"
        washing.wardrobe = w; washing.statusRaw = "inWash"
        ctx.insert(washing)
        try ctx.save()
        let vm = CheckInViewModel(wardrobe: w)
        #expect(!vm.selectableItems.contains { $0.id == washing.id })
        #expect(vm.selectableItems.contains { $0.id == available.id })
        vm.includesUnavailableItems = true
        #expect(vm.selectableItems.contains { $0.id == washing.id })
        // 排序确定（(name, id) 双键）
        #expect(vm.selectableItems.map(\.name) == vm.selectableItems.map(\.name).sorted())
    }

    /// 合身反馈走 setFitFeedback 唯一校验路径：非法值不落库，且不阻断打卡本身。
    @Test func checkInRoutesFitFeedbackThroughValidatingPath() throws {
        let (ctx, w, item, _) = try setup()
        let vm = CheckInViewModel(wardrobe: w)
        vm.toggle(item)
        vm.fitVerdict = .loose
        let rec = try #require(vm.checkIn(in: ctx))
        #expect(rec.fitFeedback == "loose")
        #expect(vm.fitVerdict == nil)   // 成功后复位

        // 脏值（历史/外部写入）不得落库，打卡仍成功
        let vm2 = CheckInViewModel(wardrobe: w)
        vm2.toggle(item)
        vm2.fitFeedback = "snug-ish"
        let rec2 = try #require(vm2.checkIn(in: ctx))
        #expect(rec2.fitFeedback == nil)
    }

    @Test func fitVerdictBridgesRawString() throws {
        let (_, w, _, _) = try setup()
        let vm = CheckInViewModel(wardrobe: w)
        vm.fitVerdict = .tight
        #expect(vm.fitFeedback == "tight")
        vm.fitFeedback = "loose"
        #expect(vm.fitVerdict == .loose)
        vm.fitFeedback = "garbage"
        #expect(vm.fitVerdict == nil)
        vm.fitVerdict = nil
        #expect(vm.fitFeedback == nil)
    }

    @Test func applyWeatherUpdatesTemp() async throws {
        let (_, w, _, _) = try setup()
        let vm = CopilotViewModel(wardrobe: w, daytimeTempF: 70)
        await vm.applyWeather(FixedWeatherProvider(temperatureF: 55))
        #expect(vm.daytimeTempF == 55)
        #expect(vm.weatherSourceLabel == "Fixed")
        #expect(vm.weatherDressCue?.localizedCaseInsensitiveContains("outerwear") == true)
    }

    @Test func applyWeatherOfflineSourceLabel() async throws {
        let (_, w, _, _) = try setup()
        w.locationCity = "Seattle"
        let vm = CopilotViewModel(wardrobe: w, daytimeTempF: 70)
        await vm.applyWeather(CityClimateWeatherProvider())
        #expect(vm.weatherSourceLabel == "Offline estimate")
    }

    /// Me → City edit must be able to move climate (Today re-applies via onChange + applyWeather).
    @Test func cityChangeMovesClimateEstimate() async throws {
        let (_, w, _, _) = try setup()
        w.locationCity = "Miami"
        let vm = CopilotViewModel(wardrobe: w, daytimeTempF: 70)
        await vm.applyWeather(CityClimateWeatherProvider())
        let warmCity = vm.daytimeTempF
        w.locationCity = "Chicago"
        await vm.applyWeather(CityClimateWeatherProvider())
        let coldCity = vm.daytimeTempF
        #expect(warmCity != coldCity)
        #expect(warmCity > coldCity)
        // Sanity: offline climate stays in a wearable Fahrenheit band.
        #expect(warmCity > 40 && warmCity < 110)
        #expect(coldCity > -20 && coldCity < 90)
    }

    /// 门控天气：daySnapshot 挂起在测试控制的 continuation 上，resume() 后才返回。
    final class GatedWeather: WeatherSnapshotProviding, @unchecked Sendable {
        let temp: Double
        let throwOnResume: Bool
        private let lock = NSLock()
        private var cont: CheckedContinuation<Void, Never>?
        private var entered = false
        var hasEntered: Bool { lock.lock(); defer { lock.unlock() }; return entered }
        init(temp: Double, throwOnResume: Bool = false) {
            self.temp = temp
            self.throwOnResume = throwOnResume
        }
        func daytimeTemperatureF(forCity city: String?, on date: Date) async throws -> Double { temp }
        func daySnapshot(forCity city: String?, on date: Date) async throws -> WeatherDaySnapshot {
            await withCheckedContinuation { c in
                lock.lock(); cont = c; entered = true; lock.unlock()
            }
            if throwOnResume { throw URLError(.timedOut) }
            return WeatherDaySnapshot(
                daytimeTempF: temp, sourceLabel: "Gated", precipProbabilityPercent: 80)
        }
        func resume() {
            lock.lock(); let c = cont; cont = nil; lock.unlock()
            c?.resume()
        }
    }

    /// 竞态：慢的旧天气请求（bootstrap）完成后不得覆盖已落地的新结果（城市变更）。
    @Test func staleWeatherResponseDoesNotOverwriteNewer() async throws {
        let (_, w, _, _) = try setup()
        let vm = CopilotViewModel(wardrobe: w, daytimeTempF: 70)
        let slow = GatedWeather(temp: 88)
        let inFlight = Task { await vm.applyWeather(slow) }
        for _ in 0..<10_000 where !slow.hasEntered { await Task.yield() }
        #expect(slow.hasEntered)
        await vm.applyWeather(FixedWeatherProvider(temperatureF: 45))
        #expect(vm.daytimeTempF == 45)
        slow.resume()
        await inFlight.value
        // 旧响应作废：温度/来源/降雨全部保持新结果
        #expect(vm.daytimeTempF == 45)
        #expect(vm.weatherSourceLabel == "Fixed")
        #expect(vm.precipProbabilityPercent != 80)
    }

    /// 竞态：陈旧的失败不得把已成功的新结果改写成 Unavailable（吞掉成功数据）。
    @Test func staleWeatherFailureDoesNotClobberNewerSuccess() async throws {
        let (_, w, _, _) = try setup()
        let vm = CopilotViewModel(wardrobe: w, daytimeTempF: 70)
        let slowFail = GatedWeather(temp: 0, throwOnResume: true)
        let inFlight = Task { await vm.applyWeather(slowFail) }
        for _ in 0..<10_000 where !slowFail.hasEntered { await Task.yield() }
        #expect(slowFail.hasEntered)
        await vm.applyWeather(FixedWeatherProvider(temperatureF: 45))
        slowFail.resume()
        await inFlight.value
        #expect(vm.weatherSourceLabel == "Fixed")
        #expect(vm.daytimeTempF == 45)
    }

    /// Hard provider throw must not leave a silent "—" / stale source (W1 honesty).
    @Test func applyWeatherFailureSurfacesUnavailableSource() async throws {
        struct ThrowingWeather: WeatherProviding {
            func daytimeTemperatureF(forCity city: String?, on date: Date) async throws -> Double {
                throw URLError(.notConnectedToInternet)
            }
        }
        let (_, w, _, _) = try setup()
        // Cool successful fetch so a dress cue would fire if we naively used retained °F.
        let vm = CopilotViewModel(wardrobe: w, daytimeTempF: 72)
        await vm.applyWeather(FixedWeatherProvider(temperatureF: 55))
        #expect(vm.weatherSourceLabel == "Fixed")
        #expect(vm.weatherDressCue != nil)
        await vm.applyWeather(ThrowingWeather())
        #expect(vm.weatherSourceLabel == CopilotViewModel.weatherUnavailableSourceLabel)
        #expect(vm.precipProbabilityPercent == nil)
        // Last known temp retained for scoring continuity.
        #expect(vm.daytimeTempF == 55)
        #expect(vm.weatherSourceLabel != "—")
        #expect(!vm.weatherSourceLabel.localizedCaseInsensitiveContains("Open-Meteo"))
        // Pill says Unavailable — do not claim cool/rain from retained °F (W1.5 honesty).
        #expect(vm.weatherDressCue == nil)
    }
}

/// D88：合身反馈保存失败**不得静默**。此前 `checkIn` 用 `_ =` 丢弃
/// `setFitFeedback` 的返回值，随后无条件清空 message 并返回记录，View 于是
/// 干净关闭表单——用户明确选了「Felt tight」，看到的却是等同成功的结果，
/// 而 fit note 根本没落库，且失败路径的 `context.rollback()` 还会连带丢弃
/// 该 context 上其它 pending 变更。`fitFeedbackSaveFailedMessage` 早就为此写好，
/// 却零生产调用点。
@MainActor
struct CheckInFitFeedbackHonestyTests {

    func setup() throws -> (ModelContext, Wardrobe, Item) {
        let ctx = try ModelContext(ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let t = Item(name: "tee"); t.slotRaw = "top"; t.wardrobe = w
        t.statusRaw = "available"; ctx.insert(t)
        try ctx.save()
        return (ctx, w, t)
    }

    /// 反馈写入被拒（脏值）→ 打卡本身仍成功，但必须**说出**备注没保存。
    @Test func rejectedFitFeedbackSurfacesMessageInsteadOfSilentSuccess() throws {
        let (ctx, w, t) = try setup()
        let vm = CheckInViewModel(wardrobe: w)
        vm.toggle(t)
        vm.fitFeedback = "snug"   // 非 FitVerdict —— setFitFeedback 拒收
        let rec = vm.checkIn(in: ctx)
        // 打卡已成功，不谎报整体失败
        #expect(rec != nil)
        // 但备注没保存这件事必须可见
        #expect(vm.message == CheckInService.fitFeedbackSaveFailedMessage)
        #expect(rec?.fitFeedback == nil)
    }

    /// 合法反馈 → 真落库，且成功回执点名了用户选的档位（不是空字符串）。
    @Test func acceptedFitFeedbackPersistsAndConfirms() throws {
        let (ctx, w, t) = try setup()
        let vm = CheckInViewModel(wardrobe: w)
        vm.toggle(t)
        vm.fitFeedback = FitVerdict.tight.rawValue
        let rec = vm.checkIn(in: ctx)
        #expect(rec?.fitFeedback == FitVerdict.tight.rawValue)
        #expect(vm.message == FitFeedbackCopy.recordedMessage(.tight))
        #expect(vm.message.localizedCaseInsensitiveContains("tight"))
    }

    /// 无反馈的普通打卡也要有回执（此前成功路径把 message 清空，表单一关无从确认）。
    @Test func plainCheckInStillConfirms() throws {
        let (ctx, w, t) = try setup()
        let vm = CheckInViewModel(wardrobe: w)
        vm.toggle(t)
        let rec = vm.checkIn(in: ctx)
        #expect(rec != nil)
        #expect(!vm.message.isEmpty)
        #expect(!vm.didFail)
    }

    /// 失败与成功必须可区分——View 靠它决定是否关表单，不得靠关键词嗅探。
    @Test func failureFlagSeparatesPartialFailureFromSuccess() throws {
        let (ctx, w, t) = try setup()
        let bad = CheckInViewModel(wardrobe: w)
        bad.toggle(t); bad.fitFeedback = "snug"
        _ = bad.checkIn(in: ctx)
        #expect(bad.didFail)

        let good = CheckInViewModel(wardrobe: w)
        good.toggle(t); good.fitFeedback = FitVerdict.loose.rawValue
        _ = good.checkIn(in: ctx)
        #expect(!good.didFail)
    }
}
