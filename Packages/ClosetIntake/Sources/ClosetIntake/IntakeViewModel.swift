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
            AppLog.error("intake matting failed: \(error)", .intake)
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
            AppLog.error("intake tagging failed: \(error)", .intake)
        }
        var d = IntakeDraft(slot: tags?.slot ?? .top)
        d.color = tags?.color
        d.occasions = tags?.occasions ?? []
        d.warmth = tags?.warmth
        var ocrFailed = false
        if let ocr {
            do {
                let label = try await ocr.readLabel(imageData)
                d.brand = label.brand
                d.size = label.size
            } catch {
                ocrFailed = true
                AppLog.error("intake OCR failed: \(error)", .intake)
            }
        }
        d.name = Self.suggestedName(for: d)
        guard generation == processGeneration else { return }  // 已被新照片/reset 取代
        mattedImage = mattingSucceeded ? workingImage : nil
        mattingFailed = !mattingSucceeded
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

    /// Primary occasions for Today filters. Empty tag/draft → `casual` so looks can match.
    public static func normalizedOccasions(_ occasions: Set<String>) -> [String] {
        let cleaned = occasions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        if cleaned.isEmpty { return ["casual"] }
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
            if (d.brand == nil || d.brand?.isEmpty == true), let b = hit.brand, !b.isEmpty {
                d.brand = b
                filledAny = true
            }
            if d.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let suggested = hit.suggestedItemName {
                d.name = suggested
                filledAny = true
            }
            // Only map quantity when it looks like apparel size (not "2 pack" / "500g").
            if (d.size == nil || d.size?.isEmpty == true),
               let q = hit.quantity, PublicSizeReference.looksLikeApparelSize(q) {
                d.size = q
                filledAny = true
            }
            draft = d
            lastError = nil
            statusMessage = filledAny
                ? Self.barcodeFilledMessage(source: hit.source)
                : Self.barcodeFoundNothingToFillMessage
            AppLog.info("product facts hit source=\(hit.source) code=\(code) filled=\(filledAny)", .intake)
        } catch {
            guard generation == processGeneration else { return }  // 已被 reset/新照片取代
            lastError = "Product lookup failed. You can still enter details manually."
            statusMessage = nil
            AppLog.error("product lookup: \(error)", .intake)
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
        let slot = Self.persistSlot(draftSlot: d.slot, name: name)
        item.slotRaw = slot.rawValue
        item.occasionsRaw = Self.normalizedOccasions(d.occasions)
        item.warmthRaw = d.warmth?.rawValue
        if let c = d.color { item.colorHue = c.hueDegrees; item.colorIsNeutral = c.isNeutral }
        item.brand = d.brand
        item.sizeLabel = d.size
        item.barcode = d.barcode
        item.statusRaw = "available"
        context.insert(item)
        if let img = mattedImage {
            // 叠衣层归一：紧 bbox + 槽位肩/腰/脚对齐标准画布
            let bodySlot = Self.layerNormalizeSlot(slotRaw: slot.rawValue, name: name)
            if let layerPNG = GarmentLayerNormalizer.normalize(imageData: img, slot: bodySlot) {
                if let rel = ItemImageStore.save(data: layerPNG, for: item.id, ext: "png") {
                    item.localImageRelativePath = rel
                    lastWrittenLayerImagePath = rel // test hook：回滚测试精确断言此文件
                } else {
                    // 磁盘写失败：衣物本体仍入库，但层图丢失不得静默——诚实提示可重拍。
                    statusMessage = Self.layerImageSaveFailedMessage
                    AppLog.error("intakeConfirm layer image save failed \(name)", .intake)
                }
            } else {
                // 归一失败不回存紧裁剪图：叠衣 composer 把任何 hasVisual 层当全身画布，
                // 紧 bbox 会被拉成全身拉伸。留空 → 槽位占位框，并诚实提示可重拍。
                statusMessage = Self.layerNormalizeFailedMessage
                AppLog.error("intakeConfirm layer normalize failed \(name)", .intake)
            }
        }
        guard ModelSave.save(context, label: "intakeConfirm") else {
            // Roll back insert + local image; keep draft so user can retry (no silent success).
            let path = item.localImageRelativePath
            context.delete(item)
            ItemImageStore.delete(relativePath: path)
            lastError = Self.confirmSaveFailedMessage
            // 层图路径可能已置 statusMessage（"Added, but…"）——但本次落库已回滚，
            // 单品并未入库，不得同时闪现成功措辞与保存失败（lastError 与 statusMessage 互斥）。
            statusMessage = nil
            AppLog.error("intakeConfirm save failed \(name)", .intake)
            return nil
        }
        if mattingFailed {
            // 抠图失败路径：衣物已入库但没有任何 try-on 层——诚实提示，不静默无图入库。
            statusMessage = Self.mattingFailedSavedMessage
            AppLog.info("intakeConfirm saved without try-on layer (matting failed) \(name)", .intake)
        }
        // confirm 成功也是一代终结：在途 enrich 的代际守卫必须失效，
        // 否则 lookup 返回时守卫通过 → 富化草稿在落库后复活，再次 confirm 生成重复单品。
        processGeneration += 1
        draft = nil
        mattedImage = nil
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
        "Added, but the photo won't appear in try-on — re-add the photo later."

    /// Customer toast when ModelSave fails on Add to closet.
    public static let confirmSaveFailedMessage = "Couldn't save — try again"

    /// Honest flash when layer normalization fails: item is saved, but the photo
    /// layer is skipped (slot placeholder, never a body-stretched tight crop).
    public static let layerNormalizeFailedMessage =
        "Added, but the photo couldn't be aligned for try-on — re-add the photo later."

    /// Honest flash when the normalized layer PNG can't be written to disk:
    /// item is saved, but the image is lost (no silent image-less save).
    public static let layerImageSaveFailedMessage =
        "Added, but the photo couldn't be saved for try-on — re-add the photo later."

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
        mattingFailed = false
        isProcessing = false
        lastError = nil
        statusMessage = nil
    }
}
