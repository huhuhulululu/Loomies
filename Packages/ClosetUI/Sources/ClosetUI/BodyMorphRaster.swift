import SwiftUI
import ClosetCore
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit) && !os(iOS)
import AppKit
#endif

/// 单次栅格化的水平剖面变形：替代 SwiftUI 多层 mask+scale（会水平碎裂/乳贴漂移）。
enum BodyMorphRaster {
    /// 是否足够接近中性，可直出原图。
    static func shouldBypass(_ morph: BodyMorphParams) -> Bool {
        morph.isVisuallyNeutral
    }

    #if canImport(UIKit)
    static func warpedUIImage(
        from source: UIImage,
        morph: BodyMorphParams,
        outputWidth: CGFloat,
        stripCount: Int = 128
    ) -> UIImage? {
        guard let cg = source.cgImage else { return nil }
        let srcW = cg.width
        let srcH = cg.height
        guard srcW > 1, srcH > 1 else { return nil }

        let outW = max(64, Int(outputWidth.rounded(.toNearestOrAwayFromZero)))
        let outH = max(96, Int((CGFloat(outW) * CGFloat(srcH) / CGFloat(srcW)).rounded(.toNearestOrAwayFromZero)))
        let m = morph.clamped()
        let heightS = CGFloat(m.height)
        let n = max(48, min(stripCount, outH))

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
            // 源图坐标系：UIKit CGImage 顶为 0
            for i in 0..<n {
                let y0 = Int((Double(i) / Double(n)) * Double(outH))
                let y1 = Int((Double(i + 1) / Double(n)) * Double(outH))
                let overlap = 1
                let clipY = max(0, y0)
                let clipH = max(1, (y1 - y0) + overlap)
                let midNorm = (Double(i) + 0.5) / Double(n)
                let sx = CGFloat(m.horizontalScale(normalizedY: midNorm))
                let destW = CGFloat(outW) * sx
                let destX = (CGFloat(outW) - destW) / 2

                // 源条：按输出行映射回源高度（再乘 height 逆映射）
                let srcY0f = (Double(y0) - Double(drawnY)) / Double(max(drawnH, 1)) * Double(srcH)
                let srcY1f = (Double(y1) - Double(drawnY)) / Double(max(drawnH, 1)) * Double(srcH)
                var sy0 = Int(floor(srcY0f)) - 1
                var sy1 = Int(ceil(srcY1f)) + 1
                sy0 = max(0, min(srcH - 1, sy0))
                sy1 = max(sy0 + 1, min(srcH, sy1))
                let crop = CGRect(x: 0, y: sy0, width: srcW, height: sy1 - sy0)
                guard let strip = cg.cropping(to: crop) else { continue }

                let destStripY = drawnY + CGFloat(sy0) / CGFloat(srcH) * drawnH
                let destStripH = CGFloat(sy1 - sy0) / CGFloat(srcH) * drawnH
                c.saveGState()
                c.clip(to: CGRect(x: 0, y: CGFloat(clipY), width: CGFloat(outW), height: CGFloat(clipH)))
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
        // macOS 测试路径：简化为整图 scale（条带在 mac 单测不关键视觉）
        let m = morph.clamped()
        let sx = CGFloat((m.chest + m.hip) / 2)
        let size = NSSize(width: max(64, outputWidth), height: max(96, outputWidth * 1.5))
        let out = NSImage(size: size)
        out.lockFocus()
        NSColor(white: 0.72, alpha: 1).setFill()
        NSRect(origin: .zero, size: size).fill()
        let dw = size.width * sx
        let dh = size.height * CGFloat(m.height)
        let rect = NSRect(x: (size.width - dw) / 2, y: (size.height - dh) / 2, width: dw, height: dh)
        NSImage(cgImage: cg, size: .zero).draw(in: rect)
        out.unlockFocus()
        return out
    }
    #endif
}

/// 加载资源 + 可选 morph 栅格，单图直出避免 48 层 SwiftUI mask 破碎。
struct BodyMorphImageView: View {
    var assetName: String
    var morph: BodyMorphParams
    /// 逻辑宽度（pt）；栅格输出按 2× 像素防糊
    var logicalWidth: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Group {
                if let rendered = Self.render(named: assetName, morph: morph, width: w) {
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

    @ViewBuilder
    static func render(named name: String, morph: BodyMorphParams, width: CGFloat) -> Image? {
        let pixelW = max(128, width * 2)  // 2× 栅格，抗压缩感
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
