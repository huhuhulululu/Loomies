import Testing
import Foundation
import CoreGraphics
@testable import ClosetModel
import ClosetCore

/// D96（缺口 #10）：抠图边缘手修。DESIGN §F1 标「**竞品被骂点必须做**」——
/// 自动抠图总有啃掉袖口、留下一块背景的时候，没有手修就只能重拍。
///
/// 设计要点：状态就是**一串笔画**，渲染永远从「原图 + 自动抠图结果」重算。
/// 撤销＝丢掉最后一笔，不需要维护像素级历史；也不会因为反复涂抹而累积压缩损失。
struct MatteRetouchTests {

    /// 造一张全不透明的纯色 PNG（当作「原图」）。
    func makeOpaquePNG(_ w: Int = 100, _ h: Int = 100) throws -> Data {
        let ctx = try #require(CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.setFillColor(CGColor(red: 0.2, green: 0.7, blue: 0.4, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        let image = try #require(ctx.makeImage())
        return try #require(MatteRetouch.encodePNG(image))
    }

    /// 造一张全透明 PNG（当作「被抠光了的」结果）。
    func makeTransparentPNG(_ w: Int = 100, _ h: Int = 100) throws -> Data {
        let ctx = try #require(CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = try #require(ctx.makeImage())
        return try #require(MatteRetouch.encodePNG(image))
    }

    func alpha(_ data: Data, atX x: Double, y: Double) throws -> Double {
        try #require(MatteRetouch.alphaSample(data, normalizedX: x, normalizedY: y))
    }

    /// 无笔画 = 原样返回（不做无谓的重编码，避免每次打开都掉一点质量）。
    @Test func noStrokesReturnsInputUnchanged() throws {
        let matted = try makeOpaquePNG()
        let out = MatteRetouch.apply([], to: matted, original: try makeOpaquePNG())
        #expect(out == nil)
    }

    /// 擦除：涂过的地方 alpha 归零，没涂的地方不动。
    @Test func eraseClearsOnlyWhereItWasPainted() throws {
        let matted = try makeOpaquePNG()
        let stroke = MatteRetouch.Stroke(
            mode: .erase, radius: 0.15, points: [CGPoint(x: 0.25, y: 0.25)])
        let out = try #require(MatteRetouch.apply([stroke], to: matted, original: matted))
        #expect(try alpha(out, atX: 0.25, y: 0.25) < 0.05)
        #expect(try alpha(out, atX: 0.8, y: 0.8) > 0.9)
    }

    /// 恢复：从**原图**取回像素，不是凭空造。全透明底上恢复出的那块必须重新可见。
    @Test func restorePullsPixelsBackFromTheOriginal() throws {
        let original = try makeOpaquePNG()
        let matted = try makeTransparentPNG()
        let stroke = MatteRetouch.Stroke(
            mode: .restore, radius: 0.2, points: [CGPoint(x: 0.5, y: 0.5)])
        let out = try #require(MatteRetouch.apply([stroke], to: matted, original: original))
        #expect(try alpha(out, atX: 0.5, y: 0.5) > 0.9)
        #expect(try alpha(out, atX: 0.05, y: 0.05) < 0.05)
    }

    /// 撤销＝少一笔重渲染：结果必须与「一开始就没画那笔」逐像素等价。
    @Test func undoIsJustRenderingWithOneFewerStroke() throws {
        let matted = try makeOpaquePNG()
        let a = MatteRetouch.Stroke(mode: .erase, radius: 0.1, points: [CGPoint(x: 0.3, y: 0.3)])
        let b = MatteRetouch.Stroke(mode: .erase, radius: 0.1, points: [CGPoint(x: 0.7, y: 0.7)])
        let both = try #require(MatteRetouch.apply([a, b], to: matted, original: matted))
        let undone = try #require(MatteRetouch.apply([a], to: matted, original: matted))
        #expect(try alpha(both, atX: 0.7, y: 0.7) < 0.05)
        #expect(try alpha(undone, atX: 0.7, y: 0.7) > 0.9)   // 第二笔确实没了
        #expect(try alpha(undone, atX: 0.3, y: 0.3) < 0.05)  // 第一笔还在
    }

    /// 笔画连成线段（拖动是采样点序列，不能画成一串断点）。
    @Test func consecutivePointsFormAContinuousStroke() throws {
        let matted = try makeOpaquePNG()
        let stroke = MatteRetouch.Stroke(
            mode: .erase, radius: 0.05,
            points: [CGPoint(x: 0.2, y: 0.5), CGPoint(x: 0.8, y: 0.5)])
        let out = try #require(MatteRetouch.apply([stroke], to: matted, original: matted))
        // 两端之间的中点必须也被擦掉
        #expect(try alpha(out, atX: 0.5, y: 0.5) < 0.05)
    }

    /// 越界与畸形输入不得崩，也不得产出空图。
    @Test func degenerateInputIsSurvivable() throws {
        let matted = try makeOpaquePNG()
        let offCanvas = MatteRetouch.Stroke(
            mode: .erase, radius: 0.1, points: [CGPoint(x: 5, y: -3)])
        let zeroRadius = MatteRetouch.Stroke(
            mode: .erase, radius: 0, points: [CGPoint(x: 0.5, y: 0.5)])
        let empty = MatteRetouch.Stroke(mode: .erase, radius: 0.1, points: [])
        let out = try #require(MatteRetouch.apply(
            [offCanvas, zeroRadius, empty], to: matted, original: matted))
        #expect(try alpha(out, atX: 0.5, y: 0.5) > 0.9)   // 什么都没被擦掉
    }

    /// 坏数据返回 nil（不产出一张假图冒充修好了）。
    @Test func corruptInputYieldsNil() {
        let junk = Data([0, 1, 2, 3])
        let stroke = MatteRetouch.Stroke(
            mode: .erase, radius: 0.1, points: [CGPoint(x: 0.5, y: 0.5)])
        #expect(MatteRetouch.apply([stroke], to: junk, original: junk) == nil)
    }

    /// 原图缺失时**只能擦不能恢复**——恢复要有源可取，没有就得说清楚，不能静默无效。
    @Test func restoreRequiresAnOriginal() throws {
        let matted = try makeOpaquePNG()
        #expect(!MatteRetouch.canRestore(original: nil))
        #expect(MatteRetouch.canRestore(original: matted))
        #expect(MatteRetouch.restoreUnavailableMessage
            .localizedCaseInsensitiveContains("original"))
    }

    /// 尺寸不一致（原图与抠图结果分辨率不同）时按抠图结果的画布走，不拉伸变形。
    @Test func mismatchedSizesUseTheMatteCanvas() throws {
        let original = try makeOpaquePNG(200, 300)
        let matted = try makeTransparentPNG(100, 150)
        let stroke = MatteRetouch.Stroke(
            mode: .restore, radius: 0.3, points: [CGPoint(x: 0.5, y: 0.5)])
        let out = try #require(MatteRetouch.apply([stroke], to: matted, original: original))
        let size = try #require(ItemImageDerivatives.pixelSize(out))
        #expect(size.width == 100 && size.height == 150)
    }
}
