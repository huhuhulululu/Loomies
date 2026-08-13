import Testing
import Foundation
import SwiftData
@testable import ClosetIntake
import ClosetModel
import ClosetCore

/// D185：**入库失败的三条提示都叫用户「re-add the photo later」，
/// 而已入库的单品根本没有任何补图/换图入口。**
///
/// `item.localImageRelativePath` 的生产写入点只有三个：入库 `confirm()` 新建、
/// 演示数据播种、导入。详情页只有一个只读缩略图，全仓 grep
/// `retake|replace photo|add photo|change photo` 零命中。
///
/// 那三条提示恰恰出现在「衣服已经存进柜子、但图没跟上」的时刻
/// （抠图失败 / 归一失败 / 层图写盘失败）——用户被告知去做一件
/// App 里做不到的事。唯一的「re-add」是**删掉重来**，而删除是有损的：
/// 引用它的搭配会被标成 `permanentlyMissing`，穿着历史里这件从此显示为
/// 「no longer in this closet」。
///
/// 处置：真的把这条路补上（`ItemPhotoService.replacePhoto`），
/// 而不是把文案改软。文案随之说清去哪儿做。
@MainActor
struct ReplacePhotoTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    private func makeItem(_ ctx: ModelContext) throws -> Item {
        let w = Wardrobe(name: "Home"); ctx.insert(w)
        let item = Item(name: "Tee"); item.slotRaw = "top"; item.wardrobe = w
        ctx.insert(item); try ctx.save()
        return item
    }

    /// 造一张能被归一器读懂的 PNG。
    private func photo() -> Data { TestImages.png(width: 300, height: 400) }

    /// **本波的核心**：一件没有图的衣服，能补上图。
    @Test func aPieceWithNoPhotoCanGetOne() async throws {
        let ctx = try makeContext()
        let item = try makeItem(ctx)
        #expect(item.localImageRelativePath == nil)

        let outcome = await ItemPhotoService.replacePhoto(
            for: item, imageData: photo(), matting: MockMattingService(), in: ctx)
        #expect(outcome == .replaced, Comment(rawValue: "补图失败：\(outcome)"))
        let path = try #require(item.localImageRelativePath)
        #expect(ItemImageStore.loadData(relativePath: path) != nil, "路径写了，文件没写")
        defer { ItemImageStore.deleteAll(relativePath: path) }
    }

    /// 换图要把**旧的派生缩略图**一并作废——否则网格里还是上一张。
    @Test func replacingAPhotoDropsTheStaleThumbnails() async throws {
        let ctx = try makeContext()
        let item = try makeItem(ctx)
        _ = await ItemPhotoService.replacePhoto(
            for: item, imageData: photo(), matting: MockMattingService(), in: ctx)
        let path = try #require(item.localImageRelativePath)
        defer { ItemImageStore.deleteAll(relativePath: path) }
        // 生成一张派生（模拟网格滚动过）
        #expect(ItemImageStore.derivedData(relativePath: path, variant: .grid) != nil)
        #expect(ItemImageStore.derivedFileExists(relativePath: path, variant: .grid))

        _ = await ItemPhotoService.replacePhoto(
            for: item, imageData: TestImages.png(width: 240, height: 360),
            matting: MockMattingService(), in: ctx)
        #expect(!ItemImageStore.derivedFileExists(relativePath: path, variant: .grid),
                "旧缩略图还在 —— 用户换了图，网格里还是上一张")
    }

    /// 抠图失败**不落图**：整幅未抠的原图当叠衣层会变成胸口贴纸（入库同一条纪律）。
    @Test func aFailedCutoutDoesNotStoreTheUncutFrame() async throws {
        let ctx = try makeContext()
        let item = try makeItem(ctx)
        let outcome = await ItemPhotoService.replacePhoto(
            for: item, imageData: photo(), matting: FailingMattingService(), in: ctx)
        #expect(outcome == .cutoutFailed)
        #expect(item.localImageRelativePath == nil, "抠图失败却把未抠的整图存成了叠衣层")
    }

    /// 读不出来的数据 → 归一失败，同样不动这件衣服。
    @Test func unreadableDataChangesNothing() async throws {
        let ctx = try makeContext()
        let item = try makeItem(ctx)
        let outcome = await ItemPhotoService.replacePhoto(
            for: item, imageData: Data([0x00, 0x01, 0x02]),
            matting: MockMattingService(), in: ctx)
        #expect(outcome == .alignFailed)
        #expect(item.localImageRelativePath == nil)
    }

    /// 写盘失败要诚实（不静默声称换好了）。
    @Test func aDiskFailureIsReported() async throws {
        let ctx = try makeContext()
        let item = try makeItem(ctx)
        let outcome = await ItemImageStore.$forcedSaveFailure.withValue(true) {
            await ItemPhotoService.replacePhoto(
                for: item, imageData: photo(), matting: MockMattingService(), in: ctx)
        }
        #expect(outcome == .diskFailed)
        #expect(item.localImageRelativePath == nil)
    }

    /// 换图要保留**用户加的那张原图**旁挂档（导出承诺过它）。
    @Test func theSourcePhotoIsKeptAlongside() async throws {
        let ctx = try makeContext()
        let item = try makeItem(ctx)
        _ = await ItemPhotoService.replacePhoto(
            for: item, imageData: photo(), matting: MockMattingService(), in: ctx)
        let path = try #require(item.localImageRelativePath)
        defer { ItemImageStore.deleteAll(relativePath: path) }
        #expect(ItemImageStore.sourcePhotoExists(relativePath: path),
                "旁挂原图没落 —— 导出承诺的「你加的那张照片」兑现不了")
    }

    /// 每条结局都有一句用户读得懂的话，且**失败的话不许听起来像成功**。
    @Test func everyOutcomeHasHonestWords() {
        for outcome in ItemPhotoService.Outcome.allCases {
            let text = ItemPhotoService.message(for: outcome)
            #expect(!text.isEmpty, Comment(rawValue: "\(outcome) 没有文案"))
            if outcome != .replaced {
                #expect(text.localizedCaseInsensitiveContains("couldn't"),
                        Comment(rawValue: "\(outcome) 的失败文案听起来像成功：\(text)"))
            }
        }
    }

    /// 结构门：**那三条「re-add the photo later」不许再指向一条不存在的路。**
    ///
    /// 判据认构造：入库的失败文案里如果出现「re-add / add it again」这类
    /// 指令性说法，仓里就必须存在一条真的补图路径（`ItemPhotoService.replacePhoto`
    /// 有生产调用点）。文案与能力必须同生共死。
    @Test func theIntakeCopyPointsAtSomethingThatExists() throws {
        let copies = [
            IntakeViewModel.mattingFailedSavedMessage,
            IntakeViewModel.layerNormalizeFailedMessage,
            IntakeViewModel.layerImageSaveFailedMessage,
        ]
        let tellsUserToAddItBack = copies.contains {
            let t = $0.lowercased()
            return t.contains("re-add") || t.contains("add the photo")
                || t.contains("add a photo")
        }
        guard tellsUserToAddItBack else { return }   // 文案不再指路 → 无需路径
        let ui = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ClosetUI/Sources/ClosetUI")
        var callSites = 0
        for case let url as URL in FileManager.default
            .enumerator(at: ui, includingPropertiesForKeys: nil)!
        where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            callSites += text.split(separator: "\n").filter {
                let t = $0.trimmingCharacters(in: .whitespaces)
                return t.contains("ItemPhotoService.replacePhoto")
                    && !t.hasPrefix("//") && !t.hasPrefix("///")
            }.count
        }
        #expect(callSites > 0, Comment(rawValue:
            "入库失败文案叫用户「re-add the photo」，而界面上没有任何补图入口"))
    }
}

/// 抠图必失败（走「衣服在、图没跟上」那条路）。
private struct FailingMattingService: MattingService {
    struct Failure: Error {}
    func removeBackground(_ imageData: Data) async throws -> Data { throw Failure() }
}

/// D194：**「Add to closet」那一下不该才开始算叠衣层。**
///
/// D181 把解码封了顶（12MP 6597ms → 1657ms，debug），但那条链仍在主线程，
/// 而 `confirm()` 是一次原子的 SwiftData 写——改 async 会波及按钮闭包与
/// 批量队列的次序与重入。
///
/// 换个方向：用户在确认页填名字/改类型的这几秒里后台把层图备好，
/// confirm 只是取现成的。**正确性不依赖预备是否命中**——没备上就原地算。
@MainActor
struct LayerPreparationTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    private func makeVM() -> IntakeViewModel {
        IntakeViewModel(
            matting: MockMattingService(),
            tagging: MockTaggingService(tags: ItemTags(slot: .top)),
            ocr: nil, productLookup: nil)
    }

    /// 备好之后 confirm 用的是那一张（同一份字节）。
    @Test func aPreparedLayerIsWhatGetsSaved() async throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Home"); ctx.insert(w); try ctx.save()
        let vm = makeVM()
        await vm.process(TestImages.png(width: 400, height: 600))
        vm.draft?.name = "Tee"
        await vm.prepareLayer()

        let slot = IntakeViewModel.layerNormalizeSlot(
            slotRaw: vm.draft!.slot.rawValue, name: "Tee")
        let prepared = try #require(vm.preparedLayerPNG(slot: slot), "层图没备上")
        let item = try #require(vm.confirm(into: w, context: ctx))
        let path = try #require(item.localImageRelativePath)
        defer { ItemImageStore.deleteAll(relativePath: path) }
        #expect(ItemImageStore.loadData(relativePath: path) == prepared,
                "落盘的不是备好的那一张")
    }

    /// **没备上照样能入库**（正确性不依赖预备）。
    @Test func confirmingWithoutPreparationStillWorks() async throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Home"); ctx.insert(w); try ctx.save()
        let vm = makeVM()
        await vm.process(TestImages.png(width: 300, height: 400))
        vm.draft?.name = "Tee"
        // 不调 prepareLayer
        let item = try #require(vm.confirm(into: w, context: ctx))
        let path = try #require(item.localImageRelativePath)
        defer { ItemImageStore.deleteAll(relativePath: path) }
        #expect(ItemImageStore.loadData(relativePath: path) != nil)
    }

    /// 改了类型 → 备好的那张作废（槽位不同，画布对齐也不同）。
    @Test func changingTheTypeInvalidatesThePreparedLayer() async throws {
        let vm = makeVM()
        await vm.process(TestImages.png(width: 300, height: 400))
        vm.draft?.name = "Tee"
        await vm.prepareLayer()
        #expect(vm.preparedLayerPNG(slot: .top) != nil)
        #expect(vm.preparedLayerPNG(slot: .shoes) == nil, "换了槽位却把上装那张给了它")
    }

    /// 手修一笔之后要重新备（旧的那张是修之前的像素）。
    @Test func retouchingInvalidatesThePreparedLayer() async throws {
        let vm = makeVM()
        await vm.process(TestImages.png(width: 300, height: 400))
        vm.draft?.name = "Tee"
        await vm.prepareLayer()
        #expect(vm.preparedLayerPNG(slot: .top) != nil)
        #expect(vm.applyRetouchedMatte(TestImages.png(width: 300, height: 400)))
        #expect(vm.preparedLayerPNG(slot: .top) == nil, "手修过了还在用修之前那张")
    }

    /// 换一张照片同样作废。
    @Test func anewPhotoInvalidatesThePreparedLayer() async throws {
        let vm = makeVM()
        await vm.process(TestImages.png(width: 300, height: 400))
        vm.draft?.name = "Tee"
        await vm.prepareLayer()
        #expect(vm.preparedLayerPNG(slot: .top) != nil)
        await vm.process(TestImages.png(width: 320, height: 420))
        #expect(vm.preparedLayerPNG(slot: .top) == nil)
    }

    /// 接线门：确认页必须真的去后台备（否则这条能力就是零调用点）。
    @Test func theConfirmScreenActuallyPreparesIt() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ClosetUI/Sources/ClosetUI/PhotoCaptureViews.swift")
        let text = try String(contentsOf: url, encoding: .utf8)
        let wired = text.split(separator: "\n").contains { line in
            let t = line.trimmingCharacters(in: .whitespaces)
            return t.contains("prepareLayer()") && !t.hasPrefix("//") && !t.hasPrefix("///")
        }
        #expect(wired, "确认页没有接后台预备 —— confirm 那一下还是当场算")
    }
}
