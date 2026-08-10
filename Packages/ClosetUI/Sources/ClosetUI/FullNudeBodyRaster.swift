import Foundation
import CoreGraphics
import ClosetCore

/// 全 nude 多人种 2D 栅格体（零遮盖）。供 cinematic export / 缺 USDZ·写实认证时的底座。
/// 非 croquis（旧 croquis 含 pastie/thong，违反死要求）；非 VTON / SMPL。
public enum FullNudeBodyRaster: Sendable {
    /// 在透明画布上绘制 `sex × phenotype` 全裸剪影；yaw 仅做宽度/侧视 squish。
    public static func makeCGImage(
        sex: AvatarBodySex,
        phenotype: AvatarBodyPhenotype,
        morph: BodyMorphParams = .neutral,
        shape: PopularShape? = nil,
        yaw: BodyAvatarYaw = .deg0,
        width: Int,
        height: Int
    ) -> CGImage? {
        let w = max(64, width)
        let h = max(96, height)
        let scales = MannequinSegmentScales.resolve(
            sex: sex, morph: morph, shape: shape, phenotype: phenotype)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.clear(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.setShouldAntialias(true)
        ctx.interpolationQuality = .high

        let skin = phenotype.skinRGB(sex: sex)
        let soft = (skin.r * 0.96, skin.g * 0.95, skin.b * 0.94)
        let shade = (skin.r * 0.82, skin.g * 0.80, skin.b * 0.78)
        let hi = (
            min(1, skin.r * 1.06 + 0.02),
            min(1, skin.g * 1.05 + 0.02),
            min(1, skin.b * 1.04 + 0.02)
        )
        let areolaD = phenotype.areolaDarken
        let areola = (skin.r * areolaD, skin.g * areolaD * 0.92, skin.b * areolaD * 0.88)
        let hair = phenotype.hairRGB

        // Yaw: 0 正面全宽；90/270 侧视最窄；45/135 中间
        let yawFactor = Self.yawWidthFactor(yaw)
        let cx = CGFloat(w) * 0.5
        // 脚在底部 8%，头在顶部 10% — 与 BodyAvatar 画布大致对齐
        let footY = CGFloat(h) * 0.08
        let headY = CGFloat(h) * 0.90
        let bodyH = headY - footY
        let baseW = CGFloat(w) * 0.22 * CGFloat(scales.shoulderWidth) * yawFactor

        func fill(_ rgb: (Double, Double, Double), alpha: CGFloat = 1) {
            ctx.setFillColor(CGColor(
                red: rgb.0, green: rgb.1, blue: rgb.2, alpha: Double(alpha)))
        }
        func oval(_ r: CGRect) { ctx.fillEllipse(in: r) }
        /// Soft limb: core + darker rim for volume (still single skin tone family).
        func limb(_ r: CGRect) {
            fill(shade)
            oval(r.insetBy(dx: -r.width * 0.04, dy: -r.height * 0.02))
            fill(skin)
            oval(r)
            fill(hi, alpha: 0.35)
            let hr = r.insetBy(dx: r.width * 0.28, dy: r.height * 0.12)
            oval(CGRect(x: hr.minX, y: hr.midY, width: hr.width * 0.55, height: hr.height * 0.45))
        }

        let isMale = sex == .male
        let limbT = CGFloat(scales.limbThickness)

        // Legs
        let thighW = baseW * 0.38 * limbT
        let shinW = baseW * 0.28 * limbT
        let legGap = baseW * 0.22
        limb(CGRect(x: cx - legGap - thighW / 2, y: footY + bodyH * 0.18,
                    width: thighW, height: bodyH * 0.28))
        limb(CGRect(x: cx + legGap - thighW / 2, y: footY + bodyH * 0.18,
                    width: thighW, height: bodyH * 0.28))
        limb(CGRect(x: cx - legGap - shinW / 2, y: footY + bodyH * 0.02,
                    width: shinW, height: bodyH * 0.22))
        limb(CGRect(x: cx + legGap - shinW / 2, y: footY + bodyH * 0.02,
                    width: shinW, height: bodyH * 0.22))
        // Feet
        let footW = shinW * 1.35
        fill(skin)
        oval(CGRect(x: cx - legGap - footW / 2, y: footY - bodyH * 0.01,
                    width: footW, height: bodyH * 0.04))
        oval(CGRect(x: cx + legGap - footW / 2, y: footY - bodyH * 0.01,
                    width: footW, height: bodyH * 0.04))

        // Hip / glute / pelvis — full skin, zero covering
        let hipW = baseW * 1.05 * CGFloat(scales.hipWidth)
        fill(shade)
        oval(CGRect(x: cx - hipW / 2, y: footY + bodyH * 0.37,
                    width: hipW, height: bodyH * 0.13))
        fill(soft)
        oval(CGRect(x: cx - hipW / 2, y: footY + bodyH * 0.38,
                    width: hipW, height: bodyH * 0.12))
        if yawFactor > 0.55 {
            // Front/mons or male genital volume (skin only)
            let pelvisW = hipW * (isMale ? 0.35 : 0.28)
            fill(soft)
            oval(CGRect(x: cx - pelvisW / 2, y: footY + bodyH * 0.40,
                        width: pelvisW, height: bodyH * 0.06))
            if isMale {
                fill(shade)
                oval(CGRect(x: cx - pelvisW * 0.28, y: footY + bodyH * 0.385,
                            width: pelvisW * 0.55, height: bodyH * 0.045))
            }
        }

        // Waist / abdomen / chest
        let waistW = baseW * 0.85 * CGFloat(scales.waistWidth)
        let chestW = baseW * 1.05 * CGFloat(scales.chestWidth)
        fill(skin)
        oval(CGRect(x: cx - waistW / 2, y: footY + bodyH * 0.46,
                    width: waistW, height: bodyH * 0.10))
        fill(shade, alpha: 0.45)
        oval(CGRect(x: cx - waistW * 0.15, y: footY + bodyH * 0.48,
                    width: waistW * 0.12, height: bodyH * 0.06)) // navel shade
        fill(skin)
        oval(CGRect(x: cx - chestW / 2, y: footY + bodyH * 0.54,
                    width: chestW, height: bodyH * 0.16))
        fill(hi, alpha: 0.25)
        oval(CGRect(x: cx - chestW * 0.15, y: footY + bodyH * 0.58,
                    width: chestW * 0.35, height: bodyH * 0.08))

        // Breasts / pecs + anatomical areola (not pasties)
        if yawFactor > 0.45 {
            let bustR = chestW * (isMale ? 0.12 : 0.18) * CGFloat(scales.chestDepth)
            let by = footY + bodyH * 0.62
            let bx = chestW * 0.22
            fill(soft)
            oval(CGRect(x: cx - bx - bustR / 2, y: by, width: bustR, height: bustR * 0.95))
            oval(CGRect(x: cx + bx - bustR / 2, y: by, width: bustR, height: bustR * 0.95))
            fill(areola)
            let ar = bustR * (isMale ? 0.18 : 0.28)
            oval(CGRect(x: cx - bx - ar / 2, y: by + bustR * 0.28, width: ar, height: ar))
            oval(CGRect(x: cx + bx - ar / 2, y: by + bustR * 0.28, width: ar, height: ar))
        }

        // Shoulders / arms
        let shW = baseW * 1.15 * CGFloat(scales.shoulderWidth)
        fill(skin)
        oval(CGRect(x: cx - shW / 2, y: footY + bodyH * 0.68,
                    width: shW, height: bodyH * 0.06))
        let armW = baseW * 0.16 * limbT
        let armX = shW * 0.48
        limb(CGRect(x: cx - armX - armW / 2, y: footY + bodyH * 0.42,
                    width: armW, height: bodyH * 0.30))
        limb(CGRect(x: cx + armX - armW / 2, y: footY + bodyH * 0.42,
                    width: armW, height: bodyH * 0.30))

        // Neck / head
        let headR = baseW * (isMale ? 0.42 : 0.40)
        fill(skin)
        oval(CGRect(x: cx - headR * 0.22, y: footY + bodyH * 0.72,
                    width: headR * 0.44, height: bodyH * 0.08))
        oval(CGRect(x: cx - headR / 2, y: footY + bodyH * 0.76,
                    width: headR, height: headR * 1.05))
        fill(shade, alpha: 0.35)
        oval(CGRect(x: cx - headR * 0.28, y: footY + bodyH * 0.78,
                    width: headR * 0.56, height: headR * 0.55)) // face shade

        // Hair volume by phenotype (never a covering garment)
        fill(hair)
        let hairBoost: CGFloat = {
            switch phenotype {
            case .african: return 1.25
            case .european: return 1.05
            case .southAsian, .latinx, .middleEastern, .indigenous: return 1.12
            case .eastAsian, .southeastAsian: return 1.0
            }
        }()
        let hr = headR * 0.95 * hairBoost
        oval(CGRect(x: cx - hr / 2, y: footY + bodyH * 0.82,
                    width: hr, height: hr * 0.75))
        if !isMale {
            oval(CGRect(x: cx - hr * 0.55, y: footY + bodyH * 0.70,
                        width: hr * 0.35, height: bodyH * 0.14))
            oval(CGRect(x: cx + hr * 0.20, y: footY + bodyH * 0.70,
                        width: hr * 0.35, height: bodyH * 0.14))
        }

        return ctx.makeImage()
    }

    /// 1 = 正/背最宽，~0.42 = 真侧（90°/270°）。
    public static func yawWidthFactor(_ yaw: BodyAvatarYaw) -> CGFloat {
        let d = Double(yaw.rawValue)
        let toFront = min(d, 360 - d)
        let toBack = abs(d - 180)
        let dist = min(toFront, toBack) // 0 at front *and* back
        // 0°/180° → 1.0；90° → 0.42
        let t = min(1, dist / 90)
        return CGFloat(1.0 - 0.58 * t)
    }
}

#if canImport(SwiftUI)
import SwiftUI

/// 程序化裸体栅格缓存（interim 路径：photoreal 资产缺失/表型未覆盖时走这条）。
/// NSCache 按字节 cost 计费 + miss 负缓存（姊妹缓存同纪律）；
/// 旧实现在 View body 里直接 makeCGImage，30fps TimelineView 下每次重求值全画布重绘。
@MainActor
final class FullNudeBodyImageCache {
    static let shared = FullNudeBodyImageCache()

    final class Box {
        let image: CGImage?
        init(_ image: CGImage?) { self.image = image }
    }

    private let cache: NSCache<NSString, Box> = {
        let c = NSCache<NSString, Box>()
        c.totalCostLimit = 48 * 1024 * 1024
        c.countLimit = 64
        return c
    }()

    /// 测试探针：栅格化实际执行次数。
    private(set) var renderAttempts = 0

    func image(
        sex: AvatarBodySex, phenotype: AvatarBodyPhenotype,
        morph: BodyMorphParams, shape: PopularShape?,
        yaw: BodyAvatarYaw, width: Int, height: Int
    ) -> CGImage? {
        let m = morph.clamped()
        let key = "\(sex.rawValue)|\(phenotype.rawValue)|\(shape?.rawValue ?? "-")"
            + "|\(yaw.rawValue)|\(width)x\(height)|"
            + String(format: "%.3f|%.3f|%.3f|%.3f|%.3f", m.chest, m.waist, m.hip, m.shoulder, m.height)
        if let box = cache.object(forKey: key as NSString) { return box.image }
        renderAttempts += 1
        let img = FullNudeBodyRaster.makeCGImage(
            sex: sex, phenotype: phenotype, morph: morph, shape: shape,
            yaw: yaw, width: width, height: height)
        cache.setObject(Box(img), forKey: key as NSString, cost: img == nil ? 1 : width * height * 4)
        return img
    }
}

/// SwiftUI 包装：全 nude 多人种 2D 底座（零遮盖；替代 pastie/thong croquis）。
public struct FullNudeBodyImageView: View {
    public var sex: AvatarBodySex
    public var phenotype: AvatarBodyPhenotype
    public var morph: BodyMorphParams
    public var shape: PopularShape?
    public var yaw: BodyAvatarYaw
    public var logicalWidth: CGFloat

    public init(
        sex: AvatarBodySex = .female,
        phenotype: AvatarBodyPhenotype = .eastAsian,
        morph: BodyMorphParams = .neutral,
        shape: PopularShape? = nil,
        yaw: BodyAvatarYaw = .deg0,
        logicalWidth: CGFloat
    ) {
        self.sex = sex
        self.phenotype = phenotype
        self.morph = morph
        self.shape = shape
        self.yaw = yaw
        self.logicalWidth = logicalWidth
    }

    public var body: some View {
        // 浮点域先钳非有限值再转 Int（Int(NaN/∞) 陷阱；GeometryReader 首帧可给 0/∞）
        let safeW = min(4096, max(64, logicalWidth.isFinite ? logicalWidth : 64))
        let h = max(96, Int(safeW * 1.5))
        let w = Int(safeW)
        // 经缓存：30fps TimelineView 下 body 每次重求值不得全画布重绘（~30 个抗锯齿椭圆）
        let img = FullNudeBodyImageCache.shared.image(
            sex: sex,
            phenotype: phenotype,
            morph: morph,
            shape: shape,
            yaw: yaw,
            width: w,
            height: h)
        Group {
            if let img {
                Image(decorative: img, scale: 1, orientation: .up)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Color.clear
            }
        }
        .accessibilityLabel(
            "Fully nude \(phenotype.displayTitle) \(sex.displayTitle.lowercased()) body, zero covering")
    }
}
#endif
