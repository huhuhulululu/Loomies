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

    public init(matting: any MattingService, tagging: any TaggingService, ocr: (any OCRService)? = nil) {
        self.matting = matting; self.tagging = tagging; self.ocr = ocr
    }

    /// True when draft has a non-empty trimmed name ready to save.
    public var canConfirm: Bool {
        guard let name = draft?.name else { return false }
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 处理一张原图 → 生成可编辑草稿。
    public func process(_ imageData: Data) async {
        lastError = nil
        guard !imageData.isEmpty else {
            draft = nil
            mattedImage = nil
            lastError = "That photo was empty. Try another shot or enter details manually."
            return
        }
        isProcessing = true
        defer { isProcessing = false }
        let matted = (try? await matting.removeBackground(imageData)) ?? imageData
        mattedImage = matted
        let tags = try? await tagging.tag(matted)
        var d = IntakeDraft(slot: tags?.slot ?? .top)
        d.color = tags?.color
        d.occasions = tags?.occasions ?? []
        d.warmth = tags?.warmth
        if let ocr, let label = try? await ocr.readLabel(imageData) {
            d.brand = label.brand
            d.size = label.size
        }
        d.name = Self.suggestedName(for: d)
        draft = d
    }

    /// Brand + slot title when known; otherwise human slot label (never "New item").
    public static func suggestedName(for draft: IntakeDraft) -> String {
        let brand = draft.brand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let slot = draft.slot.displayTitle
        if !brand.isEmpty { return "\(brand) \(slot)" }
        return slot
    }

    /// 用户确认 → 落库为 Item（可用状态）+ 可选本地抠图；清空草稿。
    @discardableResult
    public func confirm(into wardrobe: Wardrobe, context: ModelContext) -> Item? {
        guard let d = draft else {
            lastError = "Nothing to save yet. Add a photo first."
            return nil
        }
        let name = d.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            lastError = "Give this piece a name before adding it."
            return nil
        }
        lastError = nil
        let item = Item(name: name)
        item.wardrobe = wardrobe
        item.slotRaw = d.slot.rawValue
        item.occasionsRaw = Array(d.occasions)
        item.warmthRaw = d.warmth?.rawValue
        if let c = d.color { item.colorHue = c.hueDegrees; item.colorIsNeutral = c.isNeutral }
        item.brand = d.brand
        item.sizeLabel = d.size
        item.statusRaw = "available"
        context.insert(item)
        if let img = mattedImage {
            // 叠衣层归一：紧 bbox + 槽位肩/腰/脚对齐标准画布
            let slot = BodyAvatarComposer.mapSlot(item.slotRaw) ?? .top
            let layerPNG = GarmentLayerNormalizer.normalize(imageData: img, slot: slot) ?? img
            if let rel = ItemImageStore.save(data: layerPNG, for: item.id, ext: "png") {
                item.localImageRelativePath = rel
            }
        }
        ModelSave.save(context, label: "intakeConfirm")
        draft = nil
        mattedImage = nil
        return item
    }

    public func reset() {
        draft = nil
        mattedImage = nil
        isProcessing = false
        lastError = nil
    }
}
