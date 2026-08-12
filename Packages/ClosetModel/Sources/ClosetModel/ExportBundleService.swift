import Foundation
import SwiftData
import ClosetCore

/// 数据可携带性导出包（D87，§10.6 spec = JSON 全实体 + 原图 ZIP）。
///
/// 此前只出 JSON，而 JSON 里的 `localImageRelativePath` 是指向沙箱的死路径——
/// 用户拿到一串打不开的路径，等于没给照片。
///
/// 两段式：`plan` 在 MainActor 上读 SwiftData（快，只取 JSON + 路径清单），
/// `writeBundle` **nonisolated**——几百张图的拷贝与压缩在主线程会冻结 UI 数秒到数分钟
/// （`AvatarCinematicExporter` 已有同类判例）。
public enum ExportBundleService {

    public static let archiveJSONName = "data.json"
    public static let archivePhotosFolder = "photos"
    /// 归档根目录名。NSFileCoordinator 的 .forUploading 压的是**目录本身**，
    /// 所以条目形如 `loomies-export/data.json`——注释此前声称没有这一层。
    public static let archiveRootName = "loomies-export"

    public static let bundleReadyMessage = "Export ready — JSON plus your item photos."
    /// 按**实际装进去**的照片数说话。单张复制失败被 try? 吞掉是合理的弹性，
    /// 但据此仍无条件说「plus your item photos」就是部分失败被完全静音。
    public static func readyMessage(copied: Int, planned: Int) -> String {
        if planned == 0 { return "Export ready — your closet data as JSON." }
        if copied == planned {
            return "Export ready — JSON plus \(copied) \(copied == 1 ? "photo" : "photos")."
        }
        if copied == 0 {
            return "Export ready — JSON only. Your "
                + "\(planned) \(planned == 1 ? "photo" : "photos") couldn't be read."
        }
        return "Export ready — JSON plus \(copied) of \(planned) photos. "
            + "The rest couldn't be read."
    }
    /// 分享面板未接管载荷的平台（非 iOS）：不得声称已就绪。
    public static let bundleNoHandoffMessage =
        "Export built, but this platform has no share sheet to hand it to."
    public static let bundleFailedMessage = "Couldn't build the export — try again"
    /// 进行中文案（按钮禁用期间显示；不得让用户以为卡死）。
    public static let bundleInProgressMessage = "Packing your export…"

    public struct PhotoEntry: Sendable, Equatable {
        /// 源文件绝对路径（plan 时已确认存在）。
        public let sourcePath: String
        /// 归档内文件名（`photos/<itemID>.<ext>`）。
        public let archiveName: String
    }

    public struct Plan: Sendable {
        public let json: String
        public let photos: [PhotoEntry]
    }

    /// MainActor：读 SwiftData，产出可脱离 context 的值类型计划。
    /// 反向孤儿（行指向已消失文件）静默跳过——不得让整个导出失败。
    @MainActor
    public static func plan(
        in context: ModelContext, includeBodyDimensions: Bool
    ) throws -> Plan {
        let json = try DataLifecycleService.exportJSONString(
            in: context, includeBodyDimensions: includeBodyDimensions)
        let items = (try? context.fetch(FetchDescriptor<Item>())) ?? []
        var photos: [PhotoEntry] = []
        for item in items {
            guard let rel = TextNormalize.blankToNil(item.localImageRelativePath),
                  ItemImageStore.fileExists(relativePath: rel),
                  let url = ItemImageStore.absoluteURL(relativePath: rel) else { continue }
            let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
            photos.append(PhotoEntry(
                sourcePath: url.path,
                archiveName: "\(item.id.uuidString).\(ext)"))
            // 用户加的那张照片（D111）：层图是归一裁剪过的，带不走原样。
            // 存量件没有旁挂档 —— 跳过即可，不虚报。
            if let srcRel = ItemImageStore.sourcePhotoRelativePath(relativePath: rel),
               ItemImageStore.fileExists(relativePath: srcRel),
               let srcURL = ItemImageStore.absoluteURL(relativePath: srcRel) {
                photos.append(PhotoEntry(
                    sourcePath: srcURL.path,
                    archiveName: "\(item.id.uuidString)@source.jpg"))
            }
        }
        // 归档内顺序确定（导出可复现）
        photos.sort { $0.archiveName < $1.archiveName }
        return Plan(json: json, photos: photos)
    }

    /// 写入结果：zip 位置 + **实际**复制成功的照片数（文案据此说话，不据计划说话）。
    public struct WriteResult: Sendable, Equatable {
        public let url: URL
        public let copiedPhotos: Int
        public let plannedPhotos: Int
    }

    /// nonisolated：staging 拷贝 + 压缩全在调用方的执行上下文（UI 侧应放 Task.detached）。
    /// 成功后 staging 目录删除，`directory` 里只留下 zip。
    @discardableResult
    public static func writeBundle(_ plan: Plan, in directory: URL) throws -> WriteResult {
        let fm = FileManager.default
        let stem = archiveRootName
        let staging = directory.appendingPathComponent(stem, isDirectory: true)
        try? fm.removeItem(at: staging)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: staging) }

        try Data(plan.json.utf8).write(
            to: staging.appendingPathComponent(archiveJSONName), options: .atomic)

        var copied = 0
        if !plan.photos.isEmpty {
            let photosDir = staging.appendingPathComponent(archivePhotosFolder, isDirectory: true)
            try fm.createDirectory(at: photosDir, withIntermediateDirectories: true)
            for photo in plan.photos {
                let dest = photosDir.appendingPathComponent(photo.archiveName)
                // 单张失败不炸整包（源文件可能刚被删）——诚实地少一张，胜过整个导出失败；
                // 但少了几张必须记账，文案不得照旧宣称「plus your item photos」。
                do {
                    try fm.copyItem(at: URL(fileURLWithPath: photo.sourcePath), to: dest)
                    copied += 1
                } catch {
                    AppLog.notice("export photo skipped (source vanished)", .data)
                }
            }
        }

        // Foundation-only 压缩：NSFileCoordinator .forUploading 对目录产出 zip
        let destination = directory.appendingPathComponent("\(stem).zip")
        try? fm.removeItem(at: destination)
        var coordinatorError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(
            readingItemAt: staging, options: [.forUploading], error: &coordinatorError
        ) { zippedURL in
            do { try fm.copyItem(at: zippedURL, to: destination) }
            catch { copyError = error }
        }
        if let coordinatorError { throw coordinatorError }
        if let copyError { throw copyError }
        return WriteResult(
            url: destination, copiedPhotos: copied, plannedPhotos: plan.photos.count)
    }

    /// 回收遗留的 `export-*` 临时目录（写入抛错 / 分享前被杀 / 面板只删了 zip）。
    /// 与 `AvatarCinematicExporter.sweepTemporaryExports` 同纪律：目录名前缀匹配，
    /// 不碰无关文件；`directory` 可注入，避免并行测试互扫。
    public static func sweepTemporaryExports(in directory: URL? = nil) {
        let fm = FileManager.default
        let root = directory ?? fm.temporaryDirectory
        guard let entries = try? fm.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil) else { return }
        for url in entries where url.lastPathComponent.hasPrefix(temporaryDirectoryPrefix) {
            try? fm.removeItem(at: url)
        }
    }

    /// 导出临时目录前缀（UI 建目录与 sweep 必须同源，不得各写各的字面量）。
    public static let temporaryDirectoryPrefix = "export-"
}
