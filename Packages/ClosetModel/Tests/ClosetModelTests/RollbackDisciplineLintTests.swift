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
