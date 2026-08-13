import Testing
import Foundation
import SwiftData
@testable import ClosetIntake
import ClosetModel
import ClosetCore

/// D193：确认页对**这些字段是哪来的**说得不准。
///
/// 1. 「Brand and size were read from the label photo」只看
///    `brand != nil || size != nil`——而这两个字段用户自己敲、条码富化写入
///    都会让它非空。模拟器/macOS 走 `MockOCRService(info: LabelInfo())`
///    （brand/size 恒 nil），真机 OCR 认不出品牌时用户手敲——两条路上
///    那句话都是**假的**。
///    而本该当判据的那个开关 `labelOCRAvailable` 全仓零生产调用点。
/// 2. 颜色是从像素投票猜的（D124），确认页一个字没说——
///    它渲染成一个已选色点，与用户手选的形态不可区分，
///    而颜色是 `OutfitScorer` 的输入。
///
/// 两条同一个形状：**界面把「猜的」与「用户给的」画成一个样子。**
@MainActor
struct PrefillProvenanceTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    private func makeVM(
        label: LabelInfo = LabelInfo(),
        tags: ItemTags = ItemTags(slot: .top)
    ) -> IntakeViewModel {
        IntakeViewModel(
            matting: MockMattingService(),
            tagging: MockTaggingService(tags: tags),
            ocr: MockOCRService(info: label),
            productLookup: nil)
    }

    /// OCR 什么都没读出来时，**不许**说「是从洗标读的」。
    @Test func nothingReadMeansNoLabelClaim() async {
        let vm = makeVM()
        await vm.process(TestImages.png(width: 200, height: 300))
        #expect(vm.brandOrSizeFromLabel == false, Comment(rawValue:
            "OCR 一个字段都没填，界面却会说「Brand and size were read from the label photo」"))
    }

    /// 用户自己敲的品牌不算「读出来的」。
    @Test func typingABrandDoesNotMakeItAReading() async {
        let vm = makeVM()
        await vm.process(TestImages.png(width: 200, height: 300))
        vm.draft?.brand = "Uniqlo"
        #expect(vm.brandOrSizeFromLabel == false)
    }

    /// 真读出来了才说。
    @Test func aRealReadingIsDeclared() async {
        let vm = makeVM(label: LabelInfo(brand: "Uniqlo", size: "M"))
        await vm.process(TestImages.png(width: 200, height: 300))
        #expect(vm.brandOrSizeFromLabel, "OCR 真读出来了却不说")
        #expect(vm.draft?.brand == "Uniqlo")
    }

    /// 换一张照片要重新判（上一张读出来了不代表这一张也读得出）。
    @Test func eachPhotoIsJudgedOnItsOwn() async {
        let vm = makeVM(label: LabelInfo(brand: "Uniqlo", size: "M"))
        await vm.process(TestImages.png(width: 200, height: 300))
        #expect(vm.brandOrSizeFromLabel)
        vm.reset()
        #expect(vm.brandOrSizeFromLabel == false, "reset 之后还留着上一张的判断")
    }

    /// 颜色是猜的就要说出来。
    @Test func aGuessedColourIsDeclared() async {
        let vm = makeVM()
        await vm.process(TestImages.png(width: 200, height: 300))
        // Mock 抠图直通，主色采样在这张纯色图上会命中
        if vm.draft?.color != nil {
            #expect(vm.colorFromPhoto, "颜色是从像素猜的，确认页却一个字不说")
        }
    }

    /// 打标器直接给了颜色时不算「从像素猜的」（那是另一条来源）。
    @Test func aTaggedColourIsNotAPixelGuess() async {
        let tagged = ItemTags(slot: .top, color: GarmentColor(hueDegrees: 210, isNeutral: false))
        let vm = makeVM(tags: tagged)
        await vm.process(TestImages.png(width: 200, height: 300))
        #expect(vm.draft?.color != nil)
        #expect(vm.colorFromPhoto == false)
    }

    /// 两句披露都得说清「这是猜的 / 这是读的」，且给下一步。
    @Test func bothDisclosuresAreHonest() {
        let label = IntakeServiceFactory.labelReadDisclosure
        #expect(label.localizedCaseInsensitiveContains("check"))
        let colour = IntakeServiceFactory.colorGuessDisclosure
        #expect(colour.localizedCaseInsensitiveContains("photo")
                || colour.localizedCaseInsensitiveContains("guess"))
        #expect(colour.localizedCaseInsensitiveContains("change")
                || colour.localizedCaseInsensitiveContains("pick"),
                Comment(rawValue: "没说怎么改：\(colour)"))
    }

    /// 结构门：**披露的判据不许再退回「字段非空」。**
    @Test func theDisclosureIsGatedOnProvenanceNotEmptiness() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ClosetUI/Sources/ClosetUI/PhotoCaptureViews.swift")
        let text = try String(contentsOf: url, encoding: .utf8)
        let lines = text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let i = lines.firstIndex(where: {
            $0.contains("labelReadDisclosure") && !$0.hasPrefix("//")
        }) else {
            Issue.record("确认页里找不到洗标披露"); return
        }
        // 往上找它挂在哪个条件上
        let guardLine = lines[max(0, i - 4)..<i].last { $0.hasPrefix("if ") } ?? ""
        #expect(guardLine.contains("FromLabel"), Comment(rawValue:
            "披露仍挂在「字段非空」上：\(guardLine)"))
    }
}
