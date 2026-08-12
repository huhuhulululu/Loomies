import Testing
import Foundation
@testable import ClosetCore

/// D111：App Store Connect **提交前**要求 Privacy Policy URL 与 Support URL，
/// 而本项目刻意只在应用内放全文（D86：外链到不存在的域名 = 死链）。
/// 结果是两头落空——应用内诚实，但版本根本提交不了。
///
/// 处置：政策站点**从 `ComplianceCopy` 生成**（同一真相，不手抄），
/// 落进 `preview/landing/` 随落地页一起发布；生成物与源文案不一致即红。
/// 域名与客服联系方式是真实世界的事实，仓里不编造——留成显式占位并由
/// `ReleaseReadiness` 点名，提交前必须填。
struct PolicySiteTests {

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // ClosetCoreTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // ClosetCore
            .deletingLastPathComponent()   // Packages
            .deletingLastPathComponent()   // repo root
    }

    /// HTML 转义：政策正文里的 `&`、`<` 不得把页面打坏。
    @Test func markupInBodyTextIsEscaped() {
        let doc = ComplianceCopy.PolicyDocument(
            title: "T & <b>",
            lastUpdated: "August 2026",
            sections: [.init(heading: "H<", body: "a & b < c")])
        let html = PolicySite.render(doc)
        #expect(html.contains("T &amp; &lt;b&gt;"))
        #expect(html.contains("a &amp; b &lt; c"))
        #expect(!html.contains("<b>"))
    }

    /// 生成物是自包含的（无外链 CSS/JS/字体——静态托管即可用）。
    @Test func pagesAreSelfContained() {
        let html = PolicySite.render(ComplianceCopy.policyDocuments(hasSink: false)[0])
        #expect(!html.localizedCaseInsensitiveContains("http://"))
        #expect(!html.contains("<script"))
        #expect(html.contains("<style"))
        #expect(html.hasPrefix("<!doctype html>"))
    }

    /// 每个小节都要落到页面上——生成器不得悄悄漏段。
    @Test func everySectionReachesThePage() {
        for doc in ComplianceCopy.policyDocuments(hasSink: false) {
            let html = PolicySite.render(doc)
            for section in doc.sections {
                #expect(html.contains(PolicySite.escape(section.heading)),
                        Comment(rawValue: "漏了小节：\(doc.title) / \(section.heading)"))
            }
        }
    }

    /// 防漂移：仓里 check-in 的 HTML 必须等于当前文案的生成物。
    /// 改了应用内文案却没重生成站点 → 这条红（同 D84 golden 的路子）。
    /// 重生成：`LOOMIES_POLICY_SITE=record swift test --package-path Packages/ClosetCore --filter PolicySite`
    @Test func checkedInPagesMatchTheCurrentCopy() throws {
        let dir = repoRoot.appendingPathComponent("preview/landing")
        let recording = ProcessInfo.processInfo.environment["LOOMIES_POLICY_SITE"] == "record"
        for doc in ComplianceCopy.policyDocuments(hasSink: false) {
            let file = dir.appendingPathComponent(PolicySite.fileName(for: doc))
            let expected = PolicySite.render(doc)
            if recording {
                try FileManager.default.createDirectory(
                    at: dir, withIntermediateDirectories: true)
                try expected.write(to: file, atomically: true, encoding: .utf8)
                continue
            }
            let actual = try? String(contentsOf: file, encoding: .utf8)
            #expect(actual == expected, Comment(rawValue:
                "\(PolicySite.fileName(for: doc)) 与应用内文案不一致 —— "
                + "用 LOOMIES_POLICY_SITE=record 重生成并审 diff"))
        }
    }

    /// D116：没接分析服务也是提审阻断项——判定协议全是 no-op 的 build
    /// 不得悄悄走到提审。
    @Test func aMissingAnalyticsSinkBlocksSubmission() {
        let blockers = ReleaseReadiness.blockers(
            privacyPolicyURL: "https://example.com/p.html",
            supportURL: "https://example.com/s.html",
            supportContact: "help@example.com",
            telemetrySinkConnected: false)
        #expect(blockers.count == 1)
        #expect(blockers[0].localizedCaseInsensitiveContains("analytics"))
    }

    /// 提审清单必须**点名**尚未填的真实世界事实，不得静默通过。
    @Test func releaseReadinessNamesTheUnfilledFacts() {
        let blockers = ReleaseReadiness.blockers(
            privacyPolicyURL: nil, supportURL: nil, supportContact: nil)
        #expect(blockers.count == 3)
        #expect(blockers.contains { $0.localizedCaseInsensitiveContains("privacy policy url") })
        #expect(blockers.contains { $0.localizedCaseInsensitiveContains("support url") })
    }

    /// 填齐即放行（这条门是清单，不是永久红灯）。
    @Test func readinessClearsOnceTheFactsAreSupplied() {
        #expect(ReleaseReadiness.blockers(
            privacyPolicyURL: "https://example.com/privacy.html",
            supportURL: "https://example.com/support.html",
            supportContact: "help@example.com").isEmpty)
    }

    /// 空白字符串不算填了（" " 通不过提审，也不该通过这条门）。
    @Test func whitespaceDoesNotCountAsSupplied() {
        #expect(!ReleaseReadiness.blockers(
            privacyPolicyURL: "  ", supportURL: "\t", supportContact: "").isEmpty)
    }

    /// URL 必须是 https 的绝对地址——填个 "TBD" 或 http 不算数。
    @Test func placeholdersAndInsecureURLsAreRejected() {
        let blockers = ReleaseReadiness.blockers(
            privacyPolicyURL: "TBD",
            supportURL: "http://example.com/support",
            supportContact: "help@example.com")
        #expect(blockers.count == 2)
    }
}
