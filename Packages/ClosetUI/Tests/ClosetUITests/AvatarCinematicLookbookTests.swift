import Testing
import Foundation
import CoreGraphics
import ClosetCore
@testable import ClosetUI

@Suite("AvatarCinematicLookbook")
struct AvatarCinematicLookbookTests {
    @Test func frontHoldsShowGarments() {
        let start = AvatarCinematicLookbook.pose(at: 0)
        let early = AvatarCinematicLookbook.pose(at: 0.2)
        let end = AvatarCinematicLookbook.pose(at: 1)
        let late = AvatarCinematicLookbook.pose(at: 0.8)
        #expect(start.yaw == .deg0 && start.showGarments)
        #expect(early.yaw == .deg0 && early.showGarments)
        #expect(end.yaw == .deg0 && end.showGarments)
        #expect(late.yaw == .deg0 && late.showGarments)
    }

    @Test func midOrbitHidesGarmentsAndLeavesFront() {
        let mid = AvatarCinematicLookbook.pose(at: 0.5)
        #expect(mid.showGarments == false)
        #expect(mid.yaw != .deg0)
    }

    @Test func orbitVisitsBack() {
        var yaws = Set<BodyAvatarYaw>()
        for i in 0...20 {
            let t = 0.24 + (0.52 * Double(i) / 20.0)
            yaws.insert(AvatarCinematicLookbook.pose(at: t).yaw)
        }
        #expect(yaws.contains(.deg180))
        #expect(yaws.contains(.deg90))
    }

    /// 导出全链回归（此前无直测）：在非 MainActor 上下文跑完整 writer 管线，
    /// 产出非空 MP4——锁定「编码可离主线程执行」的重构不破功能。
    @Test func exportMP4ProducesNonEmptyFileOffMainActor() async throws {
        let req = AvatarCinematicExporter.Request(
            shape: .rectangle, width: 96, height: 144, duration: 0.2, fps: 8)
        let url = try await Task.detached(priority: .userInitiated) {
            try await AvatarCinematicExporter.exportMP4(req)
        }.value
        defer { try? FileManager.default.removeItem(at: url) }
        let size = (try FileManager.default
            .attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        #expect(size > 0)
        #expect(url.pathExtension == "mp4")
    }

    @Test func exportErrorsHaveActionableCopy() {
        let cases: [AvatarCinematicExporter.ExportError] = [
            .noCroquis, .writerFailed, .encodeFailed
        ]
        for err in cases {
            #expect(err.errorDescription?.isEmpty == false)
            #expect(err.toastMessage.isEmpty == false)
            #expect(err.toastMessage.count < 80)
        }
        #expect(AvatarCinematicExporter.ExportError.noCroquis.toastMessage
            .localizedCaseInsensitiveContains("try")
            || AvatarCinematicExporter.ExportError.noCroquis.toastMessage
            .localizedCaseInsensitiveContains("preview"))
        #expect(AvatarCinematicExporter.ExportError.writerFailed.toastMessage
            .localizedCaseInsensitiveContains("storage")
            || AvatarCinematicExporter.ExportError.writerFailed.toastMessage
            .localizedCaseInsensitiveContains("retry"))
    }
}

@Suite("FullNudeBodyRaster")
struct FullNudeBodyRasterTests {
    @Test func rasterProducesOpaqueSkinPixelsForEachPhenotype() {
        for p in AvatarBodyPhenotype.allCases {
            let img = FullNudeBodyRaster.makeCGImage(
                sex: .female,
                phenotype: p,
                morph: .neutral,
                shape: .hourglass,
                yaw: .deg0,
                width: 128,
                height: 192)
            #expect(img != nil, "raster nil for \(p.rawValue)")
            guard let img else { continue }
            #expect(img.width == 128 && img.height == 192)
            // Center torso should be non-transparent skin (not empty canvas).
            let alpha = sampleAlpha(img, x: 64, y: 100)
            #expect(alpha > 0.5, "expected body pixel for \(p.rawValue)")
        }
    }

    @Test func africanRasterDarkerThanEuropeanAtTorso() {
        let eu = FullNudeBodyRaster.makeCGImage(
            sex: .female, phenotype: .european, yaw: .deg0, width: 96, height: 144)!
        let af = FullNudeBodyRaster.makeCGImage(
            sex: .female, phenotype: .african, yaw: .deg0, width: 96, height: 144)!
        let euL = sampleLuma(eu, x: 48, y: 75)
        let afL = sampleLuma(af, x: 48, y: 75)
        #expect(afL < euL)
    }

    @Test func sideYawNarrowerThanFront() {
        #expect(FullNudeBodyRaster.yawWidthFactor(.deg90)
            < FullNudeBodyRaster.yawWidthFactor(.deg0))
        #expect(FullNudeBodyRaster.yawWidthFactor(.deg45)
            < FullNudeBodyRaster.yawWidthFactor(.deg0))
        #expect(FullNudeBodyRaster.yawWidthFactor(.deg180)
            == FullNudeBodyRaster.yawWidthFactor(.deg0))
    }

    @Test func maleAndFemaleRastersBothFullNudeCapable() {
        for sex in AvatarBodySex.allCases {
            let img = FullNudeBodyRaster.makeCGImage(
                sex: sex, phenotype: .latinx, yaw: .deg0, width: 80, height: 120)
            #expect(img != nil)
        }
    }

    @Test func shapePresetsFeedDistinctScalesIntoRaster() {
        let pearS = MannequinSegmentScales.resolve(
            sex: .female, morph: .neutral, shape: .pear, phenotype: .eastAsian)
        let invS = MannequinSegmentScales.resolve(
            sex: .female, morph: .neutral, shape: .invertedTriangle, phenotype: .eastAsian)
        #expect(pearS.hipWidth > invS.hipWidth)
        #expect(invS.shoulderWidth > pearS.shoulderWidth)
        #expect(FullNudeBodyRaster.makeCGImage(
            sex: .female, phenotype: .eastAsian, morph: .neutral,
            shape: .pear, yaw: .deg0, width: 80, height: 120) != nil)
        #expect(FullNudeBodyRaster.makeCGImage(
            sex: .female, phenotype: .eastAsian, morph: .neutral,
            shape: .invertedTriangle, yaw: .deg0, width: 80, height: 120) != nil)
    }

    // MARK: - pixel helpers

    private func sampleAlpha(_ image: CGImage, x: Int, y: Int) -> Double {
        sample(image, x: x, y: y).a
    }

    private func sampleLuma(_ image: CGImage, x: Int, y: Int) -> Double {
        let p = sample(image, x: x, y: y)
        return 0.299 * p.r + 0.587 * p.g + 0.114 * p.b
    }

    private func sample(
        _ image: CGImage, x: Int, y: Int
    ) -> (r: Double, g: Double, b: Double, a: Double) {
        var pixel = [UInt8](repeating: 0, count: 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return (0, 0, 0, 0) }
        // CG y-up: convert from top-down sample y if needed — bitmap render uses y-up
        // Our raster draws with y-up; tests pass y from bottom.
        ctx.draw(image, in: CGRect(x: -x, y: -y, width: image.width, height: image.height))
        return (
            Double(pixel[0]) / 255,
            Double(pixel[1]) / 255,
            Double(pixel[2]) / 255,
            Double(pixel[3]) / 255
        )
    }
}

@Suite("AvatarContactShadowLayout")
struct AvatarContactShadowLayoutTests {
    @Test func tallerMorphDropsShadowFurther() {
        let short = BodyMorphParams(chest: 1, waist: 1, hip: 1, shoulder: 1, height: 0.94)
        let tall = BodyMorphParams(chest: 1, waist: 1, hip: 1, shoulder: 1, height: 1.08)
        let yShort = AvatarContactShadowLayout.offsetY(canvasHeight: 300, morph: short)
        let yTall = AvatarContactShadowLayout.offsetY(canvasHeight: 300, morph: tall)
        #expect(yTall > yShort)
    }

    @Test func widerMorphWidensShadow() {
        let narrow = BodyMorphParams(chest: 0.92, waist: 1, hip: 0.95, shoulder: 0.95, height: 1)
        let wide = BodyMorphParams(chest: 1.08, waist: 1, hip: 1.1, shoulder: 1.05, height: 1)
        let a = AvatarContactShadowLayout.size(canvas: CGSize(width: 200, height: 300), morph: narrow)
        let b = AvatarContactShadowLayout.size(canvas: CGSize(width: 200, height: 300), morph: wide)
        #expect(b.width > a.width)
    }
}
