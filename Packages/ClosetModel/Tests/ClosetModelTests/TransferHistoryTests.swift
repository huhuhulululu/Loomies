import Testing
import SwiftData
import Foundation
@testable import ClosetModel
import ClosetCore

/// D94（缺口 #12）：转移历史 + 批量转移。DESIGN 的 Item 属性清单里「转移历史」一直挂着，
/// 而实现只是把 `item.wardrobe` 改掉——东西去哪了、什么时候走的，没有任何痕迹。
///
/// 历史用**软 UUID 引用**（与 `WearRecord` 同法）：删掉一个衣柜不该把「它曾经在这里」
/// 这段事实一并抹掉，级联关系会。
@MainActor
struct TransferHistoryTests {

    func setup() throws -> (ModelContext, Wardrobe, Wardrobe, Item) {
        let ctx = try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
        let a = Wardrobe(name: "Home"); ctx.insert(a)
        let b = Wardrobe(name: "Lake"); ctx.insert(b)
        let i = Item(name: "tee"); i.slotRaw = "top"; i.wardrobe = a
        i.statusRaw = "available"; ctx.insert(i)
        try ctx.save()
        return (ctx, a, b, i)
    }

    /// 每次成功转移写一条历史，且记录来源与去向。
    @Test func transferWritesHistory() throws {
        let (ctx, a, b, item) = try setup()
        #expect(TransferService.transfer(item, to: b, in: ctx))
        let records = try ctx.fetch(FetchDescriptor<TransferRecord>())
        #expect(records.count == 1)
        let r = try #require(records.first)
        #expect(r.itemID == item.id)
        #expect(r.fromWardrobeID == a.id)
        #expect(r.toWardrobeID == b.id)
    }

    /// 转移失败**不得**留下历史（否则历史声称发生过没发生的事）。
    @Test func failedTransferLeavesNoHistory() throws {
        let (ctx, _, b, item) = try setup()
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        #expect(!TransferService.transfer(item, to: b, in: ctx))
        #expect(try ctx.fetch(FetchDescriptor<TransferRecord>()).isEmpty)
        #expect(!ctx.hasChanges)
    }

    /// 删掉源衣柜后历史仍在——软引用的全部意义。
    @Test func historySurvivesClosetDeletion() throws {
        let (ctx, a, b, item) = try setup()
        #expect(TransferService.transfer(item, to: b, in: ctx))
        try DeleteService.deleteWardrobe(a, force: true, in: ctx)
        let records = try ctx.fetch(FetchDescriptor<TransferRecord>())
        #expect(records.count == 1)
        // 名字解析不出来时诚实显示，不留空白
        let line = TransferHistory.line(records[0], resolving: [:])
        #expect(line.localizedCaseInsensitiveContains("deleted")
                || line.localizedCaseInsensitiveContains("unknown"))
    }

    /// 历史按时间倒序 + id 决胜（排序确定性）。
    @Test func historyIsNewestFirstAndDeterministic() throws {
        let (ctx, a, b, item) = try setup()
        #expect(TransferService.transfer(item, to: b, in: ctx))
        #expect(TransferService.transfer(item, to: a, in: ctx))
        let history = TransferHistory.forItem(item.id, in: ctx)
        #expect(history.count == 2)
        #expect(history[0].date >= history[1].date)
        #expect(history[0].toWardrobeID == a.id)
    }

    /// 只看这件的历史（别的单品的转移不得混进来）。
    @Test func historyIsScopedToOneItem() throws {
        let (ctx, a, b, item) = try setup()
        let other = Item(name: "jeans"); other.slotRaw = "bottom"; other.wardrobe = a
        ctx.insert(other); try ctx.save()
        #expect(TransferService.transfer(item, to: b, in: ctx))
        #expect(TransferService.transfer(other, to: b, in: ctx))
        #expect(TransferHistory.forItem(item.id, in: ctx).count == 1)
    }

    // MARK: - 批量转移

    /// 批量转移：逐件走同一条服务路径，结果**逐项如实**。
    @Test func batchTransferReportsPerItemOutcome() throws {
        let (ctx, a, b, item) = try setup()
        let second = Item(name: "jeans"); second.slotRaw = "bottom"; second.wardrobe = a
        ctx.insert(second)
        // 已在目标柜的件：不是失败，是无需移动
        let already = Item(name: "hat"); already.slotRaw = "accessory"; already.wardrobe = b
        ctx.insert(already)
        try ctx.save()

        let outcome = TransferService.transferAll(
            [item, second, already], to: b, in: ctx)
        #expect(outcome.moved == 2)
        #expect(outcome.alreadyThere == 1)
        #expect(outcome.failed == 0)
        #expect(outcome.summary.contains("2"))
        #expect(!outcome.summary.localizedCaseInsensitiveContains("couldn't"))
        #expect(try ctx.fetch(FetchDescriptor<TransferRecord>()).count == 2)
    }

    /// 批量里失败的那几件要被点名，且**不得谎称整批成功**。
    @Test func batchTransferSurfacesFailures() throws {
        let (ctx, _, b, item) = try setup()
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        let outcome = TransferService.transferAll([item], to: b, in: ctx)
        #expect(outcome.moved == 0)
        #expect(outcome.failed == 1)
        #expect(outcome.summary.localizedCaseInsensitiveContains("couldn't"))
        #expect(!outcome.summary.contains("Moved 0"))
    }

    /// 空选择不是一次批量操作。
    @Test func emptyBatchSaysNothingToMove() throws {
        let (ctx, _, b, _) = try setup()
        let outcome = TransferService.transferAll([], to: b, in: ctx)
        #expect(outcome.moved == 0)
        #expect(outcome.summary.localizedCaseInsensitiveContains("nothing"))
    }
}

/// D94：新实体必须同时进「删除权」与「数据可携带性」两条路径——
/// 加了一张表却漏掉这两处，等于悄悄制造一个删不掉、也带不走的角落。
@MainActor
struct TransferRecordLifecycleTests {

    func setup() throws -> (ModelContext, Wardrobe, Wardrobe, Item) {
        let ctx = try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
        let a = Wardrobe(name: "Home"); ctx.insert(a)
        let b = Wardrobe(name: "Lake"); ctx.insert(b)
        let i = Item(name: "tee"); i.slotRaw = "top"; i.wardrobe = a
        i.statusRaw = "available"; ctx.insert(i)
        try ctx.save()
        return (ctx, a, b, i)
    }

    @Test func deleteAllRemovesTransferHistory() throws {
        let (ctx, _, b, item) = try setup()
        #expect(TransferService.transfer(item, to: b, in: ctx))
        #expect(try ctx.fetch(FetchDescriptor<TransferRecord>()).count == 1)

        let suite = UserDefaults(suiteName: "xfer-del-\(UUID().uuidString)")!
        defer { suite.removePersistentDomain(forName: suite.description) }
        _ = try DataLifecycleService.deleteAllUserData(
            in: ctx, wipeItemImages: false,
            bodyDataConsent: BodyDataConsent(defaults: suite),
            telemetryGate: TelemetryGate(sink: nil, defaults: suite))
        #expect(try ctx.fetch(FetchDescriptor<TransferRecord>()).isEmpty)
    }

    @Test func exportCarriesTransferHistory() throws {
        let (ctx, _, b, item) = try setup()
        #expect(TransferService.transfer(item, to: b, in: ctx))
        let json = try DataLifecycleService.exportJSONString(
            in: ctx, includeBodyDimensions: false)
        #expect(json.contains("transfers"))
        #expect(json.contains(item.id.uuidString))
    }
}

/// D105（审计 LOW，但后果是崩）：`closetNames` 用 `Dictionary(uniqueKeysWithValues:)`
/// 按 `Wardrobe.id` 建表——而 schema **没有**把 id 声明为 unique，
/// 导入/同步产生的重复 id 会让它直接 fatalError，而不是退化成一个可用的映射。
/// 崩在一个只是「给历史行取个名字」的路径上，代价完全不成比例。
@MainActor
struct TransferHistoryNameLookupTests {

    func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    /// 重复 id 不得 trap——取一个确定的胜者即可（按名 + id 决胜，可复现）。
    @Test func duplicateIdsDoNotTrap() throws {
        let ctx = try makeContext()
        let shared = UUID()
        let a = Wardrobe(name: "Alpha"); a.id = shared; ctx.insert(a)
        let b = Wardrobe(name: "Beta"); b.id = shared; ctx.insert(b)
        try ctx.save()
        let names = TransferHistory.closetNames(in: ctx)
        #expect(names[shared] != nil)
        // 确定性：同样的库跑两次结果一致
        #expect(TransferHistory.closetNames(in: ctx)[shared] == names[shared])
    }

    /// 正常情况照旧。
    @Test func distinctIdsMapNormally() throws {
        let ctx = try makeContext()
        let a = Wardrobe(name: "Home"); ctx.insert(a)
        let b = Wardrobe(name: "Lake"); ctx.insert(b)
        try ctx.save()
        let names = TransferHistory.closetNames(in: ctx)
        #expect(names[a.id] == "Home")
        #expect(names[b.id] == "Lake")
    }
}
