import Testing
import Foundation
import SwiftData
@testable import ClosetUI
import ClosetModel
import ClosetCore

/// D180：**每条建议都写着「还有 N 件没实测」，而 N 永远清不掉。**
///
/// `FitMarkService.mark` 对 `.shoes` / `.accessory` 是硬 `return nil`——
/// 这两类按设计就不出合身结论（没有可比的围度）。而 `OutfitFitMark.tightest`
/// 把**任何** nil 都记成 `unmeasured += 1`。
///
/// 加上 `OutfitGrammar` 的硬规则「每套必须有一双鞋」，结果是：
/// 生产路径上每一条建议的合身摘要都恒带 “· 1 piece not measured”，
/// 而用户无论量多少件衣服都消不掉它——他会一直以为自己还差一件没量。
///
/// 详情页那半边同样：鞋的编辑页照常显示「Fit measures (flat)」三个输入框
/// 和「Enter body profile + flat widths for fit mark.」，用户照做，什么都不会发生。
///
/// 为什么测试没抓到：`aFullyMeasuredLookSaysNothingExtra` 只传**一件上衣**，
/// 而那是唯一生产调用者永远不会给出的输入（没有鞋的套装过不了语法门）。
@MainActor
struct UnmeasurableSlotTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    private func profile(_ ctx: ModelContext) throws -> PersonBodyProfile {
        let person = Person(name: "P"); ctx.insert(person)
        let p = PersonBodyProfile(personID: person.id)
        p.bustInches = 36; p.waistInches = 28; p.hipInches = 38
        ctx.insert(p); try ctx.save()
        return p
    }

    private func item(_ ctx: ModelContext, _ name: String, _ slot: String,
                      chest: Double? = nil) -> Item {
        let i = Item(name: name); i.slotRaw = slot
        i.chestFlatWidthInches = chest
        ctx.insert(i)
        return i
    }

    /// **本波的核心**：量全了衣服，摘要就不该再提「还有几件没实测」——
    /// 哪怕这套里有鞋（生产上每套都有）。
    @Test func aLookWhoseGarmentsAreAllMeasuredSaysNothingExtra() throws {
        let ctx = try makeContext()
        let p = try profile(ctx)
        let items = [
            item(ctx, "Shirt", "top", chest: 20),
            item(ctx, "Boots", "shoes"),
        ]
        let mark = try #require(OutfitFitMark.tightest(items: items, profile: p))
        #expect(mark.unmeasuredCount == 0, Comment(rawValue:
            "鞋被算成了没实测（\(mark.unmeasuredCount) 件）—— 用户永远清不掉这个数"))
        #expect(!mark.summary.localizedCaseInsensitiveContains("not measured"),
                Comment(rawValue: mark.summary))
    }

    /// 配饰同理。
    @Test func accessoriesAreNotCountedEither() throws {
        let ctx = try makeContext()
        let p = try profile(ctx)
        let items = [
            item(ctx, "Shirt", "top", chest: 20),
            item(ctx, "Belt", "accessory"),
            item(ctx, "Boots", "shoes"),
        ]
        let mark = try #require(OutfitFitMark.tightest(items: items, profile: p))
        #expect(mark.unmeasuredCount == 0)
    }

    /// 真正没量的衣服照旧要数——这道收紧不得把该报的也吞掉。
    @Test func garmentsWithoutMeasurementsAreStillCounted() throws {
        let ctx = try makeContext()
        let p = try profile(ctx)
        let items = [
            item(ctx, "Shirt", "top", chest: 20),
            item(ctx, "Jeans", "bottom"),          // 没量
            item(ctx, "Boots", "shoes"),           // 不该算
        ]
        let mark = try #require(OutfitFitMark.tightest(items: items, profile: p))
        #expect(mark.unmeasuredCount == 1, Comment(rawValue:
            "该数的没数或不该数的数了：\(mark.unmeasuredCount)"))
    }

    /// 整套只有鞋时**不出结论**（不是「全都合身」）。
    @Test func aShoesOnlyLookHasNoFitMarkAtAll() throws {
        let ctx = try makeContext()
        let p = try profile(ctx)
        #expect(OutfitFitMark.tightest(items: [item(ctx, "Boots", "shoes")], profile: p) == nil)
    }

    /// 口径唯一：能不能出结论由 `FitMarkService` 一处说了算，
    /// 汇总侧不许自己再抄一张「哪些槽位算数」的清单。
    @Test func theMeasurableSlotsAreDeclaredOnce() {
        #expect(FitMarkService.supportsFitMark(slotRaw: "top"))
        #expect(FitMarkService.supportsFitMark(slotRaw: "bottom"))
        #expect(FitMarkService.supportsFitMark(slotRaw: "dress"))
        #expect(FitMarkService.supportsFitMark(slotRaw: "outerwear"))
        #expect(!FitMarkService.supportsFitMark(slotRaw: "shoes"))
        #expect(!FitMarkService.supportsFitMark(slotRaw: "accessory"))
        // 名字纠偏一并生效（"Dress shoes" 存在 top 上仍是鞋）
        #expect(!FitMarkService.supportsFitMark(slotRaw: "top", name: "Dress shoes"))
    }

    /// 详情页：不出结论的槽位不许再摆一组「填了也没用」的输入框。
    @Test func theDetailFormHidesFitMeasuresForUnmeasurableSlots() throws {
        let ctx = try makeContext()
        _ = try profile(ctx)
        let boots = item(ctx, "Boots", "shoes")
        let shirt = item(ctx, "Shirt", "top")
        try ctx.save()

        let bootsVM = ItemDetailViewModel(item: boots)
        let shirtVM = ItemDetailViewModel(item: shirt)
        #expect(bootsVM.showsFitMeasures == false, "鞋的编辑页还在要 flat width")
        #expect(shirtVM.showsFitMeasures == true)
    }

    /// 在同一个表单里把 Type 改成上衣，输入框要跟着回来（口径随表单，不随落库值）。
    @Test func changingTypeInTheFormBringsTheMeasuresBack() throws {
        let ctx = try makeContext()
        let boots = item(ctx, "Boots", "shoes")
        try ctx.save()
        let vm = ItemDetailViewModel(item: boots)
        #expect(vm.showsFitMeasures == false)
        vm.slotRaw = "top"
        vm.name = "Shirt"
        #expect(vm.showsFitMeasures == true)
    }
}
