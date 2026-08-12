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

    /// iCloud 备份策略裁决（D90，缺口 #19）。**不排除备份。**
    ///
    /// 两难：排除 → 换机后整柜照片全丢，用户得把衣橱重拍一遍；不排除 → 照片进备份。
    /// 取不排除：隐私承诺是「我们没有你的副本、不运营账号」，这条不受影响——
    /// iCloud 备份是**用户自己的**加密备份，不是把数据交给我们或第三方。
    /// 代价是必须如实告知（`backupDisclosure`，已进 FAQ 与隐私政策）。
    ///
    /// 身体维度不在此列：独立本地 store + D5 明令不同步（另有 schema 门守着）。
    public static let excludesFromBackup = false

    public static let backupDisclosure =
        "Your item photos are stored on this device and are included in your device "
        + "backup, so a new phone can restore them. We never receive a copy."

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

    // MARK: - 派生缩略图（D95，缺口 #11）

    /// 派生文件的相对路径：`ItemImages/<stem>@grid.jpg`（与原图同目录）。
    public static func derivedRelativePath(
        relativePath: String?, variant: ItemImageVariant
    ) -> String? {
        guard let relativePath, !relativePath.isEmpty else { return nil }
        // 纯字符串处理：`URL(fileURLWithPath:)` 会把相对路径按 cwd 解析成**绝对**路径，
        // 拼回 base 就成了错的位置（本波实测踩到）。
        var components = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard let last = components.popLast(), !last.isEmpty else { return nil }
        let stem = last.contains(".")
            ? String(last[last.startIndex..<last.lastIndex(of: ".")!])
            : String(last)
        // 派生一律 jpg（源可能是 png 层图；网格不需要透明通道）
        let name = "\(stem)\(variant.suffix).jpg"
        return components.isEmpty ? name : (components.joined(separator: "/") + "/" + name)
    }

    public static func derivedFileExists(
        relativePath: String?, variant: ItemImageVariant
    ) -> Bool {
        fileExists(relativePath: derivedRelativePath(
            relativePath: relativePath, variant: variant))
    }

    /// 派生数据：**已生成则直接读盘**，没有才从原图生成并落盘复用——
    /// 滚动时每帧重算缩放正是百件网格卡顿的来源。
    /// 原图缺失或损坏 → nil（不造占位图冒充）。
    public static func derivedData(
        relativePath: String?, variant: ItemImageVariant
    ) -> Data? {
        guard let derivedRel = derivedRelativePath(
            relativePath: relativePath, variant: variant) else { return nil }
        if let cached = loadData(relativePath: derivedRel) { return cached }
        guard let original = loadData(relativePath: relativePath),
              let scaled = ItemImageDerivatives.downscaledJPEG(
                original, maxPixel: variant.maxPixel)
        else { return nil }
        if let url = absoluteURL(relativePath: derivedRel) {
            try? scaled.write(to: url, options: .atomic)
        }
        return scaled
    }

    /// 删原图**连同全部派生**——否则派生成了删不掉的孤儿，占着磁盘。
    public static func deleteAll(relativePath: String?) {
        delete(relativePath: relativePath)
        for variant in ItemImageVariant.allCases {
            delete(relativePath: derivedRelativePath(
                relativePath: relativePath, variant: variant))
        }
    }
}
