import Testing
import SwiftData
import Foundation
@testable import ClosetModel
import ClosetCore

/// D87：数据导出补原图（§10.6 spec = JSON 全实体 + 原图 ZIP）。
/// 此前只出 JSON，且 JSON 里的 `localImageRelativePath` 是指向沙箱的死路径——
/// 用户拿到的是一串打不开的路径，数据可携带性不诚实。
@MainActor
struct ExportBundleServiceTests {
    init() { ItemImageTestRoot.install() }

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-bundle-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func planCarriesJSONAndOnlyExistingPhotos() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let withPhoto = Item(name: "tee"); withPhoto.slotRaw = "top"; withPhoto.wardrobe = w
        ctx.insert(withPhoto)
        let rel = ItemImageStore.save(data: Data([0x1, 0x2]), for: withPhoto.id, ext: "jpg")
        withPhoto.localImageRelativePath = rel
        // 反向孤儿：行指向已消失的文件 → 跳过，不得让整个导出失败
        let orphan = Item(name: "ghost"); orphan.slotRaw = "top"; orphan.wardrobe = w
        orphan.localImageRelativePath = "ItemImages/gone-\(UUID().uuidString).jpg"
        ctx.insert(orphan)
        // 无照片单品
        let bare = Item(name: "bare"); bare.slotRaw = "top"; bare.wardrobe = w; ctx.insert(bare)
        try ctx.save()
        defer { ItemImageStore.delete(relativePath: rel) }

        let plan = try ExportBundleService.plan(in: ctx, includeBodyDimensions: false)
        #expect(plan.json.contains("\"items\""))
        #expect(plan.photos.count == 1)
        #expect(plan.photos[0].archiveName.hasSuffix(".jpg"))
        #expect(plan.photos[0].archiveName.contains(withPhoto.id.uuidString))
        // 归档内名字确定（按名排序，导出可复现）
        #expect(plan.photos.map(\.archiveName) == plan.photos.map(\.archiveName).sorted())
    }

    @Test func planHonorsBodyDimensionOptIn() throws {
        let ctx = try makeContext()
        let p = Person(name: "Ada"); ctx.insert(p)
        let body = PersonBodyProfile(personID: p.id); body.bustInches = 34
        ctx.insert(body)
        try ctx.save()
        // 断言字段名而非数值——"34" 会随机出现在 UUID 里（松断言 = 时红时绿）
        let without = try ExportBundleService.plan(in: ctx, includeBodyDimensions: false)
        #expect(!without.json.contains("bustInches"))
        #expect(!without.json.contains("bodyProfiles"))
        let with = try ExportBundleService.plan(in: ctx, includeBodyDimensions: true)
        #expect(with.json.contains("bustInches"))
    }

    /// 压缩必须能在**非主线程**跑完（几百张图的 zip 在 MainActor 上会冻结 UI 数秒到数分钟）。
    @Test func writeBundleProducesZipOffMainActor() async throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "tee"); i.slotRaw = "top"; i.wardrobe = w; ctx.insert(i)
        let rel = ItemImageStore.save(data: Data(repeating: 0x7, count: 2048), for: i.id, ext: "jpg")
        i.localImageRelativePath = rel
        try ctx.save()
        defer { ItemImageStore.delete(relativePath: rel) }

        let plan = try ExportBundleService.plan(in: ctx, includeBodyDimensions: false)
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let zip = try await Task.detached(priority: .userInitiated) {
            try ExportBundleService.writeBundle(plan, in: dir).url
        }.value
        #expect(zip.pathExtension == "zip")
        #expect(FileManager.default.fileExists(atPath: zip.path))
        let size = (try FileManager.default.attributesOfItem(atPath: zip.path)[.size] as? Int) ?? 0
        #expect(size > 0)
        // 打包目录（staging）不得留下——只留 zip
        let entries = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(entries == [zip.lastPathComponent])
    }

    /// 零照片衣柜也要能导出（只含 JSON 的 zip，不报错）。
    @Test func writeBundleWorksWithNoPhotos() async throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        try ctx.save()
        let plan = try ExportBundleService.plan(in: ctx, includeBodyDimensions: false)
        #expect(plan.photos.isEmpty)
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let zip = try await Task.detached {
            try ExportBundleService.writeBundle(plan, in: dir).url }.value
        #expect(FileManager.default.fileExists(atPath: zip.path))
    }

    /// 文案：必须说清 zip 里有什么（JSON + 原图），且导出成功不得谎称含身体维度。
    @Test func bundleCopyIsHonestAboutContents() {
        #expect(ExportBundleService.bundleReadyMessage
            .localizedCaseInsensitiveContains("photo"))
        #expect(ExportBundleService.bundleFailedMessage
            .localizedCaseInsensitiveContains("couldn't"))
        #expect(ExportBundleService.archiveJSONName == "data.json")
        #expect(ExportBundleService.archivePhotosFolder == "photos")
    }
}

/// D88：导出包的诚实与清理。
/// - 归档结构此前只在注释里声称（`data.json` + `photos/<id>.<ext>`），从未解压验证过；
///   实际 NSFileCoordinator 的 .forUploading 压的是目录本身，条目多一层顶层目录。
/// - 单张照片复制失败被 `try?` 吞掉（弹性取舍本身合理），但成功文案无条件说
///   「JSON plus your item photos」——一张都没进包时这是谎报。
/// - 每次导出建一个 `tmp/export-<uuid>/`，分享面板只删了里面的 zip，目录永远留着。
@MainActor
struct ExportBundleHonestyTests {
    init() { ItemImageTestRoot.install() }

    func makeContext() throws -> ModelContext {
        try ModelContext(ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-honesty-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 解压验证归档真的装着 JSON 与照片（此前只断言 zip 存在、体积 > 0）。
    @Test func archiveActuallyContainsJSONAndPhotos() async throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "tee"); i.slotRaw = "top"; i.wardrobe = w; ctx.insert(i)
        let rel = try #require(ItemImageStore.save(
            data: Data(repeating: 0x7, count: 512), for: i.id, ext: "jpg"))
        i.localImageRelativePath = rel
        try ctx.save()
        defer { ItemImageStore.delete(relativePath: rel) }

        let plan = try ExportBundleService.plan(in: ctx, includeBodyDimensions: false)
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let out = try await Task.detached { try ExportBundleService.writeBundle(plan, in: dir) }.value
        #expect(out.copiedPhotos == 1)
        #expect(out.plannedPhotos == 1)

        let listing = try unzipListing(out.url)
        #expect(listing.contains { $0.hasSuffix("/\(ExportBundleService.archiveJSONName)") },
                Comment(rawValue: "归档内容：\(listing)"))
        #expect(listing.contains { $0.contains("/\(ExportBundleService.archivePhotosFolder)/")
                    && $0.hasSuffix(".jpg") })
        // 注释与文档声称的根目录必须与实际一致
        #expect(listing.allSatisfy { $0.hasPrefix(ExportBundleService.archiveRootName + "/") })
    }

    /// 源文件在 plan 与 write 之间消失 → 不抛错、zip 照出，但**照片数如实为 0**。
    @Test func vanishedSourceYieldsHonestZeroCount() async throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "tee"); i.slotRaw = "top"; i.wardrobe = w; ctx.insert(i)
        let rel = try #require(ItemImageStore.save(data: Data([0x1]), for: i.id, ext: "jpg"))
        i.localImageRelativePath = rel
        try ctx.save()

        let plan = try ExportBundleService.plan(in: ctx, includeBodyDimensions: false)
        #expect(plan.photos.count == 1)
        ItemImageStore.delete(relativePath: rel)   // 计划之后、写入之前被删

        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let out = try await Task.detached { try ExportBundleService.writeBundle(plan, in: dir) }.value
        #expect(FileManager.default.fileExists(atPath: out.url.path))
        #expect(out.copiedPhotos == 0)
        #expect(out.plannedPhotos == 1)
    }

    /// 文案按**实际**装进去的数量说话，不按计划说话。
    @Test func readyMessageCountsWhatActuallyMadeIt() {
        let all = ExportBundleService.readyMessage(copied: 3, planned: 3)
        #expect(all.localizedCaseInsensitiveContains("3 photos"))
        let partial = ExportBundleService.readyMessage(copied: 1, planned: 3)
        #expect(partial.contains("1"))
        #expect(partial.localizedCaseInsensitiveContains("couldn't"))
        let none = ExportBundleService.readyMessage(copied: 0, planned: 2)
        #expect(!none.localizedCaseInsensitiveContains("plus 0"))
        #expect(none.localizedCaseInsensitiveContains("couldn't be read"))
        // 双重否定读起来像「全都读到了」——文案必须一眼看懂
        #expect(!none.localizedCaseInsensitiveContains("none of"))
        #expect(none.localizedCaseInsensitiveContains("json only"))
        // 本来就没有照片的衣柜：别提照片
        let empty = ExportBundleService.readyMessage(copied: 0, planned: 0)
        #expect(!empty.localizedCaseInsensitiveContains("photo"))
        #expect(!empty.localizedCaseInsensitiveContains("couldn't"))
    }

    /// 遗留的 export-* 临时目录要能被回收（与 cinematic MP4 的 sweep 同纪律）。
    @Test func sweepReclaimsAbandonedExportDirectories() throws {
        let root = try tempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let stale = root.appendingPathComponent("export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: stale, withIntermediateDirectories: true)
        try Data([0x1]).write(to: stale.appendingPathComponent("loomies-export.zip"))
        let unrelated = root.appendingPathComponent("keep-me", isDirectory: true)
        try FileManager.default.createDirectory(at: unrelated, withIntermediateDirectories: true)

        ExportBundleService.sweepTemporaryExports(in: root)
        #expect(!FileManager.default.fileExists(atPath: stale.path))
        #expect(FileManager.default.fileExists(atPath: unrelated.path))
    }

    private func unzipListing(_ url: URL) throws -> [String] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        p.arguments = ["-Z1", url.path]
        let pipe = Pipe()
        p.standardOutput = pipe
        try p.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
            .split(separator: "\n").map(String.init)
    }
}
