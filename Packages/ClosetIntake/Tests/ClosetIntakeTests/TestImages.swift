import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// 测试用可解码 PNG（归一器只在解得开的数据上走成功路径）。
///
/// D185：`IntakeTests` / `SourcePhotoWiringTests` 各自抄了一份 `tinyPNG()`；
/// 新用例不再抄第三份。旧的两处没动——它们能用，且改它们与本波无关。
enum TestImages {
    /// 中间一块不透明矩形（当作衣服），四周透明。
    static func png(width: Int, height: Int) -> Data {
        let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        ctx.fill(CGRect(x: width / 4, y: height / 4, width: width / 2, height: height / 2))
        let image = ctx.makeImage()!
        let out = NSMutableData()
        let dest = CGImageDestinationCreateWithData(
            out, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, image, nil)
        _ = CGImageDestinationFinalize(dest)
        return out as Data
    }
}
