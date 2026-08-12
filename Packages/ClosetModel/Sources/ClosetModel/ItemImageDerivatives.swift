import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import ClosetCore

/// 派生尺寸档（D95，缺口 #11；MVP-PLAN M1 SI-8）。
///
/// 此前网格里每格都在解**全分辨率原图**去填 120pt 的方块——
/// 百件网格性能是 M1 退出门（DESIGN §11.4 预算表），这是最直接的违反。
public enum ItemImageVariant: String, CaseIterable, Sendable {
    /// 网格方块（120pt @3x ≈ 360px，留一档余量）
    case grid
    /// 详情大图 / 试衣间预览
    case detail

    /// 长边像素上限。
    public var maxPixel: Int {
        switch self {
        case .grid:   return 480
        case .detail: return 1280
        }
    }

    /// 落盘文件名后缀（与原图同目录，`<stem>@grid.jpg`）。
    public var suffix: String { "@\(rawValue)" }
}

/// 图像派生的纯函数层（CoreGraphics/ImageIO；与 `GarmentLayerNormalizer` 同层）。
public enum ItemImageDerivatives {

    /// 等比缩放到长边 ≤ `maxPixel`。**比目标小的不放大**——放大只会更糊更大。
    /// 用 ImageIO 的缩略图接口：它不会先把原图整张解到内存再缩。
    public static func downscaledJPEG(_ data: Data, maxPixel: Int, quality: CGFloat = 0.82) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0 else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // 尊重 EXIF 方向
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        return encodeJPEG(image, quality: quality)
    }

    public static func encodeJPEG(_ image: CGImage, quality: CGFloat = 0.82) -> Data? {
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            out as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(dest, image, [
            kCGImageDestinationLossyCompressionQuality: quality,
        ] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }

    /// 像素尺寸（不解码整张图，只读 header）。
    public static func pixelSize(_ data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Double,
              let h = props[kCGImagePropertyPixelHeight] as? Double
        else { return nil }
        return CGSize(width: w, height: h)
    }
}
