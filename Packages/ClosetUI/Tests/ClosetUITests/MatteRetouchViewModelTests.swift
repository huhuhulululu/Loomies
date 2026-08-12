import Testing
import Foundation
import CoreGraphics
@testable import ClosetUI
import ClosetModel
import ClosetCore

/// D96（缺口 #10）：手修编辑器的状态机。
/// 状态只有一串笔画——撤销、预览、提交全部由它推导，不维护像素级历史。
@MainActor
struct MatteRetouchViewModelTests {

    func makePNG(alpha: CGFloat) throws -> Data {
        let ctx = try #require(CGContext(
            data: nil, width: 60, height: 60, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.setFillColor(CGColor(red: 0.3, green: 0.6, blue: 0.5, alpha: alpha))
        ctx.fill(CGRect(x: 0, y: 0, width: 60, height: 60))
        let image = try #require(ctx.makeImage())
        return try #require(MatteRetouch.encodePNG(image))
    }

    /// 没画过 → 没有可提交的改动（不重写文件，避免每次打开都掉一点质量）。
    @Test func noStrokesMeansNothingToCommit() throws {
        let vm = MatteRetouchViewModel(matted: try makePNG(alpha: 1), original: nil)
        #expect(!vm.hasEdits)
        #expect(!vm.canUndo)
        #expect(vm.commit() == nil)
    }

    /// 拖动是「起笔 + 若干延伸」，合成**一笔**而不是一串独立笔。
    @Test func dragBecomesASingleStroke() throws {
        let vm = MatteRetouchViewModel(matted: try makePNG(alpha: 1), original: nil)
        vm.begin(at: CGPoint(x: 0.2, y: 0.5))
        vm.extend(to: CGPoint(x: 0.5, y: 0.5))
        vm.extend(to: CGPoint(x: 0.8, y: 0.5))
        #expect(vm.strokes.count == 1)
        #expect(vm.strokes[0].points.count == 3)
    }

    /// 撤销退掉整整一笔（不是一个采样点）。
    @Test func undoDropsAWholeStroke() throws {
        let vm = MatteRetouchViewModel(matted: try makePNG(alpha: 1), original: nil)
        vm.begin(at: CGPoint(x: 0.2, y: 0.2)); vm.extend(to: CGPoint(x: 0.3, y: 0.3))
        vm.begin(at: CGPoint(x: 0.7, y: 0.7))
        #expect(vm.strokes.count == 2)
        vm.undo()
        #expect(vm.strokes.count == 1)
        #expect(vm.strokes[0].points.count == 2)
        vm.undo()
        #expect(!vm.canUndo)
        #expect(vm.commit() == nil)
    }

    /// 没有原图时「找回」不可用——必须**说清楚**，不能让人点了没反应。
    @Test func restoreWithoutOriginalExplainsItself() throws {
        let vm = MatteRetouchViewModel(matted: try makePNG(alpha: 1), original: nil)
        #expect(!vm.canRestore)
        vm.mode = .restore
        vm.begin(at: CGPoint(x: 0.5, y: 0.5))
        #expect(vm.strokes.isEmpty)                      // 没有静默记一笔无效的
        #expect(vm.message == MatteRetouch.restoreUnavailableMessage)
    }

    /// 有原图时「找回」正常工作，且提交结果真的变了。
    @Test func restoreWorksWithAnOriginal() throws {
        let vm = MatteRetouchViewModel(
            matted: try makePNG(alpha: 0), original: try makePNG(alpha: 1))
        #expect(vm.canRestore)
        vm.mode = .restore
        vm.radius = 0.3
        vm.begin(at: CGPoint(x: 0.5, y: 0.5))
        let out = try #require(vm.commit())
        let a = try #require(MatteRetouch.alphaSample(out, normalizedX: 0.5, normalizedY: 0.5))
        #expect(a > 0.9)
    }

    /// 预览始终反映当前笔画（撤销后回到上一状态）。
    @Test func previewFollowsTheStrokeList() throws {
        let vm = MatteRetouchViewModel(matted: try makePNG(alpha: 1), original: nil)
        vm.radius = 0.3
        vm.begin(at: CGPoint(x: 0.5, y: 0.5))
        let erased = try #require(
            MatteRetouch.alphaSample(vm.preview, normalizedX: 0.5, normalizedY: 0.5))
        #expect(erased < 0.05)
        vm.undo()
        let restored = try #require(
            MatteRetouch.alphaSample(vm.preview, normalizedX: 0.5, normalizedY: 0.5))
        #expect(restored > 0.9)
    }

    /// 文案不得承诺 AI 修边（这是人手涂的）。
    @Test func copyMakesNoAutomationPromise() {
        let words = Set(MatteRetouchViewModel.hint.lowercased()
            .split(whereSeparator: { !$0.isLetter }).map(String.init))
        #expect(!words.contains("ai"))
        #expect(!words.contains("automatically"))
        #expect(MatteRetouchViewModel.hint.localizedCaseInsensitiveContains("erase"))
    }
}
