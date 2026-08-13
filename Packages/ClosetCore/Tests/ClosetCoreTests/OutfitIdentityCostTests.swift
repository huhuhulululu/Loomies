import Testing
import Foundation
@testable import ClosetCore

/// D149：**`Outfit.itemIDs` 是计算属性，每取一次就重新 map + sort + 分配。**
///
/// 而排序口径 `OutfitScorer.ranksBefore` 一次比较要取它**四遍**
///（两次数近期穿过的件、两次拼字典序字符串），去重路径 `seen.insert(outfit.itemIDs)`
/// 每套再取一遍。`OutfitCompleter` 在冷天无锚定时会枚举出成百上千套：
/// 200 套 ≈ 1500 次比较 × 4 = 六千次「分配数组 + 排序 + 拼字符串」，
/// 全发生在 Today 刷新的主线程上。
///
/// `items` 是 `let`——这个值构造完就不会变，那就构造时算一次。
/// 一处改动修掉每一个调用点，且**语义一个字不变**（下面钉住）。
struct OutfitIdentityCostTests {

    private func item(_ id: String, _ slot: GarmentSlot) -> CandidateItem {
        CandidateItem(id: id, slot: slot, occasions: [], warmth: .light, status: .available)
    }

    /// 语义不变：仍是「成员 id 排序后」，与旧的计算式逐字一致。
    @Test func theIdentityMatchesTheOldComputation() {
        let items = [item("zulu", .top), item("alpha", .bottom), item("mike", .shoes)]
        let outfit = Outfit(items: items)
        #expect(outfit.itemIDs == items.map(\.id).sorted())
        #expect(outfit.itemIDs == ["alpha", "mike", "zulu"])
    }

    /// 取两次得到同一个值（缓存不得与源漂移）。
    @Test func repeatedReadsAgree() {
        let outfit = Outfit(items: [item("b", .top), item("a", .shoes)])
        #expect(outfit.itemIDs == outfit.itemIDs)
    }

    /// **每次访问不得重新分配**——这正是这一波要修的东西。
    /// 判据：连续两次读到的是**同一块存储**（值语义下 `[String]` 的 buffer
    /// 只有在没被重算时才会共享）。计算属性每次都会造一个新数组。
    @Test func readingItDoesNotAllocateAgain() {
        let outfit = Outfit(items: [item("b", .top), item("a", .shoes)])
        var first = outfit.itemIDs
        var second = outfit.itemIDs
        let sameBuffer = first.withUnsafeBufferPointer { fp in
            second.withUnsafeBufferPointer { sp in fp.baseAddress == sp.baseAddress }
        }
        #expect(sameBuffer, "itemIDs 每次访问都在重新分配 —— 排序热路径上每比较一次要付四遍")
    }

    /// 空搭配不炸。
    @Test func anEmptyOutfitHasNoIdentity() {
        #expect(Outfit(items: []).itemIDs.isEmpty)
    }

    /// 相等性仍按成员判（缓存不得改变 `Equatable` 的语义）。
    @Test func equalityIsUnchanged() {
        let a = Outfit(items: [item("x", .top), item("y", .shoes)])
        let b = Outfit(items: [item("x", .top), item("y", .shoes)])
        let c = Outfit(items: [item("x", .top)])
        #expect(a == b)
        #expect(a != c)
    }

    /// 排序结果与改动前一致——这是替换的前提（同 D148 的做法）。
    @Test func rankingIsUnchanged() {
        func scored(_ ids: [String], _ value: Double) -> ScoredOutfit {
            ScoredOutfit(
                outfit: Outfit(items: ids.enumerated().map {
                    item($1, $0 == 0 ? .top : ($0 == 1 ? .bottom : .shoes))
                }),
                score: OutfitScore(value: value, reasons: []))
        }
        let a = scored(["m", "b", "z"], 1.0)
        let b = scored(["a", "c", "y"], 1.0)     // 同分 → 落到 itemIDs 字典序
        #expect(OutfitScorer.ranksBefore(b, a, recentlyWornIDs: []))
        #expect(!OutfitScorer.ranksBefore(a, b, recentlyWornIDs: []))
    }
}
