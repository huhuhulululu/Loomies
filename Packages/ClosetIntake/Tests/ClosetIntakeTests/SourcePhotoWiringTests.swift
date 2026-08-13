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

/// D123：**披露必须与实际接了什么对齐**。
///
/// D102 的教训：`makeTagging`/`makeOCR` 一律返回 mock，而「识别成功」路径上
/// 用户看到预填好的字段却没有任何提示说那不是识别结果——
/// 不诚实正好落在最常走的那条路上。现在洗标 OCR 真接了 Vision，
/// 而**打标仍是 mock**：两件事必须分开说，混成一个开关会让文案再次说错话。
@MainActor
struct RecognitionDisclosureTests {

    /// 两个能力位是分开的（合并成一个必然导致文案说谎）。
    @Test func theTwoCapabilitiesAreTrackedSeparately() {
        // 打标仍是 mock —— 这条为 true 的那天要连同披露一起改
        #expect(IntakeServiceFactory.recognitionAvailable == false)
        // OCR 按平台解析；macOS 测试环境下应为 false
        #expect(IntakeServiceFactory.labelOCRAvailable == false)
    }

    /// 未接打标时的披露只能说「类型和场合」是猜的——
    /// 不能再顺带声称品牌/尺码也是猜的（那是 OCR 读出来的）。
    @Test func thePrefillDisclosureOnlyClaimsWhatIsGuessed() {
        let text = IntakeServiceFactory.prefillDisclosure.lowercased()
        #expect(text.contains("type"))
        #expect(!text.contains("brand"),
                "披露仍说品牌是猜的 —— 而它现在是从洗标读出来的")
        #expect(!text.contains("size"))
    }

    /// 读到的东西要说清是**读**出来的，与猜的分开。
    @Test func theLabelDisclosureSaysItWasRead() {
        let text = IntakeServiceFactory.labelReadDisclosure.lowercased()
        #expect(text.contains("read"))
        #expect(text.contains("check"), "读出来的也要请用户核对（OCR 会错）")
    }

    /// 生产源码里必须真的用上 `VisionOCRService`（否则又是零调用点）。
    @Test func theFactoryActuallySelectsTheVisionImplementation() throws {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/ClosetIntake/IntakeServiceFactory.swift")
        let text = try String(contentsOf: file, encoding: .utf8)
        #expect(text.contains("VisionOCRService()"))
    }
}

/// D124：主色必须真的**填进草稿**——否则 `DominantColor` 就是又一个
/// 「算出来了没人调」。
@MainActor
struct DominantColorWiringTests {

    /// 纯色图入库后，草稿里带上了颜色。
    @Test func aSolidColourPhotoFillsTheDraftColour() async throws {
        let vm = IntakeViewModel(
            matting: MockMattingService(),
            tagging: MockTaggingService(tags: ItemTags(
                slot: .top, color: nil, occasions: ["casual"], warmth: .light)))
        await vm.process(try solidPNG(red: 0.13, green: 0.19, blue: 0.35))   // navy
        let draft = try #require(vm.draft)
        #expect(draft.color != nil, "抠好的图里有明确主色，草稿的颜色却还是未知")
    }

    /// 打标已经给出颜色时**不覆盖**——用户/模型给的优先于像素投票。
    @Test func anExistingTagColourWins() async throws {
        let tagged = GarmentColor(hueDegrees: 350, isNeutral: false)
        let vm = IntakeViewModel(
            matting: MockMattingService(),
            tagging: MockTaggingService(tags: ItemTags(
                slot: .top, color: tagged, occasions: ["casual"], warmth: .light)))
        await vm.process(try solidPNG(red: 0.13, green: 0.19, blue: 0.35))
        #expect(vm.draft?.color == tagged, "像素投票盖掉了打标给出的颜色")
    }

    /// 生产源码里必须存在调用点。
    @Test func theSamplerIsWiredIntoIntake() throws {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/ClosetIntake/IntakeViewModel.swift")
        let text = try String(contentsOf: file, encoding: .utf8)
        #expect(text.contains("DominantColorSampler.dominantEntry"))
    }

    /// 指定颜色的极小 PNG。
    private func solidPNG(red: Double, green: Double, blue: Double) throws -> Data {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = try #require(CGContext(
            data: nil, width: 8, height: 8,
            bitsPerComponent: 8, bytesPerRow: 32,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.setFillColor(red: red, green: green, blue: blue, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        let img = try #require(ctx.makeImage())
        let data = NSMutableData()
        let dest = try #require(CGImageDestinationCreateWithData(
            data, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(dest, img, nil)
        #expect(CGImageDestinationFinalize(dest))
        return data as Data
    }
}
