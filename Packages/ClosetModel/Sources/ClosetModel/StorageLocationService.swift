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
    /// 树深上限（§F3 语义 rail / drawer / bin 三层足够）。无上限时缩进会把深层
    /// 节点推出屏幕、Picker 标题被缩进吃光，且递归遍历对成环数据会栈溢出。
    public static let maxDepth = 3
    public static let depthLimitMessage =
        "Storage nests up to \(maxDepth) levels. Put this one a level up."

    /// 从根到该节点的层数（0 = 顶层）。成环数据下有硬上限，不会挂住。
    public static func depth(of location: StorageLocation?) -> Int {
        var n = 0
        var cur = location
        var seen = Set<UUID>()
        while let c = cur, seen.insert(c.id).inserted, n <= maxDepth + 2 {
            n += 1
            cur = c.parent
        }
        return n
    }

    /// 在该父节点下再建一层是否会超限。
    public static func depthLimitReached(parent: StorageLocation?) -> Bool {
        depth(of: parent) >= maxDepth
    }

    // MARK: - 删除前的后果告知

    public static let topLevelName = "Top level"

    /// 删除一个位置的后果快照（子位置与衣物会被提升到父级——此前完全静默）。
    public struct DeletePlan: Sendable, Equatable {
        public let name: String
        public let childCount: Int
        public let itemCount: Int
        public let destinationName: String
        /// 有东西会被搬动才需要确认；空叶子直接删，不吓唬用户。
        public var needsConfirmation: Bool { childCount > 0 || itemCount > 0 }
    }

    @MainActor
    public static func deletePlan(for location: StorageLocation) -> DeletePlan {
        DeletePlan(
            name: location.name,
            childCount: (location.children ?? []).count,
            itemCount: (location.items ?? []).count,
            destinationName: location.parent?.name ?? topLevelName)
    }

    public static func deleteWarning(_ plan: DeletePlan) -> String {
        var parts: [String] = []
        if plan.itemCount > 0 {
            parts.append("\(plan.itemCount) \(plan.itemCount == 1 ? "piece" : "pieces")")
        }
        if plan.childCount > 0 {
            parts.append("\(plan.childCount) \(plan.childCount == 1 ? "spot" : "spots")")
        }
        guard !parts.isEmpty else { return "Nothing is stored here." }
        return parts.joined(separator: " and ") + " move to \(plan.destinationName). "
            + "Nothing is deleted except this spot."
    }

    /// 同级去重命名：提升子节点时若与新兄弟撞名，追加后缀而不是让两行长得一模一样。
    /// 用户的数据不能凭空消失，但也不能变成分辨不出的两行。
    public static func deduplicatedSiblingName(
        _ name: String, in wardrobe: Wardrobe, parent: StorageLocation?,
        excluding: StorageLocation? = nil
    ) -> String {
        var candidate = name
        var suffix = 2
        while siblingNameConflicts(candidate, in: wardrobe, parent: parent, excluding: excluding) {
            candidate = "\(name) \(suffix)"
            suffix += 1
            if suffix > 50 { return "\(name) \(UUID().uuidString.prefix(4))" }
        }
        return candidate
    }

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
        // 深度上限：无限嵌套会把缩进推出屏幕，且遍历成本随层数增长
        if depthLimitReached(parent: parent) {
            AppLog.error("location create depth limit blocked", .data)
            return nil
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
            // D112：先断关系再 rollback。不断的话幻影位置留在 `wardrobe.locations` /
            // `parent.children` 里——`list()` 照列它，更伤人的是
            // **同名重试会被判重名拒绝**，用户被一个库里并不存在的位置挡住。
            loc.wardrobe = nil
            loc.parent = nil
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
        _ name: String, in wardrobe: Wardrobe, parent: StorageLocation?,
        excluding: StorageLocation? = nil
    ) -> Bool {
        guard let key = TextNormalize.blankToNil(name)?.lowercased() else { return false }
        let siblings: [StorageLocation]
        if let parent {
            siblings = parent.children ?? []
        } else {
            siblings = (wardrobe.locations ?? []).filter { $0.parent == nil }
        }
        return siblings.contains { $0.id != excluding?.id && $0.name.lowercased() == key }
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
        // 访问集合防成环：导入/外部写入的坏数据不得让递归栈溢出崩溃
        var seen = Set<UUID>()
        func walk(_ loc: StorageLocation, _ depth: Int) {
            guard seen.insert(loc.id).inserted else { return }
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
