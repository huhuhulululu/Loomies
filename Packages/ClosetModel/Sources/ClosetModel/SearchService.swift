import Foundation
import SwiftData
import ClosetCore

/// 全局查找（DESIGN §F3 / §2.3：搭配不跨柜，检索要跨柜）。
/// v1.0 = 属性/标签检索；语义检索随 embedding 层（v1.x）。
public enum SearchService {

    public struct Query: Equatable, Sendable {
        public var text: String = ""           // 匹配 name / brand（不区分大小写子串）
        public var slotRaw: String? = nil
        public var occasion: String? = nil
        public var statusRaw: String? = nil
        public var wardrobeID: UUID? = nil      // nil = 跨全部衣柜
        public init(text: String = "", slotRaw: String? = nil, occasion: String? = nil,
                    statusRaw: String? = nil, wardrobeID: UUID? = nil) {
            self.text = text; self.slotRaw = slotRaw; self.occasion = occasion
            self.statusRaw = statusRaw; self.wardrobeID = wardrobeID
        }
    }

    /// 在 context 内按条件筛 Item，按 name 升序。
    public static func searchItems(_ query: Query, in context: ModelContext) -> [Item] {
        let all = (try? context.fetch(FetchDescriptor<Item>())) ?? []
        let needle = query.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return all.filter { item in
            if let wid = query.wardrobeID, item.wardrobe?.id != wid { return false }
            if !matches(item, statusRaw: query.statusRaw, slotRaw: query.slotRaw) { return false }
            if let occ = query.occasion {
                let want = occ.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let has = item.occasionsRaw.contains {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == want
                }
                if !has { return false }
            }
            if !needle.isEmpty {
                let name = item.name.lowercased()
                let brand = (item.brand ?? "").lowercased()
                if !name.contains(needle) && !brand.contains(needle) { return false }
            }
            return true
        }
        .sorted { ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString) }
    }

    /// Closet browse / search facet: status + type via `GarmentSlot.resolved` (displaySlot truth).
    /// `statusRaw` / `slotRaw` nil = no facet. Dirty blazer-as-top matches outerwear.
    public static func matches(
        _ item: Item,
        statusRaw: String? = nil,
        slotRaw: String? = nil
    ) -> Bool {
        if let status = statusRaw, status != "all", item.statusRaw != status { return false }
        if let slot = slotRaw {
            let want = GarmentSlot.resolved(slot)
            let have = GarmentSlot.resolved(item.slotRaw, name: item.name)
            if have != want { return false }
        }
        return true
    }

    /// In-memory Closet grid filter (status + type chips). Preserves input order.
    public static func filterItems(
        _ items: [Item],
        statusRaw: String? = nil,
        slotRaw: String? = nil
    ) -> [Item] {
        items.filter { matches($0, statusRaw: statusRaw, slotRaw: slotRaw) }
    }
}
