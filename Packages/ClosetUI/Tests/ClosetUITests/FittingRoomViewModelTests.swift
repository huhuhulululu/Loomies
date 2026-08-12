import Testing
import SwiftData
import Foundation
@testable import ClosetUI
@testable import ClosetModel // ModelSave.forceFailure test hook
import ClosetCore

/// 试衣间（手动挑单品上身，DESIGN §7 v1.0「手动拼贴」）：
/// 叠衣引擎此前只有推荐/收藏只读展示，无「用户任意选衣→上身」入口。
@MainActor
struct FittingRoomViewModelTests {
    init() { ItemImageTestRoot.install() }   // 触盘套件：根目录按进程隔离，勿写真机目录

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    func mk(_ ctx: ModelContext, _ w: Wardrobe, _ name: String, _ slot: String,
            status: String = "available") -> Item {
        let i = Item(name: name); i.slotRaw = slot; i.wardrobe = w; i.statusRaw = status
        ctx.insert(i); return i
    }

    @Test func itemsForSlotFilterByDisplaySlotAndAvailability() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let tee = mk(ctx, w, "White Tee", "top")
        let blazer = mk(ctx, w, "Navy Blazer", "top")      // displaySlot 纠偏 → outerwear
        let washing = mk(ctx, w, "Muddy Tee", "top", status: "inWash")
        try ctx.save()
        let vm = FittingRoomViewModel(wardrobe: w)
        let tops = vm.items(for: .top)
        #expect(tops.map(\.id) == [tee.id])                 // blazer 归 outerwear、inWash 排除
        #expect(vm.items(for: .outerwear).map(\.id) == [blazer.id])
        #expect(!tops.contains { $0.id == washing.id })
    }

    @Test func toggleSelectsDeselectsAndDressExcludesSeparates() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let tee = mk(ctx, w, "Tee", "top")
        let jeans = mk(ctx, w, "Jeans", "bottom")
        let dress = mk(ctx, w, "Slip Dress", "dress")
        try ctx.save()
        let vm = FittingRoomViewModel(wardrobe: w)
        vm.toggle(tee); vm.toggle(jeans)
        #expect(vm.isSelected(tee) && vm.isSelected(jeans))
        // 选裙 → 上下装自动清（grammar 互斥，UX 同步执行）
        vm.toggle(dress)
        #expect(vm.isSelected(dress))
        #expect(!vm.isSelected(tee) && !vm.isSelected(jeans))
        // 反向：再选上装 → 裙清
        vm.toggle(tee)
        #expect(vm.isSelected(tee) && !vm.isSelected(dress))
        // 同件再点 = 取消
        vm.toggle(tee)
        #expect(!vm.isSelected(tee))
    }

    @Test func toggleRejectsForeignWardrobeItem() throws {
        let ctx = try makeContext()
        let a = Wardrobe(name: "A"); ctx.insert(a)
        let b = Wardrobe(name: "B"); ctx.insert(b)
        let foreign = mk(ctx, b, "Foreign Tee", "top")
        try ctx.save()
        let vm = FittingRoomViewModel(wardrobe: a)
        vm.toggle(foreign)   // 跨柜不变量：静默拒绝（不入选区）
        #expect(!vm.isSelected(foreign))
        #expect(vm.selectedItems.isEmpty)
    }

    @Test func layersReflectSelection() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let tee = mk(ctx, w, "Tee", "top")
        let jeans = mk(ctx, w, "Jeans", "bottom")
        try ctx.save()
        let vm = FittingRoomViewModel(wardrobe: w)
        #expect(vm.layers.isEmpty)
        vm.toggle(tee); vm.toggle(jeans)
        let slots = Set(vm.layers.map(\.slot))
        #expect(slots == Set([.top, .bottom]))
    }

    @Test func saveAsFavoriteCreatesLookWithFittingRoomSource() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let tee = mk(ctx, w, "Tee", "top")
        let jeans = mk(ctx, w, "Jeans", "bottom")
        try ctx.save()
        let vm = FittingRoomViewModel(wardrobe: w)
        vm.toggle(tee); vm.toggle(jeans)
        let outfit = vm.saveAsFavorite(named: "  My Mix  ", in: ctx)
        #expect(outfit != nil)
        #expect(outfit?.name == "My Mix")
        #expect(outfit?.isFavorite == true)
        #expect(outfit?.sourceRaw == "fittingRoom")
        #expect(Set((outfit?.items ?? []).map(\.id)) == Set([tee.id, jeans.id]))
        #expect(vm.message == FittingRoomViewModel.savedMessage(name: "My Mix"))
        // 空白名 → 默认名（非空）
        vm.toggle(tee)
        let auto = vm.saveAsFavorite(named: "   ", in: ctx)
        #expect(auto?.name.isEmpty == false)
    }

    @Test func emptySaveRejectedHonestly() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        try ctx.save()
        let vm = FittingRoomViewModel(wardrobe: w)
        #expect(!vm.canSave)
        #expect(vm.saveAsFavorite(named: "x", in: ctx) == nil)
        #expect(vm.message == FittingRoomViewModel.emptySaveMessage)
        #expect(try ctx.fetch(FetchDescriptor<ClosetModel.Outfit>()).isEmpty)
    }

    @Test func saveFailureKeepsSelectionWithHonestMessage() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let tee = mk(ctx, w, "Tee", "top")
        try ctx.save()
        let vm = FittingRoomViewModel(wardrobe: w)
        vm.toggle(tee)
        ModelSave.forceFailure(on: ctx)
        #expect(vm.saveAsFavorite(named: "x", in: ctx) == nil)
        #expect(vm.message == FittingRoomViewModel.saveFailedMessage)
        #expect(vm.isSelected(tee))          // 选区保留可重试
        #expect(!ctx.hasChanges)
        ModelSave.clearForcedFailure(on: ctx)
        #expect(vm.saveAsFavorite(named: "x", in: ctx) != nil)
    }
}
