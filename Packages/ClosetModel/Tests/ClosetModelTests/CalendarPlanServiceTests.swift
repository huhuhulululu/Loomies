import Testing
import SwiftData
import Foundation
@testable import ClosetModel

@MainActor
struct CalendarPlanServiceTests {

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    @Test func planBindsOutfitToDate() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let top = Item(name: "t"); top.wardrobe = w; ctx.insert(top)
        let o = Outfit(name: "look"); o.wardrobe = w; o.items = [top]; ctx.insert(o)
        try ctx.save()

        let day = Date()
        let plan = CalendarPlanService.plan(outfit: o, on: day, in: ctx)
        #expect(plan != nil)
        #expect(plan!.outfit?.id == o.id)
        #expect(plan!.needsAttention == false)

        let found = CalendarPlanService.plan(on: day, in: ctx)
        #expect(found?.id == plan!.id)
    }

    /// Save-fail toast must not look like success (no “Added to calendar”).
    @Test func saveFailedMessageIsHonest() {
        #expect(CalendarPlanService.saveFailedMessage.localizedCaseInsensitiveContains("couldn't plan"))
        #expect(CalendarPlanService.saveFailedMessage.localizedCaseInsensitiveContains("try again"))
        #expect(!CalendarPlanService.saveFailedMessage.localizedCaseInsensitiveContains("added to calendar"))
        #expect(CalendarPlanService.removeSaveFailedMessage
            .localizedCaseInsensitiveContains("couldn't remove"))
        #expect(CalendarPlanService.removeSaveFailedMessage
            .localizedCaseInsensitiveContains("try again"))
        #expect(!CalendarPlanService.removeSaveFailedMessage
            .localizedCaseInsensitiveContains("added to calendar"))
    }

    @Test func planNeedsAttentionWhenOutfitMissing() throws {
        let ctx = try makeContext()
        let a = Wardrobe(name: "A"); ctx.insert(a)
        let b = Wardrobe(name: "B"); ctx.insert(b)
        let item = Item(name: "x"); item.wardrobe = a; ctx.insert(item)
        let o = Outfit(name: "look"); o.wardrobe = a; o.items = [item]; ctx.insert(o)
        try ctx.save()
        TransferService.transfer(item, to: b, in: ctx)  // marks missing
        #expect(o.missing == true)

        let plan = CalendarPlanService.plan(outfit: o, on: Date(), in: ctx)
        #expect(plan?.needsAttention == true)
    }

    @Test func sameDayUpdatesExistingPlan() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i1 = Item(name: "1"); i1.wardrobe = w; ctx.insert(i1)
        let i2 = Item(name: "2"); i2.wardrobe = w; ctx.insert(i2)
        let o1 = Outfit(name: "a"); o1.wardrobe = w; o1.items = [i1]; ctx.insert(o1)
        let o2 = Outfit(name: "b"); o2.wardrobe = w; o2.items = [i2]; ctx.insert(o2)
        try ctx.save()

        let day = Date()
        let p1 = CalendarPlanService.plan(outfit: o1, on: day, in: ctx)
        let p2 = CalendarPlanService.plan(outfit: o2, on: day, in: ctx)
        #expect(p1 != nil && p2 != nil)
        #expect(p1!.id == p2!.id)
        #expect(p2!.outfit?.id == o2.id)
        let all = try ctx.fetch(FetchDescriptor<CalendarPlan>())
        #expect(all.count == 1)
    }

    @Test func listAndRemovePlans() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let item = Item(name: "t"); item.wardrobe = w; ctx.insert(item)
        let o = Outfit(name: "look"); o.wardrobe = w; o.items = [item]; ctx.insert(o)
        try ctx.save()
        let p = CalendarPlanService.plan(outfit: o, on: Date(), in: ctx)
        #expect(p != nil)
        #expect(CalendarPlanService.plans(for: w, in: ctx).count == 1)
        #expect(CalendarPlanService.remove(p!, in: ctx))
        #expect(CalendarPlanService.plans(for: w, in: ctx).isEmpty)
    }

    /// Delete piece → permanentlyMissing look on a plan must surface Attention (not silent).
    @Test func deleteItemFlagsPlannedLookNeedsAttention() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let item = Item(name: "top"); item.wardrobe = w; ctx.insert(item)
        let o = Outfit(name: "look"); o.wardrobe = w; o.items = [item]; o.isFavorite = true
        ctx.insert(o)
        try ctx.save()
        let plan = CalendarPlanService.plan(outfit: o, on: Date(), in: ctx)
        #expect(plan != nil)
        #expect(plan!.needsAttention == false)
        #expect(CalendarPlanService.shouldNeedAttention(o) == false)

        DeleteService.deleteItem(item, in: ctx)
        #expect(o.permanentlyMissing == true)
        #expect(CalendarPlanService.shouldNeedAttention(o) == true)
        #expect(plan!.needsAttention == true)
        #expect(CalendarPlanService.attentionPlans(in: ctx).contains(where: { $0.id == plan!.id }))
    }
}
