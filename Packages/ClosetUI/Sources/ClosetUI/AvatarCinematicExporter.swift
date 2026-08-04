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

/// 约 2s 电影感预览：yaw 切帧 + 背景视差 → HEVC/H.264 MP4（分享用，非主 UI）。
@MainActor
public enum AvatarCinematicExporter {
    public struct Request: Sendable {
        public var shape: PopularShape
        public var morph: BodyMorphParams
        public var layers: [BodyAvatarLayer]
        public var backdrop: AvatarBackdrop
        public var width: Int
        public var height: Int
        public var duration: TimeInterval
        public var fps: Int

        public init(
            shape: PopularShape,
            morph: BodyMorphParams = .neutral,
            layers: [BodyAvatarLayer] = [],
            backdrop: AvatarBackdrop = .studio,
            width: Int = 720,
            height: Int = 1080,
            duration: TimeInterval = 2.0,
            fps: Int = 24
        ) {
            self.shape = shape
            self.morph = morph
            self.layers = layers
            self.backdrop = backdrop
            self.width = width
            self.height = height
            self.duration = duration
            self.fps = fps
        }
    }

    public enum ExportError: Error {
        case noCroquis
        case writerFailed
        case encodeFailed
    }

    /// 导出临时 MP4；调用方负责分享 / 清理。
    public static func exportMP4(_ request: Request) async throws -> URL {
        let frameCount = max(24, Int(request.duration * Double(request.fps)))
        let w = request.width, h = request.height

        // 预载 yaw 序列（往返：0→90→180→90→0，约一圈半节奏）
        let yawPath: [BodyAvatarYaw] = [
            .deg0, .deg45, .deg90, .deg135, .deg180, .deg135, .deg90, .deg45, .deg0
        ]
        var croquis: [BodyAvatarYaw: CGImage] = [:]
        for y in Set(yawPath) {
            if let name = croquisName(shape: request.shape, yaw: y),
               let img = loadCGImage(named: name) {
                croquis[y] = img
            }
        }
        guard croquis[.deg0] != nil || croquis.values.first != nil else {
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
            // 视差：正弦左右
            let parallaxX = sin(t * .pi * 2) * 0.85
            let parallaxY = cos(t * .pi * 2 * 0.7) * 0.35
            // yaw 沿 path 插索引
            let yawIdx = min(yawPath.count - 1, Int(t * Double(yawPath.count - 1) + 0.001))
            let yaw = yawPath[yawIdx]
            let body = croquis[yaw] ?? croquis.values.first!

            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 2_000_000)
            }
            guard let pb = renderFrame(
                width: w, height: h,
                backdrop: backdropCG,
                body: body,
                garments: yaw == .deg0 ? garmentCGs : [],
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

        // Garments only front (normalized space ≈ BodyAvatarAnchors)
        for (layer, gimg) in garments {
            let f = layer.frame
            let sx = CGFloat(morph.clamped().horizontalScale(normalizedY: f.y + f.height / 2))
            let gw = CGFloat(f.width) * CGFloat(w) * sx
            let gh = CGFloat(f.height) * CGFloat(h) * mh
            let gcx = 0.5 * CGFloat(w) + (CGFloat(f.x) + CGFloat(f.width) / 2 - 0.5) * CGFloat(w) * sx
            let gcy = (CGFloat(f.y) + CGFloat(f.height) / 2) * CGFloat(h) * mh
            let gr = CGRect(
                x: gcx - gw / 2 + figOff.width,
                y: gcy - gh / 2 + figOff.height,
                width: gw, height: gh)
            ctx.draw(gimg, in: gr)
        }

        // Soft vignette
        ctx.setFillColor(CGColor(gray: 0, alpha: 0.18))
        // approximate: top/bottom bars
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h / 12))
        ctx.fill(CGRect(x: 0, y: h - h / 10, width: w, height: h / 10))

        return pb
    }

    // MARK: - Asset load

    private static func croquisName(shape: PopularShape, yaw: BodyAvatarYaw) -> String? {
        let name = BodyAvatarAsset.croquisName(for: shape, yaw: yaw)
        if BodyAvatarView.bundleResourceURL(named: name) != nil { return name }
        let legacy = BodyAvatarAsset.legacyFrontName(for: shape)
        return BodyAvatarView.bundleResourceURL(named: legacy) != nil ? legacy : nil
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
