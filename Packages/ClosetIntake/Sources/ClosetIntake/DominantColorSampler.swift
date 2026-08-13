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

    /// 解码尺寸上限（D136）。
    ///
    /// 此前按**原始尺寸**分配 `w*h*4` 并整帧重绘：12MP 的照片 ≈ 48MB 缓冲、
    /// 数百毫秒——而它跑在入库确认那一下的主线程上，界面当场冻住，
    /// 批量入库逐件重复。注释里写着「采样所以不卡」，前提是错的：
    /// 跨步只省了读循环，**解码与重绘并没有省**。
    public static let maxDecodePixel = 512

    /// 返回主色对应的色板项；认不出来返回 nil（宁缺勿错，同 OCR）。
    ///
    /// `async` 且在后台跑：主色是锦上添花，不该让用户对着冻住的界面等它。
    public static func dominantEntry(in imageData: Data) async -> GarmentColorPalette.Entry? {
        await Task.detached(priority: .userInitiated) {
            DominantColor.vote(samples: samples(in: imageData))
        }.value
    }

    /// 非透明像素的采样。
    static func samples(in imageData: Data) -> [RGB] {
        #if canImport(CoreGraphics)
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return [] }

        // 先降到 512 长边再解：全分辨率重绘是几十 MB 与数百毫秒，
        // 而主色投票在 512 上一样稳。
        let scale = max(1, max(image.width, image.height) / maxDecodePixel)
        let width = max(1, image.width / scale), height = max(1, image.height / scale)
        guard width > 0, height > 0 else { return [] }

        // 统一重绘成 RGBA8：源图可能是任意色彩空间/位深，直接读 dataProvider
        // 要处理十几种排列，而重绘一次就规整了。
        // `data: nil` 让 CGContext 自己持有缓冲——把栈上数组的指针传进去
        // 会在调用返回后被继续使用（未定义行为，仓内 `BodyMorphRaster` 是正解）。
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,   // 0 = 由 CGContext 自己按对齐算
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return [] }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let base = ctx.data else { return [] }
        let buffer = base.assumingMemoryBound(to: UInt8.self)
        // 行距以 CGContext 实际给的为准（它会按对齐补齐，不等于请求值）
        let rowBytes = ctx.bytesPerRow

        // 网格步长：让总采样数落在 targetSamples 附近
        let total = width * height
        let stride = max(1, Int((Double(total) / Double(targetSamples)).squareRoot()))
        var out: [RGB] = []
        out.reserveCapacity(targetSamples)
        var y = 0
        while y < height {
            var x = 0
            while x < width {
                let i = y * rowBytes + x * 4
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
