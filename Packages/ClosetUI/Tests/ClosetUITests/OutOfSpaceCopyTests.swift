import Testing
import Foundation
@testable import ClosetUI

/// D141：**`FailureCopy.outOfSpace` 零生产调用点** —— 那一档写着
/// 「空间不足，重试无意义」，而全仓没有任何一处会产出它。
///
/// D128 建这套分类的理由白纸黑字写在文件头上：「磁盘满了重试一百次还是满的」。
/// 结果最该用上它的地方——把整柜照片打进一个 zip 的导出——照旧说
/// 「— try again」，用户在一部快满的手机上会一直点。
///
/// 判据不能靠猜：错误码就在手上（catch 里拿得到 `Error`），
/// `NSFileWriteOutOfSpaceError` / `ENOSPC` 说的就是这件事。
/// 认不出来的一律回落 `.transient`——**不猜**。宁可说「重试」，
/// 也不要让一个网络抖动的失败去叫用户删照片。
@MainActor
struct OutOfSpaceCopyTests {

    private let fallback = "Couldn't export"

    /// Cocoa 的写盘空间不足。
    @Test func cocoaOutOfSpaceIsRecognised() {
        let error = NSError(domain: NSCocoaErrorDomain, code: 640)   // NSFileWriteOutOfSpaceError
        #expect(FailureCopy.classify(error, fallback: fallback) == .outOfSpace)
    }

    /// POSIX 层的 ENOSPC（低层写入直接冒上来的那条路）。
    @Test func posixNoSpaceIsRecognised() {
        let error = NSError(domain: NSPOSIXErrorDomain, code: 28)    // ENOSPC
        #expect(FailureCopy.classify(error, fallback: fallback) == .outOfSpace)
    }

    /// 底层错误藏在 userInfo 里也要认（FileManager 常这么包）。
    @Test func anUnderlyingSpaceErrorStillCounts() {
        let inner = NSError(domain: NSPOSIXErrorDomain, code: 28)
        let outer = NSError(domain: NSCocoaErrorDomain, code: 512,
                            userInfo: [NSUnderlyingErrorKey: inner])
        #expect(FailureCopy.classify(outer, fallback: fallback) == .outOfSpace)
    }

    /// **认不出来就不猜。** 一个网络抖动的失败不该叫用户去删照片。
    @Test func anythingElseFallsBackToRetry() {
        let error = NSError(domain: "Whatever", code: 1)
        #expect(FailureCopy.classify(error, fallback: fallback) == .transient(fallback))
    }

    /// 空间不足的文案不得以「try again」收尾（那正是 D128 要消灭的）。
    @Test func theOutOfSpaceLineDoesNotEndInRetry() {
        let line = FailureCopy.line(.outOfSpace)
        #expect(line.localizedCaseInsensitiveContains("free"))
        #expect(!line.lowercased().hasSuffix("try again"),
                Comment(rawValue: line))
    }

    /// 接线门：导出（把整柜照片打进 zip——最可能撑爆磁盘的动作）
    /// 必须把手上的错误交给分类器，而不是一律 `.transient`。
    @Test func theExportPathClassifiesItsError() throws {
        let text = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Sources/ClosetUI/AppRootView.swift"),
            encoding: .utf8)
        #expect(text.contains("FailureCopy.classify("),
                "导出失败仍一律说「try again」—— 磁盘满的用户会一直点")
    }
}

/// D141：`ExportError.noCroquis` 的两句文案自相矛盾。
///
/// `toastMessage` 是 D128 改对的那句（「没有身形底图不是偶发，去 Me → Body 设一个」），
/// 而 `errorDescription` 原封不动还写着「Try again in a moment」——
/// **同一个错误，两处说法相反**。哪一句会到用户眼前取决于谁调了哪个属性，
/// 而那不是用户该承担的不确定性。
@MainActor
struct CinematicErrorCopyCoherenceTests {

    /// 不是偶发的错误，两处都不许说「再试一次」。
    @Test func theTwoCopiesAgreeOnWhetherRetryHelps() {
        let long = AvatarCinematicExporter.ExportError.noCroquis.errorDescription ?? ""
        let toast = AvatarCinematicExporter.ExportError.noCroquis.toastMessage
        #expect(!long.localizedCaseInsensitiveContains("try again"),
                Comment(rawValue: "长文案仍说「再试一次」，而短文案说要去设体型：\(long)"))
        #expect(toast.localizedCaseInsensitiveContains("body"))
        #expect(long.localizedCaseInsensitiveContains("body"),
                Comment(rawValue: "长文案没给出那条真能走通的路：\(long)"))
    }

    /// 缺件同理：照片不在了，重试不会把它变回来。
    @Test func missingPhotosDoNotPromiseRetry() {
        let long = AvatarCinematicExporter.ExportError.garmentsUnavailable.errorDescription ?? ""
        #expect(!long.localizedCaseInsensitiveContains("try again"), Comment(rawValue: long))
    }

    /// **不得替系统猜原因**：`writerFailed` 可能是任何原因，
    /// 而原文案一口咬定「腾点空间」——猜错时用户白删了照片。
    @Test func theWriterFailureDoesNotGuessTheCause() {
        let long = AvatarCinematicExporter.ExportError.writerFailed.errorDescription ?? ""
        let toast = AvatarCinematicExporter.ExportError.writerFailed.toastMessage
        #expect(!long.localizedCaseInsensitiveContains("free some storage"),
                Comment(rawValue: "把一个原因未知的失败说成磁盘满：\(long)"))
        #expect(!toast.localizedCaseInsensitiveContains("free storage"),
                Comment(rawValue: toast))
    }
}
