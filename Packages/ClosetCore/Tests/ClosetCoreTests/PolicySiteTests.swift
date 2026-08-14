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
        for doc in PolicySite.hostedDocuments(hasSink: false) {
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
        for doc in PolicySite.hostedDocuments(hasSink: false) {
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

/// D142：`ReleaseReadiness` **零生产调用点**——那条「没接分析服务不得提审」的门
/// 只有测试在按，而测试传的是自己编的三个参数。
///
/// 也就是说：D116 建了一道提审阻断门，D111 又给它补了两条，
/// 而**真实的那三个事实此刻是什么，全仓没有任何一处知道**。
/// 提交当天才发现，正是这套东西当初要防的事。
///
/// 处置：三个事实收进 `ReleaseFacts`（唯一真相，此刻全空、注释说清在哪儿填），
/// 阻断项由它 + `TelemetryGate` 的实况算出来，显示在 Debug 面板——
/// 那是提审前唯一会被真人打开的那一面。
///
/// **刻意不做**：让 `blockers` 非空就红。域名此刻确实不存在（仓里不编造真实世界的
/// 事实，那是 D111 定的同一条底线），一条永远红的测试三天内就会被无视——
/// 那比没有门更糟。这里守的是「口径唯一 + 真的显示出来」。
struct ReleaseFactsTests {

    /// 事实有唯一来源（散在三处的话，填了一处等于没填）。
    @Test func theFactsHaveASingleHome() {
        // 此刻全未填——这是**事实陈述**，不是愿望：域名还不存在
        #expect(ReleaseFacts.privacyPolicyURL == nil)
        #expect(ReleaseFacts.supportURL == nil)
        #expect(ReleaseFacts.supportContact == nil)
    }

    /// 阻断项从实况算，不从测试编的参数算。
    @Test func theCurrentBlockersComeFromTheRealFacts() {
        let blockers = ReleaseReadiness.currentBlockers(telemetrySinkConnected: true)
        #expect(blockers.count == 3, Comment(rawValue: blockers.joined(separator: " / ")))
    }

    /// 填上之后这条门自己会放行——它是清单，不是永久红灯。
    @Test func supplyingTheFactsClearsIt() {
        #expect(ReleaseReadiness.blockers(
            privacyPolicyURL: "https://loomies.example/privacy.html",
            supportURL: "https://loomies.example/support.html",
            supportContact: "help@loomies.example",
            telemetrySinkConnected: true).isEmpty)
    }

    /// 一句给人看的摘要（Debug 面板那一行）。
    @Test func theSummaryNamesHowManyAreLeft() {
        let line = ReleaseReadiness.summaryLine(telemetrySinkConnected: true)
        #expect(line.contains("3"), Comment(rawValue: line))
    }

    /// 全部满足时说得出「可以提交」——不留一句模棱两可的话。
    @Test func aClearSummaryWhenNothingBlocks() {
        #expect(ReleaseReadiness.summaryLine(blockers: [])
            .localizedCaseInsensitiveContains("ready"))
    }
}

/// D217：Support 页与应用内政策同一条生成链，但不进 Help 的 Policies。
struct SupportPageTests {

    @Test func supportIsHostedButNotAnInAppPolicy() {
        let inApp = ComplianceCopy.policyDocuments(hasSink: false).map(\.title)
        #expect(!inApp.contains("Support"))
        let hosted = PolicySite.hostedDocuments(hasSink: false).map(\.title)
        #expect(hosted.contains("Support"))
        #expect(PolicySite.fileName(for: ComplianceCopy.supportDocument(contact: nil))
            == "support.html")
    }

    /// 没有收件方时不教用户「发给某处」（D191 同一条）。
    @Test func aMissingInboxDoesNotInventARecipient() {
        let html = PolicySite.render(ComplianceCopy.supportDocument(contact: nil))
        #expect(!html.localizedCaseInsensitiveContains("send it to"))
        #expect(!html.contains("@"))
        #expect(html.contains("Export diagnostics"))
    }

    @Test func aRealContactAppearsOnThePage() {
        let html = PolicySite.render(
            ComplianceCopy.supportDocument(contact: "help@example.com"))
        #expect(html.contains("help@example.com"))
        #expect(html.contains("send it to"))
    }
}
