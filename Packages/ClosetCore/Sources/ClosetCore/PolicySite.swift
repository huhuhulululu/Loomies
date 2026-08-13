import Foundation

/// 政策静态页生成器（D111）。
///
/// App Store Connect 在**提交前**就要 Privacy Policy URL 与 Support URL，
/// 而本项目此前刻意只在应用内放全文（D86 的判断没错：外链到不存在的域名 = 死链）。
/// 两条真相都成立，缺的是第三件事——把同一份文案**也**渲染成可托管的静态页。
///
/// 关键是不产生第二份真相：页面从 `ComplianceCopy` 生成，
/// `PolicySiteTests.checkedInPagesMatchTheCurrentCopy` 守住不漂移。
public enum PolicySite {

    public static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// 文件名由标题推出：`Privacy Policy` → `privacy.html`、`Terms of Use` → `terms.html`。
    public static func fileName(for doc: ComplianceCopy.PolicyDocument) -> String {
        let first = doc.title.split(separator: " ").first.map(String.init) ?? "policy"
        return first.lowercased() + ".html"
    }

    /// 自包含单页：无外链 CSS/JS/字体（静态托管直接可用，也不给第三方留追踪位）。
    public static func render(_ doc: ComplianceCopy.PolicyDocument) -> String {
        let body = doc.sections.map { section in
            "  <h2>\(escape(section.heading))</h2>\n  <p>\(escape(section.body))</p>"
        }.joined(separator: "\n")
        return """
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <title>\(escape(doc.title)) — Loomies</title>
        <style>
        :root{color-scheme:light dark}
        body{margin:0 auto;padding:40px 20px 80px;max-width:44rem;
             font:16px/1.65 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif}
        h1{font-size:1.6rem;margin:0 0 4px}
        h2{font-size:1.05rem;margin:2rem 0 .4rem}
        p{margin:0 0 1rem}
        .updated{color:#767676;font-size:.85rem;margin:0 0 2rem}
        </style>
        </head>
        <body>
        <h1>\(escape(doc.title))</h1>
        <p class="updated">Loomies · Last updated \(escape(doc.lastUpdated))</p>
        \(body)
        </body>
        </html>
        """
    }
}

/// 提审前必须由**真人**填的事实（D111）。
///
/// 仓里不编造域名、邮箱、工单地址——那正是「不得声称产品没有的东西」的同一条底线，
/// 落地页里那个 `FORM_ENDPOINT` 占位是同一个约定。
/// 这里把缺口做成**可执行清单**，免得提交当天才发现。
public enum ReleaseReadiness {

    /// 返回尚未满足的提审阻断项（空 = 可提交）。
    public static func blockers(
        privacyPolicyURL: String?,
        supportURL: String?,
        supportContact: String?,
        telemetrySinkConnected: Bool = true
    ) -> [String] {
        var out: [String] = []
        if !telemetrySinkConnected {
            // D116：MARKET §8.1 的预注册判定（GO/PIVOT/KILL）是 D20 跳过真人验证
            // 之后**唯一**的裁决装置。没接 sink 就提审 = 上线第 6 周一个数都读不到。
            out.append("Analytics sink — no analytics service is connected, so every "
                + "launch-protocol metric is a no-op. Connect one via "
                + "TelemetryGate.shared.configure(sink:) before submitting.")
        }
        if !isUsableHTTPSURL(privacyPolicyURL) {
            out.append("Privacy Policy URL — App Store Connect requires a reachable https URL "
                + "before a version can be submitted. Host preview/landing/privacy.html and "
                + "put its address here.")
        }
        if !isUsableHTTPSURL(supportURL) {
            out.append("Support URL — required on the App Store listing. Host a support page "
                + "and put its address here.")
        }
        if TextNormalize.blankToNil(supportContact) == nil {
            out.append("Support contact — how a user actually reaches a human. "
                + "The app tells them to export diagnostics and send it somewhere; "
                + "that somewhere does not exist yet.")
        }
        return out
    }

    /// 按**当前实况**算阻断项（D142）。
    ///
    /// 此前 `blockers` 零生产调用点：只有测试在按，而测试传的是自己编的三个参数——
    /// 于是「真实的那三个事实此刻是什么」全仓没有任何一处知道，
    /// 而提交当天才发现正是这套东西当初要防的事。
    public static func currentBlockers(telemetrySinkConnected: Bool) -> [String] {
        blockers(
            privacyPolicyURL: ReleaseFacts.privacyPolicyURL,
            supportURL: ReleaseFacts.supportURL,
            supportContact: ReleaseFacts.supportContact,
            telemetrySinkConnected: telemetrySinkConnected)
    }

    /// Debug 面板那一行。
    public static func summaryLine(telemetrySinkConnected: Bool) -> String {
        summaryLine(blockers: currentBlockers(telemetrySinkConnected: telemetrySinkConnected))
    }

    public static func summaryLine(blockers: [String]) -> String {
        guard !blockers.isEmpty else { return "Ready to submit — nothing blocking" }
        let n = blockers.count
        return "\(n) blocker\(n == 1 ? "" : "s") before submission"
    }

    /// https 绝对地址才算数——「TBD」「http://…」通不过审，也不该通过这条门。
    static func isUsableHTTPSURL(_ raw: String?) -> Bool {
        guard let value = TextNormalize.blankToNil(raw),
              let url = URL(string: value),
              url.scheme?.lowercased() == "https",
              let host = url.host, host.contains(".")
        else { return false }
        return true
    }
}

/// 提审需要、而**只有真人知道**的三个事实（D142）。
///
/// 仓里不编造域名、邮箱、工单地址——那是 D111 定的同一条底线
///（落地页里那个 `FORM_ENDPOINT` 占位是同一个约定）。
/// 收在这里是为了**口径唯一**：散在三处的话，填了一处等于没填。
///
/// 填的时候：把 `preview/landing/privacy.html` 与一个支持页托管出去
///（`ts-publish.sh` 或任何静态托管都行），再把地址写进来。
/// 写进来之后 `ReleaseReadiness.currentBlockers` 自己会放行——它是清单，
/// 不是永久红灯。
public enum ReleaseFacts {
    /// App Store Connect 的 Privacy Policy URL（必须 https 绝对地址）。
    public static let privacyPolicyURL: String? = nil
    /// App Store 商品页的 Support URL。
    public static let supportURL: String? = nil
    /// 用户真能找到人的联系方式——App 里让他导出诊断「发到某处」，
    /// 而那个「某处」目前不存在。
    public static let supportContact: String? = nil
}
