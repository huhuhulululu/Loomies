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

    /// 0…1。预赋的前提是**已答过引导**——这条不用参数表达：Today 只在有
    /// active 衣柜时渲染，而衣柜只在 onboarding 完成后才存在，所以进到这里
    /// 就已经答过了。此前的 `onboarded` 参数在每个生产调用点都硬写 true，
    /// false 分支不可达却被测试覆盖着，那种「保证」是没人守的（D98）。
    public static func fraction(itemCount: Int) -> Double {
        guard targetItemCount > 0 else { return 1 }
        let earned = Double(max(0, itemCount)) / Double(targetItemCount)
        return min(1, endowedFraction + earned * (1 - endowedFraction))
    }

    public static func caption(itemCount: Int) -> String {
        let n = max(0, itemCount)
        if n >= targetItemCount {
            return "\(n) pieces in — your closet is ready for daily picks."
        }
        let remaining = targetItemCount - n
        return "\(n) pieces in · \(remaining) more for a closet that carries a full week."
    }

    /// 阶梯**只在 8 件处消失，而北极星区间正好从 8 开始**——用户在 8→20 这段
    /// 完全没人告诉他还差什么（D119）。这条判据决定进度与里程碑陪到哪里。
    public static func showsLadder(itemCount: Int) -> Bool {
        itemCount < targetItemCount
    }

    /// 跨过阈值那一下的**毕业时刻**。此前横幅只是静默消失——
    /// 用户为之努力了二十件，产品一句话都没说（「App 从不标记胜利」）。
    public static let readyHeadline = "Your closet can dress you every day"
    public static func readyBody(itemCount: Int) -> String {
        "\(itemCount) pieces in. From here I'll keep the picks coming — "
            + "add more whenever you like."
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
        /// 参与计数的件里，有没有**真的标了这个场合**的。
        /// 全靠「未标 = 哪都能穿」凑出来的一套，不该被说成「你有一套 work 搭配」——
        /// 未标注参与计数是对的（否则冷启动进度不动），据此点名场合则是替用户下结论。
        public let hasTaggedForOccasion: Bool

        /// 兑现文案——**只说挣来的**，且说的是**衣柜能配出什么**，
        /// 不是「今天能不能穿」：里程碑按槽位覆盖算，而 Today 还过天气门。
        /// 满柜羊毛装在 30°C 天里，说「ready」会让用户点进去发现一套都没有。
        public var headline: String {
            guard canDressOnce else {
                return "No \(occasion) look yet"
            }
            // 没有一件真标了这个场合 → 只说「搭配」，不点名场合
            let noun = hasTaggedForOccasion ? "\(occasion) " : ""
            if reachedWeek {
                let n = distinctLooks >= ActivationProgress.maxReportedLooks
                    ? "\(ActivationProgress.maxReportedLooks)+"
                    : "\(distinctLooks)"
                return "Your closet covers \(n) \(noun)looks — a full week"
            }
            return "Your closet can make \(distinctLooks) "
                + "\(noun)\(distinctLooks == 1 ? "look" : "looks")"
        }

        /// 下一步：缺槽位就点名，够穿了就说还差几套到一周。
        public var nextStep: String {
            if !missingSlots.isEmpty {
                let names = missingSlots.map { $0.displayTitle.lowercased() }
                return "Add \(ActivationProgress.listJoin(names)) to unlock \(occasion) looks."
            }
            // 能穿了但一件都没标这个场合 → 下一步是**标注**，不是继续拍
            if canDressOnce, !hasTaggedForOccasion {
                return "Tag pieces for \(occasion) so they count toward \(occasion) looks."
            }
            guard !reachedWeek else {
                return "Keep adding to widen the rotation."
            }
            let short = max(1, ActivationProgress.weekLooks - distinctLooks)
            return "\(short) more \(short == 1 ? "look" : "looks") to cover a full week."
        }
    }

    /// 「a, b and c」——三项以上不得串成 "a and b and c"。
    /// `public`：D128 的空态缺件句复用同一份，不另造第二套连接规则。
    public static func listJoin(_ items: [String]) -> String {
        guard items.count > 1 else { return items.first ?? "" }
        guard items.count > 2 else { return items.joined(separator: " and ") }
        return items.dropLast().joined(separator: ", ") + " and " + items[items.count - 1]
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
        let tagged = usable.contains { item in
            item.occasions.contains {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == wanted
            }
        }
        return Milestone(
            occasion: wanted.isEmpty ? occasion : wanted,
            canDressOnce: looks > 0,
            distinctLooks: looks,
            reachedWeek: looks >= weekLooks,
            missingSlots: missing,
            hasTaggedForOccasion: tagged)
    }

    /// 全部跟踪场合，顺序固定。
    public static func milestones(items: [CandidateItem]) -> [Milestone] {
        trackedOccasions.map { milestone(occasion: $0, items: items) }
    }

    /// 最该被推到用户眼前的那条。
    /// `statedOccasion`（onboarding 的场合构成，D97）答过就以它打头——
    /// 用户说了主要为什么穿衣，就该先看到那条的进度；没答才退回按进度挑。
    public static func headlineMilestone(
        items: [CandidateItem], statedOccasion: String? = nil
    ) -> Milestone? {
        let all = milestones(items: items)
        guard !all.isEmpty else { return nil }
        if let stated = OccasionMix.parse(statedOccasion),
           let hit = all.first(where: { $0.occasion == stated }) {
            return hit
        }
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
