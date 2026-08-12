import Testing
import Foundation
import CoreGraphics
import SwiftData
@testable import ClosetModel
import ClosetCore

/// D95（缺口 #11，MVP-PLAN M1 SI-8）：三派生缩略图管线。
/// 此前网格里每一格都在解**全分辨率原图**去填 120pt 的方块——
/// 百件网格性能是 M1 退出门（§11.4 预算表），这是最直接的违反。
///
/// 三档：`grid`（网格方块）/ `detail`（详情大图）/ 原图（导出与叠衣层用）。
/// 派生**按需生成并落盘复用**，不是每次滚动重算。
@MainActor
struct DerivedThumbnailTests {
    init() { ItemImageTestRoot.install() }

    /// 造一张可辨认尺寸的 JPEG。
    func makeJPEG(width: Int, height: Int) throws -> Data {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: 0, space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue))
        ctx.setFillColor(CGColor(red: 0.4, green: 0.6, blue: 0.8, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(ctx.makeImage())
        return try #require(ItemImageDerivatives.encodeJPEG(image, quality: 0.9))
    }

    @Test func gridVariantIsMuchSmallerThanTheOriginal() throws {
        let original = try makeJPEG(width: 2000, height: 3000)
        let itemID = UUID()
        let rel = try #require(ItemImageStore.save(data: original, for: itemID))
        defer { ItemImageStore.deleteAll(relativePath: rel) }

        let gridData = try #require(
            ItemImageStore.derivedData(relativePath: rel, variant: .grid))
        #expect(gridData.count < original.count / 4)
        let size = try #require(ItemImageDerivatives.pixelSize(gridData))
        #expect(max(size.width, size.height) <= CGFloat(ItemImageVariant.grid.maxPixel))
    }

    /// 长边缩到目标，短边按比例——不得拉伸变形。
    @Test func aspectRatioIsPreserved() throws {
        let original = try makeJPEG(width: 1200, height: 400)
        let itemID = UUID()
        let rel = try #require(ItemImageStore.save(data: original, for: itemID))
        defer { ItemImageStore.deleteAll(relativePath: rel) }
        let data = try #require(ItemImageStore.derivedData(relativePath: rel, variant: .grid))
        let size = try #require(ItemImageDerivatives.pixelSize(data))
        #expect(abs(size.width / size.height - 3.0) < 0.05)
    }

    /// 比目标还小的图**不放大**（放大只会更糊更大）。
    @Test func smallerThanTargetIsNotUpscaled() throws {
        let original = try makeJPEG(width: 80, height: 120)
        let itemID = UUID()
        let rel = try #require(ItemImageStore.save(data: original, for: itemID))
        defer { ItemImageStore.deleteAll(relativePath: rel) }
        let data = try #require(ItemImageStore.derivedData(relativePath: rel, variant: .grid))
        let size = try #require(ItemImageDerivatives.pixelSize(data))
        #expect(size.width <= 80 && size.height <= 120)
    }

    /// 派生落盘复用：第二次取不得重新生成（否则滚动时每帧都在重算）。
    @Test func derivativesArePersistedAndReused() throws {
        let original = try makeJPEG(width: 1600, height: 1600)
        let itemID = UUID()
        let rel = try #require(ItemImageStore.save(data: original, for: itemID))
        defer { ItemImageStore.deleteAll(relativePath: rel) }

        #expect(ItemImageStore.derivedFileExists(relativePath: rel, variant: .grid) == false)
        _ = ItemImageStore.derivedData(relativePath: rel, variant: .grid)
        #expect(ItemImageStore.derivedFileExists(relativePath: rel, variant: .grid))
        // 复用路径：删掉原图后仍能拿到派生（证明不是每次从原图重算）
        ItemImageStore.delete(relativePath: rel)
        #expect(ItemImageStore.derivedData(relativePath: rel, variant: .grid) != nil)
    }

    /// 删单品图要**连派生一起删**——否则派生成了删不掉的孤儿，占着磁盘。
    @Test func deleteAllRemovesEveryVariant() throws {
        let original = try makeJPEG(width: 1600, height: 1600)
        let itemID = UUID()
        let rel = try #require(ItemImageStore.save(data: original, for: itemID))
        _ = ItemImageStore.derivedData(relativePath: rel, variant: .grid)
        _ = ItemImageStore.derivedData(relativePath: rel, variant: .detail)
        #expect(ItemImageStore.derivedFileExists(relativePath: rel, variant: .grid))

        ItemImageStore.deleteAll(relativePath: rel)
        #expect(!ItemImageStore.fileExists(relativePath: rel))
        #expect(!ItemImageStore.derivedFileExists(relativePath: rel, variant: .grid))
        #expect(!ItemImageStore.derivedFileExists(relativePath: rel, variant: .detail))
    }

    /// 原图不存在时诚实返回 nil（不造一张占位图冒充）。
    @Test func missingOriginalYieldsNil() {
        #expect(ItemImageStore.derivedData(
            relativePath: "ItemImages/gone-\(UUID().uuidString).jpg", variant: .grid) == nil)
        #expect(ItemImageStore.derivedData(relativePath: nil, variant: .grid) == nil)
    }

    /// 坏数据不得让派生崩掉（相册里塞进来的东西什么都可能）。
    @Test func corruptImageDataIsHandled() throws {
        let itemID = UUID()
        let rel = try #require(ItemImageStore.save(
            data: Data([0x00, 0x01, 0x02, 0x03]), for: itemID))
        defer { ItemImageStore.deleteAll(relativePath: rel) }
        #expect(ItemImageStore.derivedData(relativePath: rel, variant: .grid) == nil)
    }

    /// 三档尺寸单调递增，且各自有明确用途（不得两档一样大 = 白存一份）。
    @Test func variantsAreDistinctAndOrdered() {
        #expect(ItemImageVariant.grid.maxPixel < ItemImageVariant.detail.maxPixel)
        #expect(Set(ItemImageVariant.allCases.map(\.maxPixel)).count
                == ItemImageVariant.allCases.count)
        #expect(Set(ItemImageVariant.allCases.map(\.suffix)).count
                == ItemImageVariant.allCases.count)
    }
}

/// D95：派生文件必须被**全链认账**——孤儿清理不得把它们当垃圾扫掉，
/// 单品删除要连派生一起删。加了一类文件却漏掉这两处，就是自己制造抖动与残渣。
@MainActor
struct DerivedThumbnailLifecycleTests {
    init() { ItemImageTestRoot.install() }

    func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    func makeJPEG() throws -> Data {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = try #require(CGContext(
            data: nil, width: 900, height: 1200, bitsPerComponent: 8,
            bytesPerRow: 0, space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue))
        ctx.setFillColor(CGColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 900, height: 1200))
        let image = try #require(ctx.makeImage())
        return try #require(ItemImageDerivatives.encodeJPEG(image))
    }

    /// 孤儿清理不得误删在用单品的派生（否则每次对账后网格全部重算）。
    @Test func reconcileKeepsDerivativesOfLiveItems() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let item = Item(name: "tee"); item.slotRaw = "top"; item.wardrobe = w
        ctx.insert(item)
        let rel = try #require(ItemImageStore.save(data: try makeJPEG(), for: item.id))
        item.localImageRelativePath = rel
        try ctx.save()
        defer { ItemImageStore.deleteAll(relativePath: rel) }

        _ = ItemImageStore.derivedData(relativePath: rel, variant: .grid)
        #expect(ItemImageStore.derivedFileExists(relativePath: rel, variant: .grid))

        // 真的跑一次孤儿扫描。共享目录里有并行套件的文件，所以**不断言全局计数**
        //（那样只能靠关掉扫描才过 = 空转断言），只断言：我这份派生活下来了。
        let dir = try #require(ItemImageStore.rootDirectory)
        _ = ImageReconcileService.reconcile(in: ctx, directory: dir)
        #expect(ItemImageStore.derivedFileExists(relativePath: rel, variant: .grid))
        #expect(ItemImageStore.fileExists(relativePath: rel))
    }

    /// 真孤儿（无人引用的原图）连它的派生一起被扫掉。
    @Test func reconcileRemovesOrphanOriginalsAndTheirDerivatives() throws {
        let ctx = try makeContext()
        let strayID = UUID()
        let rel = try #require(ItemImageStore.save(data: try makeJPEG(), for: strayID))
        _ = ItemImageStore.derivedData(relativePath: rel, variant: .grid)
        #expect(ItemImageStore.derivedFileExists(relativePath: rel, variant: .grid))

        let dir = try #require(ItemImageStore.rootDirectory)
        let receipt = ImageReconcileService.reconcile(in: ctx, directory: dir)
        #expect(receipt.orphanFilesRemoved >= 1)
        #expect(!ItemImageStore.fileExists(relativePath: rel))
        #expect(!ItemImageStore.derivedFileExists(relativePath: rel, variant: .grid))
    }
}
