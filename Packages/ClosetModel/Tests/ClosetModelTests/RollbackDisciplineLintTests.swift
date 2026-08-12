import Testing
import Foundation
@testable import ClosetModel

/// D112 结构门：**改了关系又要 rollback 的失败分支，必须先还原/断开**。
///
/// 这已经是同一类缺陷第三次出现（D88 删柜、D103 Plan 留孤儿、D112 discardOrphan
/// 与位置 create）。逐个修不如把写法钉住：SwiftData 的 `rollback()` 撤销的是
/// 未落库的**行**，撤不掉已经改过的内存**关系**——幻影会被下一次无关的成功 save
/// 顺手写进库里，而那一刻离出错现场已经很远，没人会把两件事联系起来。
///
/// 判据（保守，只抓确定有害的形状）：一个 `guard ModelSave.save(...) else { ... }`
/// 失败块里出现 `rollback()`，而**同一个函数**在 save 之前对关系赋过值
/// （`x.someRelation = ...`），则该失败块内必须也出现对应的还原/断开赋值。
struct RollbackDisciplineLintTests {

    private var sourcesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/ClosetModel")
    }

    /// 关系属性名（schema 里的 to-one / to-many），只认这些，避免把普通字段算进来。
    private let relationNames = [
        "wardrobe", "items", "parent", "children", "outfits", "outfit",
        "owner", "location", "person", "locations",
    ]

    @Test func everyRollbackAfterARelationEditRestoresIt() throws {
        var violations: [String] = []
        let fm = FileManager.default
        for case let url as URL in fm.enumerator(at: sourcesDir, includingPropertiesForKeys: nil)!
        where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

            var funcStart = 0
            var assignedBefore: Set<String> = []
            for (i, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("func ") || trimmed.hasPrefix("public static func")
                    || trimmed.hasPrefix("static func") || trimmed.hasPrefix("public func") {
                    funcStart = i
                    assignedBefore = []
                }
                // 关系赋值：`something.relation = ...`
                for name in relationNames where trimmed.contains(".\(name) = ") {
                    assignedBefore.insert(name)
                }
                guard trimmed.contains("ModelSave.save("), trimmed.contains("guard"),
                      !assignedBefore.isEmpty else { continue }
                // 取失败块（到下一个同缩进 `}`，保守取 25 行窗口）
                let end = min(lines.count, i + 25)
                let block = lines[i..<end].joined(separator: "\n")
                guard block.contains("rollback()") else { continue }
                let blockBeforeRollback = block.components(separatedBy: "rollback()")[0]
                for name in assignedBefore
                where !blockBeforeRollback.contains(".\(name) = ") {
                    violations.append(
                        "\(url.lastPathComponent):\(funcStart + 1) 改了 .\(name) 却没在 rollback 前还原/断开")
                }
            }
        }
        #expect(violations.isEmpty, Comment(rawValue:
            "rollback 撤不掉内存关系，幻影会被下一次无关 save 写进库：\n"
            + violations.joined(separator: "\n")))
    }
}

/// D112：**测试不得对生产图片根做整目录破坏**。
///
/// `reconcile(in:)` 默认扫 `ItemImageStore.rootDirectory`，`deleteAllData` 会
/// 整根擦除——而同进程内并行跑的其他用例的文件就在同一个根下，
/// 于是「孤儿清理」会把别人的文件删掉（本波确认的 live flake，
/// 且犯这条的正是本轮新写的用例）。
/// 触盘用例要么传自己的 `directory:`，要么别用整根 API。
struct TestIsolationLintTests {

    private var testsDir: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    }

    @Test func noTestScansOrWipesTheProductionImageRoot() throws {
        var violations: [String] = []
        let fm = FileManager.default
        for case let url as URL in fm.enumerator(at: testsDir, includingPropertiesForKeys: nil)!
        where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for (i, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let s = String(line)
                // reconcile 不带 directory: → 扫生产根
                if s.contains("ImageReconcileService.reconcile("), !s.contains("directory:") {
                    violations.append("\(url.lastPathComponent):\(i + 1) reconcile 未指定 directory:")
                }
                if s.contains("wipeItemImage" + "Directory(") {
                    violations.append("\(url.lastPathComponent):\(i + 1) 测试里擦除整个图片根")
                }
            }
        }
        #expect(violations.isEmpty, Comment(rawValue:
            "并发下会删掉其他用例的文件：\n" + violations.joined(separator: "\n")))
    }

    /// 本门自身的字面量刻意拆开拼接：否则门会抓到自己的门文本（自指假阳性）。
    /// `.serialized` 挂在非参数化的单个用例上是**无操作**——
    /// 要串行就挂在 `@Suite` 上，否则那行注释在骗人。
    @Test func serializedIsDeclaredWhereItActuallyWorks() throws {
        var violations: [String] = []
        let fm = FileManager.default
        for case let url as URL in fm.enumerator(
            at: testsDir.deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent(),   // Packages/
            includingPropertiesForKeys: nil)!
        where url.pathExtension == "swift" && url.path.contains("/Tests/") {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for (i, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
            where String(line).contains("@Test(." + "serialized)") {
                violations.append("\(url.lastPathComponent):\(i + 1)")
            }
        }
        #expect(violations.isEmpty, Comment(rawValue:
            "逐用例 serialized 对非参数化用例无效，应挂 @Suite：\(violations)"))
    }
}

/// D114 结构门：**删搭配前必须先解绑它的日历计划**。
///
/// `CalendarPlan.outfit` 是 schema 里唯一没有反向关系的引用，SwiftData 不会
/// 替我们置空（`DanglingPlanTests.aBareDeleteDoesLeaveADanglingReference` 是取证）。
/// 加反向端被 golden 门判为破坏性变更，所以这条不变式只能由服务层维持——
/// 那就必须有门盯着，否则下一个人写一行 `context.delete(outfit)` 就破了它，
/// 而症状要到用户翻到那一天才出现。
struct PlanUnbindLintTests {

    private var sourcesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/ClosetModel")
    }

    @Test func everyOutfitDeletionUnbindsItsPlansFirst() throws {
        var violations: [String] = []
        let fm = FileManager.default
        for case let url as URL in fm.enumerator(at: sourcesDir, includingPropertiesForKeys: nil)!
        where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            for (i, line) in lines.enumerated() {
                // 只认删「搭配」的那种：变量名或参数名里带 outfit
                let s = line.trimmingCharacters(in: .whitespaces)
                guard s.contains("context.delete("), s.lowercased().contains("outfit") else { continue }
                // 同一函数内、这一行之前必须出现解绑调用（回看 40 行足够覆盖本仓最长的失败善后段）
                let from = max(0, i - 40)
                let before = lines[from..<i].joined(separator: "\n")
                if !before.contains("unbindPlans(referencing:") {
                    violations.append("\(url.lastPathComponent):\(i + 1)")
                }
            }
        }
        #expect(violations.isEmpty, Comment(rawValue:
            "删搭配前没解绑日历计划，会留下指向已删行的悬挂引用：\(violations)"))
    }
}
