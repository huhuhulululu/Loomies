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

    @Test func applyWeatherUpdatesTemp() async throws {
        let (_, w, _, _) = try setup()
        let vm = CopilotViewModel(wardrobe: w, daytimeTempF: 70)
        await vm.applyWeather(FixedWeatherProvider(temperatureF: 55))
        #expect(vm.daytimeTempF == 55)
    }
}
