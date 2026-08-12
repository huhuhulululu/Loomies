import Testing
import SwiftData
import Foundation
@testable import ClosetUI
@testable import ClosetModel   // ModelSave.forceFailure test hook
import ClosetCore

/// D103（审计 MEDIUM）：Today 上点「Plan」会**顺手建一个收藏**，
/// 而提示只说「Added to calendar.」——用户没要求收藏，收藏列表却多了一条
/// 名叫「Plan Aug 12」的东西（隐瞒做了的事）。
/// 更糟的是日历那步失败时，那个多出来的收藏**仍然留着**，
/// 而文案报的是纯失败——用户以为什么都没发生。
@MainActor
struct PlanTodaySideEffectTests {

    func setup() throws -> (ModelContext, Wardrobe, [CandidateItem]) {
        let ctx = try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        var candidates: [CandidateItem] = []
        for (n, slot) in [("Tee", GarmentSlot.top), ("Jeans", .bottom), ("Boots", .shoes)] {
            let i = Item(name: n); i.slotRaw = slot.rawValue; i.wardrobe = w
            i.statusRaw = "available"; ctx.insert(i)
            candidates.append(i.toCandidateItem())
        }
        try ctx.save()
        return (ctx, w, candidates)
    }

    func scored(_ items: [CandidateItem]) -> ScoredOutfit {
        ScoredOutfit(
            outfit: ClosetCore.Outfit(items: items),
            score: OutfitScore(value: 1, reasons: []))
    }

    /// 计划成功：不得顺手把它塞进收藏列表。
    @Test func planningDoesNotSilentlyCreateAFavorite() throws {
        let (ctx, w, items) = try setup()
        let vm = OutfitActionsViewModel()
        vm.planToday(scored: scored(items), occasion: "work", in: w, context: ctx)
        #expect(vm.message.localizedCaseInsensitiveContains("calendar"))
        let favorites = try ctx.fetch(FetchDescriptor<ClosetModel.Outfit>()).filter(\.isFavorite)
        #expect(favorites.isEmpty, "用户只点了 Plan，收藏列表却多了一条")
        // 计划本身要真的建起来
        #expect(try ctx.fetch(FetchDescriptor<CalendarPlan>()).count == 1)
    }

    /// 日历失败：不得留下孤儿搭配，也不得把失败说成什么都没发生之外的样子。
    @Test func calendarFailureLeavesNoOrphanOutfit() throws {
        let (ctx, w, items) = try setup()
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        let vm = OutfitActionsViewModel()
        vm.planToday(scored: scored(items), occasion: "work", in: w, context: ctx)
        #expect(!vm.message.localizedCaseInsensitiveContains("added"))
        #expect(try ctx.fetch(FetchDescriptor<ClosetModel.Outfit>()).isEmpty, "失败却留下了孤儿搭配")
        #expect(try ctx.fetch(FetchDescriptor<CalendarPlan>()).isEmpty)
        #expect(!ctx.hasChanges)
    }

    /// 显式收藏仍然照常工作（这条路径不受影响）。
    @Test func explicitFavoriteStillWorks() throws {
        let (ctx, w, items) = try setup()
        let vm = OutfitActionsViewModel()
        vm.saveFavorite(scored: scored(items), occasion: "work", in: w, context: ctx)
        #expect(try ctx.fetch(FetchDescriptor<ClosetModel.Outfit>()).filter(\.isFavorite).count == 1)
    }
}
