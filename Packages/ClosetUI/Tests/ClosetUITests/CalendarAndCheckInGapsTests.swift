import Testing
import Foundation
import SwiftData
@testable import ClosetUI
import ClosetModel
import ClosetCore

/// D189：日历与打卡剩下的三条。
@MainActor
struct CalendarAndCheckInGapsTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    // MARK: - #21 穿着历史的空态不说作用域

    /// 穿着历史按衣柜快照过滤，空态却只说「Nothing logged yet」。
    ///
    /// 同一种作用域收窄在日历那边被本仓自己判为**必须披露**
    ///（`CalendarScopeCopy` 明写「This calendar shows only the closet you're in.」，
    /// 还有一条专门的门盯着）。两处对同一件事一个说一个不说。
    ///
    /// 口径矛盾也是真的：`WearStatsService` 按单品本身聚合、不看快照柜，
    /// 于是单品详情说「Worn 5 times」，而另一个柜的 Wear history 说「Nothing logged yet」。
    @Test func theWearHistoryEmptyStateNamesItsScope() {
        let copy = WearHistoryViewModel.emptyMessage
        #expect(copy.localizedCaseInsensitiveContains("closet"), Comment(rawValue:
            "没说这是分柜视图 —— 用户会以为记录丢了：\(copy)"))
        #expect(!copy.localizedCaseInsensitiveContains("all closets"))
    }

    /// 两处作用域文案同源——同一件事两处各写各的注定走岔（D183 刚栽过）。
    @Test func bothScopedEmptyStatesShareTheSameSentence() {
        #expect(WearHistoryViewModel.emptyMessage
            .localizedCaseInsensitiveContains(ClosetScopeCopy.onlyThisCloset))
        #expect(CalendarScopeCopy.emptyMessage
            .localizedCaseInsensitiveContains(ClosetScopeCopy.onlyThisCloset))
    }

    // MARK: - #22 Plan 建出来的搭配永不回收

    private func setup() throws -> (ModelContext, Wardrobe, [Item]) {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Home"); ctx.insert(w)
        var items: [Item] = []
        for (i, slot) in ["top", "bottom", "shoes"].enumerated() {
            let it = Item(name: "p\(i)"); it.wardrobe = w; it.slotRaw = slot
            it.statusRaw = "available"; ctx.insert(it); items.append(it)
        }
        try ctx.save()
        return (ctx, w, items)
    }

    private func planOutfit(_ ctx: ModelContext, _ w: Wardrobe, _ items: [Item],
                            name: String) throws -> ClosetModel.Outfit {
        try OutfitFavoriteService.saveFavorite(
            name: name, itemIDs: items.map { $0.id.uuidString }, occasion: nil,
            in: w, source: "copilot-plan", isFavorite: false, context: ctx)
    }

    /// **本波的核心**：同一天改排一次，上一条 plan-only 搭配不该留在库里。
    ///
    /// Today 的「Plan」每点一次就新建一条 `isFavorite: false` 的搭配。
    /// 它不在收藏列表里（那边只列 `isFavorite`），也没有任何「全部搭配」页面——
    /// 于是它**谁也看不到**，却照样进导出、进删除回执、进删柜对话框的
    /// 「This also deletes N looks」。无上限、无回收。
    @Test func replanningTheSameDayReclaimsThePreviousPlanOnlyLook() throws {
        let (ctx, w, items) = try setup()
        let first = try planOutfit(ctx, w, items, name: "Plan A")
        let day = Date()
        #expect(CalendarPlanService.plan(outfit: first, on: day, in: ctx) != nil)
        let second = try planOutfit(ctx, w, items, name: "Plan B")
        #expect(CalendarPlanService.plan(outfit: second, on: day, in: ctx) != nil)

        let stored = try ctx.fetch(FetchDescriptor<ClosetModel.Outfit>())
        #expect(stored.count == 1, Comment(rawValue:
            "改排之后库里留了 \(stored.count) 条搭配 —— 多出来的那条谁也看不到，"
            + "却照样进导出与删除回执"))
        #expect(stored.first?.id == second.id)
    }

    /// 删掉计划时同样回收。
    @Test func removingAPlanReclaimsItsPlanOnlyLook() throws {
        let (ctx, w, items) = try setup()
        let look = try planOutfit(ctx, w, items, name: "Plan A")
        let plan = try #require(CalendarPlanService.plan(outfit: look, on: Date(), in: ctx))
        #expect(CalendarPlanService.remove(plan, in: ctx))
        #expect(try ctx.fetch(FetchDescriptor<ClosetModel.Outfit>()).isEmpty,
                "计划删了，那条只为它而建的搭配留在库里")
    }

    /// **收藏不许被回收**——用户存过的东西不能因为改排就消失。
    @Test func aFavouriteIsNeverReclaimed() throws {
        let (ctx, w, items) = try setup()
        let saved = try OutfitFavoriteService.saveFavorite(
            name: "My look", itemIDs: items.map { $0.id.uuidString }, occasion: nil,
            in: w, source: "fittingRoom", isFavorite: true, context: ctx)
        let day = Date()
        #expect(CalendarPlanService.plan(outfit: saved, on: day, in: ctx) != nil)
        let other = try planOutfit(ctx, w, items, name: "Plan B")
        #expect(CalendarPlanService.plan(outfit: other, on: day, in: ctx) != nil)
        #expect(try ctx.fetch(FetchDescriptor<ClosetModel.Outfit>())
            .contains { $0.id == saved.id }, "用户收藏的搭配被当成孤儿回收了")
    }

    /// **用户自己取消收藏的**也不回收（那是他的数据，不是 Plan 的副产品）。
    @Test func anUnfavouritedUserLookIsNeverReclaimed() throws {
        let (ctx, w, items) = try setup()
        let mine = try OutfitFavoriteService.saveFavorite(
            name: "Mine", itemIDs: items.map { $0.id.uuidString }, occasion: nil,
            in: w, source: "fittingRoom", isFavorite: false, context: ctx)
        let day = Date()
        #expect(CalendarPlanService.plan(outfit: mine, on: day, in: ctx) != nil)
        let other = try planOutfit(ctx, w, items, name: "Plan B")
        #expect(CalendarPlanService.plan(outfit: other, on: day, in: ctx) != nil)
        #expect(try ctx.fetch(FetchDescriptor<ClosetModel.Outfit>())
            .contains { $0.id == mine.id }, "来源不是 copilot-plan 的搭配被回收了")
    }

    /// 还被别的计划引用着就不回收（同一条搭配可以排在两天）。
    @Test func aLookStillUsedByAnotherPlanSurvives() throws {
        let (ctx, w, items) = try setup()
        let look = try planOutfit(ctx, w, items, name: "Plan A")
        let today = Date()
        let tomorrow = today.addingTimeInterval(86_400)
        #expect(CalendarPlanService.plan(outfit: look, on: today, in: ctx) != nil)
        #expect(CalendarPlanService.plan(outfit: look, on: tomorrow, in: ctx) != nil)

        let replacement = try planOutfit(ctx, w, items, name: "Plan B")
        #expect(CalendarPlanService.plan(outfit: replacement, on: today, in: ctx) != nil)
        #expect(try ctx.fetch(FetchDescriptor<ClosetModel.Outfit>())
            .contains { $0.id == look.id }, "明天还排着它呢")
    }

    // MARK: - #23 关掉开关后仍会打卡被隐藏的件

    /// 关掉「Include laundry / lent pieces」要把已勾中的那些一并取消。
    ///
    /// 此前：屏幕上一个勾都看不见，Log 按钮仍可点，落库的是被「取消显示」的那件。
    @Test func turningOffTheToggleUnselectsHiddenPieces() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Home"); ctx.insert(w)
        let clean = Item(name: "Tee"); clean.wardrobe = w; clean.statusRaw = "available"
        ctx.insert(clean)
        let inWash = Item(name: "Jeans"); inWash.wardrobe = w; inWash.statusRaw = "inWash"
        ctx.insert(inWash)
        try ctx.save()

        let vm = CheckInViewModel(wardrobe: w)
        vm.includesUnavailableItems = true
        vm.toggle(clean)
        vm.toggle(inWash)
        #expect(vm.canCheckIn)

        vm.includesUnavailableItems = false
        #expect(!vm.isSelected(inWash), Comment(rawValue:
            "在洗那件从列表里消失了，却还在选中集里 —— 屏上一个勾都看不见，"
            + "落库的却是它"))
        #expect(vm.isSelected(clean), "干净那件不该被误伤")
        #expect(vm.canCheckIn)
    }

    /// 关掉后只剩隐藏件时，Log 按钮要跟着变灰（不许提交一个看不见的选区）。
    @Test func theLogButtonGoesGreyWhenOnlyHiddenPiecesWereSelected() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Home"); ctx.insert(w)
        let lent = Item(name: "Coat"); lent.wardrobe = w; lent.statusRaw = "lent"
        ctx.insert(lent)
        try ctx.save()

        let vm = CheckInViewModel(wardrobe: w)
        vm.includesUnavailableItems = true
        vm.toggle(lent)
        #expect(vm.canCheckIn)
        vm.includesUnavailableItems = false
        #expect(!vm.canCheckIn, "选区已经空了，Log 按钮还亮着")
    }

    /// 再打开开关不会把刚取消的勾自己变回来（取消就是取消）。
    @Test func turningItBackOnDoesNotRestoreTheSelection() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Home"); ctx.insert(w)
        let inWash = Item(name: "Jeans"); inWash.wardrobe = w; inWash.statusRaw = "inWash"
        ctx.insert(inWash)
        try ctx.save()

        let vm = CheckInViewModel(wardrobe: w)
        vm.includesUnavailableItems = true
        vm.toggle(inWash)
        vm.includesUnavailableItems = false
        vm.includesUnavailableItems = true
        #expect(!vm.isSelected(inWash))
    }
}

/// D189 的结构门：**「只为挂日历而建」这个标记只许有一个出处。**
///
/// 建的一侧（`planToday`）与回收的一侧（`reclaimPlanOnlyOutfit`）
/// 各写一份字面量的话，改一处不改另一处 = 回收静默失效——
/// 而失效是**看不见的**：库里悄悄攒行，没有任何界面会露馅。
@MainActor
struct PlanOnlySourceIsSingleSourcedTests {

    @Test func noProductionCodeSpellsTheMarkerByHand() throws {
        let packages = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        var offenders: [String] = []
        for case let url as URL in FileManager.default
            .enumerator(at: packages, includingPropertiesForKeys: nil)!
        where url.pathExtension == "swift" {
            let path = url.path
            guard path.contains("/Sources/") else { continue }
            guard url.lastPathComponent != "CalendarPlanService.swift" else { continue }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let hit = text.split(separator: "\n").contains { line in
                let t = line.trimmingCharacters(in: .whitespaces)
                return t.contains("\"copilot-plan\"")
                    && !t.hasPrefix("//") && !t.hasPrefix("///")
            }
            if hit { offenders.append(url.lastPathComponent) }
        }
        #expect(offenders.isEmpty, Comment(rawValue:
            "这些地方手写了来源标记：\(offenders) —— 用 CalendarPlanService.planOnlySource"))
    }
}
