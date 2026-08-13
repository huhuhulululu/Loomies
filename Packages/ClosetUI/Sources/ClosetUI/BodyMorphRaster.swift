import SwiftUI
import ClosetCore
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit) && !os(iOS)
import AppKit
#endif

/// 水平剖面变形：保留乳贴/丁字裤完整，避免条带 mask 碎裂。
/// 实现：逐行 **双线性采样** 扫描线 warp（无 crop 接缝）。
enum BodyMorphRaster {
    static func shouldBypass(_ morph: BodyMorphParams) -> Bool {
        morph.isVisuallyNeutral
    }

    #if canImport(UIKit)
    /// 扫描线 warp。输出宽度建议 ≥ 逻辑宽度 × screenScale。
    static func warpedUIImage(
        from source: UIImage,
        morph: BodyMorphParams,
        outputWidth: CGFloat
    ) -> UIImage? {
        // 统一栅格到 RGBA8（资源为透明 croquis，保留 alpha）
        guard let rgba = Self.makeRGBABuffer(from: source) else {
            guard let cg = source.cgImage else { return nil }
            let outW0 = max(64, min(1536, Int(outputWidth.rounded(.toNearestOrAwayFromZero))))
            let outH0 = max(96, Int((CGFloat(outW0) * 1.5).rounded()))
            return fallbackStripWarp(cg: cg, morph: morph.clamped(), outW: outW0, outH: outH0)
        }
        let srcW = rgba.width
        let srcH = rgba.height
        let srcRGBA = rgba.bytes
        let srcStride = srcW * 4
        guard srcW > 2, srcH > 2 else { return nil }

        // 浮点域先钳掉非有限值再转 Int：Int(NaN/∞) 是运行时陷阱（GeometryReader
        // 首帧/无约束轴可给 0/∞）。
        let outW = Int(min(1536, max(64, outputWidth.isFinite ? outputWidth : 64))
            .rounded(.toNearestOrAwayFromZero))
        let outH = max(96, Int((CGFloat(outW) * CGFloat(srcH) / CGFloat(srcW)).rounded(.toNearestOrAwayFromZero)))
        let m = morph.clamped()
        // 高度不在像素行里做非均匀 warp（会整段纵移乳贴 →「乱飘」）；
        // height 由 BodyMorphImageView 整体 scaleEffect 处理。
        let hasAlpha = true

        // 透明底：OOB / 源透明 → alpha 0
        var out = [UInt8](repeating: 0, count: outW * outH * 4)
        let outCx = Double(outW - 1) / 2
        let srcCx = Double(srcW - 1) / 2

        for y in 0..<outH {
            // 输出行 y ↔ 源图同一归一化 y（1:1 纵向）
            let srcYN = (Double(y) + 0.5) / Double(outH)
            let srcY = min(Double(srcH - 1), max(0, srcYN * Double(srcH - 1)))
            // **必须用源图 y** 取剖面尺度，乳贴带才对得上贴片
            let sx = m.horizontalScale(normalizedY: srcYN)
            let invSx = 1.0 / max(sx, 0.001)

            for x in 0..<outW {
                let xFromCenter = Double(x) - outCx
                let srcX = srcCx + xFromCenter * invSx * (Double(srcW) / Double(outW))
                let o = (y * outW + x) * 4
                if srcX < 0 || srcX > Double(srcW - 1) {
                    continue
                }
                sampleBilinear(
                    src: srcRGBA, stride: srcStride, w: srcW, h: srcH,
                    x: srcX, y: srcY,
                    hasAlpha: hasAlpha,
                    into: &out, at: o)
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &out,
            width: outW,
            height: outH,
            bitsPerComponent: 8,
            bytesPerRow: outW * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let outCG = ctx.makeImage() else { return nil }
        return UIImage(cgImage: outCG, scale: 1, orientation: .up)
    }

    /// 将 UIImage 画成紧密 RGBA8 缓冲（保留乳贴/丁字裤像素，无二次有损压缩）。
    private static func makeRGBABuffer(from source: UIImage) -> (bytes: [UInt8], width: Int, height: Int)? {
        guard let cg = source.cgImage else { return nil }
        let w = cg.width, h = cg.height
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &buf,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return (buf, w, h)
    }

    private static func sampleBilinear(
        src: [UInt8], stride: Int, w: Int, h: Int,
        x: Double, y: Double,
        hasAlpha: Bool,
        into out: inout [UInt8], at o: Int
    ) {
        let x0 = Int(floor(x)), y0 = Int(floor(y))
        let x1 = min(w - 1, x0 + 1), y1 = min(h - 1, y0 + 1)
        let fx = x - Double(x0), fy = y - Double(y0)
        let x0c = max(0, min(w - 1, x0)), y0c = max(0, min(h - 1, y0))

        // OOB / 越界缓冲 → 透明，不填棚灰
        func px(_ xi: Int, _ yi: Int) -> (Double, Double, Double, Double) {
            let i = yi * stride + xi * 4
            if i + 3 >= src.count { return (0, 0, 0, 0) }
            return (Double(src[i]), Double(src[i + 1]), Double(src[i + 2]), Double(src[i + 3]))
        }
        let p00 = px(x0c, y0c)
        let p10 = px(x1, y0c)
        let p01 = px(x0c, y1)
        let p11 = px(x1, y1)
        func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
        // 预乘空间双线性，再解预乘 → 半透明边缘不发灰/发白
        func premul(_ p: (Double, Double, Double, Double)) -> (Double, Double, Double, Double) {
            let aa = p.3 / 255.0
            return (p.0 * aa, p.1 * aa, p.2 * aa, p.3)
        }
        let q00 = premul(p00), q10 = premul(p10), q01 = premul(p01), q11 = premul(p11)
        let pr = lerp(lerp(q00.0, q10.0, fx), lerp(q01.0, q11.0, fx), fy)
        let pg = lerp(lerp(q00.1, q10.1, fx), lerp(q01.1, q11.1, fx), fy)
        let pb = lerp(lerp(q00.2, q10.2, fx), lerp(q01.2, q11.2, fx), fy)
        let pa = hasAlpha
            ? lerp(lerp(q00.3, q10.3, fx), lerp(q01.3, q11.3, fx), fy)
            : 255.0
        if pa < 0.5 {
            out[o] = 0; out[o + 1] = 0; out[o + 2] = 0; out[o + 3] = 0
            return
        }
        let inv = 255.0 / pa
        out[o] = UInt8(min(255, max(0, (pr * inv).rounded())))
        out[o + 1] = UInt8(min(255, max(0, (pg * inv).rounded())))
        out[o + 2] = UInt8(min(255, max(0, (pb * inv).rounded())))
        out[o + 3] = UInt8(min(255, max(0, pa.rounded())))
    }

    /// 回退：旧裁条路径（仅 dataProvider 失败时）。
    private static func fallbackStripWarp(
        cg: CGImage, morph: BodyMorphParams, outW: Int, outH: Int
    ) -> UIImage? {
        let m = morph.clamped()
        let heightS = CGFloat(m.height)
        let n = min(128, outH)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outW, height: outH), format: format)
        return renderer.image { ctx in
            let c = ctx.cgContext
            c.clear(CGRect(x: 0, y: 0, width: outW, height: outH))
            c.interpolationQuality = .high
            let drawnH = CGFloat(outH) * heightS
            let drawnY = (CGFloat(outH) - drawnH) / 2
            let srcW = cg.width
            let srcH = cg.height
            for i in 0..<n {
                let y0 = Int((Double(i) / Double(n)) * Double(outH))
                let y1 = Int((Double(i + 1) / Double(n)) * Double(outH))
                let midNorm = (Double(i) + 0.5) / Double(n)
                let sx = CGFloat(m.horizontalScale(normalizedY: midNorm))
                let destW = CGFloat(outW) * sx
                let destX = (CGFloat(outW) - destW) / 2
                let srcY0f = (Double(y0) - Double(drawnY)) / Double(max(drawnH, 1)) * Double(srcH)
                let srcY1f = (Double(y1) - Double(drawnY)) / Double(max(drawnH, 1)) * Double(srcH)
                var sy0 = max(0, min(srcH - 1, Int(floor(srcY0f)) - 1))
                var sy1 = max(sy0 + 1, min(srcH, Int(ceil(srcY1f)) + 1))
                guard let strip = cg.cropping(to: CGRect(x: 0, y: sy0, width: srcW, height: sy1 - sy0)) else { continue }
                let destStripY = drawnY + CGFloat(sy0) / CGFloat(srcH) * drawnH
                let destStripH = CGFloat(sy1 - sy0) / CGFloat(srcH) * drawnH
                c.saveGState()
                c.clip(to: CGRect(x: 0, y: y0, width: outW, height: max(1, y1 - y0 + 1)))
                c.draw(strip, in: CGRect(x: destX, y: destStripY, width: destW, height: destStripH))
                c.restoreGState()
            }
        }
    }
    #endif

    #if canImport(AppKit) && !os(iOS)
    static func warpedNSImage(from source: NSImage, morph: BodyMorphParams, outputWidth: CGFloat) -> NSImage? {
        guard let tiff = source.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let cg = rep.cgImage else { return nil }
        let m = morph.clamped()
        let sx = CGFloat((m.chest + m.hip) / 2)
        let size = NSSize(width: max(64, outputWidth), height: max(96, outputWidth * 1.5))
        let out = NSImage(size: size)
        out.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()
        let dw = size.width * sx
        let dh = size.height * CGFloat(m.height)
        NSImage(cgImage: cg, size: .zero).draw(
            in: NSRect(x: (size.width - dw) / 2, y: (size.height - dh) / 2, width: dw, height: dh),
            from: .zero,
            operation: .sourceOver,
            fraction: 1)
        out.unlockFocus()
        return out
    }
    #endif
}

// MARK: - View + cache

/// 资源加载 + morph；中性直出原 PNG（保留乳贴/丁字裤像素）。
struct BodyMorphImageView: View {
    var assetName: String
    var morph: BodyMorphParams
    var logicalWidth: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let m = morph.clamped()
            // 栅格只做水平剖面；height 整体 scale，避免乳贴纵移
            let horizontalOnly = BodyMorphParams(
                chest: m.chest, waist: m.waist, hip: m.hip,
                shoulder: m.shoulder, height: 1)
            if let rendered = BodyMorphImageCache.shared.image(
                named: assetName, morph: horizontalOnly, width: w)
            {
                rendered
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(x: 1, y: CGFloat(m.height), anchor: .center)
                    .frame(width: w, height: h)
            } else {
                Color.clear
            }
        }
    }
}

/// 内存缓存，避免滑杆每帧全图 rewarp。
/// NSCache 按字节 cost 限额（warp 输出单张 ≈9.8MB，条目限容峰值 ~275MB）、
/// 近似 LRU（旧「随机半清」当前 yaw 帧 50% 中枪，恰好击穿本缓存的设立目的）；
/// **miss（资产缺失）也负缓存**——否则缺资产每 tick 重走读盘+解码。
@MainActor
final class BodyMorphImageCache {
    static let shared = BodyMorphImageCache()

    final class Box {
        let image: Image?
        init(_ image: Image?) { self.image = image }
    }

    /// D132：清空。此前没有任何主动释放路径（见 `ImageCaches`）。
    func purge() { cache.removeAllObjects() }

    private let cache: NSCache<NSString, Box> = {
        let c = NSCache<NSString, Box>()
        c.totalCostLimit = 96 * 1024 * 1024
        c.countLimit = 64
        return c
    }()

    /// 测试探针：render 实际执行次数（验证 miss 也被缓存，不每 tick 重试）。
    private(set) var renderAttempts = 0

    func image(named name: String, morph: BodyMorphParams, width: CGFloat) -> Image? {
        // 非有限/非正宽度（首帧布局瞬态）直接返回 nil，不缓存也不 trap（Int(NaN) 陷阱）。
        guard width.isFinite, width > 0 else { return nil }
        let m = morph.clamped()
        let wKey = Int(min(8192, width).rounded())
        // v3：乳贴带扩宽 + 无纵向 height warp
        let key = "v3|\(name)|\(wKey)|\(fmt(m.chest))|\(fmt(m.waist))|\(fmt(m.hip))|\(fmt(m.shoulder))|\(fmt(m.height))"
        if let box = cache.object(forKey: key as NSString) { return box.image }
        renderAttempts += 1
        let rendered = render(named: name, morph: m, width: width)
        let pixelW = max(256, min(1280, width * 2))
        let cost = rendered == nil ? 1 : Int(pixelW * pixelW * 1.5 * 4)
        cache.setObject(Box(rendered), forKey: key as NSString, cost: cost)
        return rendered
    }

    func clear() { cache.removeAllObjects() }

    private func fmt(_ v: Double) -> String { String(format: "%.3f", v) }

    private func render(named name: String, morph: BodyMorphParams, width: CGFloat) -> Image? {
        let pixelW = max(256, min(1280, width * 2))
        #if canImport(UIKit)
        guard let ui = BodyAvatarView.bundleUIImage(named: name) else { return nil }
        if BodyMorphRaster.shouldBypass(morph) {
            return Image(uiImage: ui)
        }
        if let warped = BodyMorphRaster.warpedUIImage(from: ui, morph: morph, outputWidth: pixelW) {
            return Image(uiImage: warped)
        }
        return Image(uiImage: ui)
        #elseif canImport(AppKit) && !os(iOS)
        guard let ns = BodyAvatarView.bundleNSImage(named: name) else { return nil }
        if BodyMorphRaster.shouldBypass(morph) {
            return Image(nsImage: ns)
        }
        if let warped = BodyMorphRaster.warpedNSImage(from: ns, morph: morph, outputWidth: pixelW) {
            return Image(nsImage: warped)
        }
        return Image(nsImage: ns)
        #else
        return nil
        #endif
    }
}
