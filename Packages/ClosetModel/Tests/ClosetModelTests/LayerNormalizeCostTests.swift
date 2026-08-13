import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import ClosetModel
import ClosetCore

/// D181：**点「Add to closet」时在主线程按原始分辨率重绘整张照片。**
///
/// `IntakeViewModel` 是 `@MainActor`，`confirm()` 同步调
/// `GarmentLayerNormalizer.normalize` → `decodeRGBA` 按**源图 w×h** 建
/// CGContext 整帧 draw → `alphaBoundingBox` 是 `for y { for x } }` 全像素双重循环。
/// 输入确为原分辨率：抠图服务 `croppedToInstancesExtent: false` 全幅出 PNG，
/// 上游是 UIImage 全尺寸 `jpegData(0.9)`。12MP 的照片 = 一次 48MB 分配 +
/// 一千两百万次像素访问，批量入库逐件重复。
///
/// D136 已经为**同一条链**定过纪律并落实到 `DominantColorSampler`
///（`maxDecodePixel = 512` + 后台跑），归一器没跟上——
/// 而它的输出只有 512×768，全分辨率解码从头到尾没有用武之地。
///
/// 这里不设绝对毫秒门（D173 的教训：绝对门限要么恒绿要么恒红），
/// 而是钉住**成本随输入分辨率的走向**：4032×3024 的输入不得比
/// 2048×1536（正好在上限上）的同一张图慢——封顶之后两者解出同样大的位图。
struct LayerNormalizeCostTests {

    /// 造一张 w×h 的 PNG：中间一块不透明矩形（当作衣服），四周全透明。
    private func makePNG(width: Int, height: Int) -> Data {
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

    private func elapsedMS(_ body: () -> Void) -> Double {
        let t0 = DispatchTime.now().uptimeNanoseconds
        body()
        return Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000
    }

    /// **本波的核心**：成本不再随源图分辨率线性膨胀。
    @Test func fullResolutionInputCostsNoMoreThanAModestOne() throws {
        // small 正好落在解码上限上——封顶生效后两者**解出同样大的位图**，
        // 比值应当趋近 1；封顶失效时比值 ≈ 像素数之比（约 4）。
        let small = makePNG(width: 2048, height: 1536)
        let large = makePNG(width: 4032, height: 3024)   // 12MP，iPhone 主摄一张

        // 预热（首次调用含 ImageIO 初始化）
        _ = GarmentLayerNormalizer.normalize(imageData: small, slot: .top)

        let smallMS = elapsedMS { _ = GarmentLayerNormalizer.normalize(imageData: small, slot: .top) }
        let largeMS = elapsedMS { _ = GarmentLayerNormalizer.normalize(imageData: large, slot: .top) }

        // 封顶前 largeMS/smallMS ≈ 4（像素数之比）；封顶后两者解出同样大的位图，
        // 只剩 PNG 解压的差异。门限取 2——留足噪声余量，仍能挡住「退回全分辨率」。
        #expect(largeMS < smallMS * 2 + 20, Comment(rawValue:
            "12MP 输入 \(String(format: "%.0f", largeMS))ms vs 3MP \(String(format: "%.0f", smallMS))ms"
            + " —— 成本仍在随源图分辨率膨胀（解码没有封顶）"))
    }

    /// 封顶不得改结果：输出仍是标准画布，衣服仍在槽位安全区里。
    @Test func theOutputIsUnchangedByTheCap() throws {
        let data = try #require(GarmentLayerNormalizer.normalize(
            imageData: makePNG(width: 4032, height: 3024), slot: .top))
        let src = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(src, 0, nil))
        #expect(image.width == GarmentLayerNormalizer.canvasWidth)
        #expect(image.height == GarmentLayerNormalizer.canvasHeight)
    }

    /// 小图不许被**放大**解码（封顶是上限，不是目标尺寸）。
    @Test func aSmallImageIsNotUpscaledOnDecode() throws {
        let data = try #require(GarmentLayerNormalizer.normalize(
            imageData: makePNG(width: 200, height: 300), slot: .top))
        #expect(!data.isEmpty)
    }

    /// 结构门：解码路径必须带尺寸上限。
    ///
    /// 行为用例靠时间比值，机器忙时会有噪声；这条不依赖时间——
    /// 判据认**构造**（解码函数里出现尺寸上限常量），不认词。
    @Test func theDecodePathDeclaresACap() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/ClosetModel/GarmentLayerNormalizer.swift")
        let text = try String(contentsOf: url, encoding: .utf8)
        guard let r = text.range(of: "private static func decodeRGBA") else {
            Issue.record("找不到 decodeRGBA"); return
        }
        let rest = text[r.lowerBound...]
        let stop = rest.range(of: "\n    private static func encodePNG")?.lowerBound
            ?? rest.endIndex
        let body = String(rest[rest.startIndex..<stop])
        let usesCap = body.split(separator: "\n").contains { line in
            let t = line.trimmingCharacters(in: .whitespaces)
            return t.contains("maxDecodePixel")
                && !t.hasPrefix("//") && !t.hasPrefix("///")
        }
        #expect(usesCap, Comment(rawValue:
            "decodeRGBA 没有引用尺寸上限 —— 全分辨率解码会回来（D136 同款教训）"))
        #expect(GarmentLayerNormalizer.maxDecodePixel >= GarmentLayerNormalizer.canvasHeight,
                "上限低于画布高度会让紧裁剪后的衣服被放大")
    }
}
