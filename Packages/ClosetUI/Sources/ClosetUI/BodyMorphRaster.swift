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
        // 统一栅格到 RGBA8（资源是 RGB PNG，避免 bpp/对齐坑）
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

        let outW = max(64, min(1536, Int(outputWidth.rounded(.toNearestOrAwayFromZero))))
        let outH = max(96, Int((CGFloat(outW) * CGFloat(srcH) / CGFloat(srcW)).rounded(.toNearestOrAwayFromZero)))
        let m = morph.clamped()
        let heightS = m.height

        var rowScale = [CGFloat](repeating: 1, count: outH)
        for y in 0..<outH {
            let mid = (Double(y) + 0.5) / Double(outH)
            rowScale[y] = CGFloat(m.horizontalScale(normalizedY: mid))
        }
        let hasAlpha = true

        // 棚灰底 RGB
        let bgR: UInt8 = 184, bgG: UInt8 = 184, bgB: UInt8 = 186
        var out = [UInt8](repeating: 255, count: outW * outH * 4)
        let outCx = Double(outW - 1) / 2
        let srcCx = Double(srcW - 1) / 2
        let hScale = heightS
        let invH = 1.0 / hScale

        for y in 0..<outH {
            // height：相对画布中心缩放 → 源行
            let yN = (Double(y) + 0.5) / Double(outH)
            let yFromCenter = yN - 0.5
            let srcYN = 0.5 + yFromCenter * invH
            if srcYN < -0.02 || srcYN > 1.02 {
                // 填背景
                for x in 0..<outW {
                    let o = (y * outW + x) * 4
                    out[o] = bgR; out[o + 1] = bgG; out[o + 2] = bgB; out[o + 3] = 255
                }
                continue
            }
            let srcY = min(Double(srcH - 1), max(0, srcYN * Double(srcH - 1)))
            let sx = Double(rowScale[y])
            let invSx = 1.0 / max(sx, 0.001)

            for x in 0..<outW {
                let xFromCenter = Double(x) - outCx
                let srcX = srcCx + xFromCenter * invSx * (Double(srcW) / Double(outW))
                let o = (y * outW + x) * 4
                if srcX < 0 || srcX > Double(srcW - 1) {
                    out[o] = bgR; out[o + 1] = bgG; out[o + 2] = bgB; out[o + 3] = 255
                    continue
                }
                sampleBilinear(
                    src: srcRGBA, stride: srcStride, w: srcW, h: srcH,
                    x: srcX, y: srcY,
                    hasAlpha: hasAlpha || srcBPP >= 4,
                    into: &out, at: o,
                    bgR: bgR, bgG: bgG, bgB: bgB)
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
        into out: inout [UInt8], at o: Int,
        bgR: UInt8, bgG: UInt8, bgB: UInt8
    ) {
        let x0 = Int(floor(x)), y0 = Int(floor(y))
        let x1 = min(w - 1, x0 + 1), y1 = min(h - 1, y0 + 1)
        let fx = x - Double(x0), fy = y - Double(y0)
        let x0c = max(0, min(w - 1, x0)), y0c = max(0, min(h - 1, y0))

        func px(_ xi: Int, _ yi: Int) -> (Double, Double, Double, Double) {
            let i = yi * stride + xi * 4
            if i + 3 >= src.count { return (Double(bgR), Double(bgG), Double(bgB), 255) }
            return (Double(src[i]), Double(src[i + 1]), Double(src[i + 2]), Double(src[i + 3]))
        }
        let p00 = px(x0c, y0c)
        let p10 = px(x1, y0c)
        let p01 = px(x0c, y1)
        let p11 = px(x1, y1)
        func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
        let r = lerp(lerp(p00.0, p10.0, fx), lerp(p01.0, p11.0, fx), fy)
        let g = lerp(lerp(p00.1, p10.1, fx), lerp(p01.1, p11.1, fx), fy)
        let b = lerp(lerp(p00.2, p10.2, fx), lerp(p01.2, p11.2, fx), fy)
        let a = hasAlpha ? lerp(lerp(p00.3, p10.3, fx), lerp(p01.3, p11.3, fx), fy) : 255
        out[o] = UInt8(min(255, max(0, r.rounded())))
        out[o + 1] = UInt8(min(255, max(0, g.rounded())))
        out[o + 2] = UInt8(min(255, max(0, b.rounded())))
        out[o + 3] = UInt8(min(255, max(0, a.rounded())))
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
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outW, height: outH), format: format)
        return renderer.image { ctx in
            let c = ctx.cgContext
            c.setFillColor(red: 0.72, green: 0.72, blue: 0.73, alpha: 1)
            c.fill(CGRect(x: 0, y: 0, width: outW, height: outH))
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
        NSColor(white: 0.72, alpha: 1).setFill()
        NSRect(origin: .zero, size: size).fill()
        let dw = size.width * sx
        let dh = size.height * CGFloat(m.height)
        NSImage(cgImage: cg, size: .zero).draw(
            in: NSRect(x: (size.width - dw) / 2, y: (size.height - dh) / 2, width: dw, height: dh))
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
            if let rendered = BodyMorphImageCache.shared.image(
                named: assetName, morph: morph, width: w)
            {
                rendered
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: w, height: h)
            } else {
                Color.clear
            }
        }
    }
}

/// 简单内存缓存，避免滑杆每帧全图 rewarp。
@MainActor
final class BodyMorphImageCache {
    static let shared = BodyMorphImageCache()
    private var map: [String: Image] = [:]
    private let maxEntries = 24

    func image(named name: String, morph: BodyMorphParams, width: CGFloat) -> Image? {
        let m = morph.clamped()
        let wKey = Int(width.rounded())
        let key = "\(name)|\(wKey)|\(fmt(m.chest))|\(fmt(m.waist))|\(fmt(m.hip))|\(fmt(m.shoulder))|\(fmt(m.height))"
        if let hit = map[key] { return hit }
        guard let rendered = render(named: name, morph: m, width: width) else { return nil }
        if map.count >= maxEntries { map.removeAll(keepingCapacity: true) }
        map[key] = rendered
        return rendered
    }

    func clear() { map.removeAll() }

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
