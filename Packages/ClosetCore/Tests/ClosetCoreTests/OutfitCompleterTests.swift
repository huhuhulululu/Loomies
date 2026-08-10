import Testing
@testable import ClosetCore

struct OutfitCompleterTests {
    let ctx = FilterContext(occasion: "work", daytimeTempF: 75)
    let sctx = ScoringContext()

    func item(_ id: String, _ slot: GarmentSlot, occ: Set<String> = ["work"], warmth: Warmth? = .light,
              status: ItemStatus = .available, hue: Double = 0, neutral: Bool = true) -> CandidateItem {
        CandidateItem(id: id, slot: slot, occasions: occ, warmth: warmth, status: status,
                      color: GarmentColor(hueDegrees: hue, isNeutral: neutral))
    }

    @Test func anchorTopCompletesWithBottomAndShoes() {
        let anchor = item("myTop", .top)
        let pool = [item("b", .bottom), item("sh", .shoes)]
        let out = OutfitCompleter.complete(anchors: [anchor], pool: pool, context: ctx, scoring: sctx, maxSuggestions: 3)
        #expect(!out.isEmpty)
        for s in out {
            #expect(s.outfit.itemIDs.contains("myTop"))       // 锚定项必在
            #expect(OutfitGrammar.isValid(s.outfit.items))     // 合规
        }
        #expect(out[0].outfit.itemIDs == ["b", "myTop", "sh"])
    }

    /// 无锚定 full-auto：池内裙装与上下装两种骨架都要产出（组合枝拆分不得漏形态），
    /// 且不出现裙 + 上/下装的非法混搭。
    @Test func fullAutoYieldsBothDressAndSeparatesShapes() {
        let pool = [
            item("d", .dress), item("t", .top), item("b", .bottom), item("sh", .shoes),
        ]
        let out = OutfitCompleter.complete(
            anchors: [], pool: pool, context: ctx, scoring: sctx, maxSuggestions: 10)
        let idSets = out.map { Set($0.outfit.itemIDs) }
        #expect(idSets.contains(Set(["d", "sh"])))
        #expect(idSets.contains(Set(["t", "b", "sh"])))
        for s in out {
            #expect(OutfitGrammar.isValid(s.outfit.items))
        }
    }

    /// 端到端置换不变性：锚定集顺序（SwiftData 关系数组不保序）不得改变
    /// 建议列表的内容、顺序、分数与理由文案。
    @Test func suggestionsInvariantToAnchorOrder() {
        let anchors = [
            item("a-top", .top, hue: 0, neutral: false),
            item("a-outer", .outerwear, hue: 30, neutral: false),
        ]
        let pool = [
            item("b1", .bottom, hue: 60, neutral: false),
            item("b2", .bottom, hue: 120, neutral: false),
            item("sh", .shoes, hue: 180, neutral: false),
        ]
        let sctxShaped = ScoringContext(bodyShape: .hourglass)
        let forward = OutfitCompleter.complete(
            anchors: anchors, pool: pool, context: ctx, scoring: sctxShaped, maxSuggestions: 5)
        let backward = OutfitCompleter.complete(
            anchors: anchors.reversed(), pool: pool, context: ctx, scoring: sctxShaped, maxSuggestions: 5)
        #expect(forward.map(\.outfit.itemIDs) == backward.map(\.outfit.itemIDs))
        #expect(forward.map(\.score.value) == backward.map(\.score.value))
        #expect(forward.map(\.score.reasons) == backward.map(\.score.reasons))
    }

    @Test func anchorDressCompletesWithShoes() {
        let out = OutfitCompleter.complete(anchors: [item("d", .dress)], pool: [item("sh", .shoes)],
                                           context: ctx, scoring: sctx, maxSuggestions: 3)
        #expect(out.count == 1)
        #expect(out[0].outfit.itemIDs == ["d", "sh"])
    }

    @Test func excludesInWashFromCompletion() {
        let anchor = item("myTop", .top)
        let pool = [item("b", .bottom, status: .inWash), item("sh", .shoes)]
        // 唯一的 bottom 在洗 → 无法补全合规搭配
        let out = OutfitCompleter.complete(anchors: [anchor], pool: pool, context: ctx, scoring: sctx, maxSuggestions: 3)
        #expect(out.isEmpty)
    }

    @Test func excludesAnchorFromPoolDoubleUse() {
        // 锚定的 shoes 不应又被当作候选池里的 shoes 重复
        let anchorTop = item("myTop", .top)
        let anchorShoes = item("sh", .shoes)
        let pool = [item("b", .bottom), anchorShoes]
        let out = OutfitCompleter.complete(anchors: [anchorTop, anchorShoes], pool: pool, context: ctx, scoring: sctx, maxSuggestions: 3)
        #expect(!out.isEmpty)
        for s in out { #expect(OutfitGrammar.isValid(s.outfit.items)) }  // 不会出现两双鞋
    }

    @Test func sortedByScoreHarmoniousFirst() {
        // 锚定红色上装；候选下装：中性(协调) vs 撞色黄绿(冲突) → 中性排前
        let anchor = item("myTop", .top, hue: 0, neutral: false)
        let neutralBottom = item("bNeutral", .bottom, hue: 0, neutral: true)
        let clashBottom = item("bClash", .bottom, hue: 70, neutral: false)
        let shoes = item("sh", .shoes)
        let out = OutfitCompleter.complete(anchors: [anchor], pool: [neutralBottom, clashBottom, shoes],
                                           context: ctx, scoring: sctx, maxSuggestions: 5)
        #expect(out.count == 2)
        #expect(out[0].outfit.itemIDs.contains("bNeutral"))   // 协调的排第一
        #expect(out[0].score.value > out[1].score.value)
    }

    @Test func emptyWhenCannotComplete() {
        // 锚定上装，池里没下装也没鞋 → 补不出合规搭配
        let out = OutfitCompleter.complete(anchors: [item("myTop", .top)], pool: [item("b", .bottom)],
                                           context: ctx, scoring: sctx, maxSuggestions: 3)
        #expect(out.isEmpty)
    }

    @Test func respectsMaxSuggestions() {
        let anchor = item("myTop", .top)
        let pool = [item("b1", .bottom), item("b2", .bottom), item("b3", .bottom), item("sh", .shoes)]
        let out = OutfitCompleter.complete(anchors: [anchor], pool: pool, context: ctx, scoring: sctx, maxSuggestions: 2)
        #expect(out.count == 2)
    }

    /// 大池冒烟：每槽位候选封顶 maxOptionsPerSlot，结果数有界且只取 id 升序前 N，
    /// 不会全枚举 top×bottom×shoes×outer 爆炸。
    @Test func largePoolBoundedEnumeration() {
        let anchor = item("myTop", .top)
        let cap = OutfitCompleter.maxOptionsPerSlot
        // id 用 b100…b149 / s100…s149：字典序与数值序一致
        let bottoms = (0..<50).map { item("b\(100 + $0)", .bottom) }
        let shoes = (0..<50).map { item("s\(100 + $0)", .shoes) }
        let out = OutfitCompleter.complete(anchors: [anchor], pool: bottoms + shoes,
                                           context: ctx, scoring: sctx, maxSuggestions: 10_000)
        #expect(!out.isEmpty)
        #expect(out.count <= cap * cap)
        let allowed = Set((0..<cap).map { "b\(100 + $0)" } + (0..<cap).map { "s\(100 + $0)" } + ["myTop"])
        for s in out {
            #expect(Set(s.outfit.itemIDs).isSubset(of: allowed))   // 前 N 之外的候选不得出现
        }
    }

    @Test func anchorShoesCompletesWithPoolDress() {
        // 锚定鞋、池里只有连衣裙：dress+shoes 语法合法，应能补全（连衣裙曾被漏枚举）。
        let out = OutfitCompleter.complete(anchors: [item("sh", .shoes)], pool: [item("d", .dress)],
                                           context: ctx, scoring: sctx, maxSuggestions: 3)
        #expect(out.count == 1)
        #expect(out[0].outfit.itemIDs == ["d", "sh"])
        #expect(OutfitGrammar.isValid(out[0].outfit.items))
    }
}
