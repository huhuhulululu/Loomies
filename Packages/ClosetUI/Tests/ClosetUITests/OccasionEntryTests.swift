import Testing
import SwiftData
import Foundation
@testable import ClosetUI
import ClosetModel
import ClosetCore

/// D108：场合此前是**逗号分隔的自由文本**，而它是 `CandidateFilter` 的硬过滤输入——
/// 打错一个字母（"casaul"），这件衣服就永远不再被推荐，而用户看不到任何异样。
/// 改为多选后，存进去的一定是引擎认识的值。
@MainActor
struct OccasionEntryTests {

    func setup() throws -> (ModelContext, Item) {
        let ctx = try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let i = Item(name: "Tee"); i.slotRaw = "top"; i.wardrobe = w
        i.statusRaw = "available"; ctx.insert(i)
        try ctx.save()
        return (ctx, i)
    }

    /// 选中的场合确定顺序落库（导出快照可复现）。
    @Test func selectionPersistsInDeterministicOrder() throws {
        let (ctx, item) = try setup()
        let vm = ItemDetailViewModel(item: item)
        vm.occasions = ["work", "casual"]
        vm.save(in: ctx)
        #expect(item.occasionsRaw == ["casual", "work"])
    }

    /// 往返：存下去、重开详情页读得回。
    @Test func selectionSurvivesAReopen() throws {
        let (ctx, item) = try setup()
        let vm = ItemDetailViewModel(item: item)
        vm.occasions = ["gala"]
        vm.save(in: ctx)
        #expect(ItemDetailViewModel(item: item).occasions == ["gala"])
    }

    /// 全部取消 = 未知（三值语义：空集不硬过滤），不得被当成「casual」。
    @Test func clearingAllMeansUnknownNotCasual() throws {
        let (ctx, item) = try setup()
        let vm = ItemDetailViewModel(item: item)
        vm.occasions = ["work"]
        vm.save(in: ctx)
        let second = ItemDetailViewModel(item: item)
        second.occasions = []
        second.save(in: ctx)
        #expect(item.occasionsRaw.isEmpty)
    }

    /// 存量的自定义值**原样保留**——不静默删掉用户的数据。
    @Test func legacyCustomValuesAreKeptAndOfferable() throws {
        let (ctx, item) = try setup()
        item.occasionsRaw = ["work", "beach-wedding"]
        try ctx.save()
        let vm = ItemDetailViewModel(item: item)
        #expect(vm.occasions.contains("beach-wedding"))
        #expect(vm.customOccasions == ["beach-wedding"])
        vm.save(in: ctx)
        #expect(item.occasionsRaw.contains("beach-wedding"))
    }

    /// 大小写与空白在读入时归一——存量脏值不该显示成两个不同的 chip。
    @Test func storedValuesAreNormalisedOnLoad() throws {
        let (ctx, item) = try setup()
        item.occasionsRaw = [" Work ", "work"]
        try ctx.save()
        #expect(ItemDetailViewModel(item: item).occasions == ["work"])
        _ = ctx
    }

    /// 多选出来的值一定被引擎认识（这正是改多选的理由）。
    @Test func everySelectableValueIsRecognisedByTheEngine() throws {
        let (ctx, item) = try setup()
        for choice in OccasionMix.choices {
            let vm = ItemDetailViewModel(item: item)
            vm.occasions = [choice]
            vm.save(in: ctx)
            let candidate = item.toCandidateItem()
            let kept = CandidateFilter.filter(
                [candidate],
                context: FilterContext(occasion: choice, daytimeTempF: 70))
            #expect(kept.count == 1, Comment(rawValue: "引擎不认识可选值：\(choice)"))
        }
    }
}
