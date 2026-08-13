import Testing
import Foundation
import SwiftData
@testable import ClosetModel

/// D143：**强制失败的测试钩子按堆地址记名。**
///
/// `forceFailureIDs` 存的是 `ObjectIdentifier(context)`——那就是对象地址。
/// 注册过的 context 一旦释放而没人清，这条记录就留在集合里；
/// 之后新分配的某个 `ModelContext` **正好落在同一地址**时，
/// 它会凭空继承「所有 save 都失败」。
///
/// 这类污染的特征是：与代码改动无关、与测试顺序有关、复现不了——
/// 也就是最贵的那种。而全仓有 7 处 `forceFailure` 没有紧邻的 `defer` 清理，
/// 任何一次提前 `return` / `#require` 失败都会留下一条。
///
/// 处置：注册表额外持**弱引用**，查表时要求那个对象仍然活着且是同一个。
/// 死了的条目当场清掉——地址被回收也就没得继承了。
@MainActor
struct ModelSaveHookIsolationTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    /// 钩子本身要好使（否则下面几条都是空转）。
    @Test func theHookStillForcesFailure() throws {
        let ctx = try makeContext()
        defer { ModelSave.clearForcedFailure(on: ctx) }
        ModelSave.forceFailure(on: ctx)
        #expect(ModelSave.save(ctx) == false)
    }

    /// 清掉之后恢复正常。
    @Test func clearingRestoresNormalSaves() throws {
        let ctx = try makeContext()
        ModelSave.forceFailure(on: ctx)
        ModelSave.clearForcedFailure(on: ctx)
        #expect(ModelSave.save(ctx) == true)
    }

    /// **没人清也不许留下遗产**：注册过的 context 释放之后，
    /// 注册表里不得再留着那条记录（留着就是给下一个同址对象埋雷）。
    @Test func aReleasedContextLeavesNoResidue() throws {
        do {
            let doomed = try makeContext()
            ModelSave.forceFailure(on: doomed)      // 故意不清
            #expect(ModelSave.forcedFailureCount >= 1)
        }
        // 触一次 save 让注册表自检（也可能已被 ARC 释放后自动落空）
        let fresh = try makeContext()
        #expect(ModelSave.save(fresh) == true, "新建的 context 继承了别人的强制失败")
        #expect(ModelSave.forcedFailureCount == 0,
                "死掉的 context 还占着注册表 —— 下一个同址对象会凭空开始失败")
    }

    /// 两个同时活着的 context 互不影响（按对象记名的本意）。
    @Test func liveContextsStayIndependent() throws {
        let a = try makeContext()
        let b = try makeContext()
        defer { ModelSave.clearForcedFailure(on: a) }
        ModelSave.forceFailure(on: a)
        #expect(ModelSave.save(a) == false)
        #expect(ModelSave.save(b) == true)
    }
}
