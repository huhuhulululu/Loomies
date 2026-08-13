import Testing
import Foundation
import SwiftData
@testable import ClosetModel
import ClosetCore

/// D153：**「先看效果」那条路上，产品的差异点全程为 0。**
///
/// MARKET §2 判定「合身 / 体型」是竞品都没占的唯一纵深，而 `BodyShapeStyling`
/// 靠的是单品的**剪裁属性**（`attributesRaw`）。demo 种子设了槽位、场合、
/// 温区、颜色——**唯独没设剪裁属性**。于是 affinity 恒为 0，
/// 体型加权这一整维在演示数据上不产生任何差别。
///
/// 后果不是「少个功能」，是**演示恰好把最该展示的东西藏了**：
/// D98 之后「先看效果」是用户的主动选择，他点进去正是想看这 App 凭什么不一样。
///
/// 界线：**我们自己发明的样例，我们当然知道它的剪裁**——给「Midi skirt」
/// 标 A 字、给「Navy blazer」标结构感，是在描述自家 fixture，
/// 不是替用户猜他衣柜里那条裙子。（用户真实的件仍然只由他自己标，
/// 入库路径一个字都不改。）
@MainActor
struct DemoSeedAttributesTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    private func seededWardrobe() throws -> Wardrobe {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Demo"); ctx.insert(w)
        try ctx.save()
        _ = DemoSeedService.seed(w, in: ctx)
        return w
    }

    /// 至少一半的样例件带剪裁属性——否则体型维基本还是哑的。
    @Test func mostDemoPiecesDescribeTheirCut() throws {
        let items = try seededWardrobe().items ?? []
        #expect(!items.isEmpty)
        let withCut = items.filter { !$0.attributesRaw.isEmpty }
        #expect(withCut.count * 2 >= items.count,
                Comment(rawValue: "\(withCut.count)/\(items.count) 件有剪裁属性"))
    }

    /// 属性值必须是引擎认得的——拼错的字符串等于没填，而且没人会发现。
    @Test func everyAttributeIsOneTheEngineKnows() throws {
        let items = try seededWardrobe().items ?? []
        for item in items {
            for raw in item.attributesRaw {
                #expect(StyleAttribute(rawValue: raw) != nil,
                        Comment(rawValue: "\(item.name) 带了引擎不认识的属性「\(raw)」"))
            }
        }
    }

    /// **真正的判据：体型这一维在演示衣柜上产生得出差别。**
    /// 只断言「字段填了」是走过场——填了但打分仍恒为 0 的话，这一波等于没做。
    @Test func theBodyShapeDimensionActuallyMovesOnDemoData() throws {
        let items = (try seededWardrobe().items ?? []).map { $0.toCandidateItem() }
        var moved: [PopularShape] = []
        for shape in PopularShape.allCases {
            let affinities = items.map { BodyShapeStyling.affinity(items: [$0], shape: shape) }
            if affinities.contains(where: { $0 != 0 }) { moved.append(shape) }
        }
        #expect(moved.count >= 4,
                Comment(rawValue: "只有 \(moved.count)/5 种体型能在演示数据上看出差别：\(moved)"))
    }

    /// 剪裁要与那件衣服**说得通**——A 字裙不该出现在西装外套上。
    /// 这条不是洁癖：演示数据是产品的第一印象，自相矛盾的标注会被用户看出来。
    @Test func theCutMatchesTheGarment() throws {
        let items = try seededWardrobe().items ?? []
        for item in items {
            let attrs = Set(item.attributesRaw.compactMap { StyleAttribute(rawValue: $0) })
            if item.slotRaw == "shoes" {
                #expect(attrs.isEmpty, Comment(rawValue: "鞋子标了剪裁：\(item.name)"))
            }
            if attrs.contains(.aLine) {
                #expect(item.slotRaw == "bottom" || item.slotRaw == "dress",
                        Comment(rawValue: "A 字出现在 \(item.slotRaw)：\(item.name)"))
            }
            if attrs.contains(.wideLeg) {
                #expect(item.slotRaw == "bottom",
                        Comment(rawValue: "阔腿出现在 \(item.slotRaw)：\(item.name)"))
            }
        }
    }

    /// 重复播种不得让属性丢失（第二批与第一批同质）。
    @Test func aSecondBatchIsDescribedToo() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Demo"); ctx.insert(w)
        try ctx.save()
        _ = DemoSeedService.seed(w, in: ctx)
        _ = DemoSeedService.seed(w, in: ctx)
        let items = w.items ?? []
        let withCut = items.filter { !$0.attributesRaw.isEmpty }
        #expect(withCut.count * 2 >= items.count)
    }
}
