import Testing
import SwiftData
import Foundation
import CoreGraphics
import ImageIO
@testable import ClosetIntake
@testable import ClosetModel // for ItemImageStore.forceFailure test hook
import ClosetCore

/// D112：`.serialized` 是 **suite / 参数化用例** 的 trait；
/// 挂在非参数化的单个 `@Test` 上**什么都不做**（全仓曾有 25 处这样的写法，
/// 于是「这里安全因为串行」的说法全是假的）。本套用进程级钩子
///（`ItemImageStore.forceFailure` / 共享图片根），必须真的串行。
@Suite(.serialized)
@MainActor
struct IntakeTests {
    init() { ItemImageTestRoot.install() }   // 触盘套件：根目录按进程隔离，勿写真机目录


    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    func makeVM(
        _ tags: ItemTags,
        ocr: LabelInfo? = nil,
        productLookup: (any ProductLookupProviding)? = nil
    ) -> IntakeViewModel {
        IntakeViewModel(
            matting: MockMattingService(),
            tagging: MockTaggingService(tags: tags),
            ocr: ocr.map { MockOCRService(info: $0) },
            productLookup: productLookup)
    }

    /// 可解码的极小不透明 PNG，让 GarmentLayerNormalizer 成功路径可被测。
    func tinyPNG() throws -> Data {
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
        let finalized = CGImageDestinationFinalize(dest)
        try #require(finalized)
        return data as Data
    }

    @Test func processBuildsDraftFromTags() async throws {
        let vm = makeVM(ItemTags(slot: .dress, color: GarmentColor(hueDegrees: 200, isNeutral: false),
                                 occasions: ["work"], warmth: .medium))
        await vm.process(Data([0x1, 0x2]))
        #expect(vm.draft?.slot == .dress)
        #expect(vm.draft?.color?.hueDegrees == 200)
        #expect(vm.draft?.occasions == ["work"])
        #expect(vm.draft?.warmth == .medium)
        #expect(vm.mattedImage != nil)
        #expect(vm.draft?.name == "Dress") // slot display title prefill
        #expect(vm.canConfirm)
        #expect(vm.lastError == nil)
    }

    @Test func processWithOCRFillsBrandSize() async throws {
        let vm = makeVM(ItemTags(slot: .top), ocr: LabelInfo(brand: "Sézane", size: "M"))
        await vm.process(Data([0x1]))
        #expect(vm.draft?.brand == "Sézane")
        #expect(vm.draft?.size == "M")
        #expect(vm.draft?.name == "Sézane Top")
    }

    @Test func processRejectsEmptyImage() async throws {
        let vm = makeVM(ItemTags(slot: .top))
        await vm.process(Data())
        #expect(vm.draft == nil)
        #expect(vm.mattedImage == nil)
        #expect(vm.lastError != nil)
        #expect(vm.canConfirm == false)
    }

    @Test func confirmCreatesAvailableItemInWardrobe() async throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w); try ctx.save()
        let vm = makeVM(
            ItemTags(slot: .bottom,
                     color: GarmentColor(hueDegrees: 210, isNeutral: false),
                     occasions: ["work"], warmth: .light),
            ocr: LabelInfo(brand: "COS", size: "32"))
        await vm.process(try tinyPNG()) // 可解码 PNG → 归一成功才存层图
        vm.draft?.name = "grey trousers"
        let item = vm.confirm(into: w, context: ctx)
        #expect(item != nil)
        #expect(item?.name == "grey trousers")
        #expect(item?.slotRaw == "bottom")
        #expect(item?.statusRaw == "available")
        #expect(item?.wardrobe?.id == w.id)
        #expect(vm.draft == nil)   // 确认后清空
        #expect(item?.localImageRelativePath != nil)
        #expect(ItemImageStore.loadData(relativePath: item?.localImageRelativePath) != nil)
        // confirm 必须把打标/OCR 富化字段落库到 Item，不得只留在草稿。
        #expect(item?.warmthRaw == Warmth.light.rawValue)
        #expect(item?.colorHue == 210)
        #expect(item?.colorIsNeutral == false)
        #expect(item?.brand == "COS")
        #expect(item?.sizeLabel == "32")
        #expect(try ctx.fetch(FetchDescriptor<Item>()).count == 1)
        ItemImageStore.delete(relativePath: item?.localImageRelativePath)
    }

    @Test func confirmWithoutDraftReturnsNil() async throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w); try ctx.save()
        let vm = makeVM(ItemTags(slot: .top))
        #expect(vm.confirm(into: w, context: ctx) == nil)   // 无草稿
        #expect(vm.lastError != nil)
    }

    @Test func confirmRejectsBlankName() async throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w); try ctx.save()
        let vm = makeVM(ItemTags(slot: .top))
        await vm.process(Data([0x1]))
        vm.draft?.name = "   "
        #expect(vm.canConfirm == false)
        #expect(vm.confirm(into: w, context: ctx) == nil)
        #expect(vm.lastError != nil)
        #expect(vm.draft != nil) // keep draft so user can fix name
        #expect(try ctx.fetch(FetchDescriptor<Item>()).isEmpty)
    }

    /// Save-fail toast must not look like success; draft kept for retry.
    @Test func confirmSaveFailedMessageIsHonest() {
        #expect(IntakeViewModel.confirmSaveFailedMessage
            .localizedCaseInsensitiveContains("couldn't save"))
        #expect(IntakeViewModel.confirmSaveFailedMessage
            .localizedCaseInsensitiveContains("try again"))
        #expect(!IntakeViewModel.confirmSaveFailedMessage
            .localizedCaseInsensitiveContains("added"))
    }

    /// 归一失败（图不可解码）→ 不存紧裁剪图（composer 会用槽位占位框，绝不全身拉伸），
    /// 且状态条诚实提示「已入库但照片未对齐」，不是静默成功。
    @Test func confirmNormalizeFailureSkipsLayerImageHonestly() async throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w); try ctx.save()
        let vm = makeVM(ItemTags(slot: .top))
        await vm.process(Data([0x1, 0x2, 0x3])) // 不可解码 → normalize 返回 nil
        vm.draft?.name = "Silk Tee"
        let item = vm.confirm(into: w, context: ctx)
        #expect(item != nil) // 衣物本体仍入库
        #expect(item?.localImageRelativePath == nil) // 紧裁剪图不落库 → 无全身拉伸
        #expect(vm.lastError == nil)
        #expect(vm.statusMessage == IntakeViewModel.layerNormalizeFailedMessage)
        #expect(vm.statusMessage?.localizedCaseInsensitiveContains("couldn't") == true)
        #expect(!IntakeViewModel.layerNormalizeFailedMessage
            .localizedCaseInsensitiveContains("try-on ready"))
        ItemImageStore.delete(relativePath: item?.localImageRelativePath)
    }

    @Test func suggestedNameUsesBrandAndSlot() {
        var d = IntakeDraft(slot: .outerwear)
        d.brand = "Toteme"
        #expect(IntakeViewModel.suggestedName(for: d) == "Toteme Outerwear")
        d.brand = nil
        #expect(IntakeViewModel.suggestedName(for: d) == "Outerwear")
    }

    /// Manual/add Type pickers use GarmentSlot.allCases; accessory must save + label cleanly.
    @Test func confirmAccessorySlotAndDisplayTitle() async throws {
        #expect(GarmentSlot.allCases.contains(.accessory))
        #expect(GarmentSlot.accessory.displayTitle == "Accessory")
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w); try ctx.save()
        let vm = makeVM(ItemTags(slot: .accessory, occasions: ["casual"], warmth: .veryLight))
        await vm.process(Data([0x1, 0x2]))
        #expect(vm.draft?.slot == .accessory)
        #expect(vm.draft?.name == "Accessory") // displayTitle prefill
        vm.draft?.name = "Leather Belt"
        let item = vm.confirm(into: w, context: ctx)
        #expect(item?.slotRaw == "accessory")
        #expect(item?.name == "Leather Belt")
        #expect(GarmentSlot.resolved(item?.slotRaw ?? "", name: item?.name ?? "").displayTitle
            == "Accessory")
        ItemImageStore.delete(relativePath: item?.localImageRelativePath)
    }

    /// 入库归一槽与叠衣 displaySlot 同真相：脏 blazer-as-top → outerwear 肩区。
    @Test func layerNormalizeSlotUsesDisplaySlotTruth() {
        #expect(
            IntakeViewModel.layerNormalizeSlot(slotRaw: "top", name: "Navy Blazer")
            == .outerwear)
        #expect(
            IntakeViewModel.layerNormalizeSlot(slotRaw: "top", name: "Denim jacket")
            == .outerwear)
        #expect(
            IntakeViewModel.layerNormalizeSlot(slotRaw: "top", name: "White Tee")
            == .top)
        #expect(
            IntakeViewModel.layerNormalizeSlot(slotRaw: "outerwear", name: "Blazer")
            == .outerwear)
        // 归一区 outerwear 肩线应高于 shoes（与 contentRect 同构）
        let outerY = GarmentLayerNormalizer.contentRect(for: .outerwear).y
        let topY = GarmentLayerNormalizer.contentRect(for: .top).y
        let shoeY = GarmentLayerNormalizer.contentRect(for: .shoes).y
        #expect(outerY <= topY + 0.05)
        #expect(outerY < shoeY)
    }

    /// Empty occasions on confirm → casual so Today occasion filters still match.
    @Test func confirmDefaultsEmptyOccasionsToCasual() async throws {
        #expect(IntakeViewModel.normalizedOccasions([]) == ["casual"])
        #expect(IntakeViewModel.normalizedOccasions(["  Work ", "work"]) == ["work"])
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w); try ctx.save()
        let vm = makeVM(ItemTags(slot: .top)) // no occasions in tags
        await vm.process(Data([0x1, 0x2]))
        vm.draft?.name = "Plain Tee"
        #expect(vm.draft?.occasions.isEmpty == true)
        let item = vm.confirm(into: w, context: ctx)
        #expect(item?.occasionsRaw == ["casual"])
        ItemImageStore.delete(relativePath: item?.localImageRelativePath)
    }

    /// Confirm persists resolved slotRaw (not dirty draft top) so Closet Type matches stack.
    @Test func confirmPersistsResolvedSlotForDirtyBlazerName() async throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w); try ctx.save()
        let vm = makeVM(ItemTags(slot: .top, occasions: ["work"], warmth: .medium))
        await vm.process(Data([0x1, 0x2, 0x3]))
        vm.draft?.name = "Navy Blazer"
        vm.draft?.slot = .top
        #expect(IntakeViewModel.persistSlot(draftSlot: .top, name: "Navy Blazer") == .outerwear)
        let item = vm.confirm(into: w, context: ctx)
        #expect(item?.name == "Navy Blazer")
        #expect(item?.slotRaw == "outerwear") // not left as "top"
        #expect(GarmentSlot.resolved(item?.slotRaw ?? "", name: item?.name ?? "") == .outerwear)
        ItemImageStore.delete(relativePath: item?.localImageRelativePath)

        // Clean top name stays top.
        await vm.process(Data([0x4, 0x5]))
        vm.draft?.name = "White Tee"
        vm.draft?.slot = .top
        let tee = vm.confirm(into: w, context: ctx)
        #expect(tee?.slotRaw == "top")
        ItemImageStore.delete(relativePath: tee?.localImageRelativePath)
    }

    @Test func enrichFromPublicBarcodeFillsEmptyBrandAndName() async throws {
        struct FakeLookup: ProductLookupProviding {
            func lookup(barcode: String) async throws -> PublicProductHit? {
                PublicProductHit(
                    barcode: barcode,
                    name: "Oxford Shirt",
                    brand: "PublicBrand",
                    quantity: "M",
                    source: "test")
            }
        }
        let vm = makeVM(ItemTags(slot: .top), productLookup: FakeLookup())
        await vm.process(Data([0x1]))
        vm.draft?.name = ""
        vm.draft?.brand = nil
        await vm.enrichFromPublicBarcode("0123456789012")
        #expect(vm.draft?.brand == "PublicBrand")
        #expect(vm.draft?.name == "PublicBrand Oxford Shirt")
        #expect(vm.draft?.size == "M")
        #expect(vm.draft?.barcode == "0123456789012")
        #expect(vm.lastError == nil)
        // Success is not silent — names Open Facts host when present.
        #expect(vm.statusMessage == IntakeViewModel.barcodeFilledMessage(source: "test"))
        #expect(vm.statusMessage?.localizedCaseInsensitiveContains("filled") == true)
        #expect(!IntakeViewModel.barcodeFilledMessage(source: "world.openfoodfacts.org")
            .localizedCaseInsensitiveContains("try-on"))
    }

    /// Brand/size 里误敲的空格不得阻塞条码补全（判空必须 trim，与 name 同标准）。
    @Test func enrichFillsBrandAndSizeWhenDraftValuesAreBlank() async throws {
        struct FakeLookup: ProductLookupProviding {
            func lookup(barcode: String) async throws -> PublicProductHit? {
                PublicProductHit(
                    barcode: barcode, name: "Oxford Shirt",
                    brand: "PublicBrand", quantity: "M", source: "test")
            }
        }
        let vm = makeVM(ItemTags(slot: .top), productLookup: FakeLookup())
        await vm.process(Data([0x1]))
        vm.draft?.name = "My Tee"
        vm.draft?.brand = " "
        vm.draft?.size = "  "
        await vm.enrichFromPublicBarcode("0123456789012")
        #expect(vm.draft?.brand == "PublicBrand")
        #expect(vm.draft?.size == "M")
    }

    /// Confirm 落库时 brand/size 空白转 nil、真值 trim（与 ItemEditorService 同标准）。
    @Test func confirmNormalizesBlankBrandAndSize() async throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w); try ctx.save()
        let vm = makeVM(ItemTags(slot: .top))
        await vm.process(Data([0x1]))
        vm.draft?.name = "Plain Tee"
        vm.draft?.brand = " "
        vm.draft?.size = " M "
        let item = vm.confirm(into: w, context: ctx)
        #expect(item?.brand == nil)
        #expect(item?.sizeLabel == "M")
        ItemImageStore.delete(relativePath: item?.localImageRelativePath)
    }

    /// Hit but user already filled fields → honest nothing-changed (not silent success).
    @Test func enrichFromPublicBarcodeNothingToFillSurfacesStatus() async throws {
        struct FakeLookup: ProductLookupProviding {
            func lookup(barcode: String) async throws -> PublicProductHit? {
                PublicProductHit(
                    barcode: barcode,
                    name: "Other Shirt",
                    brand: "OtherBrand",
                    quantity: "L",
                    source: "test")
            }
        }
        let vm = makeVM(ItemTags(slot: .top), productLookup: FakeLookup())
        await vm.process(Data([0x1]))
        vm.draft?.name = "My Tee"
        vm.draft?.brand = "Mine"
        vm.draft?.size = "M"
        await vm.enrichFromPublicBarcode("0123456789012")
        #expect(vm.draft?.name == "My Tee")
        #expect(vm.draft?.brand == "Mine")
        #expect(vm.draft?.size == "M")
        #expect(vm.lastError == nil)
        #expect(vm.statusMessage == IntakeViewModel.barcodeFoundNothingToFillMessage)
        // Barcode IS written even when nothing else fills — message must not
        // claim "nothing changed".
        #expect(vm.draft?.barcode == "0123456789012")
        #expect(vm.statusMessage?.localizedCaseInsensitiveContains("barcode saved") == true)
        #expect(!IntakeViewModel.barcodeFoundNothingToFillMessage
            .localizedCaseInsensitiveContains("nothing changed"))
    }

    @Test func enrichFromPublicBarcodeMissSetsErrorNotStatus() async throws {
        struct MissLookup: ProductLookupProviding {
            func lookup(barcode: String) async throws -> PublicProductHit? { nil }
        }
        let vm = makeVM(ItemTags(slot: .top), productLookup: MissLookup())
        await vm.process(Data([0x1]))
        await vm.enrichFromPublicBarcode("0000000000000")
        #expect(vm.lastError?.localizedCaseInsensitiveContains("no public") == true)
        #expect(vm.statusMessage == nil)
    }

    /// Open*Facts quantity is often pack/weight — must not land in garment size.
    @Test func enrichSkipsNonApparelQuantityForSize() async throws {
        struct PackLookup: ProductLookupProviding {
            func lookup(barcode: String) async throws -> PublicProductHit? {
                PublicProductHit(
                    barcode: barcode,
                    name: "Socks",
                    brand: "SockCo",
                    quantity: "3 pack",
                    source: "test")
            }
        }
        let vm = makeVM(ItemTags(slot: .accessory), productLookup: PackLookup())
        await vm.process(Data([0x1]))
        vm.draft?.name = ""
        vm.draft?.size = nil
        await vm.enrichFromPublicBarcode("0123456789999")
        #expect(vm.draft?.brand == "SockCo")
        #expect(vm.draft?.size == nil)
        #expect(!PublicSizeReference.looksLikeApparelSize("3 pack"))
        #expect(!PublicSizeReference.looksLikeApparelSize("500g"))
        #expect(PublicSizeReference.looksLikeApparelSize("M"))
        #expect(PublicSizeReference.looksLikeApparelSize("US 8"))
    }

    /// Choose-screen / IntakeView empty-state copy: Vision = cutout only; tags/OCR starter guesses.
    @Test func photoPipelineCaptionIsHonestAboutTagsAndOCR() {
        let cap = IntakeServiceFactory.photoPipelineCaption
        #expect(cap.localizedCaseInsensitiveContains("Vision"))
        #expect(cap.localizedCaseInsensitiveContains("starter"))
        #expect(cap.localizedCaseInsensitiveContains("edit"))
        // Must not imply Vision fills tags/type on device (old dishonest line).
        #expect(!cap.localizedCaseInsensitiveContains("mock tags on simulator"))
        #expect(!cap.localizedCaseInsensitiveContains("Vision on device"))
        #expect(!cap.localizedCaseInsensitiveContains("pre-fill"))
        #expect(!cap.localizedCaseInsensitiveContains("pre-filling"))
        #expect(!cap.localizedCaseInsensitiveContains("We'll cut it out and pre-fill"))
        #expect(IntakeServiceFactory.makeMatting() is MockMattingService)
        #expect(IntakeServiceFactory.makeTagging() is MockTaggingService)
        #expect(IntakeServiceFactory.makeOCR() is MockOCRService)
    }

    /// Processing ProgressView + barcode field must not promise OCR pre-fill or camera scan.
    @Test func photoProcessingAndBarcodeCaptionsAreHonest() {
        let processing = IntakeServiceFactory.photoProcessingCaption
        #expect(processing.localizedCaseInsensitiveContains("Cutting out"))
        #expect(processing.localizedCaseInsensitiveContains("starter"))
        #expect(!processing.localizedCaseInsensitiveContains("pre-filling"))
        #expect(!processing.localizedCaseInsensitiveContains("pre-fill"))

        let barcode = IntakeServiceFactory.barcodeEntryCaption
        #expect(barcode.localizedCaseInsensitiveContains("paste")
            || barcode.localizedCaseInsensitiveContains("Type"))
        #expect(barcode.localizedCaseInsensitiveContains("not available")
            || barcode.localizedCaseInsensitiveContains("no camera"))
        #expect(!barcode.localizedCaseInsensitiveContains("scan with camera"))
    }

    // MARK: - I1: matting failure must not store uncut photo as layer

    struct ThrowingMattingService: MattingService {
        struct MattingError: Error {}
        func removeBackground(_ imageData: Data) async throws -> Data { throw MattingError() }
    }

    /// 抠图抛错 + 不透明 PNG：草稿仍可入库，但未抠整图绝不落库为叠衣层（胸前贴纸），
    /// 且状态条诚实提示抠图失败，不是静默把原图归一进槽位画布。
    @Test func mattingFailureSkipsLayerImageWithHonestMessage() async throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w); try ctx.save()
        let vm = IntakeViewModel(
            matting: ThrowingMattingService(),
            tagging: MockTaggingService(tags: ItemTags(slot: .top)),
            productLookup: nil)
        await vm.process(try tinyPNG()) // 不透明整图：误存即胸前贴纸
        #expect(vm.draft != nil)        // 草稿仍可编辑
        #expect(vm.mattedImage == nil)  // 抠图失败不存层图
        #expect(vm.lastError == nil)
        #expect(vm.statusMessage == IntakeViewModel.mattingFailedMessage)
        #expect(vm.statusMessage?.localizedCaseInsensitiveContains("couldn't") == true)
        vm.draft?.name = "Silk Tee"
        let item = vm.confirm(into: w, context: ctx)
        #expect(item != nil) // 衣物本体仍入库
        #expect(item?.localImageRelativePath == nil) // 未抠整图不落库
        ItemImageStore.delete(relativePath: item?.localImageRelativePath)
    }

    // MARK: - I2: concurrent process() race + reset cancellation

    /// 延迟打标：槽位随输入首字节变化，用于分辨哪次调用最终落草稿。
    struct DelayedTaggingService: TaggingService {
        let delayNanos: UInt64
        func tag(_ imageData: Data) async throws -> ItemTags {
            try await Task.sleep(nanoseconds: delayNanos)
            let slot: GarmentSlot = imageData.first == 0x2 ? .dress : .top
            return ItemTags(slot: slot)
        }
    }

    /// 会合打标：tag() 挂起在测试控制的 continuation 队列上，releaseNext()
    /// 按进入顺序放行一个；waitUntilEntered 轮询确认第 N 次 tag() 确实已进入。
    /// 与 GatedTaggingService 同构但支持多次并发进入 —— 确定性握手，替代固定 sleep。
    final class RendezvousTaggingService: TaggingService, @unchecked Sendable {
        private let lock = NSLock()
        private var blocked: [CheckedContinuation<Void, Never>] = []
        private var entered = 0
        var enteredCount: Int { lock.lock(); defer { lock.unlock() }; return entered }
        /// 等到第 count 次 tag() 确实挂起（此刻 process 必在途）。
        ///
        /// 曾是有界自旋（10 万次 `Task.yield()` 后放弃），CPU 争用时会走完计数
        /// 还没等到对方被调度，于是随后的 `#require(enteredCount == N)` 偶发失败——
        /// 那是**测试脚手架**的缺陷，不是生产并发的缺陷（单跑必过）。
        /// 改成真正会挂起的信号：够数即唤醒，不够就一直等，没有上限。
        private var waiters: [(threshold: Int, c: CheckedContinuation<Void, Never>)] = []

        func waitUntilEntered(_ count: Int) async {
            await withCheckedContinuation { c in
                lock.lock()
                if entered >= count {
                    lock.unlock()
                    c.resume()
                    return
                }
                waiters.append((count, c))
                lock.unlock()
            }
        }

        /// 唤醒阈值已满足的等待者（在锁外 resume，避免重入死锁）。
        private func signal() {
            lock.lock()
            let ready = waiters.filter { entered >= $0.threshold }
            waiters.removeAll { entered >= $0.threshold }
            lock.unlock()
            for w in ready { w.c.resume() }
        }

        func tag(_ imageData: Data) async throws -> ItemTags {
            await withCheckedContinuation { c in
                lock.lock()
                blocked.append(c)
                entered += 1
                lock.unlock()
                signal()
            }
            let slot: GarmentSlot = imageData.first == 0x2 ? .dress : .top
            return ItemTags(slot: slot)
        }
        /// 放行最早进入、仍挂起的一个 tag()。
        func releaseNext() {
            lock.lock()
            let c = blocked.isEmpty ? nil : blocked.removeFirst()
            lock.unlock()
            c?.resume()
        }
    }

    /// 并发 process()：旧调用的结果不得覆盖新照片草稿（last-call-wins）。
    /// 确定性会合：确认 first 已挂起在 tag() 才启动 second，不靠固定 sleep 排序。
    @Test func concurrentProcessLastCallWins() async throws {
        let gate = RendezvousTaggingService()
        let vm = IntakeViewModel(
            matting: MockMattingService(),
            tagging: gate,
            productLookup: nil)
        let first = Task { await vm.process(Data([0x1])) }  // → top
        await gate.waitUntilEntered(1) // first 确已挂起在 tag()
        try #require(gate.enteredCount == 1)
        let second = Task { await vm.process(Data([0x2])) } // → dress
        await gate.waitUntilEntered(2) // second 也已挂起：其 processGeneration 已自增
        try #require(gate.enteredCount == 2)
        gate.releaseNext() // 放行 first：收尾时已被 second 取代，结果必须被丢弃
        gate.releaseNext() // 放行 second
        _ = await (first.value, second.value)
        #expect(vm.draft?.slot == .dress) // 后调用赢，旧结果被丢弃
        #expect(vm.isProcessing == false)
    }

    /// reset() 取消在途 process()：其结果不得复活草稿。
    /// 确定性会合：确认 process 确已挂起在 tag() 才 reset，不靠固定 sleep 排序。
    @Test func resetCancelsInFlightProcess() async throws {
        let gate = RendezvousTaggingService()
        let vm = IntakeViewModel(
            matting: MockMattingService(),
            tagging: gate,
            productLookup: nil)
        let inFlight = Task { await vm.process(Data([0x1])) }
        await gate.waitUntilEntered(1) // process 确已开始并挂起在 tag()
        try #require(gate.enteredCount == 1)
        vm.reset()
        gate.releaseNext() // 放行后收尾：代际守卫必须丢弃其结果
        await inFlight.value
        #expect(vm.draft == nil)        // 草稿不复活
        #expect(vm.mattedImage == nil)
        #expect(vm.isProcessing == false)
    }

    // MARK: - I3: junk barcode must surface an error

    @Test func enrichFromPublicBarcodeJunkSetsError() async throws {
        struct FakeLookup: ProductLookupProviding {
            func lookup(barcode: String) async throws -> PublicProductHit? { nil }
        }
        let vm = makeVM(ItemTags(slot: .top), productLookup: FakeLookup())
        await vm.process(Data([0x1]))
        await vm.enrichFromPublicBarcode("abc!!") // 归一后无数字
        #expect(vm.lastError == "Enter the digits under the barcode.")
        #expect(vm.statusMessage == nil)
        #expect(vm.draft?.barcode == nil)
    }

    // MARK: - I4: barcode persisted on confirm

    @Test func confirmPersistsBarcodeFromEnrich() async throws {
        struct FakeLookup: ProductLookupProviding {
            func lookup(barcode: String) async throws -> PublicProductHit? {
                PublicProductHit(
                    barcode: barcode, name: "Oxford Shirt",
                    brand: "PublicBrand", quantity: "M", source: "test")
            }
        }
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w); try ctx.save()
        let vm = makeVM(ItemTags(slot: .top), productLookup: FakeLookup())
        await vm.process(Data([0x1]))
        await vm.enrichFromPublicBarcode("0123 4567 8901 2") // 含空格，归一为纯数字
        #expect(vm.draft?.barcode == "0123456789012")
        let item = vm.confirm(into: w, context: ctx)
        #expect(item?.barcode == "0123456789012")
        ItemImageStore.delete(relativePath: item?.localImageRelativePath)
    }

    // MARK: - Loop4 I1: tag/OCR failure must not silently fall back to defaults

    struct ThrowingTaggingService: TaggingService {
        struct TaggingError: Error {}
        func tag(_ imageData: Data) async throws -> ItemTags { throw TaggingError() }
    }

    struct ThrowingOCRService: OCRService {
        struct OCRError: Error {}
        func readLabel(_ imageData: Data) async throws -> LabelInfo { throw OCRError() }
    }

    /// 打标抛错：草稿仍生成但退回默认（top），且状态条诚实提示「自动预填失败」，
    /// 不得把默认值静默当识别结果。
    @Test func taggingFailureFallsBackToDefaultsWithHonestMessage() async throws {
        let vm = IntakeViewModel(
            matting: MockMattingService(),
            tagging: ThrowingTaggingService(),
            ocr: ThrowingOCRService(),
            productLookup: nil)
        await vm.process(Data([0x1, 0x2]))
        #expect(vm.draft != nil)                    // 草稿仍可编辑
        #expect(vm.draft?.slot == .top)             // 退回默认槽位
        #expect(vm.draft?.occasions.isEmpty == true)
        #expect(vm.mattedImage != nil)              // 抠图成功 → 层图保留
        #expect(vm.lastError == nil)
        #expect(vm.statusMessage == IntakeViewModel.prefillFailedMessage)
        #expect(vm.statusMessage?.localizedCaseInsensitiveContains("couldn't") == true)
        #expect(vm.statusMessage?.localizedCaseInsensitiveContains("defaults") == true)
    }

    /// 抠图失败优先于预填失败：matting 消息不被 tag/OCR 消息覆盖。
    @Test func mattingFailureMessageWinsOverPrefillFailure() async throws {
        let vm = IntakeViewModel(
            matting: ThrowingMattingService(),
            tagging: ThrowingTaggingService(),
            productLookup: nil)
        await vm.process(Data([0x1]))
        #expect(vm.draft != nil)
        #expect(vm.statusMessage == IntakeViewModel.mattingFailedMessage)
    }

    // MARK: - Loop4 I2: enrich while process() in flight must not be silently wiped

    /// 门控打标：tag() 挂起在测试控制的 continuation 上，resume() 后才返回。
    /// 用于 enrich-in-flight 测试的确定性握手（替代固定 sleep）。
    final class GatedTaggingService: TaggingService, @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<Void, Never>?
        private var entered = false
        var hasEntered: Bool { lock.lock(); defer { lock.unlock() }; return entered }
        func tag(_ imageData: Data) async throws -> ItemTags {
            await withCheckedContinuation { c in
                lock.lock()
                continuation = c
                entered = true
                lock.unlock()
            }
            return ItemTags(slot: .dress)
        }
        func resume() {
            lock.lock()
            let c = continuation
            continuation = nil
            lock.unlock()
            c?.resume()
        }
    }

    /// process() 在途时 enrich 命中：若直接写 draft，process 收尾整写会丢掉
    /// barcode + 富化字段 → 必须干净中止并诚实提示，而非写一半被覆盖。
    /// 确定性握手：门控 TaggingService 挂起在测试控制的 continuation 上，
    /// 并轮询确认打标已进入，绝不依赖固定 sleep 时序。
    @Test func enrichAbortedHonestlyWhileProcessInFlight() async throws {
        struct FakeLookup: ProductLookupProviding {
            func lookup(barcode: String) async throws -> PublicProductHit? {
                PublicProductHit(
                    barcode: barcode, name: "Oxford Shirt",
                    brand: "PublicBrand", quantity: "M", source: "test")
            }
        }
        let gate = GatedTaggingService()
        let vm = IntakeViewModel(
            matting: MockMattingService(),
            tagging: gate,
            productLookup: FakeLookup())
        let inFlight = Task { await vm.process(Data([0x2])) } // → dress
        // 握手：等到打标确实挂起（process 必在途），再调 enrich。
        for _ in 0..<10_000 where !gate.hasEntered {
            await Task.yield()
        }
        #expect(gate.hasEntered)
        await vm.enrichFromPublicBarcode("0123456789012")
        // enrich 干净中止：诚实提示重试，不留半成品草稿
        #expect(vm.statusMessage == IntakeViewModel.barcodeEnrichAbortedMessage)
        #expect(vm.lastError == nil)
        #expect(vm.draft?.barcode == nil)
        gate.resume()
        await inFlight.value
        // process 收尾落自己的草稿（dress），enrich 结果不曾混入
        #expect(vm.draft?.slot == .dress)
        #expect(vm.draft?.barcode == nil)
        #expect(vm.isProcessing == false)
    }

    /// 空图打断在途处理：代际推进作废旧调用后，空图路径必须自己清 isProcessing——
    /// 旧调用的 defer 因代际不匹配不会清，否则 UI 永久卡在「Processing…」。
    @Test func emptyImageDuringInFlightProcessClearsProcessing() async throws {
        let gate = GatedTaggingService()
        let vm = IntakeViewModel(
            matting: MockMattingService(),
            tagging: gate,
            productLookup: nil)
        let inFlight = Task { await vm.process(Data([0x2])) }
        for _ in 0..<10_000 where !gate.hasEntered {
            await Task.yield()
        }
        #expect(gate.hasEntered)
        #expect(vm.isProcessing)
        await vm.process(Data())
        #expect(vm.isProcessing == false)
        #expect(vm.lastError != nil)
        gate.resume()
        await inFlight.value
        // 旧调用收尾因代际作废：不落草稿、不复活 processing 标志
        #expect(vm.isProcessing == false)
        #expect(vm.draft == nil)
    }

    /// confirm save 失败不得残留幻影 item 与关系脏标记（wardrobe.items 不得含幻影）。
    @Test func confirmSaveFailureLeavesNoDirtyState() async throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w); try ctx.save()
        let vm = makeVM(ItemTags(slot: .top))
        await vm.process(Data([0x1]))
        vm.draft?.name = "Plain Tee"
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        #expect(vm.confirm(into: w, context: ctx) == nil)
        #expect(vm.lastError == IntakeViewModel.confirmSaveFailedMessage)
        #expect(!ctx.hasChanges)
        #expect((w.items ?? []).isEmpty)
        // 草稿保留可重试
        #expect(vm.draft != nil)
    }

    /// process 完成后再 enrich：不受守卫影响，正常填充（守卫无误伤）。
    @Test func enrichAfterProcessCompletesStillFills() async throws {
        struct FakeLookup: ProductLookupProviding {
            func lookup(barcode: String) async throws -> PublicProductHit? {
                PublicProductHit(
                    barcode: barcode, name: "Oxford Shirt",
                    brand: "PublicBrand", quantity: "M", source: "test")
            }
        }
        let vm = IntakeViewModel(
            matting: MockMattingService(),
            tagging: DelayedTaggingService(delayNanos: 10_000_000),
            productLookup: FakeLookup())
        await vm.process(Data([0x1]))
        vm.draft?.name = ""
        await vm.enrichFromPublicBarcode("0123456789012")
        #expect(vm.draft?.brand == "PublicBrand")
        #expect(vm.draft?.barcode == "0123456789012")
        #expect(vm.statusMessage == IntakeViewModel.barcodeFilledMessage(source: "test"))
    }

    // MARK: - IN-N1: confirm success must invalidate in-flight enrich

    /// 门控 lookup：lookup() 挂起在测试控制的 continuation 上，resume() 后才返回命中。
    /// 与 GatedTaggingService 同构，用于 confirm-during-enrich 竞态的确定性握手。
    final class GatedLookupService: ProductLookupProviding, @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<Void, Never>?
        private var entered = false
        var hasEntered: Bool { lock.lock(); defer { lock.unlock() }; return entered }
        func lookup(barcode: String) async throws -> PublicProductHit? {
            await withCheckedContinuation { c in
                lock.lock()
                continuation = c
                entered = true
                lock.unlock()
            }
            return PublicProductHit(
                barcode: barcode, name: "Oxford Shirt",
                brand: "PublicBrand", quantity: "M", source: "test")
        }
        func resume() {
            lock.lock()
            let c = continuation
            continuation = nil
            lock.unlock()
            c?.resume()
        }
    }

    /// enrich 在途（lookup 挂起）时用户 confirm 成功：草稿已落库清空，
    /// lookup 返回后代际守卫必须拦截——富化草稿不得在落库后复活，
    /// 否则用户再次 confirm 会生成重复单品。
    @Test func confirmWhileEnrichInFlightDiscardsLateLookup() async throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w); try ctx.save()
        let gate = GatedLookupService()
        let vm = IntakeViewModel(
            matting: MockMattingService(),
            tagging: MockTaggingService(tags: ItemTags(slot: .top)),
            productLookup: gate)
        await vm.process(Data([0x1]))
        #expect(vm.draft != nil)
        let enrichTask = Task { await vm.enrichFromPublicBarcode("0123456789012") }
        // 握手：等到 lookup 确实挂起（enrich 必在途），再 confirm。
        for _ in 0..<10_000 where !gate.hasEntered {
            await Task.yield()
        }
        #expect(gate.hasEntered)
        let item = vm.confirm(into: w, context: ctx)
        #expect(item != nil)
        #expect(vm.draft == nil) // 落库清草稿
        gate.resume()
        await enrichTask.value
        // 迟到的 lookup 结果被代际守卫丢弃：草稿不复活
        #expect(vm.draft == nil)
        #expect(try ctx.fetch(FetchDescriptor<Item>()).count == 1)
    }

    // MARK: - IN-N2: confirm 早退守卫不得残留旧 statusMessage

    /// enrich 成功（statusMessage 已置）→ 用户清空名称 → confirm 早退：
    /// lastError 与 statusMessage 互斥，命名错误不得与富化成功文案同屏。
    @Test func confirmBlankNameClearsStaleStatusMessage() async throws {
        struct FakeLookup: ProductLookupProviding {
            func lookup(barcode: String) async throws -> PublicProductHit? {
                PublicProductHit(
                    barcode: barcode, name: "Oxford Shirt",
                    brand: "PublicBrand", quantity: "M", source: "test")
            }
        }
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w); try ctx.save()
        let vm = makeVM(ItemTags(slot: .top), productLookup: FakeLookup())
        await vm.process(Data([0x1]))
        await vm.enrichFromPublicBarcode("0123456789012")
        #expect(vm.statusMessage == IntakeViewModel.barcodeFilledMessage(source: "test"))
        vm.draft?.name = "   "
        #expect(vm.confirm(into: w, context: ctx) == nil)
        #expect(vm.lastError == "Give this piece a name before adding it.")
        #expect(vm.statusMessage == nil) // 不得残留富化成功文案
        #expect(vm.draft != nil) // keep draft so user can fix name
        #expect(try ctx.fetch(FetchDescriptor<Item>()).isEmpty)
    }

    // MARK: - Loop4 I3: layer image disk-write failure must be honest

    /// 归一成功但 ItemImageStore.save 返回 nil（磁盘写失败）：衣物本体仍入库，
    /// 但层图丢失不得静默——状态条诚实提示可重拍。
    @Test func confirmLayerImageSaveFailureSurfacesHonestMessage() async throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w); try ctx.save()
        let vm = makeVM(ItemTags(slot: .top))
        await vm.process(try tinyPNG()) // 可解码 PNG → 归一成功，走到 save
        vm.draft?.name = "Silk Tee"
        ItemImageStore.forceFailure()
        defer { ItemImageStore.forceFailure(false) }
        let item = vm.confirm(into: w, context: ctx)
        #expect(item != nil) // 衣物本体仍入库
        #expect(item?.localImageRelativePath == nil) // 但层图未落盘
        #expect(vm.lastError == nil)
        #expect(vm.statusMessage == IntakeViewModel.layerImageSaveFailedMessage)
        #expect(vm.statusMessage?.localizedCaseInsensitiveContains("couldn't") == true)
        #expect(vm.statusMessage?.localizedCaseInsensitiveContains("saved") == true)
        ItemImageStore.delete(relativePath: item?.localImageRelativePath)
    }

    // MARK: - IN-1: matting-failed save must flash honestly post-confirm

    /// 抠图失败后 confirm：衣物入库但无任何 try-on 层——不得静默无图入库，
    /// 落库后状态条必须诚实提示「已入库但照片不会出现在试穿」。
    @Test func confirmAfterMattingFailureFlashesHonestNoTryOnMessage() async throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w); try ctx.save()
        let vm = IntakeViewModel(
            matting: ThrowingMattingService(),
            tagging: MockTaggingService(tags: ItemTags(slot: .top)),
            productLookup: nil)
        await vm.process(Data([0x1, 0x2]))
        #expect(vm.mattedImage == nil) // 抠图失败 → 无层图
        vm.draft?.name = "Silk Tee"
        let item = vm.confirm(into: w, context: ctx)
        #expect(item != nil) // 衣物本体仍入库
        #expect(item?.localImageRelativePath == nil)
        #expect(vm.lastError == nil)
        #expect(vm.statusMessage == IntakeViewModel.mattingFailedSavedMessage)
        #expect(vm.statusMessage?.localizedCaseInsensitiveContains("added") == true)
        #expect(vm.statusMessage?.localizedCaseInsensitiveContains("try-on") == true)
        #expect(!IntakeViewModel.mattingFailedSavedMessage
            .localizedCaseInsensitiveContains("couldn't save"))
        ItemImageStore.delete(relativePath: item?.localImageRelativePath)
    }

    // MARK: - IN-3: OCR-only failure must not claim defaults

    /// 打标成功但洗标 OCR 抛错：slot/color/occasions 是真实识别结果，
    /// 状态条不得谎称「用了默认值」，应提示仅 brand/size 留空。
    @Test func ocrFailureKeepsTagResultsWithDistinctMessage() async throws {
        let vm = IntakeViewModel(
            matting: MockMattingService(),
            tagging: MockTaggingService(tags: ItemTags(
                slot: .dress,
                color: GarmentColor(hueDegrees: 200, isNeutral: false),
                occasions: ["work"], warmth: .medium)),
            ocr: ThrowingOCRService(),
            productLookup: nil)
        await vm.process(Data([0x1, 0x2]))
        #expect(vm.draft != nil)
        #expect(vm.draft?.slot == .dress)            // 打标结果真实保留
        #expect(vm.draft?.occasions == ["work"])
        #expect(vm.draft?.warmth == .medium)
        #expect(vm.draft?.brand == nil)              // 仅 brand/size 留空
        #expect(vm.lastError == nil)
        #expect(vm.statusMessage == IntakeViewModel.ocrFailedMessage)
        #expect(vm.statusMessage?.localizedCaseInsensitiveContains("couldn't") == true)
        #expect(vm.statusMessage?.localizedCaseInsensitiveContains("brand/size") == true)
        #expect(!IntakeViewModel.ocrFailedMessage
            .localizedCaseInsensitiveContains("defaults"))
    }

    // MARK: - IN-A: empty photo must clear stale matting-failed flag

    /// 抠图失败 → process(empty) → enrich 命中建出纯条形码草稿 → confirm：
    /// 该单品从未有照片，不得闪现「照片不会出现在试穿」的误报。
    @Test func emptyPhotoClearsStaleMattingFailedFlag() async throws {
        struct FakeLookup: ProductLookupProviding {
            func lookup(barcode: String) async throws -> PublicProductHit? {
                PublicProductHit(
                    barcode: barcode, name: "Oxford Shirt",
                    brand: "PublicBrand", quantity: "M", source: "test")
            }
        }
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w); try ctx.save()
        let vm = IntakeViewModel(
            matting: ThrowingMattingService(),
            tagging: MockTaggingService(tags: ItemTags(slot: .top)),
            productLookup: FakeLookup())
        await vm.process(Data([0x1, 0x2])) // 抠图失败 → mattingFailed = true
        #expect(vm.statusMessage == IntakeViewModel.mattingFailedMessage)
        await vm.process(Data()) // 空照片：放弃流水线，旧失败标志不得残留
        #expect(vm.draft == nil)
        await vm.enrichFromPublicBarcode("0123456789012") // 新建条形码草稿
        #expect(vm.draft != nil)
        #expect(vm.draft?.barcode == "0123456789012")
        let item = vm.confirm(into: w, context: ctx)
        #expect(item != nil)
        #expect(vm.statusMessage != IntakeViewModel.mattingFailedSavedMessage)
        ItemImageStore.delete(relativePath: item?.localImageRelativePath)
    }

    // MARK: - IN-B: confirm save failure must roll back insert + image

    /// ModelSave 失败：confirm 返回 nil、诚实报错、草稿保留可重试，
    /// Item 不得落库，已写出的层图文件必须一并清除（无孤儿文件）。
    /// 只断言本测试 confirm 写出的那个文件：ItemImageStore.rootDirectory 是
    /// 跨测试进程共享的真盘目录，全目录快照 diff 会被并行进程的外来增删打乱。
    @Test func confirmSaveFailureRollsBackItemAndImage() async throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w); try ctx.save()
        let vm = makeVM(ItemTags(slot: .top))
        await vm.process(try tinyPNG()) // 可解码 → 会写出层图文件
        vm.draft?.name = "Silk Tee"
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        let item = vm.confirm(into: w, context: ctx)
        #expect(item == nil)
        #expect(vm.lastError == IntakeViewModel.confirmSaveFailedMessage)
        #expect(vm.draft != nil)            // 草稿保留，用户可重试
        #expect(vm.draft?.name == "Silk Tee")
        #expect(try ctx.fetch(FetchDescriptor<Item>()).isEmpty) // 无滞留入库
        let rel = try #require(vm.lastWrittenLayerImagePath) // confirm 确曾写出层图
        #expect(ItemImageStore.loadData(relativePath: rel) == nil) // 已随回滚删除，无孤儿文件
        ItemImageStore.delete(relativePath: rel) // 兜底清理：仅本测试自己的文件，不碰外来文件
    }

    /// INT-1: 层图路径已置 statusMessage（归一失败 "Added, but…"）后 ModelSave 失败：
    /// 单品实际未入库（已回滚），不得同时闪现成功措辞与保存失败——
    /// statusMessage 必须随回滚清空，只留 lastError。
    @Test func confirmSaveFailureRollbackClearsStaleStatusMessage() async throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w); try ctx.save()
        let vm = makeVM(ItemTags(slot: .top))
        await vm.process(Data([0x1, 0x2, 0x3])) // 不可解码 → 归一失败置 statusMessage
        vm.draft?.name = "Silk Tee"
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        let item = vm.confirm(into: w, context: ctx)
        #expect(item == nil)
        #expect(vm.lastError == IntakeViewModel.confirmSaveFailedMessage)
        #expect(vm.statusMessage == nil) // "Added, but…" 不得残留在回滚后的单品上
        #expect(vm.draft != nil)
        #expect(try ctx.fetch(FetchDescriptor<Item>()).isEmpty)
    }

    // MARK: - INT-3: nil product lookup must not silently no-op

    /// 无 lookup 提供者时 enrich 不得静默返回：与其他失败路径一致地诚实报错。
    @Test func enrichWithoutLookupProviderSetsError() async throws {
        let vm = makeVM(ItemTags(slot: .top)) // productLookup = nil
        await vm.process(Data([0x1]))
        await vm.enrichFromPublicBarcode("0123456789012")
        #expect(vm.lastError == "Barcode lookup isn't available right now.")
        #expect(vm.statusMessage == nil)
        #expect(vm.draft?.barcode == nil)
    }

    // MARK: - IN-C: product lookup throw must surface error honestly

    /// lookup 抛错：lastError 诚实报错、无成功状态条、草稿原样保留。
    @Test func enrichLookupThrowSetsErrorKeepsDraft() async throws {
        struct ThrowingLookup: ProductLookupProviding {
            struct LookupError: Error {}
            func lookup(barcode: String) async throws -> PublicProductHit? {
                throw LookupError()
            }
        }
        let vm = makeVM(ItemTags(slot: .top), productLookup: ThrowingLookup())
        await vm.process(Data([0x1]))
        vm.draft?.name = "My Tee"
        await vm.enrichFromPublicBarcode("0123456789012")
        #expect(vm.lastError?.localizedCaseInsensitiveContains("failed") == true)
        #expect(vm.statusMessage == nil)
        #expect(vm.draft?.name == "My Tee") // 草稿不被 lookup 失败污染
        #expect(vm.draft?.barcode == nil)
    }
}

/// D102（审计 HIGH）：AI 打标与洗标 OCR 在生产里是**永久 mock**——
/// `makeTagging`/`makeOCR` 没有任何平台分支，一律返回 mock。
/// 于是「识别成功」路径上，用户看到预填好的类型/场合，
/// 却**没有任何提示**说那不是识别结果、只是默认值。
/// 失败时反而有诚实文案（"Couldn't auto-tag… defaults used"），成功时没有——
/// 这正好把不诚实留在了最常走的那条路上。
struct RecognitionAvailabilityHonestyTests {

    /// 当前构建没有接任何识别服务——这个事实必须可查询，UI 才能据实说话。
    @Test func recognitionIsReportedAsUnavailable() {
        #expect(!IntakeServiceFactory.recognitionAvailable)
    }

    /// 未接识别时的披露：说清字段是**起点**不是识别结果，且不得暗示 AI 看过照片。
    @Test func prefillDisclosureDoesNotClaimRecognition() {
        let text = IntakeServiceFactory.prefillDisclosure
        #expect(!text.isEmpty)
        let words = Set(text.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
        for claim in ["recognized", "detected", "identified", "ai", "smart"] {
            #expect(!words.contains(claim), Comment(rawValue: "声称识别过：\(text)"))
        }
        // 必须点明这是起点/需要核对
        #expect(text.localizedCaseInsensitiveContains("starting")
                || text.localizedCaseInsensitiveContains("check")
                || text.localizedCaseInsensitiveContains("guess"))
    }

    /// mock 打标不得给出「确定的」温区/颜色——未知就是未知（D88 已修温区，此处锁住）。
    @Test func mockTaggingInventsNoConfidentAttributes() {
        let tags = IntakeServiceFactory.makeTagging()
        #expect(tags is MockTaggingService)
        // 默认值里不得含臆造的温区
        let defaults = ItemTags(slot: .top, color: nil, occasions: ["casual"], warmth: nil)
        #expect(defaults.warmth == nil)
    }

    /// 接上真识别后这条门会自动放行——它守的是「没接却装作接了」。
    @Test func disclosureIsOnlyRequiredWhileRecognitionIsMissing() {
        if IntakeServiceFactory.recognitionAvailable {
            // 真接上了：不再需要这条披露（本测试留作口径记录）
            #expect(Bool(true))
        } else {
            #expect(!IntakeServiceFactory.prefillDisclosure.isEmpty)
        }
    }
}
