import Foundation
import ClosetCore

/// 按平台选择抠图/打标实现：真机优先 Vision；模拟器/mac 回退 mock。
public enum IntakeServiceFactory {

    /// Add-piece choose screen: cutout is device-aware; tags/OCR are always starter guesses.
    /// Must not claim Vision fills type/brand (those stay mock until VLM/OCR wire-up).
    public static let photoPipelineCaption =
        "Cutout uses Vision on a real iPhone (mock in Simulator). Type, brand, and size are starter guesses — edit before saving."

    /// In-flight ProgressView while matting/tagging run — must not imply real OCR/VLM pre-fill.
    public static let photoProcessingCaption =
        "Cutting out the piece… type, brand, and size stay starter guesses — edit before saving."

    /// Barcode field: digits only for now (no DataScanner). Apparel Open*Facts hit rate is thin.
    public static let barcodeEntryCaption =
        "Type or paste UPC/EAN digits from the hang tag. Camera scan is not available yet."

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

    /// 当前构建是否接了**真的**识别（AI 打标 / 洗标 OCR）。
    ///
    /// D102：`makeTagging` / `makeOCR` 没有任何平台分支，一律返回 mock ——
    /// 于是「识别成功」路径上用户看到预填好的类型/场合，却没有任何提示说
    /// 那不是识别结果、只是默认值。失败时反而有诚实文案，成功时没有，
    /// 不诚实正好落在最常走的那条路上。接上真服务时把这里改 true，
    /// 披露会自动收起（门也随之放行）。
    public static let recognitionAvailable = false

    /// 未接识别时的披露：字段是**起点**，不是照片识别出来的。
    public static let prefillDisclosure =
        "Type and occasion start from a common guess, not from your photo — check them before adding."

    public static func makeTagging(
        defaultTags: ItemTags = ItemTags(
            slot: .top,
            color: nil,
            occasions: ["casual"],
            // 云端 VLM 未接：不得凭空给出确定温区档。未知就是未知（nil），
            // 用户在入库确认页当场填，冷天不因伪造的「薄款」被硬过滤掉。
            warmth: nil)
    ) -> any TaggingService {
        // 云端 VLM 未接：始终 mock；接 Worker 后在此 DI
        MockTaggingService(tags: defaultTags)
    }

    public static func makeOCR(
        defaultInfo: LabelInfo = LabelInfo()
    ) -> any OCRService {
        // Document OCR not wired — always mock empty/defaults.
        MockOCRService(info: defaultInfo)
    }

}
