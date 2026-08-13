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
        /// D120：色板条目 id（"navy"）。站在店里那一刻，用户脑子里的检索词是
        /// **颜色 + 品类**，不是名字——而这里此前只有文本/槽位/场合/状态。
        /// 匹配复用 `GarmentColorPalette.nearest(to:)`（同一套容差与中性/彩色分离），
        /// 不引入新字段（schema 单向门 D84）。
        public var colorPaletteID: String? = nil
        public init(text: String = "", slotRaw: String? = nil, occasion: String? = nil,
                    statusRaw: String? = nil, wardrobeID: UUID? = nil,
                    colorPaletteID: String? = nil) {
            self.text = text; self.slotRaw = slotRaw; self.occasion = occasion
            self.statusRaw = statusRaw; self.wardrobeID = wardrobeID
            self.colorPaletteID = colorPaletteID
        }
    }

    /// 在 context 内按条件筛 Item，按 name 升序。
    public static func searchItems(_ query: Query, in context: ModelContext) -> [Item] {
        let all = (try? context.fetch(FetchDescriptor<Item>())) ?? []
        // foldedKey：变音符号折叠（"sezane" 命中 "Sézane"）+ locale 无关大小写。
        let needle = TextNormalize.foldedKey(
            query.text.trimmingCharacters(in: .whitespacesAndNewlines))
        return all.filter { item in
            if let wid = query.wardrobeID, item.wardrobe?.id != wid { return false }
            if !matches(item, statusRaw: query.statusRaw, slotRaw: query.slotRaw) { return false }
            if let wanted = TextNormalize.blankToNil(query.colorPaletteID) {
                // 未标颜色的件**不算命中**：三值语义——未知就是未知，不替用户猜。
                guard let hue = item.colorHue,
                      let nearest = GarmentColorPalette.nearest(
                        to: GarmentColor(hueDegrees: hue, isNeutral: item.colorIsNeutral)),
                      nearest.id == wanted.lowercased()
                else { return false }
            }
            if let occ = query.occasion {
                let want = occ.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let has = item.occasionsRaw.contains {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == want
                }
                if !has { return false }
            }
            if !needle.isEmpty {
                let name = TextNormalize.foldedKey(item.name)
                let brand = TextNormalize.foldedKey(item.brand ?? "")
                if !name.contains(needle) && !brand.contains(needle) { return false }
            }
            return true
        }
        .sortedByName()
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


extension SearchService {
    /// 结果计数的用户读法（D120）。
    ///
    /// 「你已经有 4 件」——一个能直接读出来的数，而不是相似度分数：
    /// 那种数字用户既没法验证也没法用。
    public static func resultsHeadline(count: Int) -> String {
        count <= 0 ? "Nothing like that yet" : "You already have \(count)"
    }
}
