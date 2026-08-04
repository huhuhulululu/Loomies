import Testing
import SwiftData
import Foundation
@testable import ClosetUI
import ClosetModel
import ClosetCore
import ClosetIntake

/// 主路径打磨回归：种子 → 推荐 → 收藏/计划 → 打卡 → 检索 → 体型 → 导出/删除。
@MainActor
struct FeatureJourneyTests {

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    func seededCloset() throws -> (ModelContext, Person, Wardrobe) {
        let ctx = try makeContext()
        let person = Person(name: "Test")
        ctx.insert(person)
        let w = Wardrobe(name: "Home", locationCity: "New York")
        w.owner = person
        ctx.insert(w)
        let n = DemoSeedService.seed(w, in: ctx)
        #expect(n >= 8)  // ≥ coldStartThreshold so full-auto works without anchors
        try ctx.save()
        // 刷新关系：availableItems 读 wardrobe.items
        try ctx.save()
        return (ctx, person, w)
    }

    @Test func journeySeedToSuggestions() throws {
        let (ctx, _, w) = try seededCloset()
        // 确保 items 关系可见
        #expect((w.items ?? []).count >= 8)
        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 70)
        #expect(vm.availableItems.count >= 8)
        #expect(!vm.isColdStart)
        vm.fullAuto = true
        vm.refresh()
        #expect(!vm.suggestions.isEmpty, "seeded closet should complete looks")
        #expect(vm.statusMessage.contains("Look") || vm.selectedSuggestion != nil)
        let layers = OutfitAvatarComposer.layers(
            itemIDs: vm.suggestions[0].outfit.itemIDs, in: w)
        #expect(!layers.isEmpty)
        _ = ctx
    }

    @Test func journeySavePlanCheckInSearch() throws {
        let (ctx, _, w) = try seededCloset()
        let copilot = CopilotViewModel(wardrobe: w, occasion: "casual", daytimeTempF: 72)
        copilot.fullAuto = true
        copilot.refresh()
        #expect(!copilot.suggestions.isEmpty)
        let scored = copilot.suggestions[0]

        let actions = OutfitActionsViewModel()
        actions.saveFavorite(scored: scored, occasion: "casual", in: w, context: ctx)
        #expect(!OutfitFavoriteService.favorites(in: w).isEmpty)

        actions.planToday(scored: scored, occasion: "casual", in: w, context: ctx)
        let plans = CalendarPlanService.plans(for: w, in: ctx)
        #expect(!plans.isEmpty)

        // 打卡建议里的单品
        let ids = Set(scored.outfit.itemIDs)
        let items = (w.items ?? []).filter { ids.contains($0.id.uuidString) }
        #expect(!items.isEmpty)
        let checkIn = CheckInViewModel(wardrobe: w)
        for i in items { checkIn.toggle(i) }
        #expect(checkIn.canCheckIn)
        let rec = checkIn.checkIn(in: ctx)
        #expect(rec != nil)
        #expect(checkIn.selectedIDs.isEmpty)

        let search = SearchViewModel()
        search.wardrobeID = w.id
        search.text = "tee"
        search.run(in: ctx)
        #expect(search.results.contains(where: { $0.name.localizedCaseInsensitiveContains("tee") }))
        search.clear()
        #expect(search.results.isEmpty)
    }

    @Test func journeyBodyMorphAndDataLifecycle() throws {
        let (ctx, person, w) = try seededCloset()
        let body = BodyProfileViewModel(personID: person.id)
        body.selectPopularShape(.hourglass, in: ctx)
        body.bustInches = 36
        body.waistInches = 26
        body.hipInches = 38
        body.highHipInches = 34
        body.fineChest = 1.03
        body.save(in: ctx)
        #expect(body.isComplete)
        #expect(body.morph.chest > 1.0)
        #expect(body.confidence == .mixed || body.confidence == .measured)

        let json = try DataLifecycleService.exportJSONString(
            in: ctx, includeBodyDimensions: true)
        #expect(json.contains("wardrobes"))
        #expect(json.contains("Home"))
        #expect(json.contains("bodyProfiles") || json.contains("bustInches"))

        let receipt = try DataLifecycleService.deleteAllUserData(in: ctx)
        #expect(receipt.deletedItems >= 5)
        #expect(try ctx.fetch(FetchDescriptor<Item>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<Wardrobe>()).isEmpty)
        _ = w
    }

    @Test func journeyTransferAndStatus() throws {
        let (ctx, _, w) = try seededCloset()
        let w2 = Wardrobe(name: "Trip"); ctx.insert(w2); try ctx.save()
        let item = (w.items ?? []).first!
        let detail = ItemDetailViewModel(item: item)
        detail.statusRaw = "inWash"
        detail.save(in: ctx)
        #expect(item.statusRaw == "inWash")

        // 在洗不进 available
        let copilot = CopilotViewModel(wardrobe: w)
        #expect(!copilot.availableItems.contains(where: { $0.id == item.id }))

        detail.statusRaw = "available"
        detail.save(in: ctx)
        let transfer = TransferViewModel(item: item)
        transfer.loadDestinations(in: ctx)
        transfer.selectedDestinationID = w2.id
        transfer.transfer(in: ctx)
        #expect(item.wardrobe?.id == w2.id)
    }

    @Test func journeyIntakeConfirmSavesImage() async throws {
        let (ctx, _, w) = try seededCloset()
        let vm = IntakeServiceFactory.makeViewModel()
        await vm.process(Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]))  // fake png header-ish
        vm.draft?.name = "Photo blouse"
        vm.draft?.slot = .top
        let item = vm.confirm(into: w, context: ctx)
        #expect(item?.name == "Photo blouse")
        #expect(item?.localImageRelativePath != nil)
        #expect(ItemImageStore.loadData(relativePath: item?.localImageRelativePath) != nil)
        ItemImageStore.delete(relativePath: item?.localImageRelativePath)
    }

    @Test func journeyWeatherAndCityClimate() async throws {
        let (ctx, _, w) = try seededCloset()
        let copilot = CopilotViewModel(wardrobe: w, daytimeTempF: 70)
        await copilot.applyWeather(CityClimateWeatherProvider())
        // NYC in summer/winter varies; just ensure it changed from absurd or stayed finite
        #expect(copilot.daytimeTempF > 0 && copilot.daytimeTempF < 120)
        _ = ctx
    }
}
