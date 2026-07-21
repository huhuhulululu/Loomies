import Foundation

/// 单品风格属性（供体型加权）。取自 research/04 §3.2 扬长避短规则涉及的版型要素。
public enum StyleAttribute: String, Sendable, Hashable, CaseIterable {
    case wrap, belt, highWaist, straightNoWaist   // 腰线相关
    case boatNeck, structuredTop, aLine, lowRise  // 梨形上移视线
    case vNeck, empireWaist, draping              // 苹果友好
    case peplum                                   // 矩形造曲线
    case wideLeg, paddedShoulder                  // 倒三角
}

/// 体型×属性加权表（DESIGN §F4：FFIT×属性二维可配置表，可解释）。
/// 正=扬长、负=避短、0=中性。按大众 5 类键控（FFIT 9 类经 popularCategory 折叠）。
/// 权重值为规则资产初版，最终由造型顾问评审（DESIGN §F4 规则资产运营）。
public enum BodyShapeStyling {

    static let table: [PopularShape: [StyleAttribute: Double]] = [
        .hourglass:        [.wrap: 1, .belt: 1, .highWaist: 1, .straightNoWaist: -1],
        .pear:             [.boatNeck: 1, .structuredTop: 1, .aLine: 1, .lowRise: -1],
        .apple:            [.vNeck: 1, .empireWaist: 1, .wrap: 1, .draping: 1, .belt: -1],
        .rectangle:        [.peplum: 1, .belt: 1, .aLine: 1, .straightNoWaist: -1],
        .invertedTriangle: [.vNeck: 1, .wideLeg: 1, .aLine: 1, .paddedShoulder: -1],
    ]

    public static func weight(_ shape: PopularShape, _ attr: StyleAttribute) -> Double {
        table[shape]?[attr] ?? 0
    }

    /// outfit 对某体型的综合体型加权（累加各单品各属性）。
    public static func affinity(items: [CandidateItem], shape: PopularShape) -> Double {
        items.reduce(0.0) { sum, item in
            sum + item.attributes.reduce(0.0) { $0 + weight(shape, $1) }
        }
    }
}
