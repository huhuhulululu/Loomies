import Testing
import Foundation
import SwiftData
@testable import ClosetModel
import ClosetCore


/// D146：**删一个存放位会悄悄给提升上来的子格改名，而警告只字不提。**
///
/// 警告说的是「N pieces and M spots move to <父级>. Nothing is deleted except this spot.」
/// ——听起来除了这一格什么都没变。而 `deleteLocation` 在提升子格时，
/// 一旦与新的兄弟撞名就会追加后缀（`deduplicatedSiblingName`）：
/// 用户亲手起名「Attic」的那一格，事后叫「Attic 2」。
///
/// 改名本身是对的（D85 定的：两行长得一模一样比改名更糟）——
/// **问题是没告诉他**。他会去找「Attic」，然后对着两个相似的名字发愣。
/// 与 D139/D144 同一条底线：删除对话框必须说清它还会做什么。
///
/// 预测与执行必须同源：警告问的是 `deduplicatedSiblingName` 本人，
/// 不另写一套「大概会不会撞名」。
@MainActor
struct StorageDeleteRenameDisclosureTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    /// 根层已有「Attic」，被删格子下面也有一个「Attic」→ 提升必然撞名。
    private func makeCollision(in ctx: ModelContext) throws
        -> (doomed: StorageLocation, child: StorageLocation) {
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let rootAttic = StorageLocation(name: "Attic")
        rootAttic.wardrobe = w; ctx.insert(rootAttic)
        let doomed = StorageLocation(name: "Closet 1")
        doomed.wardrobe = w; ctx.insert(doomed)
        let child = StorageLocation(name: "Attic")
        child.wardrobe = w; child.parent = doomed; ctx.insert(child)
        try ctx.save()
        return (doomed, child)
    }

    /// 会改名就必须说。
    @Test func theWarningNamesTheRename() throws {
        let ctx = try makeContext()
        let (doomed, _) = try makeCollision(in: ctx)

        let plan = StorageLocationService.deletePlan(for: doomed)
        #expect(plan.renamedChildren.count == 1)
        let warning = StorageLocationService.deleteWarning(plan)
        // 断言的是**信息在不在**，不是措辞：旧名与新名都要出现，
        // 用户才对得上「我那个 Attic 去哪了」。
        #expect(warning.contains("Attic 2"),
                Comment(rawValue: "改名了却没说新名字：\(warning)"))
        #expect(warning.contains("Attic"), Comment(rawValue: warning))
    }

    /// 预测与执行一致——说了叫什么，事后就得叫什么。
    @Test func thePredictionMatchesWhatActuallyHappens() throws {
        let ctx = try makeContext()
        let (doomed, child) = try makeCollision(in: ctx)

        let predicted = StorageLocationService.deletePlan(for: doomed).renamedChildren
        #expect(DeleteService.deleteLocation(doomed, in: ctx))
        #expect(predicted.first?.to == child.name,
                Comment(rawValue: "预告叫 \(predicted.first?.to ?? "?")，实际叫 \(child.name)"))
    }

    /// 不撞名就不提改名（不制造无谓的不安）。
    @Test func noCollisionMeansNoRenameSentence() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let doomed = StorageLocation(name: "Closet 1")
        doomed.wardrobe = w; ctx.insert(doomed)
        let child = StorageLocation(name: "Sweaters")
        child.wardrobe = w; child.parent = doomed; ctx.insert(child)
        try ctx.save()

        let plan = StorageLocationService.deletePlan(for: doomed)
        #expect(plan.renamedChildren.isEmpty)
        let warning = StorageLocationService.deleteWarning(plan)
        #expect(!warning.localizedCaseInsensitiveContains("keep names apart"),
                Comment(rawValue: "没撞名却提了改名，制造无谓的不安：\(warning)"))
    }

    /// 多个改名时不逐条罗列到读不下去——给数目。
    @Test func manyRenamesAreSummarised() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let doomed = StorageLocation(name: "Closet 1")
        doomed.wardrobe = w; ctx.insert(doomed)
        for name in ["A", "B", "C"] {
            let existing = StorageLocation(name: name)
            existing.wardrobe = w; ctx.insert(existing)
            let child = StorageLocation(name: name)
            child.wardrobe = w; child.parent = doomed; ctx.insert(child)
        }
        try ctx.save()

        let plan = StorageLocationService.deletePlan(for: doomed)
        #expect(plan.renamedChildren.count == 3)
        let warning = StorageLocationService.deleteWarning(plan)
        #expect(warning.contains("3"), Comment(rawValue: warning))
    }

    /// 「除了这一格什么都没删」仍然成立——改名不是删除，别把两件事说混。
    @Test func itStillSaysNothingElseIsDeleted() throws {
        let ctx = try makeContext()
        let (doomed, _) = try makeCollision(in: ctx)
        let warning = StorageLocationService.deleteWarning(
            StorageLocationService.deletePlan(for: doomed))
        #expect(warning.localizedCaseInsensitiveContains("nothing is deleted"))
    }
}
