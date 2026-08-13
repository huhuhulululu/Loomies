import Testing
import Foundation

/// D206：守住 `docs/DOC-SYNC.md` 那张「改动 → 该复查哪条承诺」的映射。
///
/// 本 session 逐份核实了五份决策文档，**四份都有过期条目**。
/// 四份都不是没人维护——是**维护的时机不对**：全在「回头审计时」维护，
/// 而该在**改动时**维护。
///
/// 那张表把「该读哪份」从记忆搬到磁盘上。而它自己也会过期，所以这里守三件事：
/// 文档存在、glob 匹配得到真文件、每份决策文档都在表里。
///
/// **守不住的**：某一行的「该复查的承诺」写错或写漏——那是自然语言判断，
/// 没法 lint（与 D195/D203 同一条：硬造只会得到一道假绿）。
struct DocSyncMapTests {

    /// 仓库根：`.../Packages/ClosetCore/Tests/ClosetCoreTests/<file>` 往上五层。
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // ClosetCoreTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // ClosetCore
            .deletingLastPathComponent()   // Packages
            .deletingLastPathComponent()   // repo root
    }

    /// 解析 ```docsync 块 → [(glob, 承诺)]。
    private func rows() throws -> [(glob: String, promise: String)] {
        let text = try String(
            contentsOf: repoRoot.appendingPathComponent("docs/DOC-SYNC.md"),
            encoding: .utf8)
        guard let start = text.range(of: "```docsync"),
              let end = text.range(of: "```", range: start.upperBound..<text.endIndex)
        else {
            Issue.record("DOC-SYNC.md 里找不到 ```docsync 块"); return []
        }
        return text[start.upperBound..<end.lowerBound]
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .compactMap { line in
                let parts = line.split(separator: "|", maxSplits: 1)
                guard parts.count == 2 else {
                    Issue.record(Comment(rawValue: "这一行没有 `|` 分隔：\(line)"))
                    return nil
                }
                return (parts[0].trimmingCharacters(in: .whitespaces),
                        parts[1].trimmingCharacters(in: .whitespaces))
            }
    }

    /// 块解析得出东西（解析口径坏了会静默变成空表——那是最坏的假绿）。
    @Test func theMapParses() throws {
        let count = try rows().count
        #expect(count >= 10, Comment(rawValue:
            "只解析出 \(count) 行 —— 解析口径坏了，这张表就在空转"))
    }

    /// **每条 glob 都要匹配到真文件**——文件改名/删除之后那一行就是死的。
    @Test func everyGlobStillMatchesSomething() throws {
        let fm = FileManager.default
        var dead: [String] = []
        for row in try rows() {
            let pattern = repoRoot.appendingPathComponent(row.glob).path
            // `**` 与 `*` 都交给 shell glob 语义的最小实现：
            // 取通配符之前的固定前缀，再在那棵子树里找匹配后缀的文件。
            let head = pattern.components(separatedBy: "*").first ?? pattern
            let dir = URL(fileURLWithPath: head).deletingLastPathComponent()
            let prefix = URL(fileURLWithPath: head).lastPathComponent
            let suffix = pattern.hasSuffix("**") ? "" :
                (pattern.components(separatedBy: "*").last ?? "")
            var found = false
            if let walker = fm.enumerator(at: dir, includingPropertiesForKeys: nil) {
                for case let url as URL in walker where url.pathExtension == "swift" {
                    let name = url.lastPathComponent
                    if url.path.hasPrefix(head) || (name.hasPrefix(prefix) && name.hasSuffix(suffix)) {
                        found = true; break
                    }
                }
            }
            if !found { dead.append(row.glob) }
        }
        #expect(dead.isEmpty, Comment(rawValue:
            "这些 glob 一个文件都匹配不到（改名/删除后没跟上）：\(dead)"))
    }

    /// 右边点名的文档都得存在。
    @Test func everyNamedDocumentExists() throws {
        let known = [
            "requirements": "docs/requirements/PRACTICAL-JOURNEY-AND-PUBLIC-API.md",
            "DESIGN": "docs/DESIGN.md",
            "MVP-PLAN": "docs/MVP-PLAN.md",
            "MARKET": "docs/MARKET.md",
            "FEATURE-GAP": "docs/FEATURE-GAP.md",
        ]
        let fm = FileManager.default
        for (_, path) in known {
            #expect(fm.fileExists(atPath: repoRoot.appendingPathComponent(path).path),
                    Comment(rawValue: "\(path) 不见了，而 DOC-SYNC 还在指它"))
        }
        let promises = try rows().map(\.promise).joined()
        for name in known.keys {
            #expect(promises.contains(name), Comment(rawValue:
                "\(name) 没有出现在任何一行的「该复查的承诺」里 —— "
                + "它要么该进表，要么不该算决策文档"))
        }
    }

    /// **新加一份决策文档而不进表 → 红。**
    ///
    /// 判据：`docs/` 顶层的 md 里，凡带「验收 / 退出门 / 判定 / 缺口」这类
    /// 决策词的，都必须在 DOC-SYNC 里被点名。
    @Test func noDecisionDocumentSitsOutsideTheDiscipline() throws {
        let fm = FileManager.default
        let docs = repoRoot.appendingPathComponent("docs")
        let promises = try rows().map(\.promise).joined()
        // 这几份不是「对代码作断言」的决策文档，故不在纪律内
        let exempt: Set<String> = [
            "ARCHITECTURE.md",       // 架构目录，另有 ArchDoc/ArchGate 两道 hook 守
            "decisions.md",          // ADR 只追加，不作断言
            "DOC-SYNC.md",           // 表自己
            "DEVICE-ACCEPTANCE.md",  // 待人验的清单，不声称代码状态
            "PROJECT-CONTEXT.md", "HANDOFF.md",
            "DEMAND-VALIDATION.md",  // 需求调研，不对代码作断言
            "BODY-AVATAR-IMAGE-PROMPTS.md", "BODY-AVATAR-USER-FLOW.md",
        ]
        var outside: [String] = []
        for name in (try? fm.contentsOfDirectory(atPath: docs.path))?.sorted() ?? []
        where name.hasSuffix(".md") && !exempt.contains(name) {
            let text = (try? String(
                contentsOf: docs.appendingPathComponent(name), encoding: .utf8)) ?? ""
            let makesClaims = ["验收", "退出门", "判定", "缺口"].contains {
                text.contains($0)
            }
            guard makesClaims else { continue }
            let stem = name.replacingOccurrences(of: ".md", with: "")
            if !promises.contains(stem) { outside.append(name) }
        }
        #expect(outside.isEmpty, Comment(rawValue:
            "这些文档对代码作了断言，却不在 DOC-SYNC 里：\(outside) —— "
            + "改代码的人不会知道该去看它们"))
    }
}
