import Foundation
import ClosetCore
#if canImport(CoreGraphics)
import CoreGraphics
import ImageIO
#endif

/// 从抠好的图里取主色（D124 的平台层）。
///
/// 「怎么判主色」全在 `ClosetCore.DominantColor`（纯函数、9 条测试）；
/// 这里只负责把像素读出来、把透明的丢掉。
///
/// 采样而不是全读：一张 512×768 有 39 万像素，主色投票用几千个就足够稳，
/// 而全读会在入库确认那一帧上卡住主线程。
public enum DominantColorSampler {

    /// 采样目标数（网格步长按图大小反推）。
    public static let targetSamples = 2_000

    /// 低于这个 alpha 的像素算背景，不参与投票——
    /// 抠图边缘的半透明像素混着背景色，投进去会把主色拖偏。
    public static let opaqueThreshold: UInt8 = 200

    /// 返回主色对应的色板项；认不出来返回 nil（宁缺勿错，同 OCR）。
    public static func dominantEntry(in imageData: Data) -> GarmentColorPalette.Entry? {
        DominantColor.vote(samples: samples(in: imageData))
    }

    /// 非透明像素的采样。
    static func samples(in imageData: Data) -> [RGB] {
        #if canImport(CoreGraphics)
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return [] }

        let width = image.width, height = image.height
        guard width > 0, height > 0 else { return [] }

        // 统一重绘成 RGBA8：源图可能是任意色彩空间/位深，直接读 dataProvider
        // 要处理十几种排列，而重绘一次就规整了。
        let bytesPerRow = width * 4
        var buffer = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let ctx = CGContext(
            data: &buffer, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return [] }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // 网格步长：让总采样数落在 targetSamples 附近
        let total = width * height
        let stride = max(1, Int((Double(total) / Double(targetSamples)).squareRoot()))
        var out: [RGB] = []
        out.reserveCapacity(targetSamples)
        var y = 0
        while y < height {
            var x = 0
            while x < width {
                let i = y * bytesPerRow + x * 4
                let alpha = buffer[i + 3]
                if alpha >= opaqueThreshold {
                    // premultiplied：除回 alpha 才是真实颜色
                    let a = Double(alpha) / 255
                    out.append(RGB(
                        Double(buffer[i]) / 255 / a,
                        Double(buffer[i + 1]) / 255 / a,
                        Double(buffer[i + 2]) / 255 / a))
                }
                x += stride
            }
            y += stride
        }
        return out
        #else
        return []
        #endif
    }
}
