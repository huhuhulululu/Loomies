import Foundation
import ClosetCore

/// 按平台选择抠图/打标实现：真机优先 Vision；模拟器/mac 回退 mock。
public enum IntakeServiceFactory {

    @MainActor
    public static func makeViewModel() -> IntakeViewModel {
        IntakeViewModel(
            matting: makeMatting(),
            tagging: makeTagging(),
            ocr: makeOCR())
    }

    public static func makeMatting() -> any MattingService {
        #if canImport(Vision) && os(iOS) && !targetEnvironment(simulator)
        return VisionMattingService()
        #else
        // 模拟器 / macOS 测试：Vision 前景 mask 不可用
        return MockMattingService()
        #endif
    }

    public static func makeTagging(
        defaultTags: ItemTags = ItemTags(
            slot: .top,
            color: nil,
            occasions: ["casual"],
            warmth: .light)
    ) -> any TaggingService {
        // 云端 VLM 未接：始终 mock；接 Worker 后在此 DI
        MockTaggingService(tags: defaultTags)
    }

    public static func makeOCR(
        defaultInfo: LabelInfo = LabelInfo()
    ) -> any OCRService {
        MockOCRService(info: defaultInfo)
    }

}
