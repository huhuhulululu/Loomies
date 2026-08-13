import Testing
import Foundation
import CoreVideo
@testable import ClosetUI

/// D150：**导出每一帧都新分配一整块全尺寸像素缓冲。**
///
/// `renderFrame` 里是 `CVPixelBufferCreate(kCFAllocatorDefault, w, h, …)`——
/// 1080×1920 BGRA 一块约 8MB，而一段 lookbook 有上百帧：
/// 上百次「申请 8MB → 画 → 交给编码器 → 释放」，全在导出那几秒里。
/// 峰值内存与分配器压力都由此而来，而 `AVAssetWriterInputPixelBufferAdaptor`
/// **自带 `pixelBufferPool` 就是为这件事准备的**：池子回收同一批缓冲，
/// 分配只发生前几帧。
///
/// 池子在 `startWriting()` 之前是 nil，所以取缓冲这一步要能优雅回落——
/// 回落路径必须仍然给得出缓冲，否则导出会在某些时序下直接失败
///（比「慢一点」糟得多）。
struct PixelBufferPoolTests {

    private let width = 64, height = 48

    private func makePool() -> CVPixelBufferPool? {
        let attrs: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        var pool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(
            kCFAllocatorDefault, nil, attrs as CFDictionary, &pool)
        return pool
    }

    /// 有池子就从池子里取。
    @Test func itTakesFromThePoolWhenThereIsOne() throws {
        let pool = try #require(makePool())
        let pb = try #require(AvatarCinematicExporter.acquirePixelBuffer(
            pool: pool, width: width, height: height))
        #expect(CVPixelBufferGetWidth(pb) == width)
        #expect(CVPixelBufferGetHeight(pb) == height)
    }

    /// **真的回收**：上一块释放之后再取，拿到的是同一块内存。
    /// 这正是这一波要的东西——不回收的话池子等于没用。
    @Test func releasedBuffersComeBack() throws {
        let pool = try #require(makePool())
        var firstAddress: UnsafeMutableRawPointer?
        do {
            let pb = try #require(AvatarCinematicExporter.acquirePixelBuffer(
                pool: pool, width: width, height: height))
            CVPixelBufferLockBaseAddress(pb, [])
            firstAddress = CVPixelBufferGetBaseAddress(pb)
            CVPixelBufferUnlockBaseAddress(pb, [])
        }   // 出作用域即释放回池
        let second = try #require(AvatarCinematicExporter.acquirePixelBuffer(
            pool: pool, width: width, height: height))
        CVPixelBufferLockBaseAddress(second, [])
        let secondAddress = CVPixelBufferGetBaseAddress(second)
        CVPixelBufferUnlockBaseAddress(second, [])
        #expect(secondAddress == firstAddress,
                "池子没有回收 —— 每帧仍在新分配一整块全尺寸缓冲")
    }

    /// **没有池子也得给得出缓冲**（`startWriting()` 之前 pool 是 nil）。
    /// 回落失败会让导出在某些时序下直接崩掉，比慢一点糟得多。
    @Test func itStillWorksWithoutAPool() throws {
        let pb = try #require(AvatarCinematicExporter.acquirePixelBuffer(
            pool: nil, width: width, height: height))
        #expect(CVPixelBufferGetWidth(pb) == width)
    }

    /// 接线门：帧循环必须真的把池子递进去——否则这套东西又是「实现了没人调」。
    @Test func theFrameLoopActuallyUsesThePool() throws {
        let text = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Sources/ClosetUI/AvatarCinematicExporter.swift"),
            encoding: .utf8)
        #expect(text.contains("adaptor.pixelBufferPool"),
                "帧循环没用上 adaptor 自带的池子 —— 每帧仍在新分配 8MB")
        // 逐帧创建的那行不许再留在渲染函数里
        // D162：原来取「函数往后 1200 字」——我把一个真的 `CVPixelBufferCreate`
        // 注入 `renderFrame` **末尾**（超出窗口），门照样绿。
        // 「不存在」断言配固定窗口 = 看不见的地方就等于不存在，假绿的方向。
        // 改按**结构边界**：从函数声明到下一个函数声明为止。
        let after = text.components(separatedBy: "func renderFrame(").last ?? ""
        let renderBody = after.components(separatedBy: "\n    private static func").first
            ?? after
        #expect(!renderBody.contains("CVPixelBufferCreate("),
                "renderFrame 里仍有逐帧 CVPixelBufferCreate")
    }
}
