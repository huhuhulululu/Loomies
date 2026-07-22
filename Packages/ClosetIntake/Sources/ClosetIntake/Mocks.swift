import Foundation
import ClosetCore

/// Mock 抠图：直通（模拟器/测试；Vision 模拟器不可用，DESIGN §4.2）。
public struct MockMattingService: MattingService {
    public init() {}
    public func removeBackground(_ imageData: Data) async throws -> Data { imageData }
}

/// Mock 打标：返回注入的固定标签。
public struct MockTaggingService: TaggingService {
    public let tags: ItemTags
    public init(tags: ItemTags) { self.tags = tags }
    public func tag(_ imageData: Data) async throws -> ItemTags { tags }
}

/// Mock OCR：返回注入的固定洗标。
public struct MockOCRService: OCRService {
    public let info: LabelInfo
    public init(info: LabelInfo) { self.info = info }
    public func readLabel(_ imageData: Data) async throws -> LabelInfo { info }
}
