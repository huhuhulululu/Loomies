import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import ClosetCore

/// 入库叠衣层归一化：紧 bbox + 标准画布 + 按槽位对齐（肩/腰/脚）。
/// 纯 CoreGraphics，可在 macOS 测试。
public enum GarmentLayerNormalizer {
    public static let canvasWidth = 512
    public static let canvasHeight = 768

    /// 归一化 PNG；失败返回 nil（调用方回退原图）。
    public static func normalize(imageData: Data, slot: BodyAvatarSlot) -> Data? {
        guard let src = decodeRGBA(imageData) else { return nil }
        let bbox = alphaBoundingBox(src) ?? fullBox(src.width, src.height)
        guard let cropped = crop(src, to: bbox) else { return nil }
        let placed = placeOnCanvas(cropped, slot: slot)
        return encodePNG(placed)
    }

    /// 槽位在标准画布上的内容安全区（对齐 BodyAvatarAnchors，肩线略靠上）。
    public static func contentRect(for slot: BodyAvatarSlot) -> NormalizedRect {
        // 相对 512×768；与 UI 锚点同构，略放宽供归一
        let f = BodyAvatarAnchors.frame(for: slot)
        let padX = 0.04
        let padY: Double = slot == .shoes ? 0.01 : 0.02
        return NormalizedRect(
            x: max(0, f.x - padX),
            y: max(0, f.y - padY),
            width: min(1 - max(0, f.x - padX), f.width + padX * 2),
            height: min(1 - max(0, f.y - padY), f.height + padY * 2))
    }

    // MARK: - Decode / encode

    private static func decodeRGBA(_ data: Data) -> CGImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        return cg.toRGBA8()
    }

    private static func encodePNG(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    // MARK: - Geometry

    private static func fullBox(_ w: Int, _ h: Int) -> CGRect {
        CGRect(x: 0, y: 0, width: w, height: h)
    }

    /// 非零 alpha 外接矩形；JPEG 无 alpha 时用非近白像素。
    private static func alphaBoundingBox(_ image: CGImage) -> CGRect? {
        let w = image.width, h = image.height
        guard w > 0, h > 0, let data = image.dataProvider?.data else { return nil }
        let ptr = CFDataGetBytePtr(data)
        let bpp = max(1, image.bitsPerPixel / 8)
        let bpr = image.bytesPerRow
        var minX = w, minY = h, maxX = 0, maxY = 0
        var found = false
        let hasAlpha = image.alphaInfo != .none && image.alphaInfo != .noneSkipLast
            && image.alphaInfo != .noneSkipFirst

        for y in 0..<h {
            for x in 0..<w {
                let i = y * bpr + x * bpp
                let keep: Bool
                if hasAlpha, bpp >= 4 {
                    keep = ptr![i + 3] > 12
                } else if bpp >= 3 {
                    let r = Int(ptr![i]), g = Int(ptr![i + 1]), b = Int(ptr![i + 2])
                    // 非棚白/近白
                    keep = r < 245 || g < 245 || b < 245
                } else {
                    keep = ptr![i] < 250
                }
                if keep {
                    found = true
                    if x < minX { minX = x }
                    if y < minY { minY = y }
                    if x > maxX { maxX = x }
                    if y > maxY { maxY = y }
                }
            }
        }
        guard found else { return nil }
        // 2% 边距
        let pad = max(2, Int(Double(max(w, h)) * 0.015))
        let x0 = max(0, minX - pad)
        let y0 = max(0, minY - pad)
        let x1 = min(w - 1, maxX + pad)
        let y1 = min(h - 1, maxY + pad)
        return CGRect(x: x0, y: y0, width: x1 - x0 + 1, height: y1 - y0 + 1)
    }

    private static func crop(_ image: CGImage, to rect: CGRect) -> CGImage? {
        let r = CGRect(
            x: floor(rect.origin.x),
            y: floor(rect.origin.y),
            width: max(1, floor(rect.width)),
            height: max(1, floor(rect.height)))
        return image.cropping(to: r)
    }

    private static func placeOnCanvas(_ image: CGImage, slot: BodyAvatarSlot) -> CGImage {
        let cw = canvasWidth, ch = canvasHeight
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: nil, width: cw, height: ch,
            bitsPerComponent: 8, bytesPerRow: cw * 4,
            space: colorSpace, bitmapInfo: bitmapInfo
        ) else { return image }

        ctx.clear(CGRect(x: 0, y: 0, width: cw, height: ch))
        // CGContext 原点左下；我们按「上为肩」用 flip 画
        ctx.translateBy(x: 0, y: CGFloat(ch))
        ctx.scaleBy(x: 1, y: -1)

        let nr = contentRect(for: slot)
        let zone = CGRect(
            x: nr.x * Double(cw),
            y: nr.y * Double(ch),
            width: nr.width * Double(cw),
            height: nr.height * Double(ch))

        let iw = CGFloat(image.width), ih = CGFloat(image.height)
        let scale = min(zone.width / iw, zone.height / ih)
        let dw = iw * scale, dh = ih * scale
        // 水平居中；垂直按槽位贴顶/贴底/居中
        let dx = zone.midX - dw / 2
        let dy: CGFloat = {
            switch slot {
            case .top, .outerwear, .dress:
                return zone.minY // 肩线上沿
            case .shoes:
                return zone.maxY - dh // 贴脚
            case .bottom:
                return zone.minY + (zone.height - dh) * 0.15 // 略靠上（腰线）
            }
        }()

        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: dx, y: dy, width: dw, height: dh))
        return ctx.makeImage() ?? image
    }
}

private extension CGImage {
    func toRGBA8() -> CGImage? {
        let w = width, h = height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: colorSpace, bitmapInfo: bitmapInfo
        ) else { return nil }
        ctx.draw(self, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()
    }
}
