import Testing
import Foundation
import SwiftData
@testable import ClosetModel
import ClosetCore

/// D112（数据层审计）：本仓已有的铁律是
/// **create 失败要断关系再 rollback，mutate 失败要先还原内存值再 rollback**——
/// 因为 SwiftData 的 `rollback()` 撤销的是**未落库的行**，撤不掉已被改过的
/// 内存关系；那些幻影关系会被**下一次无关的成功 save** 顺手写进库里。
///
/// 两处漏了这一步（`DeleteService.deleteLocation` 是做对的样板）：
/// - `OutfitFavoriteService.discardOrphan` 先清空 `items`/`wardrobe` 再 delete，
///   失败只 rollback → 那条搭配活下来了，但**件全没了**（或 wardrobe 变 nil，
///   成为任何界面都看不到的孤行）。
/// - `StorageLocationService.create` 失败不断关系 → 幻影位置留在
///   `wardrobe.locations` / `parent.children` 里，`list()` 照列，
///   而且**同名重试会被判重名拒绝**——用户被一个不存在的位置挡住。
@MainActor
struct RollbackRestoreTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    // MARK: - discardOrphan

    @Test func failedDiscardKeepsTheLookIntact() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Home"); ctx.insert(w)
        let shirt = Item(name: "Shirt"); shirt.slotRaw = "top"; shirt.wardrobe = w; ctx.insert(shirt)
        let jeans = Item(name: "Jeans"); jeans.slotRaw = "bottom"; jeans.wardrobe = w; ctx.insert(jeans)
        let look = ClosetModel.Outfit(name: "Look"); look.wardrobe = w; look.items = [shirt, jeans]
        ctx.insert(look)
        try ctx.save()

        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        #expect(OutfitFavoriteService.discardOrphan(look, in: ctx) == false)
        ModelSave.clearForcedFailure(on: ctx)

        #expect(look.wardrobe?.id == w.id, "丢弃失败之后这条搭配没了归属柜 —— 任何界面都看不到它")
        #expect(look.items?.count == 2, "丢弃失败之后这条搭配的件被清空了")
    }

    /// 关键在**下一次无关的成功 save**：幻影关系正是在那一刻被写进库的。
    @Test func aLaterUnrelatedSaveDoesNotCommitThePhantom() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Home"); ctx.insert(w)
        let shirt = Item(name: "Shirt"); shirt.slotRaw = "top"; shirt.wardrobe = w; ctx.insert(shirt)
        let jeans = Item(name: "Jeans"); jeans.slotRaw = "bottom"; jeans.wardrobe = w; ctx.insert(jeans)
        let look = ClosetModel.Outfit(name: "Look"); look.wardrobe = w; look.items = [shirt, jeans]
        ctx.insert(look)
        try ctx.save()

        ModelSave.forceFailure(on: ctx)
        _ = OutfitFavoriteService.discardOrphan(look, in: ctx)
        ModelSave.clearForcedFailure(on: ctx)

        // 一次完全无关的成功保存
        shirt.statusRaw = "inWash"
        #expect(ModelSave.save(ctx, label: "unrelated"))

        let stored = try ctx.fetch(FetchDescriptor<ClosetModel.Outfit>())
        let persisted = try #require(stored.first { $0.id == look.id })
        #expect(persisted.items?.count == 2,
                "一次无关的保存把这条搭配的件永久清空了")
        #expect(persisted.wardrobe?.id == w.id,
                "一次无关的保存把这条搭配变成了无主孤行")
    }

    @Test func aSuccessfulDiscardStillRemovesTheOutfit() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Home"); ctx.insert(w)
        let look = ClosetModel.Outfit(name: "Junk"); look.wardrobe = w; ctx.insert(look)
        try ctx.save()
        #expect(OutfitFavoriteService.discardOrphan(look, in: ctx))
        #expect(try ctx.fetch(FetchDescriptor<ClosetModel.Outfit>()).isEmpty)
    }

    // MARK: - StorageLocationService.create

    @Test func failedLocationCreateLeavesNoPhantom() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Home"); ctx.insert(w)
        try ctx.save()
        let rail = try #require(StorageLocationService.create(
            name: "Rail", in: w, parent: nil, context: ctx))

        ModelSave.forceFailure(on: ctx)
        #expect(StorageLocationService.create(
            name: "Drawer", in: w, parent: rail, context: ctx) == nil)
        ModelSave.clearForcedFailure(on: ctx)

        #expect(w.locations?.count == 1, "幻影位置还挂在衣柜上")
        #expect(rail.children?.isEmpty ?? true, "幻影位置还挂在父节点下")
        #expect(StorageLocationService.list(in: w).map(\.name) == ["Rail"],
                "位置列表里列着一个库里不存在的位置")
    }

    /// 最伤人的后果：同名重试被一个**不存在**的位置判为重名。
    @Test func theUserCanRetryWithTheSameName() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Home"); ctx.insert(w)
        try ctx.save()
        let rail = try #require(StorageLocationService.create(
            name: "Rail", in: w, parent: nil, context: ctx))

        ModelSave.forceFailure(on: ctx)
        _ = StorageLocationService.create(name: "Drawer", in: w, parent: rail, context: ctx)
        ModelSave.clearForcedFailure(on: ctx)

        let retry = StorageLocationService.create(
            name: "Drawer", in: w, parent: rail, context: ctx)
        #expect(retry != nil, "同名重试被一个不存在的位置挡住了")
    }
}
