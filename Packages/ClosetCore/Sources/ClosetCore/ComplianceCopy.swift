import Foundation

/// 真实出网面清单（D86）。**这是披露的单一真相**：任何新增的网络请求
/// 都必须在此登记，否则 `ComplianceCopyTests.everyOutboundHostIsDisclosed` 变红。
/// 教训：旧 About 文案笼统写「images never leave」，而条码查询其实会把用户扫到的
/// 商品条码（= 用户拥有的具体商品身份）发往 Open*Facts。
public enum NetworkSurfaceCatalog {

    public struct Surface: Sendable, Equatable, Identifiable {
        public let id: String
        public let title: String
        /// 发出去的到底是什么（用用户听得懂的话，不是字段名）。
        public let sends: String
        /// 什么时候发。
        public let trigger: String
        /// 能不能不发 / 怎么关。
        public let optOut: String
        public let hosts: [String]
    }

    public static let surfaces: [Surface] = [
        Surface(
            id: "weather",
            title: "Weather",
            sends: "The city name you set for a closet — no closet contents, no photos, no identifiers.",
            trigger: "When Today loads or you change a closet's city.",
            optOut: "Leave the closet's city empty; the app falls back to an offline climate estimate.",
            hosts: ["geocoding-api.open-meteo.com", "api.open-meteo.com"]),
        Surface(
            id: "barcode",
            title: "Barcode lookup",
            sends: "The barcode you scanned — this identifies a specific product you own.",
            trigger: "Only when you scan or enter a barcode while adding a piece.",
            optOut: "Skip the barcode step and type the brand and size yourself.",
            hosts: [
                "world.openproductsfacts.org",
                "world.openbeautyfacts.org",
                "world.openfoodfacts.org",
            ]),
    ]
}

/// 产品外壳的合规文案（§10.6：帮助/FAQ、政策链接、开源署名、隐私摘要）。
/// 铁律：**不得承诺产品没有的能力**——旧 About 声称遥测「opt-in when enabled」
/// 而开关与发送出口都不存在，正是本波要消灭的缺陷。
public enum ComplianceCopy {

    public struct Attribution: Sendable, Equatable, Identifiable {
        public let name: String
        public let license: String
        public let usage: String
        public var id: String { name }
    }

    public struct FAQEntry: Sendable, Equatable, Identifiable {
        public let question: String
        public let answer: String
        public var id: String { question }
    }

    public struct PolicyLink: Sendable, Equatable, Identifiable {
        public let title: String
        public let url: URL
        public var id: String { title }
    }

    /// 隐私摘要：只说做得到的。身体维度本地域是 D5 + schema 守卫双锁的事实。
    public static let privacySummary =
        "Your closet, photos, and body measurements live on this device. "
        + "Body measurements are kept in a separate local store and are never synced. "
        + "Two features do reach the internet — see \"What leaves my device\" below for exactly what and when."

    /// 遥测状态行。当前没有任何发送出口（无 SDK），措辞不得暗示正在上报。
    public static func telemetryStatusLine(enabled: Bool) -> String {
        enabled
            ? "Anonymous usage stats: on. Nothing is sent yet — no analytics service is connected in this build."
            : "Anonymous usage stats: off. Nothing is collected or sent."
    }

    /// 逐项开源署名（§4.3 许可红线）。按 name 排序——确定性，且 UI 直接铺。
    public static let attributions: [Attribution] = [
        Attribution(
            name: "FFIT body-shape research",
            license: "Academic literature (methodology, no code)",
            usage: "Body-shape classification thresholds."),
        Attribution(
            name: "Open Food Facts / Open Products Facts / Open Beauty Facts",
            license: "Open Database License (ODbL)",
            usage: "Optional barcode lookup for brand and size."),
        Attribution(
            name: "Open-Meteo",
            license: "CC BY 4.0 (data), Apache-2.0 (API)",
            usage: "Daily temperature and precipitation for your closet's city."),
    ].sorted { $0.name < $1.name }

    public static let faq: [FAQEntry] = [
        FAQEntry(
            question: "What leaves my device?",
            answer: "Only two things. Your closet's city name goes to Open-Meteo for the "
                + "forecast, and a barcode goes to the Open Facts databases when you scan one. "
                + "Photos, item names, body measurements, and looks never leave."),
        FAQEntry(
            question: "Why is my recommendation empty?",
            answer: "Pieces are filtered by today's temperature, the occasion you picked, and "
                + "anything you wore in the last 7 days. Setting each piece's warmth helps most — "
                + "an unset warmth is treated as unknown and is never filtered out."),
        FAQEntry(
            question: "Can I try clothes on?",
            answer: "The fitting room dresses a body-shape avatar with your item photos so you "
                + "can judge proportion and color. It is not a photo-realistic try-on of your own body."),
        FAQEntry(
            question: "How do I delete everything?",
            answer: "Me → Data → Delete all data removes closets, pieces, looks, wear history, "
                + "plans, and local photos from this device. Uninstalling the app alone does not."),
        FAQEntry(
            question: "Where are my body measurements stored?",
            answer: "In a separate local store on this device that is excluded from cloud sync. "
                + "They are left out of data exports unless you explicitly include them."),
    ]

    public static let policyLinks: [PolicyLink] = [
        PolicyLink(title: "Privacy Policy", url: URL(string: "https://loomies.app/privacy")!),
        PolicyLink(title: "Terms of Use", url: URL(string: "https://loomies.app/terms")!),
    ]

    /// 帮助与反馈：反馈通道复用既有诊断导出（不虚构邮箱/工单系统）。
    public static let feedbackTitle = "Send feedback"
    public static let feedbackBody =
        "Export diagnostics from Me → Support and attach it to your message — "
        + "it contains counts and recent logs, with closet names and city removed."
}
