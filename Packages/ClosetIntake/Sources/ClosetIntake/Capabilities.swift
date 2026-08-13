import Foundation
import ClosetCore

// F1 能力协议（DESIGN §F1，MVP-PLAN SI-0）：真机用 Vision，模拟器/测试用 mock，DI 切换无需改调用点。

/// 抠图（VNGenerateForegroundInstanceMaskRequest，真机；mock 直通）。
public protocol MattingService: Sendable {
    func removeBackground(_ imageData: Data) async throws -> Data
}

/// AI 打标（云端 VLM，真机经代理；mock 返回固定标签）。
public protocol TaggingService: Sendable {
    func tag(_ imageData: Data) async throws -> ItemTags
}

/// 洗标 OCR（RecognizeDocumentsRequest，真机；mock 返回固定）。
public protocol OCRService: Sendable {
    func readLabel(_ imageData: Data) async throws -> LabelInfo
}

/// AI 预填标签（全部可编辑，color 弱置信见 §F1）。
public struct ItemTags: Sendable, Equatable {
    public var slot: GarmentSlot
    public var color: GarmentColor?
    public var occasions: Set<String>
    public var warmth: Warmth?
    public init(slot: GarmentSlot, color: GarmentColor? = nil,
                occasions: Set<String> = [], warmth: Warmth? = nil) {
        self.slot = slot; self.color = color; self.occasions = occasions; self.warmth = warmth
    }
}

/// 洗标抽取结果（仅入库用到的字段；material 无人消费，已从契约中移除）。
public struct LabelInfo: Sendable, Equatable {
    public var brand: String?
    public var size: String?
    public init(brand: String? = nil, size: String? = nil) {
        self.brand = brand; self.size = size
    }
}

/// 入库草稿（落库前的中间态，单屏确认时用户可改）。
public struct IntakeDraft: Sendable, Equatable {
    public var name: String
    public var slot: GarmentSlot
    public var color: GarmentColor?
    public var occasions: Set<String>
    public var warmth: Warmth?
    public var brand: String?
    public var size: String?
    /// Optional retail barcode (UPC/EAN/GTIN digits) for Open*Facts lookup.
    public var barcode: String?
    /// 预填时给的那个类型（D194）。用户在确认页把 `slot` 改成别的
    /// 才算「明确设过」——**没碰过的预填不算**，那只是个猜测。
    public private(set) var suggestedSlot: GarmentSlot
    public var slotWasChangedByUser: Bool { slot != suggestedSlot }

    /// Default name is empty so confirm UI can require an intentional label
    /// (process() usually prefills brand + slot display title).
    public init(name: String = "", slot: GarmentSlot = .top) {
        self.name = name; self.slot = slot; self.occasions = []
        self.suggestedSlot = slot
    }
}
