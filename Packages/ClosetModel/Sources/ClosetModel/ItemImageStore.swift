import Foundation
import ClosetCore

/// 单品本地图存储（Application Support/ItemImages）。
/// 路径记在 `Item.localImageRelativePath`；文件不入 SwiftData/CloudKit blob。
public enum ItemImageStore {
    public static let folderName = "ItemImages"

    public static var rootDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent(folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 写入 PNG/JPEG 数据，返回相对路径（如 `ItemImages/{uuid}.jpg`）。
    @discardableResult
    public static func save(data: Data, for itemID: UUID, ext: String = "jpg") -> String? {
        let name = "\(itemID.uuidString).\(ext)"
        let url = rootDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            let rel = "\(folderName)/\(name)"
            AppLog.info("item image saved \(rel) bytes=\(data.count)", .data)
            return rel
        } catch {
            AppLog.error("item image save failed: \(error)", .data)
            return nil
        }
    }

    public static func absoluteURL(relativePath: String?) -> URL? {
        guard let relativePath, !relativePath.isEmpty else { return nil }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(relativePath)
    }

    public static func loadData(relativePath: String?) -> Data? {
        guard let url = absoluteURL(relativePath: relativePath) else { return nil }
        return try? Data(contentsOf: url)
    }

    public static func delete(relativePath: String?) {
        guard let url = absoluteURL(relativePath: relativePath) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
