import Testing
import SwiftData
import Foundation
@testable import ClosetUI
import ClosetModel
import ClosetCore

/// D90（缺口 #15）：推荐卡显示存放位置（DESIGN §10.3「省一次跳转」）。
/// 用户决定「今天穿这套」之后，下一个动作是去把它们拿出来——
/// 此前得逐件点进详情页才知道在哪。
struct OutfitStorageHintTests {

    @Test func groupsPiecesByLocationInDeterministicOrder() {
        let hint = OutfitStorageHint.text(pairs: [
            (piece: "Jeans", location: "Rail A"),
            (piece: "Tee", location: "Rail A"),
            (piece: "Boots", location: "Bin 2"),
        ])
        // 位置按名排序，位置内单品按名排序——顺序不得随传入顺序漂移
        #expect(hint == "Bin 2: Boots · Rail A: Jeans, Tee")
    }

    /// 全在一个位置**且无漏网**时说一句就够；有没标位置的件时不得说 "All"
    /// （"All in Rail A · 1 not placed" 自相矛盾）。
    @Test func singleLocationReadsAsOneLine() {
        let hint = OutfitStorageHint.text(pairs: [
            (piece: "Tee", location: "Rail A"),
            (piece: "Jeans", location: "Rail A"),
        ])
        #expect(hint == "All in Rail A")
    }

    /// 没有任何一件有位置 → nil（不显示空行，也不编一个「Unknown」出来）。
    @Test func noLocationsYieldsNothing() {
        #expect(OutfitStorageHint.text(pairs: []) == nil)
        #expect(OutfitStorageHint.text(pairs: [(piece: "Tee", location: nil)]) == nil)
    }

    /// 部分有位置：只说知道的那些，并**如实**说明还有几件没标位置——
    /// 不得让用户以为列出的就是全部。
    @Test func partialLocationsSayHowManyAreUnplaced() {
        let hint = OutfitStorageHint.text(pairs: [
            (piece: "Tee", location: "Rail A"),
            (piece: "Jeans", location: nil),
            (piece: "Boots", location: nil),
        ])
        let text = try! #require(hint)
        #expect(text.contains("Rail A"))
        #expect(text.contains("Tee"))
        #expect(!text.localizedCaseInsensitiveContains("all in"))
        #expect(text.localizedCaseInsensitiveContains("2 not placed"))
    }

    /// 空白位置名按「没标位置」处理（不显示空冒号）。
    @Test func blankLocationNamesCountAsUnplaced() {
        #expect(OutfitStorageHint.text(pairs: [(piece: "Tee", location: "   ")]) == nil)
    }

    /// 从真实模型取值：只算这套里的件，且尊重跨柜边界。
    @Test @MainActor func resolvesFromWardrobeItems() throws {
        let ctx = try ModelContext(ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let rail = try #require(StorageLocationService.create(
            name: "Rail A", in: w, context: ctx))
        let tee = Item(name: "Tee"); tee.slotRaw = "top"; tee.wardrobe = w
        tee.location = rail; ctx.insert(tee)
        let jeans = Item(name: "Jeans"); jeans.slotRaw = "bottom"; jeans.wardrobe = w
        ctx.insert(jeans)
        let unrelated = Item(name: "Coat"); unrelated.slotRaw = "outerwear"
        unrelated.wardrobe = w; unrelated.location = rail; ctx.insert(unrelated)
        try ctx.save()

        let hint = OutfitStorageHint.text(
            forItemIDs: [tee.id.uuidString, jeans.id.uuidString],
            in: (w.items ?? []))
        let text = try #require(hint)
        #expect(text.contains("Rail A"))
        #expect(text.contains("Tee"))
        #expect(!text.contains("Coat"))          // 不在这套里
        #expect(text.localizedCaseInsensitiveContains("1 not placed"))
    }
}
