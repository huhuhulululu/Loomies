import Foundation
import ClosetCore

/// 单品本地图存储（Application Support/ItemImages）。
/// 路径记在 `Item.localImageRelativePath`；文件不入 SwiftData/CloudKit blob。
public enum ItemImageStore {
    public static let folderName = "ItemImages"

    /// Test hook: when enabled, `save` returns nil without writing (tests force
    /// the disk-failure path). Mirrors ModelSave.forceFailure.
    private static let forceFailureLock = NSLock()
    nonisolated(unsafe) private static var forceFailureEnabled = false

    /// Test hook: force all `save` calls to fail (returns nil, no write).
    static func forceFailure(_ enabled: Bool = true) {
        forceFailureLock.lock()
        forceFailureEnabled = enabled
        forceFailureLock.unlock()
    }

    /// 图片存储基目录（生产 = Application Support，行为不变）。
    /// 测试可设环境变量 ITEM_IMAGE_ROOT 重定向到按进程隔离的临时目录——
    /// 并行跑的多个测试进程共享真实真盘目录会互相看到/删到对方文件。
    /// rootDirectory 与 absoluteURL 必须共用同一基目录，否则存取路径分叉。
    /// Application Support 取不到（理论罕见）时**不退 tmp**——tmp 被系统按存储压力
    /// 任意清空，静默写进易失目录 = 全部单品图必然反向孤儿；诚实失败（save 返回
    /// nil → intake 显示重试文案）优于静默丢失。
    private static var baseDirectory: URL? {
        if let override = ProcessInfo.processInfo.environment["ITEM_IMAGE_ROOT"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    }

    /// nil = 基目录不可用（fail-closed；调用方按「目录空」处理）。
    public static var rootDirectory: URL? {
        guard let base = baseDirectory else { return nil }
        let dir = base.appendingPathComponent(folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 写入 PNG/JPEG 数据，返回相对路径（如 `ItemImages/{uuid}.jpg`）。
    @discardableResult
    public static func save(data: Data, for itemID: UUID, ext: String = "jpg") -> String? {
        forceFailureLock.lock()
        let forced = forceFailureEnabled
        forceFailureLock.unlock()
        if forced {
            AppLog.error("item image save forced failure (test hook)", .data)
            return nil
        }
        let name = "\(itemID.uuidString).\(ext)"
        guard let dir = rootDirectory else {
            AppLog.error("item image save failed: storage directory unavailable", .data)
            return nil
        }
        let url = dir.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            let rel = "\(folderName)/\(name)"
            AppLog.debug("item image saved bytes=\(data.count)", .data)
            return rel
        } catch {
            AppLog.error("item image save failed: \(AppLog.errRef(error))", .data)
            return nil
        }
    }

    public static func absoluteURL(relativePath: String?) -> URL? {
        guard let relativePath, !relativePath.isEmpty, let base = baseDirectory else { return nil }
        return base.appendingPathComponent(relativePath)
    }

    public static func loadData(relativePath: String?) -> Data? {
        guard let url = absoluteURL(relativePath: relativePath) else { return nil }
        return try? Data(contentsOf: url)
    }

    /// 存在性检查（stat，不读内容）：同槽择优等热路径用，别用 loadData 全量读。
    public static func fileExists(relativePath: String?) -> Bool {
        guard let url = absoluteURL(relativePath: relativePath) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    public static func delete(relativePath: String?) {
        guard let url = absoluteURL(relativePath: relativePath) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
