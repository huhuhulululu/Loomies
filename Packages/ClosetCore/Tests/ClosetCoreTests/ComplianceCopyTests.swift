import Testing
import Foundation
@testable import ClosetCore

/// D86 产品外壳合规：§10.6 承诺的帮助/政策/署名/遥测开关。
/// 教训来自审查——旧 About 文案承诺了「Telemetry is opt-in ... when enabled」这个
/// **不存在**的控件；新文案不得重犯，且必须如实披露真实出网面（条码查询会把
/// 用户扫到的商品条码发往 Open*Facts）。
struct ComplianceCopyTests {

    /// 出网面对账：客户端实际会请求的每个 host 都必须在披露清单里。
    /// 新增出网面而文案未更新 → 本测试红（比「禁用词」黑名单强得多）。
    @Test func everyOutboundHostIsDisclosed() {
        let disclosedHosts = Set(NetworkSurfaceCatalog.surfaces.flatMap(\.hosts))
        // 条码查询（Open*Facts）
        for host in OpenProductFactsClient().hosts {
            #expect(disclosedHosts.contains(host), Comment(rawValue: "undisclosed host: \(host)"))
        }
        // 天气（Open-Meteo：geocoding + forecast）
        for host in ["geocoding-api.open-meteo.com", "api.open-meteo.com"] {
            #expect(disclosedHosts.contains(host), Comment(rawValue: "undisclosed host: \(host)"))
        }
        #expect(!NetworkSurfaceCatalog.surfaces.isEmpty)
    }

    /// 每条出网面都要说清「发什么 / 何时发 / 能否关」——不得只列域名。
    @Test func everySurfaceExplainsPayloadTriggerAndOptOut() {
        for s in NetworkSurfaceCatalog.surfaces {
            #expect(!s.title.isEmpty)
            #expect(!s.sends.isEmpty)
            #expect(!s.trigger.isEmpty)
            #expect(!s.optOut.isEmpty)
            #expect(!s.hosts.isEmpty)
            // 不得把「什么都不发」写成披露（那就不该出现在清单里）
            #expect(!s.sends.localizedCaseInsensitiveContains("nothing"))
        }
        // 条码面必须点名「barcode」，天气面必须点名「city」——否则等于没披露
        let joined = NetworkSurfaceCatalog.surfaces.map(\.sends).joined(separator: " ").lowercased()
        #expect(joined.contains("barcode"))
        #expect(joined.contains("city"))
    }

    /// 隐私段不得再出现「承诺了但没做」的句子。
    @Test func privacyCopyMakesNoUnbackedPromises() {
        let text = ComplianceCopy.privacySummary.lowercased()
        // 绝对化断言必须有据：不得声称「什么都不离开设备」
        #expect(!text.contains("never leave"))
        #expect(!text.contains("nothing leaves"))
        // 身体数据本地域是真的（D5 + schema 守卫），可以说
        #expect(text.contains("body"))
        // 遥测：措辞必须与实际状态一致（当前无 SDK，未发送任何事件）
        #expect(ComplianceCopy.telemetryStatusLine(enabled: false)
            .localizedCaseInsensitiveContains("off"))
        for enabled in [true, false] {
            let line = ComplianceCopy.telemetryStatusLine(enabled: enabled)
            #expect(!line.isEmpty)
            // 不得声称正在上报——当前没有 sink
            #expect(!line.localizedCaseInsensitiveContains("uploading"))
        }
    }

    /// 开源署名逐项可列（§4.3 许可红线：Fashionpedia CC BY 4.0 / SAM2 Apache-2.0 等）。
    @Test func attributionsAreItemizedWithLicenses() {
        #expect(ComplianceCopy.attributions.count >= 3)
        for a in ComplianceCopy.attributions {
            #expect(!a.name.isEmpty)
            #expect(!a.license.isEmpty)
            #expect(!a.usage.isEmpty)
        }
        let names = ComplianceCopy.attributions.map(\.name).joined(separator: " ").lowercased()
        #expect(names.contains("open-meteo"))
        // 排序确定（禁止依赖声明顺序漂移）
        #expect(ComplianceCopy.attributions.map(\.name)
            == ComplianceCopy.attributions.map(\.name).sorted())
    }

    /// FAQ 每条都有问有答，且答案不得含未兑现承诺。
    @Test func faqEntriesAreAnsweredHonestly() {
        #expect(ComplianceCopy.faq.count >= 4)
        for entry in ComplianceCopy.faq {
            #expect(entry.question.hasSuffix("?"))
            #expect(entry.answer.count > 20)
            #expect(!entry.answer.localizedCaseInsensitiveContains("coming soon"))
        }
        // 必须有一条讲「我的数据去哪了」，且与出网面清单一致
        let answers = ComplianceCopy.faq.map(\.answer).joined(separator: " ").lowercased()
        #expect(answers.contains("barcode") || answers.contains("open"))
    }

    @Test func policyLinksAreHTTPSAndLabeled() {
        #expect(ComplianceCopy.policyLinks.count >= 2)
        for link in ComplianceCopy.policyLinks {
            #expect(link.url.scheme == "https")
            #expect(!link.title.isEmpty)
        }
    }
}
