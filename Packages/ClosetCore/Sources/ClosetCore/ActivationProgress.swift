import Foundation

/// 冷启动激活进度与场合里程碑（D91，缺口 #14；MVP critic 标 critical）。
///
/// DESIGN §475：「录入激励用**预赋进度**（答完引导问题即显 20%）+ 按**场合里程碑**
/// 即时兑现推荐（『通勤装满 10 件，已可生成一周通勤搭配』）」。
///
/// 本项目铁律在这里最容易破：里程碑文案是**承诺**。说「已可生成一周通勤搭配」
/// 就必须真的能凑出 7 套不重样的——按槽位覆盖算，不是数够 10 件就吹。
/// 组合口径与 `OutfitGrammar` 一致：连衣裙独立成套，否则上下装齐，两种都必须有鞋。
public enum ActivationProgress {

    /// 答完引导问题即预赋的进度（DESIGN 明文 20%）。
    public static let endowedFraction = 0.2

    /// 进度条的「满」对应的件数。北极星是 7 天数字化 40 件（MARKET §7），
    /// 但进度条要在**可用**这个点满——40 件是留存目标，不是能用的门槛。
    public static let targetItemCount = 20

    /// 「一周不重样」的口径 = 7（防重复窗口就是 7 天，说少了会自相矛盾）。
    public static let weekLooks = 7

    /// 组合数上报封顶——大衣柜报「你能生成 4096 套」没有意义。
    public static let maxReportedLooks = 30

    /// 里程碑跟踪的场合（顺序确定，UI 直接铺）。
    public static let trackedOccasions = ["work", "casual", "date", "gala"]

    // MARK: - 预赋进度

    /// 0…1。`onboarded` 为假时不预赋——凭空的进度是骗人的。
    public static func fraction(itemCount: Int, onboarded: Bool) -> Double {
        guard onboarded else { return 0 }
        guard targetItemCount > 0 else { return 1 }
        let earned = Double(max(0, itemCount)) / Double(targetItemCount)
        return min(1, endowedFraction + earned * (1 - endowedFraction))
    }

    public static func caption(itemCount: Int, onboarded: Bool) -> String {
        let n = max(0, itemCount)
        guard onboarded else { return "Answer a couple of questions to get started." }
        if n >= targetItemCount {
            return "\(n) pieces in — your closet is ready for daily picks."
        }
        let remaining = targetItemCount - n
        return "\(n) pieces in · \(remaining) more for a closet that carries a full week."
    }

    // MARK: - 场合里程碑

    public struct Milestone: Sendable, Equatable {
        public let occasion: String
        /// 至少能穿出去一次（上下装齐或连衣裙，且有鞋）。
        public let canDressOnce: Bool
        /// 当前能拼出的不重样套数（封顶 `maxReportedLooks`）。
        public let distinctLooks: Int
        /// 够不够 7 天不重样。
        public let reachedWeek: Bool
        /// 还缺哪些槽位（用户才知道下一件该拍什么）。
        public let missingSlots: [GarmentSlot]

        /// 兑现文案——**只说挣来的**。
        public var headline: String {
            guard canDressOnce else {
                return "No \(occasion) look yet"
            }
            if reachedWeek {
                let n = distinctLooks >= ActivationProgress.maxReportedLooks
                    ? "\(ActivationProgress.maxReportedLooks)+"
                    : "\(distinctLooks)"
                return "\(n) \(occasion) looks — enough for a full week"
            }
            return "\(distinctLooks) \(occasion) \(distinctLooks == 1 ? "look" : "looks") ready"
        }

        /// 下一步：缺槽位就点名，够穿了就说还差几套到一周。
        public var nextStep: String {
            if let missing = missingSlots.first {
                let names = missingSlots.map { $0.displayTitle.lowercased() }
                    .joined(separator: " and ")
                _ = missing
                return "Add \(names) to unlock \(occasion) looks."
            }
            guard !reachedWeek else {
                return "Keep adding to widen the rotation."
            }
            let short = max(1, ActivationProgress.weekLooks - distinctLooks)
            return "\(short) more \(short == 1 ? "look" : "looks") to cover a full week."
        }
    }

    /// 单场合里程碑。只算**该场合可用**的件；场合未标注（空集）视为「哪都能穿」，
    /// 与 `CandidateFilter` 的三值语义一致——否则刚入库还没标场合的件全被忽略，
    /// 冷启动阶段进度永远不动。
    public static func milestone(occasion: String, items: [CandidateItem]) -> Milestone {
        let wanted = occasion.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let usable = items.filter { item in
            guard item.status == .available else { return false }
            guard !item.occasions.isEmpty else { return true }   // 未知 = 哪都能穿
            let normalized = item.occasions.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
            return wanted.isEmpty || normalized.contains(wanted)
        }
        func count(_ slot: GarmentSlot) -> Int { usable.filter { $0.slot == slot }.count }
        let tops = count(.top), bottoms = count(.bottom)
        let dresses = count(.dress), shoes = count(.shoes)

        var missing: [GarmentSlot] = []
        if shoes == 0 { missing.append(.shoes) }
        if dresses == 0 {
            if tops == 0 { missing.append(.top) }
            if bottoms == 0 { missing.append(.bottom) }
        }
        // 缺项顺序确定（按 slot 原始序），UI 与 VoiceOver 不随集合序漂移
        missing.sort { $0.rawValue < $1.rawValue }

        let combos = shoes > 0 ? (tops * bottoms + dresses) : 0
        let looks = min(combos, maxReportedLooks)
        return Milestone(
            occasion: wanted.isEmpty ? occasion : wanted,
            canDressOnce: looks > 0,
            distinctLooks: looks,
            reachedWeek: looks >= weekLooks,
            missingSlots: missing)
    }

    /// 全部跟踪场合，顺序固定。
    public static func milestones(items: [CandidateItem]) -> [Milestone] {
        trackedOccasions.map { milestone(occasion: $0, items: items) }
    }

    /// 最该被推到用户眼前的那条：已兑现的挑最接近一周的，都没兑现就挑最接近能穿的。
    public static func headlineMilestone(items: [CandidateItem]) -> Milestone? {
        let all = milestones(items: items)
        guard !all.isEmpty else { return nil }
        // (能穿, 套数, 场合序) —— 全确定，无随机
        return all.max { a, b in
            if a.canDressOnce != b.canDressOnce { return !a.canDressOnce }
            if a.distinctLooks != b.distinctLooks { return a.distinctLooks < b.distinctLooks }
            let ia = trackedOccasions.firstIndex(of: a.occasion) ?? 0
            let ib = trackedOccasions.firstIndex(of: b.occasion) ?? 0
            return ia > ib
        }
    }
}
