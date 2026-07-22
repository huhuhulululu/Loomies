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
}
