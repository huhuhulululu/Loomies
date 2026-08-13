import Testing
import Foundation
import SwiftData
@testable import ClosetUI
import ClosetModel
import ClosetCore

/// D184：**从详情页把单品转到别的柜，之后再点 Save 永远报
/// 「Couldn't update location — try again」——而重试永远无用。**
///
/// `locationID` 是 `init` 时的一次性快照（`item.location?.id`），
/// 而 `storageLocations` 是按 `item.wardrobe` 现读的。
/// `TransferService` 把 `wardrobe` 换成目的柜并 `item.location = nil`，
/// 详情页的 `vm` 是 `@State` 一次构造、转移只 `dismiss()` 了 sheet，
/// 全文件没有任何 onChange 重置它。
///
/// 于是 `applyLocation` 在目的柜的位置表里找不到源柜那个 id → `return false`，
/// 而 `ItemEditorService.apply` **早已提交**——名字确实存进去了却报错。
/// 目的柜一个存放位置都没有时连 Picker 都不渲染，用户没有任何手段清掉它，成死路。
///
/// 「找不到就诚实报错」这条本身是对的（位置被**删掉**时就该这样，
/// `FeatureGapViewModelTests` 有用例钉着）。区别在于：
/// 删除 = 那个位置不存在了；转移 = 它还在，只是不属于这件衣服现在的柜。
/// 后者不是错误，是**这件衣服换了柜子**，picker 的快照理应跟着作废。
@MainActor
struct DetailAfterTransferTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    private func setup() throws -> (ModelContext, Item, Wardrobe, Wardrobe, StorageLocation) {
        let ctx = try makeContext()
        let home = Wardrobe(name: "Home"); ctx.insert(home)
        let lake = Wardrobe(name: "Lake"); ctx.insert(lake)
        try ctx.save()
        let rail = try #require(StorageLocationService.create(
            name: "Rail", in: home, context: ctx))
        let tee = Item(name: "Tee"); tee.wardrobe = home; ctx.insert(tee)
        try ctx.save()
        #expect(StorageLocationService.assign(tee, to: rail, in: ctx))
        return (ctx, tee, home, lake, rail)
    }

    /// **本波的核心**：转移之后还能存得下去。
    @Test func savingAfterATransferSucceeds() throws {
        let (ctx, tee, _, lake, _) = try setup()
        let vm = ItemDetailViewModel(item: tee)
        #expect(vm.locationID != nil)

        #expect(TransferService.transfer(tee, to: lake, in: ctx))
        vm.name = "Renamed tee"
        vm.save(in: ctx)

        #expect(vm.message == "Saved.", Comment(rawValue:
            "转移之后再存报的是「\(vm.message)」—— 名字其实已经存进去了，"
            + "而目的柜没有存放位置时用户没有任何手段修好它"))
        #expect(tee.name == "Renamed tee")
        #expect(tee.location == nil, "转移已经脱离了源柜的位置，不该被写回去")
        #expect(vm.locationID == nil, "picker 里还留着源柜那个位置")
    }

    /// 目的柜**有**位置时，转移后仍是「未指定」，用户可以自己再选一个。
    @Test func afterATransferThePieceIsUnassignedInTheNewCloset() throws {
        let (ctx, tee, _, lake, _) = try setup()
        let shelf = try #require(StorageLocationService.create(
            name: "Shelf", in: lake, context: ctx))
        let vm = ItemDetailViewModel(item: tee)
        #expect(TransferService.transfer(tee, to: lake, in: ctx))
        vm.save(in: ctx)
        #expect(vm.message == "Saved.")

        vm.locationID = shelf.id
        vm.save(in: ctx)
        #expect(vm.message == "Saved.")
        #expect(tee.location?.id == shelf.id)
    }

    /// **位置被删**仍然诚实报错（这条是刻意设计，不得被本波的放宽吃掉）。
    @Test func aDeletedLocationStillFailsHonestly() throws {
        let (ctx, tee, _, _, rail) = try setup()
        let vm = ItemDetailViewModel(item: tee)
        vm.locationID = rail.id
        #expect(DeleteService.deleteLocation(rail, in: ctx))
        vm.save(in: ctx)
        #expect(vm.message != "Saved.", "位置已经不存在了，却报了保存成功")
        #expect(CustomerFlashStyle.isFailure(vm.message)
                || vm.message.localizedCaseInsensitiveContains("couldn't"))
    }

    /// 没转移、位置也没删时行为一个字不变。
    @Test func theOrdinarySaveIsUnchanged() throws {
        let (ctx, tee, _, _, rail) = try setup()
        let vm = ItemDetailViewModel(item: tee)
        vm.name = "Still here"
        vm.save(in: ctx)
        #expect(vm.message == "Saved.")
        #expect(tee.location?.id == rail.id)
    }
}
