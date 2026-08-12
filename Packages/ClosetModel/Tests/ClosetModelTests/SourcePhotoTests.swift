import Testing
import Foundation
import SwiftData
@testable import ClosetModel
import ClosetCore

/// D111：导出文案承诺「your original photos」，而**从来没有存过原图**——
/// 落盘的只有归一后的叠衣层（紧裁剪 + 512×768 画布 + 重编码 PNG）。
/// 相机拍的那张不进相册（`UIImagePickerController` 只取 `jpegData` 转手），
/// 所以对拍照入库的件来说，用户的原始照片被**永久丢弃**了。
///
/// 处置：把用户加的那张照片作为**旁挂档**存下来（`<stem>@source.jpg`，长边 ≤2048），
/// 导出带上它、删除连它一起删、对账不把它当孤儿。
/// 文案随之改成说得出口的话——不再叫「original」，因为存的是压过的副本。
@MainActor
struct SourcePhotoTests {

    /// 1×1 JPEG（最小可解码源）
    private func tinyJPEG() -> Data {
        Data(base64Encoded: """
        /9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0a\
        HBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAA\
        AAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==
        """.replacingOccurrences(of: "\n", with: ""))!
    }

    private func makeStore() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    /// 旁挂路径与层图同目录、同 stem，扩展名固定 jpg。
    @Test func sourcePathSitsBesideTheLayerFile() {
        let rel = ItemImageStore.sourcePhotoRelativePath(
            relativePath: "ItemImages/ABC-123.png")
        #expect(rel == "ItemImages/ABC-123@source.jpg")
    }

    /// 空/无路径 → nil（不造路径）。
    @Test func noLayerMeansNoSourcePath() {
        #expect(ItemImageStore.sourcePhotoRelativePath(relativePath: nil) == nil)
        #expect(ItemImageStore.sourcePhotoRelativePath(relativePath: "") == nil)
    }

    /// 存得下、读得回。
    @Test func sourcePhotoRoundTrips() throws {
        let id = UUID()
        let layer = try #require(ItemImageStore.save(data: tinyJPEG(), for: id, ext: "png"))
        defer { ItemImageStore.deleteAll(relativePath: layer) }
        let src = try #require(ItemImageStore.saveSourcePhoto(tinyJPEG(), layerRelativePath: layer))
        #expect(ItemImageStore.fileExists(relativePath: src))
        #expect(ItemImageStore.loadData(relativePath: src) != nil)
    }

    /// 删层图连旁挂一起删——否则用户「删了这件」之后照片还留在盘上。
    @Test func deletingTheItemImageAlsoDeletesTheSourcePhoto() throws {
        let id = UUID()
        let layer = try #require(ItemImageStore.save(data: tinyJPEG(), for: id, ext: "png"))
        let src = try #require(ItemImageStore.saveSourcePhoto(tinyJPEG(), layerRelativePath: layer))
        ItemImageStore.deleteAll(relativePath: layer)
        #expect(!ItemImageStore.fileExists(relativePath: src),
                "删件之后用户的照片还留在盘上 —— 删除权没兑现")
    }

    /// 对账不得把旁挂当孤儿扫掉。
    @Test func reconcileKeepsTheSourcePhoto() throws {
        let ctx = try makeStore()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let item = Item(name: "Tee"); item.wardrobe = w; ctx.insert(item)
        let layer = try #require(ItemImageStore.save(data: tinyJPEG(), for: item.id, ext: "png"))
        item.localImageRelativePath = layer
        try ctx.save()
        let src = try #require(ItemImageStore.saveSourcePhoto(tinyJPEG(), layerRelativePath: layer))
        defer { ItemImageStore.deleteAll(relativePath: layer) }

        // 扫描目录必须是**本用例自己的**：`reconcile(in:)` 默认扫生产根，
        // 并发跑的其他用例的文件会被当孤儿一起删掉（本波审计确认的 live flake，
        // 而这行正是我自己一小时前写下的）。照 `ImageReconcileServiceTests` 的
        // scanDir 写法收口：把两个文件按同名复制进临时目录，rel 串照样对得上。
        let scanDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("source-photo-scan-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: scanDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scanDir) }
        for rel in [layer, src] {
            let from = try #require(ItemImageStore.absoluteURL(relativePath: rel))
            try FileManager.default.copyItem(
                at: from, to: scanDir.appendingPathComponent(from.lastPathComponent))
        }
        _ = ImageReconcileService.reconcile(in: ctx, directory: scanDir)
        #expect(FileManager.default.fileExists(
            atPath: scanDir.appendingPathComponent(
                URL(fileURLWithPath: src).lastPathComponent).path),
                "对账把用户的照片当孤儿删了")
    }

    /// 导出必须带上它 —— 这正是「take everything with you」的兑现物。
    @Test func exportCarriesTheSourcePhoto() throws {
        let ctx = try makeStore()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let item = Item(name: "Tee"); item.wardrobe = w; ctx.insert(item)
        let layer = try #require(ItemImageStore.save(data: tinyJPEG(), for: item.id, ext: "png"))
        item.localImageRelativePath = layer
        try ctx.save()
        _ = ItemImageStore.saveSourcePhoto(tinyJPEG(), layerRelativePath: layer)
        defer { ItemImageStore.deleteAll(relativePath: layer) }

        let plan = try ExportBundleService.plan(in: ctx, includeBodyDimensions: false)
        #expect(plan.photos.count == 2,
                Comment(rawValue: "导出只带了 \(plan.photos.count) 个文件：\(plan.photos.map(\.archiveName))"))
        #expect(plan.photos.contains { $0.archiveName.contains("@source") })
    }

    /// 没有旁挂的存量件照常导出（不因缺档失败、也不虚报）。
    @Test func legacyItemsWithoutASourcePhotoStillExport() throws {
        let ctx = try makeStore()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let item = Item(name: "Tee"); item.wardrobe = w; ctx.insert(item)
        let layer = try #require(ItemImageStore.save(data: tinyJPEG(), for: item.id, ext: "png"))
        item.localImageRelativePath = layer
        try ctx.save()
        defer { ItemImageStore.deleteAll(relativePath: layer) }

        let plan = try ExportBundleService.plan(in: ctx, includeBodyDimensions: false)
        #expect(plan.photos.count == 1)
    }

    /// 归档名确定（同一份数据导两次得到同样的包）。
    @Test func archiveNamesAreDeterministic() throws {
        let ctx = try makeStore()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let item = Item(name: "Tee"); item.wardrobe = w; ctx.insert(item)
        let layer = try #require(ItemImageStore.save(data: tinyJPEG(), for: item.id, ext: "png"))
        item.localImageRelativePath = layer
        try ctx.save()
        _ = ItemImageStore.saveSourcePhoto(tinyJPEG(), layerRelativePath: layer)
        defer { ItemImageStore.deleteAll(relativePath: layer) }

        let a = try ExportBundleService.plan(in: ctx, includeBodyDimensions: false)
        let b = try ExportBundleService.plan(in: ctx, includeBodyDimensions: false)
        #expect(a.photos.map(\.archiveName) == b.photos.map(\.archiveName))
    }

    /// 坏数据不落一个假文件（读不出来的东西不冒充照片）。
    @Test func undecodableDataIsNotStored() throws {
        let id = UUID()
        let layer = try #require(ItemImageStore.save(data: tinyJPEG(), for: id, ext: "png"))
        defer { ItemImageStore.deleteAll(relativePath: layer) }
        #expect(ItemImageStore.saveSourcePhoto(Data([0, 1, 2, 3]), layerRelativePath: layer) == nil)
    }
}
