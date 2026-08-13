import Foundation
import Observation
import SwiftData
import ClosetModel
import ClosetCore

/// 入库流水线编排（DESIGN §F1）：连拍/导入 → 抠图 → AI 预填 → 单屏确认 → 落库。
/// 能力经协议注入，逻辑可 swift test；真机换 Real* 实现。
@MainActor
@Observable
public final class IntakeViewModel {
    private let matting: any MattingService
    private let tagging: any TaggingService
    private let ocr: (any OCRService)?

    public var draft: IntakeDraft?
    public private(set) var mattedImage: Data?
    /// 抠图结果的代号。换一张图 / 手修一笔都自增——**预备好的层图靠它判新旧**，
    /// 比拿 `Data` 做等值比较便宜（那是逐字节 O(n)，而这条路每次击键都会走）。
    public private(set) var mattedGeneration = 0
    /// 抠图前的原图。手修的「找回」要从这里取像素——不留着就只能擦不能恢复（D96）。
    /// 手修结果回写（D96）。只在有真改动时调用，避免无谓重编码。
    @discardableResult
    public func applyRetouchedMatte(_ data: Data) -> Bool {
        guard mattedImage != nil else { return false }
        mattedImage = data
        mattedGeneration &+= 1
        preparedLayer = nil          // 手修过了，预备的那张作废
        AppLog.info("matte retouched", .intake)
        return true
    }

    // MARK: - 叠衣层预备（D194）

    /// 已经在后台算好的叠衣层。
    ///
    /// D181 把解码封了顶（12MP 6597ms → 1657ms，debug），但那条链**仍在主线程**：
    /// `confirm()` 是一次原子的 SwiftData 写（insert + 落盘 + save + 失败回滚），
    /// 把它改 async 会波及按钮闭包与批量队列的次序与重入。
    ///
    /// 换个方向：**别让 confirm 那一下才开始算**。用户在确认页填名字/改类型的
    /// 这几秒里后台就把层图备好，confirm 只是取现成的。
    /// 备不及（用户秒按、或刚改完类型）则原地算——**正确性不依赖预备是否命中**。
    private var preparedLayer: (generation: Int, slot: BodyAvatarSlot, png: Data)?

    /// 预备的 key：抠图代号 + 归一目标槽位。槽位由类型与名字共同决定，
    /// 所以用户改任一个都会让它变，`.task(id:)` 随之重跑。
    public var layerPrepKey: String {
        guard let d = draft else { return "none" }
        let slot = Self.layerNormalizeSlot(slotRaw: d.slot.rawValue, name: d.name)
        return "\(mattedGeneration)|\(slot.rawValue)"
    }

    /// 后台算好叠衣层。可重复调用；被取消或输入已变则不落地。
    public func prepareLayer() async {
        guard let image = mattedImage, let d = draft else { return }
        let generation = mattedGeneration
        let slot = Self.layerNormalizeSlot(slotRaw: d.slot.rawValue, name: d.name)
        if let ready = preparedLayer, ready.generation == generation, ready.slot == slot { return }
        let png = await Task.detached(priority: .userInitiated) {
            GarmentLayerNormalizer.normalize(imageData: image, slot: slot)
        }.value
        guard !Task.isCancelled, mattedGeneration == generation, let png else { return }
        preparedLayer = (generation, slot, png)
        AppLog.debug("layer prepared slot=\(slot.rawValue)", .intake)
    }

    /// 取预备好的层图；没命中返回 nil（调用方原地算）。
    func preparedLayerPNG(slot: BodyAvatarSlot) -> Data? {
        guard let ready = preparedLayer,
              ready.generation == mattedGeneration, ready.slot == slot
        else { return nil }
        return ready.png
    }

    public private(set) var originalImage: Data?
    public private(set) var isProcessing = false
    /// User-facing last failure (empty photo, blank name, etc.).
    public private(set) var lastError: String?
    /// Non-error flash (barcode fill / nothing-to-change). Cleared on next error or reset.
    public private(set) var statusMessage: String?

    /// Test hook: relative path of the layer image written by the most recent
    /// `confirm` (nil when no image was written). Lets save-failure rollback tests
    /// assert on the exact file instead of diffing the shared ItemImageStore
    /// directory, which parallel test-bundle processes also mutate.
    /// Mirrors ModelSave/ItemImageStore forceFailure hooks.
    private(set) var lastWrittenLayerImagePath: String?

    private let productLookup: (any ProductLookupProviding)?

    /// 代际计数：process() 新调用与 reset() 自增，在途旧调用的结果被丢弃。
    private var processGeneration = 0

    /// 抠图曾失败：confirm 落库时无 try-on 层，须事后诚实提示（非静默无图入库）。
    private var mattingFailed = false

    /// D193：这一张照片的**洗标 OCR 真读出东西了吗**。
    ///
    /// 确认页那句「Brand and size were read from the label photo」此前挂在
    /// `brand != nil || size != nil` 上——而用户自己敲、条码富化写入都会让它非空；
    /// 模拟器/macOS 走 `MockOCRService(info: LabelInfo())`（两个字段恒 nil），
    /// 真机 OCR 认不出品牌时用户手敲——两条路上那句话都是**假的**。
    public private(set) var brandOrSizeFromLabel = false

    /// D193：颜色是**从像素投票猜的**吗（D124）。
    ///
    /// 猜出来的颜色渲染成一个已选色点，与用户手选的形态不可区分，
    /// 而颜色是 `OutfitScorer` 的输入（配色协调 / 60-30-10 / 色季）。
    /// 打标器直接给的颜色不算——那是另一条来源。
    public private(set) var colorFromPhoto = false

    public init(
        matting: any MattingService,
        tagging: any TaggingService,
        ocr: (any OCRService)? = nil,
        productLookup: (any ProductLookupProviding)? = OpenProductFactsClient()
    ) {
        self.matting = matting
        self.tagging = tagging
        self.ocr = ocr
        self.productLookup = productLookup
    }

    /// True when draft has a non-empty trimmed name ready to save.
    public var canConfirm: Bool {
        guard let name = draft?.name else { return false }
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 处理一张原图 → 生成可编辑草稿。
    public func process(_ imageData: Data) async {
        processGeneration += 1   // 新照片/reset 使在途旧结果作废（last-call-wins）
        let generation = processGeneration
        lastError = nil
        statusMessage = nil
        guard !imageData.isEmpty else {
            draft = nil
            mattedImage = nil
            originalImage = nil
            // 空照片即放弃整条流水线：旧的抠图失败标志不得残留，
            // 否则后续条形码草稿 confirm 会误报「照片不会出现在试穿」。
            mattingFailed = false
            lastError = "That photo was empty. Try another shot or enter details manually."
            // 本分支已推进代际：在途旧调用的 defer 不会再清 isProcessing（代际不匹配），
            // 必须在此显式复位，否则 UI 永久卡在 Processing。
            isProcessing = false
            return
        }
        isProcessing = true
        defer {
            // 仅最新一代收尾清标志；被取代的旧调用不得误清 isProcessing。
            if generation == processGeneration { isProcessing = false }
        }
        // 抠图失败诚实记录：不把未抠整图当叠衣层存（confirm 会跳过层图），
        // 草稿仍用原图打标生成，用户可手动入库。
        let workingImage: Data
        var mattingSucceeded = true
        do {
            workingImage = try await matting.removeBackground(imageData)
        } catch {
            workingImage = imageData
            mattingSucceeded = false
            AppLog.error("intake matting failed: \(AppLog.errRef(error))", .intake)
        }
        // 打标/OCR 失败同样诚实：打标失败草稿退回默认（top/casual），状态条提示
        // 「自动预填失败」；仅 OCR 失败时打标结果是真的，不得谎称「用了默认值」。
        // 不得静默当默认就是识别结果（用户可手动改，不阻塞入库）。
        var taggingFailed = false
        let tags: ItemTags?
        do {
            tags = try await tagging.tag(workingImage)
        } catch {
            tags = nil
            taggingFailed = true
            AppLog.error("intake tagging failed: \(AppLog.errRef(error))", .intake)
        }
        var d = IntakeDraft(slot: tags?.slot ?? .top)
        d.color = tags?.color
        // D124：颜色此前永远是「未知」，除非用户逐件手选色板——
        // 而它是 `OutfitScorer` 的输入（配色协调 / 60-30-10 / 色季）：
        // 没人填过颜色的衣柜，那几项打分全程不参与。
        // 抠图已经算出来了，主色是顺手就能拿到的东西，不需要任何模型。
        // 只在抠图**成功**时取：失败时 workingImage 是原图，背景色会赢过衣服。
        var colorWasGuessed = false
        if d.color == nil, mattingSucceeded,
           let entry = await DominantColorSampler.dominantEntry(in: workingImage) {
            d.color = entry.color
            colorWasGuessed = true
        }
        d.occasions = tags?.occasions ?? []
        d.warmth = tags?.warmth
        var ocrFailed = false
        var labelFilled = false
        if let ocr {
            do {
                let label = try await ocr.readLabel(imageData)
                d.brand = label.brand
                d.size = label.size
                // D193：判据是「**这一张**真读出东西了吗」，不是「字段非空」。
                labelFilled = label.brand != nil || label.size != nil
            } catch {
                ocrFailed = true
                AppLog.error("intake OCR failed: \(AppLog.errRef(error))", .intake)
            }
        }
        d.name = Self.suggestedName(for: d)
        guard generation == processGeneration else { return }  // 已被新照片/reset 取代
        mattedImage = mattingSucceeded ? workingImage : nil
        mattedGeneration &+= 1
        preparedLayer = nil
        originalImage = imageData
        mattingFailed = !mattingSucceeded
        brandOrSizeFromLabel = labelFilled
        colorFromPhoto = colorWasGuessed
        if !mattingSucceeded {
            statusMessage = Self.mattingFailedMessage
        } else if taggingFailed {
            statusMessage = Self.prefillFailedMessage
        } else if ocrFailed {
            statusMessage = Self.ocrFailedMessage
        }
        draft = d
    }

    /// Brand + slot title when known; otherwise human slot label (never "New item").
    public static func suggestedName(for draft: IntakeDraft) -> String {
        let brand = draft.brand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let slot = draft.slot.displayTitle
        if !brand.isEmpty { return "\(brand) \(slot)" }
        return slot
    }

    /// 入库叠衣层对齐槽：与 `displaySlot` / `GarmentSlot.resolved` 同真相。
    /// 名称纠偏脏 top（blazer/jacket/coat…）到 outerwear 肩区，避免胸前小贴纸。
    public static func layerNormalizeSlot(slotRaw: String, name: String) -> BodyAvatarSlot {
        BodyAvatarComposer.displaySlot(slotRaw: slotRaw, itemName: name) ?? .top
    }

    /// Persist slot = displaySlot truth so Closet Type / filter chips match stacking.
    /// Dirty "top" + "Navy Blazer" → outerwear (not left as raw top).
    public static func persistSlot(draftSlot: GarmentSlot, name: String) -> GarmentSlot {
        GarmentSlot.resolved(draftSlot.rawValue, name: name)
    }

    /// Primary occasions for Today filters.
    ///
    /// D179：空集**保持空集**（= 未知），不偷塞 `casual`。三处依据：
    /// 手填路径（`QuickAddDraft`，D103）就是这么存的；同屏的 `OccasionChips`
    /// 自己印着 “Leave all off if it works for anything.”；而候选硬门
    /// （`CandidateFilter`）对空场合的件本来就**不过滤**——空集不需要一个具体值
    /// 才能被选上。D114 修好了控件回显却没修落库，于是界面显示全关、
    /// 库里是 casual，两者反而更不一致。
    public static func normalizedOccasions(_ occasions: Set<String>) -> [String] {
        let cleaned = occasions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        return Array(Set(cleaned)).sorted()
    }

    /// Enrich draft from public Open*Facts catalogs by barcode (no API key).
    /// Fills empty brand/name/size-ish quantity only — never overwrites user edits.
    /// Sets `statusMessage` on hit (success or nothing-to-fill); `lastError` on
    /// miss/fail or when no lookup provider is available.
    public func enrichFromPublicBarcode(_ rawCode: String) async {
        guard let productLookup else {
            // 无 lookup 能力不得静默无响应：与其他失败路径一致地诚实报错。
            lastError = "Barcode lookup isn't available right now."
            statusMessage = nil
            return
        }
        // 代际守卫：lookup 在途期间 reset/新照片会使结果作废；
        // process() 仍在处理时其收尾会整写 draft，覆盖 enriched 字段 → 诚实中止。
        let generation = processGeneration
        let code = OpenProductFactsClient.normalizeBarcode(rawCode)
        guard !code.isEmpty else {
            lastError = "Enter the digits under the barcode."
            statusMessage = nil
            return
        }
        do {
            guard let hit = try await productLookup.lookup(barcode: code) else {
                guard generation == processGeneration else { return }  // 已被 reset/新照片取代
                lastError = "No public product record for that barcode."
                statusMessage = nil
                return
            }
            guard generation == processGeneration else { return }  // 已被 reset/新照片取代
            guard !isProcessing else {
                // process() 收尾晚于本调用 → 整写 draft 会丢 barcode/富化字段；不静默写一半。
                lastError = nil
                statusMessage = Self.barcodeEnrichAbortedMessage
                AppLog.info("product facts enrich aborted: photo still processing", .intake)
                return
            }
            if draft == nil { draft = IntakeDraft() }
            guard var d = draft else { return }
            d.barcode = code
            var filledAny = false
            // 判空必须 trim（与 name 同标准）：Brand 里误敲的 " " 不得阻塞补全。
            if TextNormalize.isBlank(d.brand), let b = TextNormalize.blankToNil(hit.brand) {
                d.brand = b
                filledAny = true
            }
            if d.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let suggested = hit.suggestedItemName {
                d.name = suggested
                filledAny = true
            }
            // Only map quantity when it looks like apparel size (not "2 pack" / "500g").
            if TextNormalize.isBlank(d.size),
               let q = hit.quantity, PublicSizeReference.looksLikeApparelSize(q) {
                d.size = q
                filledAny = true
            }
            draft = d
            lastError = nil
            statusMessage = filledAny
                ? Self.barcodeFilledMessage(source: hit.source)
                : Self.barcodeFoundNothingToFillMessage
            AppLog.info("product facts hit source=\(hit.source) codeLen=\(code.count) filled=\(filledAny)", .intake)
        } catch {
            guard generation == processGeneration else { return }  // 已被 reset/新照片取代
            lastError = "Product lookup failed. You can still enter details manually."
            statusMessage = nil
            AppLog.error("product lookup: \(AppLog.errRef(error))", .intake)
        }
    }

    /// Success chip after Open*Facts fill — names host when known (no silent green check).
    public static func barcodeFilledMessage(source: String) -> String {
        let host = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if host.isEmpty {
            return "Filled empty fields from Open Facts."
        }
        return "Filled empty fields from \(host)."
    }

    /// Hit with nothing applied (user already typed name/brand/size, or the
    /// record carried no usable fields). Barcode IS still written to the draft,
    /// so the message must not claim "nothing changed" or "already set" — say
    /// exactly what was saved.
    public static let barcodeFoundNothingToFillMessage =
        "Found a public record — nothing new to fill; barcode saved."

    /// Enrich aborted while process() is still in flight: its draft write would land
    /// after enrich and wipe barcode + filled fields, so we drop the hit honestly
    /// instead of writing a half-enriched draft that silently disappears.
    public static let barcodeEnrichAbortedMessage =
        "Still processing the photo — scan the barcode again when it's done."

    /// 用户确认 → 落库为 Item（可用状态）+ 可选本地抠图；清空草稿。
    @discardableResult
    public func confirm(into wardrobe: Wardrobe, context: ModelContext) -> Item? {
        guard let d = draft else {
            lastError = "Nothing to save yet. Add a photo first."
            statusMessage = nil  // lastError 与 statusMessage 互斥：错误不得残留旧成功措辞
            return nil
        }
        let name = d.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            lastError = "Give this piece a name before adding it."
            statusMessage = nil  // 同上：enrich 成功文案不得与命名错误同屏
            return nil
        }
        lastError = nil
        statusMessage = nil
        let item = Item(name: name)
        item.wardrobe = wardrobe
        // Store resolved slot (name-aware) so detail Type / chips == paper-doll layer.
        // D194：用户在确认页动过 Type 就原样存并记住是他设的；
        // 没碰过的预填仍走名字纠偏（「西装写在 top」这类脏数据是它存在的理由）。
        let slot = d.slotWasChangedByUser
            ? d.slot
            : Self.persistSlot(draftSlot: d.slot, name: name)
        item.slotRaw = slot.rawValue
        item.slotUserSet = d.slotWasChangedByUser
        item.occasionsRaw = Self.normalizedOccasions(d.occasions)
        item.warmthRaw = d.warmth?.rawValue
        if let c = d.color { item.colorHue = c.hueDegrees; item.colorIsNeutral = c.isNeutral }
        // 落库归一（与 ItemEditorService 同标准）：空白转 nil、真值 trim。
        item.brand = TextNormalize.blankToNil(d.brand)
        item.sizeLabel = TextNormalize.blankToNil(d.size)
        item.barcode = d.barcode
        item.statusRaw = "available"
        context.insert(item)
        if let img = mattedImage {
            // 叠衣层归一：紧 bbox + 槽位肩/腰/脚对齐标准画布
            let bodySlot = Self.layerNormalizeSlot(slotRaw: slot.rawValue, name: name)
            // D194：优先用后台备好的那张；没备上（用户秒按/刚改完类型）才原地算。
            let layer = preparedLayerPNG(slot: bodySlot)
                ?? GarmentLayerNormalizer.normalize(imageData: img, slot: bodySlot)
            if let layerPNG = layer {
                if let rel = ItemImageStore.save(data: layerPNG, for: item.id, ext: "png") {
                    item.localImageRelativePath = rel
                    lastWrittenLayerImagePath = rel // test hook：回滚测试精确断言此文件
                    // D111：层图是**归一裁剪过**的，带不走原样，也没法重新抠。
                    // 相机路径不写相册（只转手 jpegData），不存这一份 = 永久丢弃用户的照片。
                    // 失败只记日志不打断：衣物本体与层图都已就绪，为一份旁挂档拦下整个入库
                    // 与代价不成比例（导出届时按实际有的份数如实说话）。
                    if let source = originalImage,
                       ItemImageStore.saveSourcePhoto(source, layerRelativePath: rel) == nil {
                        AppLog.error(
                            "intakeConfirm source photo save failed item=\(AppLog.ref(item.id))",
                            .intake)
                    }
                } else {
                    // 磁盘写失败：衣物本体仍入库，但层图丢失不得静默——诚实提示可重拍。
                    statusMessage = Self.layerImageSaveFailedMessage
                    AppLog.error("intakeConfirm layer image save failed item=\(AppLog.ref(item.id))", .intake)
                }
            } else {
                // 归一失败不回存紧裁剪图：叠衣 composer 把任何 hasVisual 层当全身画布，
                // 紧 bbox 会被拉成全身拉伸。留空 → 槽位占位框，并诚实提示可重拍。
                statusMessage = Self.layerNormalizeFailedMessage
                AppLog.error("intakeConfirm layer normalize failed item=\(AppLog.ref(item.id))", .intake)
            }
        }
        guard ModelSave.save(context, label: "intakeConfirm") else {
            // Roll back insert + local image; keep draft so user can retry (no silent success).
            // 断关系 + rollback（delete 只删行，wardrobe.items 幻影与脏标记滞留）。
            let path = item.localImageRelativePath
            item.wardrobe = nil
            context.rollback()
            ItemImageStore.delete(relativePath: path)
            lastError = Self.confirmSaveFailedMessage
            // 层图路径可能已置 statusMessage（"Added, but…"）——但本次落库已回滚，
            // 单品并未入库，不得同时闪现成功措辞与保存失败（lastError 与 statusMessage 互斥）。
            statusMessage = nil
            AppLog.error("intakeConfirm save failed item=\(AppLog.ref(item.id))", .intake)
            return nil
        }
        if mattingFailed {
            // 抠图失败路径：衣物已入库但没有任何 try-on 层——诚实提示，不静默无图入库。
            statusMessage = Self.mattingFailedSavedMessage
            AppLog.info("intakeConfirm saved without try-on layer (matting failed) item=\(AppLog.ref(item.id))", .intake)
        }
        // confirm 成功也是一代终结：在途 enrich 的代际守卫必须失效，
        // 否则 lookup 返回时守卫通过 → 富化草稿在落库后复活，再次 confirm 生成重复单品。
        processGeneration += 1
        draft = nil
        mattedImage = nil
        originalImage = nil
        mattingFailed = false
        return item
    }

    /// Honest flash when background removal fails: draft stays editable, but the
    /// uncut full-frame photo is never stored as a try-on layer (no chest sticker).
    public static let mattingFailedMessage =
        "Couldn't cut out the photo — it won't appear in try-on. You can still add the item."

    /// Post-save flash when matting failed earlier: the item is in the closet but
    /// has no try-on layer at all — never a silent image-less save.
    public static let mattingFailedSavedMessage =
        "Added, but the photo won't appear in try-on — add a photo from the piece's page."

    /// Customer toast when ModelSave fails on Add to closet.
    public static let confirmSaveFailedMessage = "Couldn't save — try again"

    /// Honest flash when layer normalization fails: item is saved, but the photo
    /// layer is skipped (slot placeholder, never a body-stretched tight crop).
    public static let layerNormalizeFailedMessage =
        "Added, but the photo couldn't be aligned for try-on — add a photo from the piece's page."

    /// Honest flash when the normalized layer PNG can't be written to disk:
    /// item is saved, but the image is lost (no silent image-less save).
    public static let layerImageSaveFailedMessage =
        "Added, but the photo couldn't be saved for try-on — add a photo from the piece's page."

    /// Honest flash when AI pre-fill (tags/OCR) throws: draft falls back to
    /// defaults (top/casual) which the user must review — never presented as
    /// a real recognition result.
    public static let prefillFailedMessage =
        "Couldn't auto-tag the photo — defaults used; please review before adding."

    /// Honest flash when tagging succeeds but care-label OCR throws: tag results
    /// (slot/color/occasions) are real; only brand/size are left blank — the
    /// message must not claim defaults were used.
    public static let ocrFailedMessage =
        "Couldn't read the care label — brand/size left blank."

    public func reset() {
        processGeneration += 1   // 取消在途 process()：其结果不得复活草稿
        draft = nil
        mattedImage = nil
        originalImage = nil
        mattingFailed = false
        preparedLayer = nil            // D194：上一张备好的层图不得留给下一张
        brandOrSizeFromLabel = false   // D193：上一张的判断不得留给下一张
        colorFromPhoto = false
        isProcessing = false
        lastError = nil
        statusMessage = nil
    }
}
