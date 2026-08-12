import Foundation
import SwiftData
import ClosetCore

/// 图片目录 ↔ DB 对账（启动期/进前台调用）：
/// - 孤儿文件（目录里无任何 Item 引用）→ 删文件——写图→落库之间的崩溃窗口、
///   Delete all 部分失败都会产生，且此前无任何回收机制；
/// - 死路径（行指向已消失的文件）→ 清 nil 落库——UI 回到诚实「无照片」态，
///   同槽择优/叠衣门禁立即恢复正确。
/// 文件名即 `{itemID}.{ext}`（ItemImageStore 约定），对账 O(n) 无需索引。
public enum ImageReconcileService {

    public struct Receipt: Sendable, Equatable {
        public var orphanFilesRemoved: Int
        public var deadPathsCleared: Int
    }

    /// - Parameter directory: 孤儿扫描目录（默认生产图根）。测试注入私有临时目录——
    ///   共享 per-process 根上并行套件互写文件，按共享根扫孤儿既不确定又会误删别家文件。
    @discardableResult
    public static func reconcile(
        in context: ModelContext,
        directory: URL? = ItemImageStore.rootDirectory
    ) -> Receipt {
        let items = (try? context.fetch(FetchDescriptor<Item>())) ?? []
        let originals = Set(items.compactMap(\.localImageRelativePath).filter { !$0.isEmpty })
        // 派生缩略图（D95）也算「被引用」——否则每次对账把它们当孤儿扫掉，
        // 下次滚动全部重算，并且回执里的孤儿数会虚高得离谱。
        var referenced = originals
        for rel in originals {
            for variant in ItemImageVariant.allCases {
                if let derived = ItemImageStore.derivedRelativePath(
                    relativePath: rel, variant: variant) {
                    referenced.insert(derived)
                }
            }
            // 用户原始照片旁挂档（D111）同属「被引用」
            if let src = ItemImageStore.sourcePhotoRelativePath(relativePath: rel) {
                referenced.insert(src)
            }
        }

        // 孤儿文件：目录扫描减去 DB 引用集（纯文件操作，无 DB 依赖）
        var orphansRemoved = 0
        let fm = FileManager.default
        if let dir = directory,
           let entries = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for url in entries {
                let rel = "\(ItemImageStore.folderName)/\(url.lastPathComponent)"
                guard !referenced.contains(rel) else { continue }
                if (try? fm.removeItem(at: url)) != nil { orphansRemoved += 1 }
            }
        }

        // 死路径：行在、文件没了 → 清 nil（单次 save；失败则内存还原 + rollback）
        var cleared: [(Item, String)] = []
        for item in items {
            guard let rel = item.localImageRelativePath, !rel.isEmpty,
                  !ItemImageStore.fileExists(relativePath: rel) else { continue }
            cleared.append((item, rel))
            item.localImageRelativePath = nil
        }
        if !cleared.isEmpty {
            guard ModelSave.save(context, label: "imageReconcile") else {
                for (item, rel) in cleared { item.localImageRelativePath = rel }
                context.rollback()   // 失败变更不得滞留，否则污染下一次无关 save
                AppLog.error("imageReconcile save failed", .data)
                return Receipt(orphanFilesRemoved: orphansRemoved, deadPathsCleared: 0)
            }
        }
        if orphansRemoved > 0 || !cleared.isEmpty {
            AppLog.notice(
                "imageReconcile orphans=\(orphansRemoved) deadPaths=\(cleared.count)", .data)
        }
        return Receipt(orphanFilesRemoved: orphansRemoved, deadPathsCleared: cleared.count)
    }
}
