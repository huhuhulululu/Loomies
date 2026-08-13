import Testing
import Foundation
@testable import ClosetCore

/// D130：**「不许两件同型外套」的规则在真实数据上是死的**。
///
/// `OutfitGrammar` 会按 `subtype` 拒绝「一套里两件 blazer」，而
/// `Item.subtype` **生产里没有任何写入方**——入库不写、编辑器不写，
/// 只有导入会写（而导出源本身也从没设过）。规则写了、测了，永远不触发。
///
/// 处置不是删规则（它编码的是真实的穿搭常识），而是给它一个**真实的来源**：
/// 按名字判型——这正是 `GarmentSlot.resolved` 已经在用的手法，
/// 数据本来就有，只是没人去读。
struct GarmentSubtypeTests {

    @Test func itRecognisesCommonOuterwearTypes() {
        #expect(GarmentSubtype.inferred(name: "Navy blazer") == "blazer")
        #expect(GarmentSubtype.inferred(name: "Wool trench coat") == "trench")
        #expect(GarmentSubtype.inferred(name: "Denim jacket") == "denim jacket")
        #expect(GarmentSubtype.inferred(name: "Puffer") == "puffer")
        #expect(GarmentSubtype.inferred(name: "Leather biker jacket") == "leather jacket")
    }

    /// 大小写与多余空白不影响。
    @Test func itIsCaseAndWhitespaceInsensitive() {
        #expect(GarmentSubtype.inferred(name: "  BLAZER  ") == "blazer")
        #expect(GarmentSubtype.inferred(name: "Cropped Blazer") == "blazer")
    }

    /// 认不出就是认不出——**不猜**（猜错会把两件本可同穿的衣服判为冲突）。
    @Test func anUnknownNameYieldsNothing() {
        #expect(GarmentSubtype.inferred(name: "My favourite thing") == nil)
        #expect(GarmentSubtype.inferred(name: "") == nil)
    }

    /// 非外套不判型：这条规则只管外套叠穿，给上装判型只会误伤
    ///（「两件 tee」本来就被槽位重复规则挡住了）。
    @Test func onlyOuterwearGetsASubtype() {
        #expect(GarmentSubtype.inferred(name: "Blazer dress") == nil,
                "连衣裙被判成了 blazer")
    }

    /// 判型结果确定（同一个名字两次一样）。
    @Test func inferenceIsDeterministic() {
        let a = GarmentSubtype.inferred(name: "Wool trench coat")
        let b = GarmentSubtype.inferred(name: "Wool trench coat")
        #expect(a == b)
    }

    /// 端到端：两件 blazer 现在真的会被语法判为冲突。
    @Test func twoBlazersNowActuallyConflict() {
        func outer(_ id: String, _ name: String) -> CandidateItem {
            CandidateItem(
                id: id, slot: .outerwear,
                subtype: GarmentSubtype.inferred(name: name),
                occasions: [], warmth: .medium, status: .available)
        }
        let items = [
            CandidateItem(id: "t", slot: .top, occasions: [], warmth: .light, status: .available),
            CandidateItem(id: "b", slot: .bottom, occasions: [], warmth: .light, status: .available),
            CandidateItem(id: "s", slot: .shoes, occasions: [], warmth: .light, status: .available),
            outer("o1", "Navy blazer"), outer("o2", "Grey blazer"),
        ]
        #expect(OutfitGrammar.violations(items).contains(.duplicateSubtype("blazer")),
                "两件 blazer 仍然被当成合法的一身")
    }

    /// 不同型的两件外套可以叠（大衣 + 西装外套是真实穿法）。
    @Test func differentOuterwearTypesMayLayer() {
        func outer(_ id: String, _ name: String) -> CandidateItem {
            CandidateItem(
                id: id, slot: .outerwear,
                subtype: GarmentSubtype.inferred(name: name),
                occasions: [], warmth: .medium, status: .available)
        }
        let items = [
            CandidateItem(id: "t", slot: .top, occasions: [], warmth: .light, status: .available),
            CandidateItem(id: "b", slot: .bottom, occasions: [], warmth: .light, status: .available),
            CandidateItem(id: "s", slot: .shoes, occasions: [], warmth: .light, status: .available),
            outer("o1", "Navy blazer"), outer("o2", "Wool trench coat"),
        ]
        let subtypeViolations = OutfitGrammar.violations(items).filter {
            if case .duplicateSubtype = $0 { return true }
            return false
        }
        #expect(subtypeViolations.isEmpty)
    }
}
