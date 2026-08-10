import Foundation
import SwiftData
import ClosetCore

/// 存放位置树（DESIGN §F3 / §2.2）。
public enum StorageLocationService {

    /// Customer toast when ModelSave fails on Add location (no silent success).
    public static let createSaveFailedMessage = "Couldn't add location — try again"

    /// Customer toast when ModelSave fails on assign (no silent move).
    public static let assignSaveFailedMessage = "Couldn't update location — try again"

    /// Customer toast when ModelSave fails on swipe-delete (list must not silently drop).
    public static let removeSaveFailedMessage = "Couldn't remove location — try again"

    /// Creates a location. Returns `nil` when ModelSave fails (insert rolled back).
    @discardableResult
    public static func create(
        name: String, in wardrobe: Wardrobe, parent: StorageLocation? = nil,
        context: ModelContext
    ) -> StorageLocation? {
        // 空白名守卫下沉服务层（public API 不能只靠 View 层 .disabled gate）：
        // 空白节点在 Picker 里显示为空行，用户无法辨认单品存放位置。
        guard let trimmedName = TextNormalize.blankToNil(name) else {
            AppLog.error("location create blank name blocked", .data)
            return nil
        }
        // 父节点必须同柜（与 assign 同守卫）：跨柜父节点破坏同柜不变量，拒绝创建
        if let parent {
            guard parent.wardrobe?.id == wardrobe.id else {
                AppLog.error("location create cross-wardrobe parent blocked", .data)
                return nil
            }
        }
        // 同级重名拒绝（大小写不敏感）：同名兄弟在 Picker 里不可区分；跨 parent 同名合法。
        let siblings = parent?.children
            ?? (wardrobe.locations ?? []).filter { $0.parent == nil }
        if siblings.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            AppLog.error("location create duplicate sibling blocked", .data)
            return nil
        }
        let loc = StorageLocation(name: trimmedName)
        loc.wardrobe = wardrobe
        loc.parent = parent
        context.insert(loc)
        guard ModelSave.save(context, label: "locationCreate") else {
            // rollback 一并丢弃 pending insert（delete 只删行，脏标记会滞留）
            context.rollback()   // 失败变更不得滞留，否则污染下一次无关 save
            AppLog.error("locationCreate save failed", .data)
            return nil
        }
        return loc
    }

    /// Assigns item to location (same wardrobe only). Returns `false` when blocked or save fails.
    @discardableResult
    public static func assign(_ item: Item, to location: StorageLocation?, in context: ModelContext) -> Bool {
        // 位置必须同柜：任一侧衣柜归属缺失（nil）也阻断，不得静默放行
        if let location {
            guard let lid = location.wardrobe?.id, let iid = item.wardrobe?.id, lid == iid else {
                AppLog.error("location assign cross-wardrobe blocked", .data)
                return false
            }
        }
        let previous = item.location
        let previousRevision = item.revision
        item.location = location
        item.revision += 1
        guard ModelSave.save(context, label: "locationAssign") else {
            item.location = previous
            item.revision = previousRevision
            context.rollback()   // 失败变更不得滞留，否则污染下一次无关 save
            AppLog.error("locationAssign save failed item=\(AppLog.ref(item.id))", .data)
            return false
        }
        return true
    }

    /// 扁平列出某柜位置（深度优先）。
    public static func list(in wardrobe: Wardrobe) -> [StorageLocation] {
        // 同名按 id 决胜（与导出快照同约定）：Swift sort 不稳定，同名兄弟顺序不得随 fetch 漂移。
        let roots = (wardrobe.locations ?? []).filter { $0.parent == nil }
            .sorted { ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString) }
        var out: [StorageLocation] = []
        func walk(_ loc: StorageLocation) {
            out.append(loc)
            for c in (loc.children ?? []).sorted(by: {
                ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString)
            }) { walk(c) }
        }
        for r in roots { walk(r) }
        return out
    }
}
