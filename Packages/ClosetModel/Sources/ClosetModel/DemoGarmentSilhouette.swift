import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import ClosetCore

/// Demo / cold-start 纸娃娃层：程序化槽位剪影 PNG（非照片）。
/// 对齐 `GarmentLayerNormalizer` 画布 + 内容区，便于叠在 croquis 上。
public enum DemoGarmentSilhouette {
    public static let canvasWidth = GarmentLayerNormalizer.canvasWidth
    public static let canvasHeight = GarmentLayerNormalizer.canvasHeight

    /// 生成 RGBA PNG；失败返回 nil。
    public static func pngData(
        slot: BodyAvatarSlot,
        name: String,
        hue: Double?,
        isNeutral: Bool
    ) -> Data? {
        let cw = canvasWidth, ch = canvasHeight
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: nil, width: cw, height: ch,
            bitsPerComponent: 8, bytesPerRow: cw * 4,
            space: colorSpace, bitmapInfo: bitmapInfo
        ) else { return nil }

        ctx.clear(CGRect(x: 0, y: 0, width: cw, height: ch))
        // 与 Normalizer 一致：上为肩（y 向下）
        ctx.translateBy(x: 0, y: CGFloat(ch))
        ctx.scaleBy(x: 1, y: -1)

        let nr = GarmentLayerNormalizer.contentRect(for: slot)
        let zone = CGRect(
            x: nr.x * Double(cw),
            y: nr.y * Double(ch),
            width: nr.width * Double(cw),
            height: nr.height * Double(ch))

        let fill = fillColor(name: name, hue: hue, isNeutral: isNeutral)
        let shade = darker(fill, by: 0.22)
        let light = lighter(fill, by: 0.16)

        ctx.setLineJoin(.round)
        ctx.setLineWidth(max(1.5, zone.width * 0.012))

        switch slot {
        case .top:
            drawTop(ctx, zone: zone, name: name, fill: fill, light: light, shade: shade)
        case .outerwear:
            drawOuterwear(ctx, zone: zone, fill: fill, light: light, shade: shade)
        case .dress:
            drawDress(ctx, zone: zone, fill: fill, light: light, shade: shade)
        case .bottom:
            drawBottom(ctx, zone: zone, name: name, fill: fill, light: light, shade: shade)
        case .shoes:
            drawShoes(ctx, zone: zone, name: name, fill: fill, light: light, shade: shade)
        }

        guard let image = ctx.makeImage() else { return nil }
        return encodePNG(image)
    }

    // MARK: - Shaded fill（tech-pack 剪影 + 纵向上浅下深，减贴纸平面感）

    private static func fillShadedPath(
        _ ctx: CGContext,
        path: CGPath,
        zone: CGRect,
        fill: CGColor,
        light: CGColor,
        shade: CGColor
    ) {
        // 轻接触影：贴 croquis 更稳
        ctx.setShadow(
            offset: CGSize(width: 0, height: max(1, zone.height * 0.01)),
            blur: max(2, zone.width * 0.03),
            color: CGColor(gray: 0, alpha: 0.22))
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        let space = CGColorSpaceCreateDeviceRGB()
        let colors = [light, fill, shade] as CFArray
        let locs: [CGFloat] = [0, 0.42, 1]
        if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: locs) {
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: zone.midX, y: zone.minY),
                end: CGPoint(x: zone.midX, y: zone.maxY),
                options: [])
        } else {
            ctx.setFillColor(fill)
            ctx.fill(zone)
        }
        ctx.restoreGState()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)
        ctx.addPath(path)
        ctx.setStrokeColor(shade)
        ctx.strokePath()
    }

    // MARK: - Shapes（flat fashion / tech pack 简剪影）

    private static func drawTop(
        _ ctx: CGContext, zone: CGRect, name: String,
        fill: CGColor, light: CGColor, shade: CGColor
    ) {
        let blazer = name.localizedCaseInsensitiveContains("blazer")
            || name.localizedCaseInsensitiveContains("jacket")
        let w = zone.width, h = zone.height
        let midX = zone.midX
        // 躯干 + 短袖
        let path = CGMutablePath()
        let neck = w * 0.14
        let shoulder = w * (blazer ? 0.48 : 0.42)
        let hem = w * (blazer ? 0.40 : 0.36)
        let sleeveDrop = h * (blazer ? 0.42 : 0.32)
        let bodyEnd = h * (blazer ? 0.92 : 0.78)

        path.move(to: CGPoint(x: midX - neck, y: zone.minY + h * 0.02))
        path.addLine(to: CGPoint(x: midX - shoulder, y: zone.minY + h * 0.08))
        // left sleeve
        path.addLine(to: CGPoint(x: zone.minX + w * 0.02, y: zone.minY + sleeveDrop))
        path.addLine(to: CGPoint(x: zone.minX + w * 0.12, y: zone.minY + sleeveDrop + h * 0.06))
        path.addLine(to: CGPoint(x: midX - hem * 0.85, y: zone.minY + sleeveDrop * 0.85))
        // left hem
        path.addLine(to: CGPoint(x: midX - hem, y: zone.minY + bodyEnd))
        path.addLine(to: CGPoint(x: midX + hem, y: zone.minY + bodyEnd))
        // right mirror
        path.addLine(to: CGPoint(x: midX + hem * 0.85, y: zone.minY + sleeveDrop * 0.85))
        path.addLine(to: CGPoint(x: zone.maxX - w * 0.12, y: zone.minY + sleeveDrop + h * 0.06))
        path.addLine(to: CGPoint(x: zone.maxX - w * 0.02, y: zone.minY + sleeveDrop))
        path.addLine(to: CGPoint(x: midX + shoulder, y: zone.minY + h * 0.08))
        path.addLine(to: CGPoint(x: midX + neck, y: zone.minY + h * 0.02))
        path.closeSubpath()

        fillShadedPath(ctx, path: path, zone: zone, fill: fill, light: light, shade: shade)

        // 中线 / 领口 hint
        ctx.setStrokeColor(light)
        ctx.setLineWidth(max(1, zone.width * 0.008))
        ctx.move(to: CGPoint(x: midX, y: zone.minY + h * 0.10))
        ctx.addLine(to: CGPoint(x: midX, y: zone.minY + bodyEnd * 0.55))
        ctx.strokePath()
    }

    private static func drawOuterwear(
        _ ctx: CGContext, zone: CGRect,
        fill: CGColor, light: CGColor, shade: CGColor
    ) {
        let w = zone.width, h = zone.height
        let midX = zone.midX
        let path = CGMutablePath()
        path.move(to: CGPoint(x: midX - w * 0.12, y: zone.minY + h * 0.02))
        path.addLine(to: CGPoint(x: midX - w * 0.48, y: zone.minY + h * 0.10))
        path.addLine(to: CGPoint(x: zone.minX + w * 0.04, y: zone.minY + h * 0.38))
        path.addLine(to: CGPoint(x: zone.minX + w * 0.14, y: zone.minY + h * 0.42))
        path.addLine(to: CGPoint(x: midX - w * 0.38, y: zone.minY + h * 0.36))
        path.addLine(to: CGPoint(x: midX - w * 0.36, y: zone.minY + h * 0.96))
        path.addLine(to: CGPoint(x: midX - w * 0.06, y: zone.minY + h * 0.96))
        path.addLine(to: CGPoint(x: midX - w * 0.04, y: zone.minY + h * 0.18))
        path.addLine(to: CGPoint(x: midX + w * 0.04, y: zone.minY + h * 0.18))
        path.addLine(to: CGPoint(x: midX + w * 0.06, y: zone.minY + h * 0.96))
        path.addLine(to: CGPoint(x: midX + w * 0.36, y: zone.minY + h * 0.96))
        path.addLine(to: CGPoint(x: midX + w * 0.38, y: zone.minY + h * 0.36))
        path.addLine(to: CGPoint(x: zone.maxX - w * 0.14, y: zone.minY + h * 0.42))
        path.addLine(to: CGPoint(x: zone.maxX - w * 0.04, y: zone.minY + h * 0.38))
        path.addLine(to: CGPoint(x: midX + w * 0.48, y: zone.minY + h * 0.10))
        path.addLine(to: CGPoint(x: midX + w * 0.12, y: zone.minY + h * 0.02))
        path.closeSubpath()
        fillShadedPath(ctx, path: path, zone: zone, fill: fill, light: light, shade: shade)
        ctx.setStrokeColor(light)
        ctx.setLineWidth(max(1, w * 0.01))
        ctx.move(to: CGPoint(x: midX, y: zone.minY + h * 0.16))
        ctx.addLine(to: CGPoint(x: midX, y: zone.minY + h * 0.90))
        ctx.strokePath()
    }

    private static func drawDress(
        _ ctx: CGContext, zone: CGRect,
        fill: CGColor, light: CGColor, shade: CGColor
    ) {
        let w = zone.width, h = zone.height
        let midX = zone.midX
        let path = CGMutablePath()
        path.move(to: CGPoint(x: midX - w * 0.12, y: zone.minY + h * 0.02))
        path.addLine(to: CGPoint(x: midX - w * 0.40, y: zone.minY + h * 0.10))
        path.addLine(to: CGPoint(x: midX - w * 0.28, y: zone.minY + h * 0.28))
        path.addLine(to: CGPoint(x: midX - w * 0.42, y: zone.minY + h * 0.96))
        path.addLine(to: CGPoint(x: midX + w * 0.42, y: zone.minY + h * 0.96))
        path.addLine(to: CGPoint(x: midX + w * 0.28, y: zone.minY + h * 0.28))
        path.addLine(to: CGPoint(x: midX + w * 0.40, y: zone.minY + h * 0.10))
        path.addLine(to: CGPoint(x: midX + w * 0.12, y: zone.minY + h * 0.02))
        path.closeSubpath()
        fillShadedPath(ctx, path: path, zone: zone, fill: fill, light: light, shade: shade)
    }

    private static func drawBottom(
        _ ctx: CGContext, zone: CGRect, name: String,
        fill: CGColor, light: CGColor, shade: CGColor
    ) {
        let skirt = name.localizedCaseInsensitiveContains("skirt")
        let w = zone.width, h = zone.height
        let midX = zone.midX
        let path = CGMutablePath()
        if skirt {
            path.move(to: CGPoint(x: midX - w * 0.28, y: zone.minY + h * 0.04))
            path.addLine(to: CGPoint(x: midX + w * 0.28, y: zone.minY + h * 0.04))
            path.addLine(to: CGPoint(x: midX + w * 0.46, y: zone.minY + h * 0.92))
            path.addLine(to: CGPoint(x: midX - w * 0.46, y: zone.minY + h * 0.92))
            path.closeSubpath()
        } else {
            // trousers: two legs + waist
            path.move(to: CGPoint(x: midX - w * 0.30, y: zone.minY + h * 0.04))
            path.addLine(to: CGPoint(x: midX + w * 0.30, y: zone.minY + h * 0.04))
            path.addLine(to: CGPoint(x: midX + w * 0.28, y: zone.minY + h * 0.22))
            path.addLine(to: CGPoint(x: midX + w * 0.22, y: zone.minY + h * 0.96))
            path.addLine(to: CGPoint(x: midX + w * 0.06, y: zone.minY + h * 0.96))
            path.addLine(to: CGPoint(x: midX + w * 0.04, y: zone.minY + h * 0.28))
            path.addLine(to: CGPoint(x: midX - w * 0.04, y: zone.minY + h * 0.28))
            path.addLine(to: CGPoint(x: midX - w * 0.06, y: zone.minY + h * 0.96))
            path.addLine(to: CGPoint(x: midX - w * 0.22, y: zone.minY + h * 0.96))
            path.addLine(to: CGPoint(x: midX - w * 0.28, y: zone.minY + h * 0.22))
            path.closeSubpath()
        }
        fillShadedPath(ctx, path: path, zone: zone, fill: fill, light: light, shade: shade)
        ctx.setStrokeColor(light)
        ctx.setLineWidth(max(1, w * 0.008))
        ctx.move(to: CGPoint(x: midX - w * 0.28, y: zone.minY + h * 0.08))
        ctx.addLine(to: CGPoint(x: midX + w * 0.28, y: zone.minY + h * 0.08))
        ctx.strokePath()
    }

    private static func drawShoes(
        _ ctx: CGContext, zone: CGRect, name: String,
        fill: CGColor, light: CGColor, shade: CGColor
    ) {
        let pumps = name.localizedCaseInsensitiveContains("pump")
            || name.localizedCaseInsensitiveContains("heel")
        let w = zone.width, h = zone.height
        let footW = w * 0.34
        let footH = h * (pumps ? 0.55 : 0.48)
        let y = zone.maxY - footH - h * 0.08
        let gap = w * 0.08
        let left = CGRect(x: zone.midX - gap / 2 - footW, y: y, width: footW, height: footH)
        let right = CGRect(x: zone.midX + gap / 2, y: y, width: footW, height: footH)
        for r in [left, right] {
            let path = CGMutablePath()
            path.addRoundedRect(
                in: r,
                cornerWidth: footW * 0.35,
                cornerHeight: footH * 0.35)
            if pumps {
                // 细跟
                let heel = CGRect(
                    x: r.minX + footW * 0.08,
                    y: r.maxY - footH * 0.15,
                    width: footW * 0.14,
                    height: footH * 0.35)
                path.addRect(heel)
            }
            fillShadedPath(ctx, path: path, zone: r, fill: fill, light: light, shade: shade)
        }
    }

    // MARK: - Color

    private static func fillColor(name: String, hue: Double?, isNeutral: Bool) -> CGColor {
        let lower = name.lowercased()
        if lower.contains("white") {
            return CGColor(srgbRed: 0.94, green: 0.94, blue: 0.93, alpha: 0.96)
        }
        if lower.contains("black") {
            return CGColor(srgbRed: 0.14, green: 0.14, blue: 0.16, alpha: 0.96)
        }
        if lower.contains("navy") {
            return CGColor(srgbRed: 0.16, green: 0.22, blue: 0.40, alpha: 0.96)
        }
        if lower.contains("camel") {
            return CGColor(srgbRed: 0.76, green: 0.58, blue: 0.38, alpha: 0.96)
        }
        if lower.contains("blue") || lower.contains("jean") {
            return CGColor(srgbRed: 0.28, green: 0.42, blue: 0.62, alpha: 0.96)
        }
        if lower.contains("linen") {
            return CGColor(srgbRed: 0.88, green: 0.84, blue: 0.74, alpha: 0.96)
        }
        if let hue, !isNeutral {
            return hsb(h: hue / 360.0, s: 0.42, b: 0.78)
        }
        return CGColor(srgbRed: 0.55, green: 0.52, blue: 0.50, alpha: 0.94)
    }

    private static func hsb(h: Double, s: Double, b: Double) -> CGColor {
        // Standard HSB → RGB
        let h6 = (h.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1) * 6
        let c = b * s
        let x = c * (1 - abs(h6.truncatingRemainder(dividingBy: 2) - 1))
        let m = b - c
        let (r1, g1, b1): (Double, Double, Double)
        switch Int(h6) {
        case 0: (r1, g1, b1) = (c, x, 0)
        case 1: (r1, g1, b1) = (x, c, 0)
        case 2: (r1, g1, b1) = (0, c, x)
        case 3: (r1, g1, b1) = (0, x, c)
        case 4: (r1, g1, b1) = (x, 0, c)
        default: (r1, g1, b1) = (c, 0, x)
        }
        return CGColor(
            srgbRed: CGFloat(r1 + m),
            green: CGFloat(g1 + m),
            blue: CGFloat(b1 + m),
            alpha: 0.96)
    }

    private static func darker(_ c: CGColor, by t: CGFloat) -> CGColor {
        guard let comps = c.components, comps.count >= 3 else {
            return CGColor(gray: 0.2, alpha: 1)
        }
        return CGColor(
            srgbRed: max(0, comps[0] * (1 - t)),
            green: max(0, comps[1] * (1 - t)),
            blue: max(0, comps[2] * (1 - t)),
            alpha: comps.count > 3 ? comps[3] : 1)
    }

    private static func lighter(_ c: CGColor, by t: CGFloat) -> CGColor {
        guard let comps = c.components, comps.count >= 3 else {
            return CGColor(gray: 0.9, alpha: 1)
        }
        return CGColor(
            srgbRed: min(1, comps[0] + (1 - comps[0]) * t),
            green: min(1, comps[1] + (1 - comps[1]) * t),
            blue: min(1, comps[2] + (1 - comps[2]) * t),
            alpha: comps.count > 3 ? comps[3] : 1)
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
}
