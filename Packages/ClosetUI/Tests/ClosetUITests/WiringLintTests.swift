import Testing
import Foundation
@testable import ClosetUI

/// 结构性接线门。来源是一次实证失败：D83 把属性录入控件接进了 `QuickAddSheet`——
/// 一个自 46dc6ff 起零呈现点的死 View——而 commit / decisions.md / ARCHITECTURE.md
/// 都把它写成「已交付」，用户真正点到的「Enter manually」照旧硬编码温区与中性色。
///
/// 本项目的历史病根正是「能力就绪 + 有测试 + 零调用点」。人眼复查抓不住它
/// （每个单点看都对），只能靠门。这三条门扫源码文本，与 AppLog 隐私 lint 同法。
struct WiringLintTests {

    /// Packages/ 与 app-shell/ 下的全部生产源码（不含 Tests）。
    static func productionSources() -> [URL] {
        let packages = URL(fileURLWithPath: #filePath)   // …/ClosetUITests/WiringLintTests.swift
            .deletingLastPathComponent()                 // ClosetUITests
            .deletingLastPathComponent()                 // Tests
            .deletingLastPathComponent()                 // ClosetUI
            .deletingLastPathComponent()                 // Packages
        let appShell = packages.deletingLastPathComponent()
            .appendingPathComponent("app-shell", isDirectory: true)
        var files: [URL] = []
        let fm = FileManager.default
        for root in [packages, appShell] {
            let en = fm.enumerator(at: root, includingPropertiesForKeys: nil)
            while let url = en?.nextObject() as? URL {
                guard url.pathExtension == "swift",
                      url.path.contains("/Sources/") || url.path.contains("/app-shell/"),
                      !url.path.contains("/Tests/"), !url.path.contains("/.build/")
                else { continue }
                files.append(url)
            }
        }
        return files
    }

    /// 每个 View 都必须有呈现点。已知死 View 用**精确集合**锁定（棘轮）：
    /// 新增孤儿 → 红；清理掉某个孤儿而不更新清单 → 也红，逼清单只减不增。
    ///
    /// 清单里这四个是本次交付**之前**就存在的孤儿，属产品决策（3D 人台是否做、
    /// IntakeView 是否替换 AddPieceSheet），不在本波顺手删——但从此被钉住不再增长。
    @Test func everyViewHasACallSiteExceptTheKnownDeadList() throws {
        let knownDead: Set<String> = [
            "BodyMorphStripView",   // 体型调节条：BodyProfileView 走 shape 卡片，未接
            "IntakeView",           // 旧入库面：已被 AddPieceSheet 取代，未删
            "Mannequin3DView",      // 3D 人台：能力探针，未接产品面
            "PlaceholderCroquis",   // 占位人形：真实 croquis 落地后未清理
        ]
        var texts: [URL: String] = [:]
        for url in Self.productionSources() {
            texts[url] = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }
        var declared: [(name: String, file: URL)] = []
        for (url, text) in texts {
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                let s = line.trimmingCharacters(in: .whitespaces)
                guard s.hasPrefix("struct ") || s.hasPrefix("public struct "),
                      s.contains(":"), s.contains("View"), s.hasSuffix("{")
                else { continue }
                // `struct X: View {` / `public struct X: Identifiable, View {`
                let afterStruct = s.replacingOccurrences(of: "public ", with: "")
                    .dropFirst("struct ".count)
                guard let colon = afterStruct.firstIndex(of: ":") else { continue }
                let conformances = afterStruct[afterStruct.index(after: colon)...]
                    .dropLast()  // trailing {
                    .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                guard conformances.contains("View") else { continue }
                let name = afterStruct[..<colon].trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { declared.append((name, url)) }
            }
        }
        #expect(declared.count > 20, "View 扫描器失效（只找到 \(declared.count) 个）")

        var orphans: Set<String> = []
        for (name, declFile) in declared {
            // 调用点：`Name(` 或尾随闭包 `Name {`——两种都算呈现
            var used = false
            for (url, text) in texts {
                for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                    let s = line.trimmingCharacters(in: .whitespaces)
                    if s.hasPrefix("struct \(name)") || s.hasPrefix("public struct \(name)") {
                        continue  // 声明行本身不算调用
                    }
                    guard s.contains(name) else { continue }
                    // app-shell 的 RootView / OnboardingScreen 由 @main 场景挂载，同文件内即算
                    if s.contains("\(name)(") || s.contains("\(name) {") || s.contains("\(name)()") {
                        used = true
                        break
                    }
                }
                if used { break }
                _ = url
            }
            if !used { orphans.insert(name) }
            _ = declFile
        }
        #expect(orphans == knownDead,
                Comment(rawValue: "新孤儿 \(orphans.subtracting(knownDead).sorted())；"
                        + "清单已过期 \(knownDead.subtracting(orphans).sorted())"))
    }

    /// 入库路径不得**替用户假设**温区与颜色。未选 = 未知（nil），
    /// 冷天硬过滤与配色打分都按未知处理，而不是伪造「薄款 + 中性」。
    @Test func addPathsDoNotFabricateWarmthOrNeutralColor() throws {
        var violations: [String] = []
        for url in Self.productionSources() {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for (n, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let s = line.trimmingCharacters(in: .whitespaces)
                guard !s.hasPrefix("//"), !s.hasPrefix("///") else { continue }
                if s.contains("Warmth.light.rawValue") || s.contains("warmth: .light")
                    || s.contains("colorIsNeutral = true") {
                    violations.append("\(url.lastPathComponent):\(n + 1) ~ \(s)")
                }
            }
        }
        #expect(violations.isEmpty, Comment(rawValue: "\(violations)"))
    }

    /// create 失败一律「断关系 + rollback」。`context.delete` 只删行，
    /// 关系幻影与脏标记会滞留并污染下一次无关 save。
    ///
    /// 扫描面限定在 **UI / Intake 层**：真正的删除功能（DeleteService /
    /// DataLifecycleService / CalendarPlanService）住在 ClosetModel，那里的
    /// `context.delete` 是本职工作；而表现层出现它，只可能是 create 失败的错误善后。
    @Test func createFailurePathsRollbackInsteadOfDelete() throws {
        var violations: [String] = []
        for url in Self.productionSources()
        where url.path.contains("/ClosetUI/") || url.path.contains("/ClosetIntake/")
                || url.path.contains("/app-shell/") {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            for (n, line) in lines.enumerated() where line.contains("context.delete(") {
                let s = line.trimmingCharacters(in: .whitespaces)
                guard !s.hasPrefix("//"), !s.hasPrefix("///") else { continue }
                violations.append("\(url.lastPathComponent):\(n + 1) ~ \(s)")
            }
        }
        #expect(violations.isEmpty, Comment(rawValue: "\(violations)"))
    }
}

/// 面向用户的文案不得再出现「wardrobe」。D85/D86 把词汇统一成 closet 之后
/// 留了两处漂移：Me 的分区标题仍写 "Wardrobes"（其中那一行却叫 "Closets & people"），
/// Transfer 让用户去 "Me → Wardrobes" 找一个已经不存在的标签。
struct CustomerCopyVocabularyTests {

    /// 剥掉字符串插值再判——`\(wardrobe.items)` 是代码，不是给用户看的话。
    static func customerProse(in literal: String) -> String {
        var out = ""
        var depth = 0
        var i = literal.startIndex
        while i < literal.endIndex {
            if literal[i] == "\\", literal.index(after: i) < literal.endIndex,
               literal[literal.index(after: i)] == "(" {
                depth += 1
                i = literal.index(i, offsetBy: 2)
                continue
            }
            if depth > 0 {
                if literal[i] == "(" { depth += 1 }
                if literal[i] == ")" { depth -= 1 }
            } else {
                out.append(literal[i])
            }
            i = literal.index(after: i)
        }
        return out
    }

    @Test func noCustomerFacingStringSaysWardrobe() throws {
        var violations: [String] = []
        for url in WiringLintTests.productionSources()
        where url.path.contains("/ClosetUI/") || url.path.contains("/ClosetIntake/") {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for (n, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let s = line.trimmingCharacters(in: .whitespaces)
                guard !s.hasPrefix("//"), !s.hasPrefix("///"), !s.contains("AppLog.") else { continue }
                var scanning = false
                var literal = ""
                for ch in s {
                    if ch == "\"" {
                        if scanning {
                            let prose = Self.customerProse(in: literal)
                            // 带空格 = 句子（标识符 / 键名 / 日志标签不算）
                            if prose.localizedCaseInsensitiveContains("wardrobe"),
                               prose.contains(" ") {
                                violations.append("\(url.lastPathComponent):\(n + 1) ~ \(prose)")
                            }
                        }
                        scanning.toggle(); literal = ""
                    } else if scanning { literal.append(ch) }
                }
            }
        }
        #expect(violations.isEmpty, Comment(rawValue: "\(violations)"))
    }

    /// 门本身要能抓到真违规（防止上面的剥离逻辑把什么都吃掉 = 空转的门）。
    @Test func theLintItselfCatchesRealProse() {
        #expect(Self.customerProse(in: "No other wardrobes. Create one in Me.")
            .localizedCaseInsensitiveContains("wardrobe"))
        #expect(!Self.customerProse(in: "\\((wardrobe.items ?? []).count) pieces")
            .localizedCaseInsensitiveContains("wardrobe"))
    }
}
