import Testing
import Foundation
@testable import ClosetCore

/// D151：**边枚举边只留前 K，与「全物化再排序取前 K」必须给出同一个答案。**
///
/// 冷天 240 件衣柜要枚举 12×12×12×13 ≈ 2.2 万套，而此前每一套都被物化进结果数组
///（成员数组 + id 数组 + 一串理由），最后才排序取 3。实测该路径整整 **3 秒**，
/// 同步跑在主线程上——用户在冬天打开 Today，界面冻结三秒，
/// 而这个 App 冬天最该有用。
///
/// `ranksBefore` 是全序（分数带容差 → 近期穿着更少 → itemIDs 字典序），
/// 所以有界选择是安全的。**但这条等价性必须被钉住**：
/// 哪天有人给比较器加一个不构成全序的键，这里就该红。
struct BoundedSelectionTests {

    private func pool(seed: Int, perSlot: Int = 8) -> [CandidateItem] {
        var out: [CandidateItem] = []
        for (si, slot) in [GarmentSlot.top, .bottom, .shoes, .outerwear].enumerated() {
            for i in 0..<perSlot {
                out.append(CandidateItem(
                    id: "\(slot)-\(i)", slot: slot,
                    occasions: ["work"], warmth: .medium, status: .available,
                    color: GarmentColor(
                        hueDegrees: Double((i * 37 + si * 91 + seed * 13) % 360),
                        isNeutral: i % 5 == 0)))
            }
        }
        return out
    }

    /// 取前 3 == 取前 200 再截前 3（冷天，组合空间最大的那条路）。
    @Test func theTopKMatchesAFullRankingTruncated() {
        for seed in 0..<8 {
            let ctx = FilterContext(occasion: "work", daytimeTempF: 38)
            let scoring = ScoringContext()
            let bounded = OutfitCompleter.complete(
                anchors: [], pool: pool(seed: seed), context: ctx,
                scoring: scoring, maxSuggestions: 3)
            let full = OutfitCompleter.complete(
                anchors: [], pool: pool(seed: seed), context: ctx,
                scoring: scoring, maxSuggestions: 200)
            #expect(bounded.map(\.outfit.itemIDs) == full.prefix(3).map(\.outfit.itemIDs),
                    Comment(rawValue: "seed \(seed)：有界选择与全排序取前 3 不一致"))
        }
    }

    /// 暖天（无外套维度）同样成立。
    @Test func itAlsoHoldsOnAWarmDay() {
        let ctx = FilterContext(occasion: "work", daytimeTempF: 75)
        let scoring = ScoringContext()
        let bounded = OutfitCompleter.complete(
            anchors: [], pool: pool(seed: 3), context: ctx,
            scoring: scoring, maxSuggestions: 2)
        let full = OutfitCompleter.complete(
            anchors: [], pool: pool(seed: 3), context: ctx,
            scoring: scoring, maxSuggestions: 100)
        #expect(bounded.map(\.outfit.itemIDs) == full.prefix(2).map(\.outfit.itemIDs))
    }

    /// 有锚定时也成立（锚定件直接进结果，组合空间换了形状）。
    @Test func itHoldsWithAnchorsToo() {
        let p = pool(seed: 5)
        let anchor = p.first { $0.slot == .top }!
        let ctx = FilterContext(occasion: "work", daytimeTempF: 38)
        let scoring = ScoringContext()
        let bounded = OutfitCompleter.complete(
            anchors: [anchor], pool: p, context: ctx, scoring: scoring, maxSuggestions: 3)
        let full = OutfitCompleter.complete(
            anchors: [anchor], pool: p, context: ctx, scoring: scoring, maxSuggestions: 150)
        #expect(bounded.map(\.outfit.itemIDs) == full.prefix(3).map(\.outfit.itemIDs))
    }

    /// 结果不足 K 时照常给（不补空、不报错）。
    @Test func fewerThanKIsFine() {
        let tiny = [
            CandidateItem(id: "t", slot: .top, occasions: ["work"], warmth: .medium, status: .available),
            CandidateItem(id: "b", slot: .bottom, occasions: ["work"], warmth: .medium, status: .available),
            CandidateItem(id: "s", slot: .shoes, occasions: ["work"], warmth: .medium, status: .available),
        ]
        let out = OutfitCompleter.complete(
            anchors: [], pool: tiny,
            context: FilterContext(occasion: "work", daytimeTempF: 75),
            scoring: ScoringContext(), maxSuggestions: 3)
        #expect(out.count == 1)
    }
}
