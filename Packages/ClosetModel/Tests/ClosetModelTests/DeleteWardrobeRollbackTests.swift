import Testing
import Foundation
import SwiftData
@testable import ClosetModel

/// D145：删柜失败路径的**否定结论**——留在这里，免得下一轮审计再走一遍。
///
/// 一份审计报告说：成功路径会把别柜的搭配标 `permanentlyMissing` 并重算计划的
/// `needsAttention`，而失败分支只还原了标记、没重算计划，于是留下一枚假警示
/// （D112 那类幻影：`rollback` 撤的是没保存的行，不回写已改的内存属性）。
///
/// 照着写测试才发现**这个幻影不可能存在**：`shouldNeedAttention` 是
/// `missing || permanentlyMissing || !WardrobeInvariant.isValid(outfit)`，
/// 而「被删柜波及的别柜搭配」按定义就是跨柜的——它的 `needsAttention`
/// 在删除发生**之前**就已经是 true。翻不过来的东西，也就不会被翻错。
///
/// 所以这里不改代码，只把这条性质钉住：失败之后标记还原、context 不留脏。
/// （造出那个幻影需要一个现实中不存在的 fixture——我第一版就是那么写的。）
@MainActor
struct DeleteWardrobeRollbackTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    /// 搭在别柜、用到本柜某件的场景（D103 的形状）。
    private func makeCrossClosetPlan(in ctx: ModelContext) throws
        -> (doomed: Wardrobe, plan: CalendarPlan, outfit: Outfit) {
        let doomed = Wardrobe(name: "Spare"); ctx.insert(doomed)
        let home = Wardrobe(name: "Home"); ctx.insert(home)
        let borrowed = Item(name: "Coat"); borrowed.slotRaw = "outerwear"
        borrowed.wardrobe = doomed; ctx.insert(borrowed)
        let look = Outfit(name: "Layered"); look.wardrobe = home
        look.items = [borrowed]; ctx.insert(look)
        let plan = CalendarPlan(date: Date()); plan.outfit = look; ctx.insert(plan)
        try ctx.save()
        #expect(plan.needsAttention == false)
        return (doomed, plan, look)
    }

    /// 删成功 → 别柜的搭配被标为永久缺件（D103 定的行为，先钉住）。
    @Test func aSuccessfulDeleteFlagsTheForeignLook() throws {
        let ctx = try makeContext()
        let (doomed, plan, look) = try makeCrossClosetPlan(in: ctx)

        try DeleteService.deleteWardrobe(doomed, force: true, in: ctx)
        #expect(look.permanentlyMissing)
        #expect(plan.needsAttention, "删掉了别人搭配里的件，日历却毫无表示")
    }

    /// 跨柜搭配的计划**从一开始**就该是「需要处理」——
    /// 这正是上面那个幻影不可能存在的原因。
    @Test func aCrossClosetLookAlreadyNeedsAttentionBeforeAnyDelete() throws {
        let ctx = try makeContext()
        let (_, _, look) = try makeCrossClosetPlan(in: ctx)
        #expect(CalendarPlanService.shouldNeedAttention(look),
                "跨柜搭配本来就不满足不变量 —— 删柜翻不动一个已经是 true 的位")
    }

    /// **删失败 → 标记还原、不留脏。**
    @Test func aFailedDeleteLeavesNoPhantomAttention() throws {
        let ctx = try makeContext()
        let (doomed, plan, look) = try makeCrossClosetPlan(in: ctx)

        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        #expect(throws: DeleteError.saveFailed) {
            try DeleteService.deleteWardrobe(doomed, force: true, in: ctx)
        }
        ModelSave.clearForcedFailure(on: ctx)

        #expect(!look.permanentlyMissing, "失败之后搭配仍被标为永久缺件")
        #expect(!ctx.hasChanges, "失败的删除留下了脏标记")
        _ = plan
    }

    /// 失败之后来一次无关的成功 save——不许把任何东西捎带提交（D112 同款检查）。
    @Test func anUnrelatedSaveCarriesNothingFromTheFailedDelete() throws {
        let ctx = try makeContext()
        let (doomed, plan, _) = try makeCrossClosetPlan(in: ctx)

        ModelSave.forceFailure(on: ctx)
        #expect(throws: DeleteError.saveFailed) {
            try DeleteService.deleteWardrobe(doomed, force: true, in: ctx)
        }
        ModelSave.clearForcedFailure(on: ctx)

        // 一次完全无关的写入
        ctx.insert(Wardrobe(name: "Unrelated"))
        #expect(ModelSave.save(ctx, label: "unrelated"))

        // 柜与件都还在（删除失败了，不许有半个成功）
        #expect(try ctx.fetch(FetchDescriptor<Wardrobe>()).count == 3)
        let looks = try ctx.fetch(FetchDescriptor<Outfit>())
        #expect(looks.count == 1)
        #expect(!looks[0].permanentlyMissing,
                "失败的删除把「永久缺件」捎带提交了")
        _ = plan
    }
}

/// D145：`TransferService.transfer` 是公开 API，而「转到它已经在的那个柜」
/// 会**静默抹掉这件衣服的存放位置**（`item.location = nil`，理由是
/// 「位置属源柜，转移即脱离」——可这次根本没换柜），还写一条
/// 「从 A 到 A」的转移历史。
///
/// 批量版 `transferAll` 早就在外面挡了这一下（`already += 1`），
/// 单件的 VM 也把当前柜从候选里滤掉了——**唯独服务本身没有守卫**。
/// 挡在调用方的不变量，迟早会有第三个调用方不知道。
@MainActor
struct SameClosetTransferTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    @Test func movingIntoTheSameClosetKeepsTheStorageSpot() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let shelf = StorageLocation(name: "Top shelf"); shelf.wardrobe = w; ctx.insert(shelf)
        let tee = Item(name: "Tee"); tee.wardrobe = w; tee.location = shelf; ctx.insert(tee)
        try ctx.save()

        #expect(TransferService.transfer(tee, to: w, in: ctx))
        #expect(tee.location?.id == shelf.id,
                "转到它本来就在的柜，存放位置被抹掉了")
    }

    /// 没发生的移动不许进历史。
    @Test func noHistoryRowForAMoveThatDidNotHappen() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let tee = Item(name: "Tee"); tee.wardrobe = w; ctx.insert(tee)
        try ctx.save()

        _ = TransferService.transfer(tee, to: w, in: ctx)
        #expect(try ctx.fetch(FetchDescriptor<TransferRecord>()).isEmpty,
                "写了一条「从 A 到 A」的转移历史")
    }

    /// 真的换柜照旧（守卫不许把正常路径也挡掉）。
    @Test func aRealMoveStillWorks() throws {
        let ctx = try makeContext()
        let from = Wardrobe(name: "Main"); ctx.insert(from)
        let to = Wardrobe(name: "Box"); ctx.insert(to)
        let shelf = StorageLocation(name: "Top shelf"); shelf.wardrobe = from; ctx.insert(shelf)
        let tee = Item(name: "Tee"); tee.wardrobe = from; tee.location = shelf; ctx.insert(tee)
        try ctx.save()

        #expect(TransferService.transfer(tee, to: to, in: ctx))
        #expect(tee.wardrobe?.id == to.id)
        #expect(tee.location == nil, "换了柜，存放位置该脱离")
        #expect(try ctx.fetch(FetchDescriptor<TransferRecord>()).count == 1)
    }
}
