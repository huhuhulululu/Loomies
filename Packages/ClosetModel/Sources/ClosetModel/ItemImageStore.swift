import Foundation
import ClosetCore

/// 单品本地图存储（Application Support/ItemImages）。
/// 路径记在 `Item.localImageRelativePath`；文件不入 SwiftData/CloudKit blob。
public enum ItemImageStore {
    public static let folderName = "ItemImages"

    /// 测试钩子：作用域内 `save` 直接返回 nil（不写盘），用来走磁盘失败那条路。
    ///
    /// D158：此前是**进程级** `static var`——五个测试文件跨两个包在用它，
    /// 而 `@Suite(.serialized)` 只保证套件**内**串行，套件之间照样并行：
    /// A 把开关拨开的那几毫秒里 B 正在存图，B 的写入就无缘无故失败了。
    /// 这是 D143（堆地址注册表）、D154（全局调试开关）之后同一族的第三个。
    ///
    /// `@TaskLocal` 按**调用任务**作用域，而每个测试各跑在自己的任务里——
    /// 天然不串味，也不需要锁和「记得还原」的纪律。
    /// 用法：`ItemImageStore.$forcedSaveFailure.withValue(true) { … }`
    @TaskLocal public static var forcedSaveFailure = false

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
        // task-local 天生按任务隔离，不需要锁（D158）
        if forcedSaveFailure {
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

    // MARK: - 用户原始照片旁挂档（D111）

    /// 用户加的那张照片，与层图同目录同 stem：`ItemImages/<stem>@source.jpg`。
    ///
    /// 此前入库只落**归一后的叠衣层**（紧 bbox 裁剪 + 512×768 画布 + 重编码），
    /// 用户拍的原图仅存在于 `IntakeViewModel.originalImage` 内存里，确认即清空——
    /// 而相机路径根本不写相册，所以那张照片被**永久丢弃**。
    /// 导出文案却承诺「your original photos」，兑现不了。
    ///
    /// 存的是压过的副本（长边 ≤2048），因此对外一律称「the photo you added」，
    /// 不称 original——文案不得比实物说得大。
    public static func sourcePhotoRelativePath(relativePath: String?) -> String? {
        guard let relativePath, !relativePath.isEmpty else { return nil }
        var components = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard let last = components.popLast(), !last.isEmpty else { return nil }
        let stem = last.contains(".")
            ? String(last[last.startIndex..<last.lastIndex(of: ".")!])
            : String(last)
        let name = "\(stem)\(sourcePhotoSuffix).jpg"
        return components.isEmpty ? name : (components.joined(separator: "/") + "/" + name)
    }

    public static let sourcePhotoSuffix = "@source"

    /// 长边上限：全分辨率相机原图 2-4MB × 百件 = 几百 MB，代价与用途不成比例。
    /// 2048 足够重新抠图与外部查看。
    public static let sourcePhotoMaxPixel = 2048

    /// 落旁挂档。解不出来的数据返回 nil——不落一个读不出的假文件冒充照片。
    @discardableResult
    public static func saveSourcePhoto(_ data: Data, layerRelativePath: String) -> String? {
        guard let rel = sourcePhotoRelativePath(relativePath: layerRelativePath),
              let url = absoluteURL(relativePath: rel),
              let scaled = ItemImageDerivatives.downscaledJPEG(
                data, maxPixel: sourcePhotoMaxPixel, quality: 0.85)
        else { return nil }
        do {
            try scaled.write(to: url, options: .atomic)
            return rel
        } catch {
            AppLog.error("source photo save failed: \(AppLog.errRef(error))", .data)
            return nil
        }
    }

    public static func sourcePhotoExists(relativePath: String?) -> Bool {
        fileExists(relativePath: sourcePhotoRelativePath(relativePath: relativePath))
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
        // 旁挂原图同批删——否则用户「删了这件」之后照片还留在盘上（删除权没兑现）
        delete(relativePath: sourcePhotoRelativePath(relativePath: relativePath))
    }
}
