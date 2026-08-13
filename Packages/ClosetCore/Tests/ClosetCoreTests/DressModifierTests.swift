import Testing
import Foundation
@testable import ClosetCore

/// D178：**「Dress shirt」被存成连衣裙，而且详情页改不回来。**
///
/// `displaySlot` 用名字纠偏历史脏数据（「西装写在 top」），最后一条是
/// `if base == .top, n.contains("dress") … { return .dress }`。
/// 作者显然知道这个陷阱——为 “dress pants” 专门把裤子分支**前置**
///（注释原话：「先于 dress：dress pants 是裤不是裙」），为 “dress shoes”
/// 前置了鞋分支——唯独没管 “dress shirt”，而它是英语里最常见的那件衬衫。
///
/// 后果不止是分错类：`GarmentSlot.resolved(item.slotRaw, name: item.name)`
/// 在**八个读取点**都会重解一遍，用户在详情页把 Type 改回 Top、保存，
/// 下次打开还是 Dress。推断压过了用户的明确选择——这与 copilot 铁律相反。
///
/// 判据：`dress` 后面**紧跟另一件衣服的名词**时它是形容词（dress shirt /
/// dress socks），反过来 `shirt dress` 才是裙子。靠词序区分，不靠词表相减——
/// 单纯排掉含 “shirt” 的名字会把 shirt dress 一起误伤。
struct DressModifierTests {

    private func slot(_ name: String, raw: String = "top") -> BodyAvatarSlot? {
        BodyAvatarComposer.displaySlot(slotRaw: raw, itemName: name)
    }

    /// `dress` 当形容词时不是裙子。
    @Test func dressAsAModifierIsNotADress() {
        #expect(slot("Dress shirt") == .top)
        #expect(slot("White dress shirt") == .top)
        #expect(slot("dress-shirt") == .top)
        #expect(slot("Dress blouse") == .top)
        #expect(slot("Dress vest") == .top)
        #expect(slot("Dress sweater") == .top)
    }

    /// 反过来仍然是裙子——词序才是判据。
    @Test func aShirtDressIsStillADress() {
        #expect(slot("Shirt dress") == .dress)
        #expect(slot("Sweater dress") == .dress)
        #expect(slot("Slip dress") == .dress)
        #expect(slot("Gown") == .dress)
        #expect(slot("Jumpsuit") == .dress)
    }

    /// 原有的两条前置排除一个字不变。
    @Test func theExistingModifierCasesStillWork() {
        #expect(slot("Dress pants") == .bottom)
        #expect(slot("Dress shoes") == .shoes)
        #expect(slot("Oxford shirt") == .top)
        #expect(slot("Oxford shoes") == .shoes)
    }

    /// 用户明确标成 dress 的件不受影响（纠偏只在 `base == .top` 时介入）。
    @Test func anExplicitDressRawIsUntouched() {
        #expect(slot("Dress shirt", raw: "dress") == .dress)
    }
}
