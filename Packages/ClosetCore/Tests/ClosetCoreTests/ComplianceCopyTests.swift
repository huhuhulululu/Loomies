import Testing
import Foundation
@testable import ClosetCore

/// D86 产品外壳合规：§10.6 承诺的帮助/政策/署名/遥测开关。
/// 教训来自审查——旧 About 文案承诺了「Telemetry is opt-in ... when enabled」这个
/// **不存在**的控件；新文案不得重犯，且必须如实披露真实出网面（条码查询会把
/// 用户扫到的商品条码发往 Open*Facts）。
struct ComplianceCopyTests {

    /// 录 URL 的假传输：只记账、永远抛错（不联网）。
    actor URLLedger {
        private(set) var urls: [URL] = []
        func record(_ url: URL) { urls.append(url) }
    }

    struct RecordingTransport: PublicAPITransport {
        let ledger = URLLedger()
        func get(url: URL) async throws -> Data {
            await ledger.record(url)
            throw PublicAPIError.notFound
        }
    }

    /// 出网面对账：客户端实际会请求的每个 host 都必须在披露清单里。
    /// 新增出网面而文案未更新 → 本测试红（比「禁用词」黑名单强得多）。
    @Test func everyOutboundHostIsDisclosed() {
        let disclosedHosts = Set(NetworkSurfaceCatalog.surfaces.flatMap(\.hosts))
        // 条码查询（Open*Facts）
        for host in OpenProductFactsClient().hosts {
            #expect(disclosedHosts.contains(host), Comment(rawValue: "undisclosed host: \(host)"))
        }
        // 天气（Open-Meteo：geocoding + forecast）——取实现的真值，不手抄字面量
        for host in OpenMeteoWeatherProvider.hosts {
            #expect(disclosedHosts.contains(host), Comment(rawValue: "undisclosed host: \(host)"))
        }
        #expect(!NetworkSurfaceCatalog.surfaces.isEmpty)
    }

    /// 行为级对账：让两个客户端**真的发一次请求**，录下它们请求的 URL，
    /// 断言每个 host 都已披露。此前天气侧是测试里手抄的字面量数组，与实现互不引用——
    /// 改 host 或加 endpoint 时对账不会红，而 D86 的卖点正是「新增出网面即红」。
    @Test func hostsActuallyRequestedAtRuntimeAreDisclosed() async throws {
        let spy = RecordingTransport()
        let disclosed = Set(NetworkSurfaceCatalog.surfaces.flatMap(\.hosts))

        // 天气：geocode + forecast 两个 endpoint 都要走到
        let weather = OpenMeteoWeatherProvider(transport: spy)
        _ = try? await weather.geocode(name: "Austin")
        _ = try? await weather.forecastDay(latitude: 30, longitude: -97, on: Date())
        // 城市选择器（D107）：**边打字边发**，是这条门此前完全看不见的一路请求
        _ = try? await weather.searchCities(name: "Aus", limit: 8)
        // 条码：三个 Facts 域名依次尝试
        let facts = OpenProductFactsClient(transport: spy)
        _ = try? await facts.lookup(barcode: "0123456789012")

        let requested = Set(await spy.ledger.urls.compactMap { $0.host })
        #expect(requested.count >= 4, Comment(rawValue: "只录到 \(requested.sorted())"))
        for host in requested {
            #expect(disclosed.contains(host), Comment(rawValue: "undisclosed at runtime: \(host)"))
        }
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

    /// D111：披露的「何时发」必须覆盖**打字即发**。
    /// D107 把城市改成搜索选择器后，第一条出网请求发生在 onboarding 的欢迎屏上——
    /// 早于任何隐私界面可达，而披露当时还写着「当你改某个衣柜的城市时」。
    /// 原文案给的退出路径（把城市留空）在那一步根本不可选：onboarding 要求非空城市。
    @Test func theWeatherSurfaceDisclosesTypeAheadLookups() async throws {
        let weather = try #require(
            NetworkSurfaceCatalog.surfaces.first { $0.id == "weather" })
        let trigger = weather.trigger.lowercased()
        #expect(trigger.contains("type"),
                Comment(rawValue: "披露没说打字就会发：\(weather.trigger)"))
        #expect(weather.sends.lowercased().contains("type"),
                Comment(rawValue: "披露没说发的是正在输入的文本：\(weather.sends)"))
    }

    /// 录下来的请求参数必须被披露的「发什么」覆盖住（不只对账 host）。
    @Test func typedTextIsWhatActuallyGoesOut() async throws {
        let spy = RecordingTransport()
        let weather = OpenMeteoWeatherProvider(transport: spy)
        _ = try? await weather.searchCities(name: "Aus", limit: 8)
        let queries = await spy.ledger.urls.compactMap { url -> String? in
            URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "name" }?.value
        }
        #expect(queries.contains("Aus"),
                Comment(rawValue: "录到的查询参数：\(queries)"))
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
        #expect(ComplianceCopy.telemetryStatusLine(enabled: false, hasSink: false)
            .localizedCaseInsensitiveContains("off"))
        for enabled in [true, false] {
            let line = ComplianceCopy.telemetryStatusLine(enabled: enabled, hasSink: false)
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

    /// 政策必须**应用内可读**：外链到尚不存在的域名 = App 里放死链，
    /// 与「不得声称做不到的事」同源（实测 loomies.app 当时无法解析）。
    @Test func policiesAreReadableInAppNotDeadLinks() {
        #expect(ComplianceCopy.policyDocuments(hasSink: false).count >= 2)
        let titles = ComplianceCopy.policyDocuments(hasSink: false).map(\.title)
        #expect(titles.contains { $0.localizedCaseInsensitiveContains("privacy") })
        #expect(titles.contains { $0.localizedCaseInsensitiveContains("terms") })
        for doc in ComplianceCopy.policyDocuments(hasSink: false) {
            #expect(!doc.title.isEmpty)
            #expect(!doc.sections.isEmpty)
            for section in doc.sections {
                #expect(!section.heading.isEmpty)
                // 实质内容，不是占位
                #expect(section.body.count > 40)
                #expect(!section.body.localizedCaseInsensitiveContains("lorem"))
                #expect(!section.body.localizedCaseInsensitiveContains("coming soon"))
                #expect(!section.body.localizedCaseInsensitiveContains("tbd"))
            }
            #expect(!doc.lastUpdated.isEmpty)
        }
        // 隐私政策必须与出网面清单对得上（同一真相，不得各说各话）
        let privacyText = ComplianceCopy.policyDocuments(hasSink: false)
            .first { $0.title.localizedCaseInsensitiveContains("privacy") }?
            .sections.map(\.body).joined(separator: " ").lowercased() ?? ""
        #expect(privacyText.contains("barcode"))
        #expect(privacyText.contains("city"))
    }
}

/// D105（审计 LOW）：`TelemetryGate.hasSink` 存在的**唯一理由**就是让这句隐私文案
/// 说得诚实——「没有接分析服务，所以什么都没发」。它却零调用点，
/// 而 `telemetryStatusLine` 把「no analytics service is connected」**硬编码**进句子里。
/// 真接上 SDK 那天，这句话会在没人注意的情况下变成谎话。
struct TelemetryStatusLineReflectsRealityTests {

    @Test func statusLineIsDrivenByWhetherASinkExists() {
        // 无 sink：可以说「什么都没发」
        let noSink = ComplianceCopy.telemetryStatusLine(enabled: true, hasSink: false)
        #expect(noSink.localizedCaseInsensitiveContains("nothing is sent"))
        // 有 sink 且用户已开启：**不得**再说「什么都没发」
        let withSink = ComplianceCopy.telemetryStatusLine(enabled: true, hasSink: true)
        #expect(!withSink.localizedCaseInsensitiveContains("nothing is sent"))
        #expect(!withSink.localizedCaseInsensitiveContains("no analytics service"))
    }

    /// 关掉时无论有没有 sink 都是「不收集不发送」——那是开关的语义。
    @Test func disabledMeansNothingRegardlessOfSink() {
        for hasSink in [true, false] {
            let line = ComplianceCopy.telemetryStatusLine(enabled: false, hasSink: hasSink)
            #expect(line.localizedCaseInsensitiveContains("off"))
            #expect(line.localizedCaseInsensitiveContains("nothing"))
        }
    }

    /// 当前构建确实没有 sink——文案与事实一致（接上那天这条会红，逼人改文案）。
    @Test func thisBuildHasNoSinkAndSaysSo() {
        #expect(!TelemetryGate.shared.hasSink)
        let line = ComplianceCopy.telemetryStatusLine(
            enabled: true, hasSink: TelemetryGate.shared.hasSink)
        #expect(line.localizedCaseInsensitiveContains("nothing is sent"))
    }
}


/// D111：D105 修了状态行，**政策正文里同一句硬编码留着没动**——而政策是风险更高的那份。
/// 隐私 workflow 的 16 个 agent 里有一个专门盯这条，它是对的。
struct PolicyAnalyticsClaimFollowsRealityTests {

    /// 没接 SDK：可以说「什么都没发」。
    @Test func withoutASinkThePolicyMaySayNothingIsSent() {
        let body = ComplianceCopy.analyticsPolicyBody(hasSink: false)
        #expect(body.localizedCaseInsensitiveContains("no analytics service"))
        #expect(body.localizedCaseInsensitiveContains("opt-in"))
    }

    /// 接上 SDK：**不得**再说「什么都没发」，否则政策当场变谎话。
    @Test func withASinkThePolicyMustNotClaimNothingIsSent() {
        let body = ComplianceCopy.analyticsPolicyBody(hasSink: true).lowercased()
        #expect(!body.contains("nothing is sent"))
        #expect(!body.contains("no analytics service"))
        #expect(body.contains("allowlist"))
    }

    /// 全文里这句话只能有**一个**产地——再出现第二处硬编码就是 D105 的复发。
    @Test func theClaimHasExactlyOneSource() {
        let doc = ComplianceCopy.policyDocuments(hasSink: true)
            .flatMap { $0.sections }.map(\.body).joined(separator: " ").lowercased()
        #expect(!doc.contains("no analytics service"),
                Comment(rawValue: "接上 sink 后政策里仍有硬编码的「未接分析服务」"))
    }

    /// 状态行与政策正文不得互相打架（同一实况，两处说法必须同向）。
    @Test func statusLineAndPolicyAgree() {
        for hasSink in [true, false] {
            let line = ComplianceCopy.telemetryStatusLine(enabled: true, hasSink: hasSink).lowercased()
            let body = ComplianceCopy.analyticsPolicyBody(hasSink: hasSink).lowercased()
            #expect(line.contains("no analytics service") == body.contains("no analytics service"),
                    Comment(rawValue: "hasSink=\(hasSink) 时状态行与政策正文说法相反"))
        }
    }
}

/// D166：**出网必须只有一条通道，否则上面那道运行时对账覆盖不到新来的流量。**
///
/// `everyOutboundHostIsDisclosed` 与 `hostsActuallyRequestedAtRuntimeAreDisclosed`
/// 都是好门——host 取实现真值、还真发一次请求录 URL。但它们枚举的是**两个已知客户端**：
/// 谁加第三个客户端，没人会想起来来更新这份枚举。
///
/// 实测当下全仓 `PublicAPITransport` 之外零个 `URLSession`——**这条性质今天成立，
/// 却没有任何东西让它继续成立**。有了这道门，「所有出网都经同一条通道」变成可执行事实，
/// 上面那两道才真的覆盖全部流量（而不是覆盖「我们记得的那些」）。
struct SingleOutboundChokepointTests {

    @Test func nothingReachesTheNetworkOutsideTheTransport() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        // 判据认**构造**不认词：`URLSessionTransport()` 里也含 "URLSession"，
        // 而那正是通道本身——第一版就这么误报了两处（写门时最容易犯的那个错，
        // 本 session 已在 D147/D156/D158/D164 上各记过一次）。
        let networkAPIs = ["URLSession.", "URLSession(", "URLSession.shared",
                           "URLRequest(", "URLProtocol", "NWConnection"]
        /// 通道自身：它就是那条唯一允许直接出网的路。
        let exempt = ["PublicAPITransport.swift"]

        var offenders: [String] = []
        let fm = FileManager.default
        for root in [repoRoot.appendingPathComponent("Packages"),
                     repoRoot.appendingPathComponent("app-shell")] {
            guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: nil)
            else { continue }
            for case let url as URL in walker where url.pathExtension == "swift" {
                let path = url.path
                guard path.contains("/Sources/") || path.contains("/app-shell/") else { continue }
                guard !exempt.contains(url.lastPathComponent) else { continue }
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                for line in text.split(separator: "\n") {
                    let t = line.trimmingCharacters(in: .whitespaces)
                    guard !t.hasPrefix("//"), !t.hasPrefix("///"), !t.hasPrefix("*") else { continue }
                    for api in networkAPIs where t.contains(api) {
                        offenders.append("\(url.lastPathComponent) ~ \(api)")
                    }
                }
            }
        }
        #expect(offenders.isEmpty, Comment(rawValue:
            "这些地方绕开 `PublicAPITransport` 直接出网，运行时 host 对账看不见它们："
            + "\(offenders) —— 新出网面必须走通道，否则披露清单可能已经在说谎"))
    }
}

/// D171：**M1 退出门「出网 payload 身体字段隐私单测绿」此前根本没实现。**
///
/// `MVP-PLAN.md` 的 M1 门白纸黑字列着它，而 `PublicAPITests` 里一条相关断言都没有——
/// 一条只写在计划里的验收标准，与只写在注释里的规则一样，等于没有。
///
/// 判据取**白名单**而非禁词黑名单：录下真实出网 URL，其查询参数名必须逐个在册。
/// 黑名单只挡得住你想得到的字段（`bust`…），白名单让**任何新参数**都得先过人眼——
/// 而身体维度进出网面这种事，恰恰不会用 `bust` 当参数名。
@MainActor
struct OutboundPayloadPrivacyTests {

    /// 每个 endpoint 允许出现的查询参数。加参数要在这里过一遍脑子。
    private static let allowedQueryKeys: Set<String> = [
        // Open-Meteo geocoding：城市名（用户输入，已披露）
        "name", "count", "language", "format",
        // Open-Meteo forecast：坐标与时段
        "latitude", "longitude", "hourly", "daily",
        "temperature_unit", "timezone", "start_date", "end_date",
    ]

    /// 身体维度绝不出现在出网面上（D5 铁律的出网侧）。
    private static let bodyMarkers = [
        "bust", "waist", "hip", "height", "chest", "inseam", "shape", "body",
    ]

    @Test func noOutboundRequestCarriesBodyOrUnvettedFields() async throws {
        let spy = ComplianceCopyTests.RecordingTransport()
        let weather = OpenMeteoWeatherProvider(transport: spy)
        _ = try? await weather.geocode(name: "Austin")
        _ = try? await weather.forecastDay(latitude: 30, longitude: -97, on: Date())
        _ = try? await weather.searchCities(name: "Aus", limit: 8)
        let facts = OpenProductFactsClient(transport: spy)
        _ = try? await facts.lookup(barcode: "0123456789012")

        let urls = await spy.ledger.urls
        #expect(!urls.isEmpty, "一条请求都没录到 —— 门在空转")

        var offenders: [String] = []
        for url in urls {
            let full = url.absoluteString.lowercased()
            for marker in Self.bodyMarkers where full.contains(marker) {
                offenders.append("\(url.path) ~ 出现身体字段词 \(marker)")
            }
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            for item in comps?.queryItems ?? [] where !Self.allowedQueryKeys.contains(item.name) {
                offenders.append("\(url.path) ~ 未过审的查询参数 \(item.name)")
            }
        }
        #expect(offenders.isEmpty, Comment(rawValue:
            "出网面带上了不该带的东西：\(offenders) —— "
            + "身体维度永不出网（D5）；新参数先加进白名单并说明它是什么"))
    }

    /// 门自身要能抓到真违规——白名单判据最容易写成「什么都放过」。
    @Test func theWhiteListActuallyRejectsSomething() {
        #expect(!Self.allowedQueryKeys.contains("bust_inches"))
        #expect(!Self.allowedQueryKeys.contains("body_shape"))
        #expect(Self.allowedQueryKeys.contains("latitude"))
    }
}
