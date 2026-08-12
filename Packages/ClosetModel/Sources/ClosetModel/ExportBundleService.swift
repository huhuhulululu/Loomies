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

    public static let bundleReadyMessage = "Export ready — JSON plus your item photos."
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
        }
        // 归档内顺序确定（导出可复现）
        photos.sort { $0.archiveName < $1.archiveName }
        return Plan(json: json, photos: photos)
    }

    /// nonisolated：staging 拷贝 + 压缩全在调用方的执行上下文（UI 侧应放 Task.detached）。
    /// 成功后 staging 目录删除，`directory` 里只留下 zip。
    public static func writeBundle(_ plan: Plan, in directory: URL) throws -> URL {
        let fm = FileManager.default
        let stem = "loomies-export"
        let staging = directory.appendingPathComponent(stem, isDirectory: true)
        try? fm.removeItem(at: staging)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: staging) }

        try Data(plan.json.utf8).write(
            to: staging.appendingPathComponent(archiveJSONName), options: .atomic)

        if !plan.photos.isEmpty {
            let photosDir = staging.appendingPathComponent(archivePhotosFolder, isDirectory: true)
            try fm.createDirectory(at: photosDir, withIntermediateDirectories: true)
            for photo in plan.photos {
                let dest = photosDir.appendingPathComponent(photo.archiveName)
                // 单张失败不炸整包（源文件可能刚被删）——诚实地少一张，胜过整个导出失败
                try? fm.copyItem(at: URL(fileURLWithPath: photo.sourcePath), to: dest)
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
        return destination
    }
}
