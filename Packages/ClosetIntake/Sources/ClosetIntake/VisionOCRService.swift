import Foundation
import ClosetCore
#if canImport(Vision)
import Vision
#endif

/// 洗标 OCR 的平台层（D123）。
///
/// 「认得准不准」全在 `ClosetCore.LabelTextParser`（纯函数、13 条测试）；
/// 这里只负责把图片交给 Vision、把识别出来的行交回去。
///
/// ⚠️ 主体在 `#if canImport(Vision)` 里——macOS 的 `swift test` 编不到
/// （D92/D118 都栽过），改完必须 `xcodebuild` 验证。
public struct VisionOCRService: OCRService {

    public init() {}

    public func readLabel(_ imageData: Data) async throws -> LabelInfo {
        let lines = await Self.recognizeLines(in: imageData)
        guard !lines.isEmpty else { return LabelInfo() }
        let parsed = LabelTextParser.parse(lines: lines)
        AppLog.debug(
            "labelOCR lines=\(lines.count) brand=\(parsed.brand != nil) size=\(parsed.size != nil)",
            .intake)
        return LabelInfo(brand: parsed.brand, size: parsed.size)
    }

    /// 识别出的文本行。失败一律返回空数组——**认不出就别填**，
    /// 而不是抛错打断整个入库（照片本身可能压根没拍到标）。
    static func recognizeLines(in imageData: Data) async -> [String] {
        #if canImport(Vision)
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    AppLog.error("labelOCR failed: \(AppLog.errRef(error))", .intake)
                    continuation.resume(returning: [])
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                // 每行只取最优候选：次优候选在洗标这种小字上噪声很大，
                // 而错一个尺码比留空更糟。
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            // 洗标是印刷小字，语言矫正会把 "XL" 纠成单词——关掉。
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-US"]
            do {
                try VNImageRequestHandler(data: imageData, options: [:]).perform([request])
            } catch {
                AppLog.error("labelOCR handler failed: \(AppLog.errRef(error))", .intake)
                continuation.resume(returning: [])
            }
        }
        #else
        return []
        #endif
    }
}
