import Foundation

#if canImport(Vision) && canImport(CoreImage) && canImport(ImageIO)
import Vision
import CoreImage
import ImageIO
import UniformTypeIdentifiers

/// 真实抠图（VNGenerateForegroundInstanceMaskRequest，iOS 17+/macOS 14+）。
/// ⚠️ 模拟器不支持该 Vision 推理（DESIGN §4.2），须真机验证；本文件仅经 swift build 编译验证。
public struct VisionMattingService: MattingService {

    public enum MattingError: Error { case invalidImage, noSubject, encodingFailed }

    public init() {}

    public func removeBackground(_ imageData: Data) async throws -> Data {
        guard let ciImage = CIImage(data: imageData) else { throw MattingError.invalidImage }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first else { throw MattingError.noSubject }
        let maskedBuffer = try observation.generateMaskedImage(
            ofInstances: observation.allInstances,
            from: handler,
            croppedToInstancesExtent: false)

        let masked = CIImage(cvPixelBuffer: maskedBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(masked, from: masked.extent) else {
            throw MattingError.encodingFailed
        }
        return try encodePNG(cgImage)
    }

    private func encodePNG(_ cgImage: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil) else {
            throw MattingError.encodingFailed
        }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else { throw MattingError.encodingFailed }
        return data as Data
    }
}
#endif
