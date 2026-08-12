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
        if siblingNameConflicts(trimmedName, in: wardrobe, parent: parent) {
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

    /// 同级重名判定（大小写/空白不敏感）。UI 提交前调用即可给出诚实的「重名」提示，
    /// 而不是把重名笼统报成「Couldn't add — try again」。
    /// ⚠️ 父层与根层必须显式分支：`parent?.children ?? 根层` 在 children 为 nil 时
    /// 会拿根层当兄弟，导致「父节点下新建与某根节点同名」被误报重名。
    public static func siblingNameConflicts(
        _ name: String, in wardrobe: Wardrobe, parent: StorageLocation?
    ) -> Bool {
        guard let key = TextNormalize.blankToNil(name)?.lowercased() else { return false }
        let siblings: [StorageLocation]
        if let parent {
            siblings = parent.children ?? []
        } else {
            siblings = (wardrobe.locations ?? []).filter { $0.parent == nil }
        }
        return siblings.contains { $0.name.lowercased() == key }
    }

    /// 客户可见的重名提示（与 `siblingNameConflicts` 同源）。
    public static let duplicateSiblingMessage = "A location with that name already exists here."

    /// 位置 + 树深度（UI 缩进展示用）。
    public struct Node: Identifiable {
        public let location: StorageLocation
        public let depth: Int
        public var id: UUID { location.id }
    }

    /// 深度优先展开（与 `list(in:)` 同序，附层级）。
    public static func listWithDepth(in wardrobe: Wardrobe) -> [Node] {
        // 同名按 id 决胜（与导出快照同约定）：Swift sort 不稳定
        let roots = (wardrobe.locations ?? []).filter { $0.parent == nil }
            .sorted { ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString) }
        var out: [Node] = []
        func walk(_ loc: StorageLocation, _ depth: Int) {
            out.append(Node(location: loc, depth: depth))
            for c in (loc.children ?? []).sorted(by: {
                ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString)
            }) { walk(c, depth + 1) }
        }
        for r in roots { walk(r, 0) }
        return out
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
