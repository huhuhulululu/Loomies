import Foundation

/// 一套搭配（值类型）。
public struct Outfit: Sendable, Equatable {
    public let items: [CandidateItem]

    /// 稳定标识：成员 id 排序后（供去重/排序/断言）。
    ///
    /// D149：此前是**计算属性**，每取一次就重新 map + sort + 分配。
    /// 而排序口径 `OutfitScorer.ranksBefore` 一次比较要取它四遍
    ///（两次数近期穿过的件、两次拼字典序字符串），去重路径每套再取一遍。
    /// 冷天无锚定时 `OutfitCompleter` 会枚举出成百上千套：
    /// 200 套 ≈ 1500 次比较 × 4 = 六千次分配 + 排序，全在 Today 刷新的主线程上。
    ///
    /// `items` 是 `let`——这个值构造完就不会变，构造时算一次即可。
    /// 语义一个字不变（`OutfitIdentityCostTests` 钉住与旧计算式逐字一致）。
    public let itemIDs: [String]

    public init(items: [CandidateItem]) {
        self.items = items
        self.itemIDs = items.map(\.id).sorted()
    }
}

/// 组套器：从已过滤候选池产出 grammar-valid 搭配（DESIGN §F4）。
/// 冷天（日间代表温度 < 60°F）且有外套则加层。确定性顺序，取前 maxOutfits。
/// 注：当前为 O(基底×shoes×outerwear) 朴素枚举，适配百件级衣橱；大池的 beam search 优化留 v1.x。
/// ⚠️ 生产路径已由 `OutfitCompleter`（锚定+补全+打分）取代，`assemble` 仅测试引用且
/// 截断不看分数（itemIDs 字典序前 N）；保留作 v0.9 参考实现，新代码勿用。
public enum OutfitAssembler {

    static let coldThresholdF = 60.0

    public static func assemble(pool: [CandidateItem], daytimeTempF: Double, maxOutfits: Int) -> [Outfit] {
        let byID: ([CandidateItem]) -> [CandidateItem] = { $0.sorted { $0.id < $1.id } }
        let tops = byID(pool.filter { $0.slot == .top })
        let bottoms = byID(pool.filter { $0.slot == .bottom })
        let dresses = byID(pool.filter { $0.slot == .dress })
        let shoes = byID(pool.filter { $0.slot == .shoes })
        let outerwear = byID(pool.filter { $0.slot == .outerwear })

        guard !shoes.isEmpty else { return [] }

        var bases: [[CandidateItem]] = dresses.map { [$0] }
        for t in tops { for b in bottoms { bases.append([t, b]) } }

        let addOuter = daytimeTempF < coldThresholdF && !outerwear.isEmpty

        var outfits: [Outfit] = []
        for base in bases {
            for s in shoes {
                var items = base
                items.append(s)
                if addOuter {
                    for coat in outerwear {
                        var withCoat = items
                        withCoat.append(coat)
                        if OutfitGrammar.isValid(withCoat) { outfits.append(Outfit(items: withCoat)) }
                    }
                } else if OutfitGrammar.isValid(items) {
                    outfits.append(Outfit(items: items))
                }
            }
        }
        outfits.sort { $0.itemIDs.joined(separator: ",") < $1.itemIDs.joined(separator: ",") }
        return Array(outfits.prefix(max(0, maxOutfits)))
    }
}
