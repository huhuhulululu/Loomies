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
