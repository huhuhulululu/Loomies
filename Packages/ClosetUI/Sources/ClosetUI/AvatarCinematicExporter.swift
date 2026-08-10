import Foundation
import SwiftUI
import ClosetCore
import ClosetModel
import CoreGraphics
import ImageIO
import AVFoundation
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

/// 分享片时间轴（lookbook）：先站正面展 look → 轻转体 → 回正面。
/// 叠衣仅正面有资产；加长 front hold，避免「衣服只闪一帧」。
public enum AvatarCinematicLookbook {
    /// t ∈ [0,1] → (yaw, 是否叠衣)。
    public static func pose(at t: Double) -> (yaw: BodyAvatarYaw, showGarments: Bool) {
        let t = min(1, max(0, t))
        // 前/后各约 24% 时间钉在正面 + 叠衣（产品 look 可读）
        if t <= 0.24 || t >= 0.76 {
            return (.deg0, true)
        }
        // 中间段：45→90→135→180→135→90→45
        let u = (t - 0.24) / 0.52
        let orbit: [BodyAvatarYaw] = [
            .deg45, .deg90, .deg135, .deg180, .deg135, .deg90, .deg45
        ]
        let idx = min(orbit.count - 1, Int(u * Double(orbit.count - 1) + 0.001))
        return (orbit[idx], false)
    }
}

/// 约 2s 电影感预览：yaw 切帧 + 背景视差 → HEVC/H.264 MP4（分享用，非主 UI）。
@MainActor
public enum AvatarCinematicExporter {
    public struct Request: Sendable {
        public var shape: PopularShape
        public var morph: BodyMorphParams
        public var layers: [BodyAvatarLayer]
        public var backdrop: AvatarBackdrop
        public var bodySex: AvatarBodySex
        public var bodyPhenotype: AvatarBodyPhenotype
        public var width: Int
        public var height: Int
        public var duration: TimeInterval
        public var fps: Int

        public init(
            shape: PopularShape,
            morph: BodyMorphParams = .neutral,
            layers: [BodyAvatarLayer] = [],
            backdrop: AvatarBackdrop = .studio,
            bodySex: AvatarBodySex = .female,
            bodyPhenotype: AvatarBodyPhenotype = .eastAsian,
            width: Int = 720,
            height: Int = 1080,
            duration: TimeInterval = 2.0,
            fps: Int = 24
        ) {
            self.shape = shape
            self.morph = morph
            self.layers = layers
            self.backdrop = backdrop
            self.bodySex = bodySex
            self.bodyPhenotype = bodyPhenotype
            self.width = width
            self.height = height
            self.duration = duration
            self.fps = fps
        }
    }

    public enum ExportError: Error, LocalizedError, Equatable, Sendable {
        case noCroquis
        case writerFailed
        case encodeFailed

        public var errorDescription: String? {
            switch self {
            case .noCroquis:
                return "Couldn't build the nude body preview. Try again in a moment."
            case .writerFailed:
                return "Couldn't start the video writer. Free some storage and try again."
            case .encodeFailed:
                return "Couldn't finish encoding the preview. Try again in a moment."
            }
        }

        /// Short chip copy for Today toast (HIG: concise, actionable).
        public var toastMessage: String {
            switch self {
            case .noCroquis: return "Couldn't preview body — try again"
            case .writerFailed: return "Couldn't export — free storage & retry"
            case .encodeFailed: return "Couldn't export preview — try again"
            }
        }
    }

    /// 导出临时 MP4；调用方负责分享 / 清理。
    public static func exportMP4(_ request: Request) async throws -> URL {
        let frameCount = max(24, Int(request.duration * Double(request.fps)))
        let w = request.width, h = request.height

        // 全 nude 底座：优先已认证 photoreal 正面；否则程序化多人种栅格。
        // **禁止** 回退 pastie/thong croquis（违反 NudeBodyBaseSpec）。
        let neededYaw: [BodyAvatarYaw] = [
            .deg0, .deg45, .deg90, .deg135, .deg180
        ]
        var bodyFrames: [BodyAvatarYaw: CGImage] = [:]
        for y in neededYaw {
            if let img = loadFullNudeBodyFrame(request: request, yaw: y) {
                bodyFrames[y] = img
            }
        }
        guard bodyFrames[.deg0] != nil || bodyFrames.values.first != nil else {
            throw ExportError.noCroquis
        }

        let backdropCG = loadBackdropCG(request.backdrop)
        let garmentCGs: [(BodyAvatarLayer, CGImage)] = request.layers.compactMap { layer in
            guard let data = layer.localRelativePath.flatMap({ ItemImageStore.loadData(relativePath: $0) }),
                  let cg = cgImage(from: data) else { return nil }
            return (layer, cg)
        }

        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("loomies-cinematic-\(UUID().uuidString).mp4")
        try? FileManager.default.removeItem(at: outURL)

        let writer = try AVAssetWriter(outputURL: outURL, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: w,
            AVVideoHeightKey: h,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 6_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: w,
            kCVPixelBufferHeightKey as String: h
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: attrs)
        guard writer.canAdd(input) else { throw ExportError.writerFailed }
        writer.add(input)
        guard writer.startWriting() else { throw ExportError.writerFailed }
        writer.startSession(atSourceTime: .zero)

        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(request.fps))

        for i in 0..<frameCount {
            let t = Double(i) / Double(max(frameCount - 1, 1))
            // 视差：正弦左右（orbit 段更明显）
            let parallaxX = sin(t * .pi * 2) * 0.85
            let parallaxY = cos(t * .pi * 2 * 0.7) * 0.35
            let pose = AvatarCinematicLookbook.pose(at: t)
            guard let body = Self.resolveBodyFrame(yaw: pose.yaw, frames: bodyFrames)
            else { continue }

            while !(try Self.writerReadiness(
                isReady: input.isReadyForMoreMediaData,
                writerStatus: writer.status
            )) {
                try await Task.sleep(nanoseconds: 2_000_000)
            }
            guard let pb = renderFrame(
                width: w, height: h,
                backdrop: backdropCG,
                body: body,
                garments: pose.showGarments ? garmentCGs : [],
                morph: request.morph,
                parallaxX: parallaxX,
                parallaxY: parallaxY
            ) else { continue }

            let time = CMTimeMultiply(frameDuration, multiplier: Int32(i))
            if !adaptor.append(pb, withPresentationTime: time) {
                throw ExportError.encodeFailed
            }
        }

        input.markAsFinished()
        await writer.finishWriting()
        if writer.status != .completed {
            throw writer.error ?? ExportError.encodeFailed
        }
        return outURL
    }

    // MARK: - Frame composite

    /// Missing-yaw fallback: hold 正面 (deg0) deterministically before any
    /// arbitrary frame — Dictionary iteration order is not a policy.
    nonisolated static func resolveBodyFrame(
        yaw: BodyAvatarYaw,
        frames: [BodyAvatarYaw: CGImage]
    ) -> CGImage? {
        frames[yaw] ?? frames[.deg0] ?? frames.values.first
    }

    /// Back-pressure wait predicate for the writer loop: throws when the writer
    /// died mid-export (otherwise `isReadyForMoreMediaData == false` would hang
    /// forever with the film button spinning).
    nonisolated static func writerReadiness(
        isReady: Bool,
        writerStatus: AVAssetWriter.Status
    ) throws -> Bool {
        switch writerStatus {
        case .failed, .cancelled:
            throw ExportError.encodeFailed
        default:
            return isReady
        }
    }

    private static func renderFrame(
        width w: Int, height h: Int,
        backdrop: CGImage?,
        body: CGImage,
        garments: [(BodyAvatarLayer, CGImage)],
        morph: BodyMorphParams,
        parallaxX: Double,
        parallaxY: Double
    ) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &buffer)
        guard let pb = buffer else { return nil }
        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }

        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(pb),
            width: w, height: h,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        // UIKit 风格：原点左上 → flip for drawing images upright with UI coords
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)

        let full = CGRect(x: 0, y: 0, width: w, height: h)
        ctx.setFillColor(CGColor(gray: 0.45, alpha: 1))
        ctx.fill(full)

        let bgTravel: CGFloat = 28
        let figTravel: CGFloat = 12
        let bgOff = CGSize(width: parallaxX * bgTravel, height: parallaxY * bgTravel)
        let figOff = CGSize(width: parallaxX * figTravel, height: parallaxY * figTravel)

        // Backdrop (scaled up for parallax)
        if let backdrop {
            let scale: CGFloat = 1.18
            let bw = CGFloat(w) * scale, bh = CGFloat(h) * scale
            let br = CGRect(
                x: (CGFloat(w) - bw) / 2 + bgOff.width,
                y: (CGFloat(h) - bh) / 2 + bgOff.height,
                width: bw, height: bh)
            ctx.interpolationQuality = .high
            ctx.draw(backdrop, in: br)
        }

        // Body fit 2:3 in canvas
        let bodyRect = CGRect(x: 0, y: 0, width: w, height: h)
            .insetBy(dx: 0, dy: 0)
            .offsetBy(dx: figOff.width, dy: figOff.height)
        // Simple uniform scale for morph height approximation
        let mh = CGFloat(morph.clamped().height)
        let bodyDraw = CGRect(
            x: bodyRect.minX,
            y: bodyRect.midY - bodyRect.height * mh / 2,
            width: bodyRect.width,
            height: bodyRect.height * mh)
        ctx.draw(body, in: bodyDraw)

        // Garments only front — full-canvas pre-laid layers (same as BodyAvatarView)
        for (layer, gimg) in garments {
            let nr = BodyAvatarGarmentLayout.displayFrame(
                layer: layer,
                canvasWidth: Double(w),
                canvasHeight: Double(h),
                morph: morph)
            let gr = CGRect(
                x: nr.x + Double(figOff.width),
                y: nr.y + Double(figOff.height),
                width: nr.width,
                height: nr.height)
            ctx.draw(gimg, in: gr)
        }

        // Soft vignette
        ctx.setFillColor(CGColor(gray: 0, alpha: 0.18))
        // approximate: top/bottom bars
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h / 12))
        ctx.fill(CGRect(x: 0, y: h - h / 10, width: w, height: h / 10))

        return pb
    }

    // MARK: - Full-nude body frames (never covered croquis)

    private static func loadFullNudeBodyFrame(
        request: Request,
        yaw: BodyAvatarYaw
    ) -> CGImage? {
        // 认证 catalog 真人多角切帧；缺 yaw 帧时 hold 正面（保持真人身份，不跳程序化栅格）
        let available: (String) -> Bool = {
            NudeBodyBaseSpec.mayUsePhotorealFrontAsset(named: $0)
                && BodyAvatarView.bundleResourceURL(named: $0) != nil
        }
        if let name = BodyAvatarAsset.resolvePhotorealFrameName(
            sex: request.bodySex,
            phenotype: request.bodyPhenotype,
            yaw: yaw,
            available: available),
           let photo = loadCGImage(named: name)
        {
            return photo
        }
        if let front = BodyAvatarAsset.resolvePhotorealFrontName(
            sex: request.bodySex,
            phenotype: request.bodyPhenotype,
            available: available),
           let photo = loadCGImage(named: front)
        {
            return photo
        }
        return FullNudeBodyRaster.makeCGImage(
            sex: request.bodySex,
            phenotype: request.bodyPhenotype,
            morph: request.morph,
            shape: request.shape,
            yaw: yaw,
            width: request.width,
            height: request.height)
    }

    private static func loadCGImage(named name: String) -> CGImage? {
        guard let url = BodyAvatarView.bundleResourceURL(named: name),
              let data = try? Data(contentsOf: url) else { return nil }
        return cgImage(from: data)
    }

    private static func loadBackdropCG(_ b: AvatarBackdrop) -> CGImage? {
        let name = b.imageResourceName
        if let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Backdrops")
            ?? Bundle.module.url(forResource: name, withExtension: "png"),
           let data = try? Data(contentsOf: url) {
            return cgImage(from: data)
        }
        return nil
    }

    private static func cgImage(from data: Data) -> CGImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }
}
