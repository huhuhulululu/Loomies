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

    /// 私有扫描目录：共享 per-process 根上其他套件并发写文件，按共享根扫孤儿
    /// 既数不准（计入别家文件）又会误删（把并发测试在用的文件当孤儿）。
    func makeScanDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("reconcile-scan-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func removesOrphanFilesAndClearsDeadPaths() throws {
        let ctx = try makeContext()
        let scanDir = try makeScanDir()
        defer { try? FileManager.default.removeItem(at: scanDir) }
        let w = Wardrobe(name: "A"); ctx.insert(w)
        // 正常件：行与文件都在 → 不动（存在性检查走生产根，路径唯一无竞态）
        let ok = Item(name: "ok"); ok.slotRaw = "top"; ok.wardrobe = w; ctx.insert(ok)
        let okRel = ItemImageStore.save(data: Data([0x1]), for: ok.id, ext: "jpg")
        ok.localImageRelativePath = okRel
        // 死路径件：行在、文件没了 → 路径清 nil（UI 回到诚实「无照片」态）
        let dead = Item(name: "dead"); dead.slotRaw = "top"; dead.wardrobe = w; ctx.insert(dead)
        dead.localImageRelativePath = "ItemImages/gone-\(UUID().uuidString).jpg"
        try ctx.save()
        // 孤儿文件：扫描目录里存在、无任何行引用 → 删文件
        let orphanURL = scanDir.appendingPathComponent("\(UUID().uuidString).jpg")
        try Data([0x2]).write(to: orphanURL)

        let receipt = ImageReconcileService.reconcile(in: ctx, directory: scanDir)
        #expect(receipt.orphanFilesRemoved == 1)
        #expect(receipt.deadPathsCleared == 1)
        #expect(!FileManager.default.fileExists(atPath: orphanURL.path))
        #expect(dead.localImageRelativePath == nil)
        // 正常件不受影响
        #expect(ok.localImageRelativePath == okRel)
        #expect(ItemImageStore.loadData(relativePath: okRel) != nil)
        ItemImageStore.delete(relativePath: okRel)
    }

    @Test func reconcileIsIdempotentAndCheapWhenClean() throws {
        let ctx = try makeContext()
        let scanDir = try makeScanDir()
        defer { try? FileManager.default.removeItem(at: scanDir) }
        let first = ImageReconcileService.reconcile(in: ctx, directory: scanDir)
        let second = ImageReconcileService.reconcile(in: ctx, directory: scanDir)
        #expect(first == ImageReconcileService.Receipt(orphanFilesRemoved: 0, deadPathsCleared: 0))
        #expect(second == first)
    }

    /// save 失败：死路径清理回滚（内存还原 + rollback），孤儿文件删除不受影响（无 DB 依赖）。
    @Test func deadPathClearRollsBackOnSaveFailure() throws {
        let ctx = try makeContext()
        let scanDir = try makeScanDir()
        defer { try? FileManager.default.removeItem(at: scanDir) }
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let dead = Item(name: "dead"); dead.slotRaw = "top"; dead.wardrobe = w; ctx.insert(dead)
        let deadPath = "ItemImages/gone-\(UUID().uuidString).jpg"
        dead.localImageRelativePath = deadPath
        try ctx.save()
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        let receipt = ImageReconcileService.reconcile(in: ctx, directory: scanDir)
        #expect(receipt.deadPathsCleared == 0)
        #expect(dead.localImageRelativePath == deadPath)
        #expect(!ctx.hasChanges)
    }
}
