import Testing
import SwiftData
import Foundation
@testable import ClosetModel
import ClosetCore

/// 图片目录 ↔ DB 对账：崩溃窗口/部分失败产生的孤儿文件与死路径无人回收——
/// 全仓此前无任何 reconcile 机制（wipe 只在 Delete all 内部）。
@MainActor
struct ImageReconcileServiceTests {
    init() { ItemImageTestRoot.install() }   // 触盘套件：根目录按进程隔离，勿写真机目录


    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    @Test(.serialized) func removesOrphanFilesAndClearsDeadPaths() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        // 正常件：行与文件都在 → 不动
        let ok = Item(name: "ok"); ok.slotRaw = "top"; ok.wardrobe = w; ctx.insert(ok)
        let okRel = ItemImageStore.save(data: Data([0x1]), for: ok.id, ext: "jpg")
        ok.localImageRelativePath = okRel
        // 死路径件：行在、文件没了 → 路径清 nil（UI 回到诚实「无照片」态）
        let dead = Item(name: "dead"); dead.slotRaw = "top"; dead.wardrobe = w; ctx.insert(dead)
        dead.localImageRelativePath = "ItemImages/gone-\(UUID().uuidString).jpg"
        try ctx.save()
        // 孤儿文件：文件在、无任何行引用 → 删文件
        let orphanRel = ItemImageStore.save(data: Data([0x2]), for: UUID(), ext: "jpg")
        #expect(ItemImageStore.loadData(relativePath: orphanRel) != nil)

        let receipt = ImageReconcileService.reconcile(in: ctx)
        #expect(receipt.orphanFilesRemoved == 1)
        #expect(receipt.deadPathsCleared == 1)
        #expect(ItemImageStore.loadData(relativePath: orphanRel) == nil)
        #expect(dead.localImageRelativePath == nil)
        // 正常件不受影响
        #expect(ok.localImageRelativePath == okRel)
        #expect(ItemImageStore.loadData(relativePath: okRel) != nil)
        ItemImageStore.delete(relativePath: okRel)
    }

    @Test(.serialized) func reconcileIsIdempotentAndCheapWhenClean() throws {
        let ctx = try makeContext()
        let first = ImageReconcileService.reconcile(in: ctx)
        let second = ImageReconcileService.reconcile(in: ctx)
        #expect(first.orphanFilesRemoved == 0 || second.orphanFilesRemoved == 0)
        #expect(second.deadPathsCleared == 0)
    }

    /// save 失败：死路径清理回滚（内存还原 + rollback），孤儿文件删除不受影响（无 DB 依赖）。
    @Test(.serialized) func deadPathClearRollsBackOnSaveFailure() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let dead = Item(name: "dead"); dead.slotRaw = "top"; dead.wardrobe = w; ctx.insert(dead)
        let deadPath = "ItemImages/gone-\(UUID().uuidString).jpg"
        dead.localImageRelativePath = deadPath
        try ctx.save()
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        let receipt = ImageReconcileService.reconcile(in: ctx)
        #expect(receipt.deadPathsCleared == 0)
        #expect(dead.localImageRelativePath == deadPath)
        #expect(!ctx.hasChanges)
    }
}
