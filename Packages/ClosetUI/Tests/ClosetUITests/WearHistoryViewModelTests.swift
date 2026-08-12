import Testing
import SwiftData
import Foundation
@testable import ClosetUI
import ClosetModel
import ClosetCore

/// D88：穿着历史此前**只写不读**——全 App 无任何界面 fetch WearRecord，
/// 合身反馈采集后既不展示也不可修改，用户点错一次就永远改不回来，
/// 而 `FitFeedbackCopy.logCaption`（专为历史回显写的）零生产调用点。
/// 这与 copilot「用户掌舵、推荐可覆盖」的定位相抵。
@MainActor
struct WearHistoryViewModelTests {

    func setup() throws -> (ModelContext, Wardrobe, Item, Item) {
        let ctx = try ModelContext(ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let tee = Item(name: "Tee"); tee.slotRaw = "top"; tee.wardrobe = w
        tee.statusRaw = "available"; ctx.insert(tee)
        let jeans = Item(name: "Jeans"); jeans.slotRaw = "bottom"; jeans.wardrobe = w
        jeans.statusRaw = "available"; ctx.insert(jeans)
        try ctx.save()
        return (ctx, w, tee, jeans)
    }

    /// 最近在前；只列本柜的记录。
    @Test func entriesAreNewestFirstAndScopedToThisCloset() throws {
        let (ctx, w, tee, jeans) = try setup()
        let other = Wardrobe(name: "Other"); ctx.insert(other)
        let alien = Item(name: "Alien"); alien.slotRaw = "top"; alien.wardrobe = other
        alien.statusRaw = "available"; ctx.insert(alien)
        try ctx.save()

        let old = Date().addingTimeInterval(-86_400 * 3)
        _ = CheckInService.recordWear(items: [tee], on: old, in: w, in: ctx)
        _ = CheckInService.recordWear(items: [jeans], on: Date(), in: w, in: ctx)
        _ = CheckInService.recordWear(items: [alien], on: Date(), in: other, in: ctx)

        let vm = WearHistoryViewModel(wardrobe: w)
        vm.load(in: ctx)
        #expect(vm.entries.count == 2)
        #expect(vm.entries.first?.pieceNames == ["Jeans"])
        #expect(vm.entries.last?.pieceNames == ["Tee"])
    }

    /// 已转移/删除的单品不得让整条记录变空白——诚实说「N pieces no longer here」。
    @Test func missingPiecesAreNamedHonestly() throws {
        let (ctx, w, tee, jeans) = try setup()
        _ = CheckInService.recordWear(items: [tee, jeans], on: Date(), in: w, in: ctx)
        ctx.delete(jeans)
        try ctx.save()

        let vm = WearHistoryViewModel(wardrobe: w)
        vm.load(in: ctx)
        let entry = try #require(vm.entries.first)
        #expect(entry.pieceNames == ["Tee"])
        #expect(entry.missingCount == 1)
        #expect(entry.subtitle.localizedCaseInsensitiveContains("no longer"))
    }

    /// 合身反馈可回显，也**可改**——用户掌舵，记错的能纠正。
    @Test func fitFeedbackIsVisibleAndEditable() throws {
        let (ctx, w, tee, _) = try setup()
        let rec = try #require(CheckInService.recordWear(
            items: [tee], on: Date(), in: w, in: ctx))
        #expect(CheckInService.setFitFeedback(FitVerdict.tight.rawValue, on: rec, in: ctx))

        let vm = WearHistoryViewModel(wardrobe: w)
        vm.load(in: ctx)
        #expect(vm.entries.first?.fitCaption == FitFeedbackCopy.logCaption(FitVerdict.tight.rawValue))

        // 改成 loose
        #expect(vm.updateFit(.loose, forEntryID: try #require(vm.entries.first?.id), in: ctx))
        #expect(vm.entries.first?.fitCaption == FitFeedbackCopy.logCaption(FitVerdict.loose.rawValue))
        // 清除
        #expect(vm.updateFit(nil, forEntryID: try #require(vm.entries.first?.id), in: ctx))
        #expect(vm.entries.first?.fitCaption == nil)
    }

    /// 删一条打卡记录（记错了日子）——防重复窗口随之更新。
    @Test func deletingAnEntryReleasesTheAntiRepeatWindow() throws {
        let (ctx, w, tee, _) = try setup()
        _ = CheckInService.recordWear(items: [tee], on: Date(), in: w, in: ctx)
        #expect(CheckInViewModel.recentlyWornIDs(in: ctx).contains(tee.id.uuidString))

        let vm = WearHistoryViewModel(wardrobe: w)
        vm.load(in: ctx)
        #expect(vm.delete(entryID: try #require(vm.entries.first?.id), in: ctx))
        #expect(vm.entries.isEmpty)
        #expect(!CheckInViewModel.recentlyWornIDs(in: ctx).contains(tee.id.uuidString))
    }

    /// 空态文案指路，不假装有内容。
    @Test func emptyStateExplainsHowToGetHere() throws {
        let (ctx, w, _, _) = try setup()
        let vm = WearHistoryViewModel(wardrobe: w)
        vm.load(in: ctx)
        #expect(vm.entries.isEmpty)
        #expect(WearHistoryViewModel.emptyMessage.localizedCaseInsensitiveContains("log"))
    }
}
