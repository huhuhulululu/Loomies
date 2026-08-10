import Foundation
import CoreGraphics
import ImageIO
import ClosetCore

/// Automated **zero-covering** heuristic for real-human photoreal body bases.
///
/// Used only before flipping `NudeBodyBaseSpec.photorealFrontAssetsCertifiedFullNude`
/// (aspirational full-nude path). **Does not gate D59/D63 catalog basewear display** —
/// catalog assets intentionally keep pastie/thong and will fail this heuristic.
/// Detects high-frequency edge residue typical of pastie scallops and thong straps
/// in chest / pelvis bands. Not a substitute for human visual QA — fail-closed for full-nude cert.
///
/// Pure analysis (no mutation). Mesh / procedural paths are out of scope.
public enum PhotorealCoveringQA: Sendable {
    public struct Report: Equatable, Sendable {
        public var width: Int
        public var height: Int
        /// Mean gradient magnitude in chest band (normalized 0…~1 scale).
        public var chestEdgeScore: Double
        /// Mean gradient magnitude in pelvis band.
        public var pelvisEdgeScore: Double
        /// Combined score (max of bands).
        public var combinedEdgeScore: Double
        /// `true` only when both bands look like continuous skin (below thresholds).
        public var passesZeroCoveringHeuristic: Bool
        public var notes: [String]

        public init(
            width: Int,
            height: Int,
            chestEdgeScore: Double,
            pelvisEdgeScore: Double,
            combinedEdgeScore: Double,
            passesZeroCoveringHeuristic: Bool,
            notes: [String]
        ) {
            self.width = width
            self.height = height
            self.chestEdgeScore = chestEdgeScore
            self.pelvisEdgeScore = pelvisEdgeScore
            self.combinedEdgeScore = combinedEdgeScore
            self.passesZeroCoveringHeuristic = passesZeroCoveringHeuristic
            self.notes = notes
        }
    }

    /// Empirically set from current covered F/M photoreal (pastie/thong; ♂ also thong).
    /// Clean continuous skin should land lower; re-tune when true full-nude plates arrive.
    public static let chestEdgeFailThreshold: Double = 0.085
    public static let pelvisEdgeFailThreshold: Double = 0.090

    /// Analyze a decoded body photo (RGBA/BGRA/RGB). Returns fail-closed report on decode issues.
    public static func analyze(cgImage: CGImage) -> Report {
        let w = cgImage.width
        let h = cgImage.height
        guard w >= 64, h >= 96 else {
            return Report(
                width: w, height: h,
                chestEdgeScore: 1, pelvisEdgeScore: 1, combinedEdgeScore: 1,
                passesZeroCoveringHeuristic: false,
                notes: ["image too small for covering QA"])
        }
        guard let pixels = rgbaBytes(from: cgImage) else {
            return Report(
                width: w, height: h,
                chestEdgeScore: 1, pelvisEdgeScore: 1, combinedEdgeScore: 1,
                passesZeroCoveringHeuristic: false,
                notes: ["could not read pixel buffer"])
        }

        // Normalized bands on full-length standing figure (black studio).
        let chest = bandEdgeScore(
            pixels: pixels, width: w, height: h,
            y0: Int(Double(h) * 0.30), y1: Int(Double(h) * 0.40),
            x0: Int(Double(w) * 0.28), x1: Int(Double(w) * 0.72))
        let pelvis = bandEdgeScore(
            pixels: pixels, width: w, height: h,
            y0: Int(Double(h) * 0.48), y1: Int(Double(h) * 0.62),
            x0: Int(Double(w) * 0.30), x1: Int(Double(w) * 0.70))

        var notes: [String] = []
        if chest >= chestEdgeFailThreshold {
            notes.append(String(format: "chest edge score %.3f ≥ thr %.3f (pastie/fabric risk)",
                                chest, chestEdgeFailThreshold))
        }
        if pelvis >= pelvisEdgeFailThreshold {
            notes.append(String(format: "pelvis edge score %.3f ≥ thr %.3f (thong risk)",
                                pelvis, pelvisEdgeFailThreshold))
        }
        let combined = max(chest, pelvis)
        let passes = chest < chestEdgeFailThreshold && pelvis < pelvisEdgeFailThreshold
        if passes {
            notes.append("heuristic clear — still require human visual QA before cert flip")
        }
        return Report(
            width: w, height: h,
            chestEdgeScore: chest,
            pelvisEdgeScore: pelvis,
            combinedEdgeScore: combined,
            passesZeroCoveringHeuristic: passes,
            notes: notes)
    }

    /// Load PNG/JPEG from file URL.
    public static func analyze(fileURL: URL) -> Report? {
        guard let src = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil)
        else { return nil }
        return analyze(cgImage: img)
    }

    /// Bundle photoreal by resource name (no extension).
    public static func analyzeBundlePhotoreal(named name: String) -> Report? {
        guard let url = BodyAvatarView.bundleResourceURL(named: name) else { return nil }
        return analyze(fileURL: url)
    }

    /// Cert flip is allowed only when flag intent + automated heuristic + human QA all agree.
    /// This never mutates `NudeBodyBaseSpec`; callers must still edit the const deliberately.
    public static func mayRecommendCertification(
        automated: Report,
        humanZeroCoveringConfirmed: Bool
    ) -> Bool {
        guard NudeBodyBaseSpec.primaryRenderMode == .realHumanPhoto else { return false }
        guard !NudeBodyBaseSpec.allowsAnyCovering else { return false }
        guard automated.passesZeroCoveringHeuristic else { return false }
        guard humanZeroCoveringConfirmed else { return false }
        return true
    }

    // MARK: - Internals

    private static func rgbaBytes(from image: CGImage) -> [UInt8]? {
        let w = image.width
        let h = image.height
        let bytesPerRow = w * 4
        var data = [UInt8](repeating: 0, count: h * bytesPerRow)
        guard let ctx = CGContext(
            data: &data,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return data
    }

    /// Mean Sobel-ish gradient on luminance, only where alpha/luma suggests body (not black bg).
    private static func bandEdgeScore(
        pixels: [UInt8],
        width w: Int,
        height h: Int,
        y0: Int,
        y1: Int,
        x0: Int,
        x1: Int
    ) -> Double {
        let yStart = max(1, min(h - 2, y0))
        let yEnd = max(yStart + 1, min(h - 1, y1))
        let xStart = max(1, min(w - 2, x0))
        let xEnd = max(xStart + 1, min(w - 1, x1))

        func lum(_ x: Int, _ y: Int) -> Double {
            let i = (y * w + x) * 4
            let r = Double(pixels[i])
            let g = Double(pixels[i + 1])
            let b = Double(pixels[i + 2])
            return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
        }

        var sum = 0.0
        var count = 0
        var y = yStart
        while y < yEnd {
            var x = xStart
            while x < xEnd {
                let L = lum(x, y)
                // skip near-black studio background
                if L > 0.12 {
                    let gx = -lum(x - 1, y - 1) - 2 * lum(x - 1, y) - lum(x - 1, y + 1)
                        + lum(x + 1, y - 1) + 2 * lum(x + 1, y) + lum(x + 1, y + 1)
                    let gy = -lum(x - 1, y - 1) - 2 * lum(x, y - 1) - lum(x + 1, y - 1)
                        + lum(x - 1, y + 1) + 2 * lum(x, y + 1) + lum(x + 1, y + 1)
                    let mag = (gx * gx + gy * gy).squareRoot()
                    sum += mag
                    count += 1
                }
                x += 1
            }
            y += 1
        }
        guard count > 0 else { return 1 }
        return sum / Double(count)
    }
}
