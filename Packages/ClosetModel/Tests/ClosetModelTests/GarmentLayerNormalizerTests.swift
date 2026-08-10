import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import ClosetCore
@testable import ClosetModel

struct GarmentLayerNormalizerTests {

    @Test func contentRectsCoverSlots() {
        for slot in BodyAvatarSlot.allCases {
            let r = GarmentLayerNormalizer.contentRect(for: slot)
            #expect(r.width > 0.3 && r.height > 0.1)
            #expect(r.x >= 0 && r.y >= 0)
            #expect(r.x + r.width <= 1.01)
            #expect(r.y + r.height <= 1.01)
        }
        // 上装偏上、鞋偏下
        #expect(GarmentLayerNormalizer.contentRect(for: .top).y
                < GarmentLayerNormalizer.contentRect(for: .shoes).y)
    }

    @Test func normalizeProducesPNGOnCanvas() throws {
        let raw = try makeTestGarmentPNG(width: 200, height: 120)
        let out = GarmentLayerNormalizer.normalize(imageData: raw, slot: .top)
        #expect(out != nil)
        #expect(out!.count > 100)
        // 应可解码且画布为 512×768
        let src = CGImageSourceCreateWithData(out! as CFData, nil)
        #expect(src != nil)
        let cg = CGImageSourceCreateImageAtIndex(src!, 0, nil)
        #expect(cg?.width == GarmentLayerNormalizer.canvasWidth)
        #expect(cg?.height == GarmentLayerNormalizer.canvasHeight)
    }

    @Test func normalizeRejectsEmptyData() {
        #expect(GarmentLayerNormalizer.normalize(imageData: Data(), slot: .top) == nil)
    }

    /// CM-N1: 不透明 JPEG（入库默认格式）无 alpha——须按非近白像素裁剪白边。
    /// 白底小深色方块归一后应放大充满槽位安全区；旧 bug 把 bbox 当整帧，
    /// 方块只占安全区约 1/36。
    @Test func normalizeCropsOpaqueJPEGWhiteMargins() throws {
        let jpg = try makeJPEG(width: 240, height: 240, square: 40)
        let out = try #require(GarmentLayerNormalizer.normalize(imageData: jpg, slot: .top))
        let src = try #require(CGImageSourceCreateWithData(out as CFData, nil))
        let cg = try #require(CGImageSourceCreateImageAtIndex(src, 0, nil))
        // 裁剪后 ≈6.8 万深像素（方块充满 .top 区）；整帧 bbox 下 <2 千
        #expect(darkPixelCount(cg) > 20_000)
    }

    /// 白底中央深色小方块 JPEG（不透明，无 alpha）——模拟棚拍入库图。
    private func makeJPEG(width: Int, height: Int, square: Int) throws -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.noneSkipLast.rawValue
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace, bitmapInfo: info
        ) else { throw NSError(domain: "test", code: 1) }
        ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.setFillColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)
        let s = CGFloat(square)
        ctx.fill(CGRect(
            x: (CGFloat(width) - s) / 2, y: (CGFloat(height) - s) / 2,
            width: s, height: s))
        guard let img = ctx.makeImage() else { throw NSError(domain: "test", code: 2) }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            data, UTType.jpeg.identifier as CFString, 1, nil
        ) else { throw NSError(domain: "test", code: 3) }
        CGImageDestinationAddImage(dest, img, [
            kCGImageDestinationLossyCompressionQuality: 0.9
        ] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw NSError(domain: "test", code: 4) }
        return data as Data
    }

    /// 重绘为 RGBA8 后统计不透明深像素数（r/g/b 均 <100 且 alpha 不透明）。
    private func darkPixelCount(_ image: CGImage) -> Int {
        let w = image.width, h = image.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let buf = ctx.data else { return 0 }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        let ptr = buf.bindMemory(to: UInt8.self, capacity: w * h * 4)
        var count = 0
        for i in stride(from: 0, to: w * h * 4, by: 4) {
            if ptr[i + 3] > 200, ptr[i] < 100, ptr[i + 1] < 100, ptr[i + 2] < 100 { count += 1 }
        }
        return count
    }

    /// 红色不透明矩形 PNG（模拟抠好的上装）。
    private func makeTestGarmentPNG(width: Int, height: Int) throws -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace, bitmapInfo: info
        ) else {
            throw NSError(domain: "test", code: 1)
        }
        ctx.setFillColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1)
        ctx.fill(CGRect(x: 20, y: 10, width: width - 40, height: height - 20))
        guard let img = ctx.makeImage() else { throw NSError(domain: "test", code: 2) }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil
        ) else { throw NSError(domain: "test", code: 3) }
        CGImageDestinationAddImage(dest, img, nil)
        guard CGImageDestinationFinalize(dest) else { throw NSError(domain: "test", code: 4) }
        return data as Data
    }
}
