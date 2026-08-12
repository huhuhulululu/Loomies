import Testing
import Foundation
import CoreGraphics
import ImageIO
import SwiftData
@testable import ClosetIntake
import ClosetModel
import ClosetCore

/// D111 接线门：旁挂原图这个能力必须真的**在入库时被写**。
/// 本仓的复发病正是「能力实现了 + 测试写了 + 零调用点」——
/// `ItemImageStore.saveSourcePhoto` 若只有单测调用，等于没做。
@MainActor
struct SourcePhotoWiringTests {

    /// 与 IntakeTests 同法的可解码极小 PNG（归一成功路径才会落层图）。
    private func tinyPNG() throws -> Data {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = try #require(CGContext(
            data: nil, width: 4, height: 4,
            bitsPerComponent: 8, bytesPerRow: 16,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.setFillColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        let img = try #require(ctx.makeImage())
        let data = NSMutableData()
        let dest = try #require(CGImageDestinationCreateWithData(
            data, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(dest, img, nil)
        #expect(CGImageDestinationFinalize(dest))
        return data as Data
    }

    /// 生产源码里必须存在调用点（不是只有测试在用）。
    @Test func intakeActuallyPersistsTheSourcePhoto() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // ClosetIntakeTests
            .deletingLastPathComponent()      // Tests
            .deletingLastPathComponent()      // ClosetIntake
            .deletingLastPathComponent()      // Packages
        var callSites: [String] = []
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: nil)
        else { return }
        for case let url as URL in walker where url.pathExtension == "swift" {
            let path = url.path
            // 排除定义处本身 —— 否则「它自己定义了自己」就算接线了（假阳性）
            guard !path.contains("/Tests/"), path.contains("/Sources/"),
                  url.lastPathComponent != "ItemImageStore.swift" else { continue }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if text.contains("saveSourcePhoto(") {
                callSites.append(url.lastPathComponent)
            }
        }
        #expect(!callSites.isEmpty,
                "saveSourcePhoto 零生产调用点 —— 用户的照片仍在被丢弃，导出仍兑现不了承诺")
    }

    /// 端到端：确认入库后，旁挂档在盘上。
    @Test func confirmWritesThePhotoBesideTheLayer() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let ctx = ModelContext(try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config))
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        try ctx.save()

        let vm = IntakeViewModel(
            matting: MockMattingService(),
            tagging: MockTaggingService(tags: ItemTags(
                slot: .top, color: GarmentColor(hueDegrees: 0, isNeutral: true),
                occasions: ["casual"], warmth: .light)))
        await vm.process(try tinyPNG())
        vm.draft?.name = "Tee"
        let item = vm.confirm(into: w, context: ctx)
        let layer = try #require(item?.localImageRelativePath)
        defer { ItemImageStore.deleteAll(relativePath: layer) }

        #expect(ItemImageStore.sourcePhotoExists(relativePath: layer),
                "确认入库没写旁挂原图 —— 用户拍的那张照片被丢了")
    }
}
