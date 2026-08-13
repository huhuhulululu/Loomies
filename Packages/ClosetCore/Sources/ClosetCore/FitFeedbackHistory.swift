import Foundation

/// 用户**穿过之后**报告的合身结论（D196）。
///
/// `FitEngine` 那条是**预测**：拿平铺尺寸与围度算 ease，落进阈值带。
/// 而打卡时那一问（「今天穿着怎么样」）拿到的是**实测**——衣服穿在身上是什么感觉。
/// 预测与实测冲突时，没有理由继续相信预测。
///
/// v1.0 刻意只采集不回流（`FitFeedbackCopy` 的抬头写着这条）。
/// 那个取舍在「还没有足够记录」的阶段是对的，但它带来一个副作用：
/// **App 每次打卡都问，然后什么都不做**——问了不用比不问更糟。
///
/// 收口判据取「够稳才算数」：
/// - 至少 `minimumReports` 次同一个结论（一次可能是那天吃多了）；
/// - 且它必须是**严格多数**（说紧两次、说松两次 = 没有结论，不许挑一个）。
///
/// 不够稳就返回 nil——**宁可不说，不说错**（与本仓 OCR / 主色的三值语义同源）。
public enum FitFeedbackHistory {

    /// 至少要几次同样的反馈才算数。
    ///
    /// 取 2 而不是 3：一件衣服要穿够三次同样感觉才肯承认，
    /// 对「买回来就紧」这种最该被记住的情况反应太慢；
    /// 而 1 次会让「那天吃多了」变成永久结论。
    public static let minimumReports = 2

    public struct Settled: Equatable, Sendable {
        /// 用户反复报告的那个结论。
        public let verdict: FitVerdict
        /// 支持它的次数。
        public let count: Int
        /// 这件衣服一共报告过几次（`count` 之外的是别的结论）。
        public let total: Int

        public init(verdict: FitVerdict, count: Int, total: Int) {
            self.verdict = verdict
            self.count = count
            self.total = total
        }
    }

    public struct Entry: Equatable, Sendable {
        public let itemID: String
        public let verdict: FitVerdict
        public init(itemID: String, verdict: FitVerdict) {
            self.itemID = itemID
            self.verdict = verdict
        }
    }

    /// 逐件收敛出「够稳的那个结论」。没收敛的件不在返回值里（不是给个 nil）。
    public static func settled(from entries: [Entry]) -> [String: Settled] {
        var byItem: [String: [FitVerdict: Int]] = [:]
        for e in entries { byItem[e.itemID, default: [:]][e.verdict, default: 0] += 1 }

        var result: [String: Settled] = [:]
        for (itemID, counts) in byItem {
            let total = counts.values.reduce(0, +)
            // 取次数最多的那个；并列时**没有结论**（下面的严格多数会把它挡掉）
            guard let top = counts.max(by: { $0.value < $1.value }) else { continue }
            let isStrictMajority = top.value * 2 > total
            guard top.value >= minimumReports, isStrictMajority else { continue }
            result[itemID] = Settled(verdict: top.key, count: top.value, total: total)
        }
        return result
    }

    /// 一句用户读得懂的话。**说清这是他自己说的**，不是 App 算的——
    /// 两者混在一起，用户就没法判断该信哪个。
    public static func caption(_ settled: Settled) -> String {
        let times = settled.count == 1 ? "once" : "\(settled.count) times"
        switch settled.verdict {
        case .tight:  return "You've said this felt tight \(times)."
        case .fitted: return "You've said this fit just right \(times)."
        case .loose:  return "You've said this felt loose \(times)."
        }
    }

    /// 实测与预测**不一致**时的说明（只在真不一致时给，别造噪声）。
    public static func disagreementCaption(
        settled: Settled, predicted: FitVerdict
    ) -> String? {
        guard settled.verdict != predicted else { return nil }
        return caption(settled) + " Going with that over the measurements."
    }
}
