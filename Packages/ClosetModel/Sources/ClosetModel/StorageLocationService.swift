import Foundation
import SwiftData
import ClosetCore

/// 存放位置树（DESIGN §F3 / §2.2）。
public enum StorageLocationService {

    @discardableResult
    public static func create(
        name: String, in wardrobe: Wardrobe, parent: StorageLocation? = nil,
        context: ModelContext
    ) -> StorageLocation {
        let loc = StorageLocation(name: name)
        loc.wardrobe = wardrobe
        loc.parent = parent
        context.insert(loc)
        ModelSave.save(context, label: "locationCreate")
        return loc
    }

    public static func assign(_ item: Item, to location: StorageLocation?, in context: ModelContext) {
        // 位置必须同柜
        if let location, let lid = location.wardrobe?.id, let iid = item.wardrobe?.id, lid != iid {
            AppLog.error("location assign cross-wardrobe blocked", .data)
            return
        }
        item.location = location
        item.revision += 1
        ModelSave.save(context, label: "locationAssign")
    }

    /// 扁平列出某柜位置（深度优先）。
    public static func list(in wardrobe: Wardrobe) -> [StorageLocation] {
        let roots = (wardrobe.locations ?? []).filter { $0.parent == nil }
            .sorted { $0.name < $1.name }
        var out: [StorageLocation] = []
        func walk(_ loc: StorageLocation) {
            out.append(loc)
            for c in (loc.children ?? []).sorted(by: { $0.name < $1.name }) { walk(c) }
        }
        for r in roots { walk(r) }
        return out
    }
}
