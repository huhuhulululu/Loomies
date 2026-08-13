import Foundation
import ClosetModel
import ClosetCore

/// 整套的合身结论（D117）。
///
/// MARKET §2 判定「合身」是竞品都没占的唯一纵深，而本仓早就把它算出来了
/// （`FitMarkService`）——却只挂在网格徽章和详情页上，**Today 的建议行与试衣间
/// 零引用**。用户做「今天穿不穿这套」这个决定的那一刻，屏幕上没有这条信息；
/// 试衣间尤其讽刺：那里的字面问题就是「这件穿在我身上怎么样」。
///
/// 不新增服务、不改排序（守 D85），只把已有结论端到决策现场。
/// 与 `OutfitStorageHint` 同层：纯值逻辑，可单测（本仓无 ViewInspector）。
public enum OutfitFitMark {

    /// 整套里最值得说的那条结论。
    public struct Mark: Equatable, Sendable {
        public let verdict: FitVerdict
        /// 给出该结论的那件（点名，用户才知道要换哪件）。
        public let pieceName: String
        /// 这套里还有几件没有实测——如实说，否则用户以为结论覆盖了整套。
        public let unmeasuredCount: Int

        /// 一行摘要：先给结论，再补覆盖范围。
        public var summary: String {
            let head = "\(FitMarkCopy.label(verdict)) · \(pieceName)"
            guard unmeasuredCount > 0 else { return head }
            let noun = unmeasuredCount == 1 ? "piece" : "pieces"
            return "\(head) · \(unmeasuredCount) \(noun) not measured"
        }
    }

    /// 一件实测都没有时给的**入口**，而不是一片空白——
    /// 走快速添加建库的用户否则永远不知道这条能力存在。
    public static let measureInvite = "Add flat measurements to see how a look will sit"

    /// 严格度排序：紧 > 松 > 合身。
    ///
    /// 「最紧的那件说了算」——决定今天穿不穿这套的是**最勒**的那一件，不是平均值。
    /// 偏松排在合身之前，是因为它同样值得一提（版型不对），只是不如偏紧要紧。
    private static func severity(_ v: FitVerdict) -> Int {
        switch v {
        case .tight:  return 2
        case .loose:  return 1
        case .fitted: return 0
        }
    }

    /// 计算整套的结论。无档案 / 全套无实测 → nil（不编）。
    @MainActor
    public static func tightest(items: [Item], profile: PersonBodyProfile?) -> Mark? {
        guard let profile else { return nil }
        var best: (verdict: FitVerdict, name: String)?
        var unmeasured = 0
        // 名称升序遍历：同严格度打平时结论确定，不随集合顺序漂移
        for item in items.sortedByName() {
            guard let verdict = FitMarkService.mark(item: item, profile: profile) else {
                unmeasured += 1
                continue
            }
            if best == nil || severity(verdict) > severity(best!.verdict) {
                best = (verdict, item.name)
            }
        }
        guard let best else { return nil }
        return Mark(verdict: best.verdict, pieceName: best.name, unmeasuredCount: unmeasured)
    }

    /// 单件版（试衣间的 chip 用）。
    @MainActor
    public static func mark(for item: Item, profile: PersonBodyProfile?) -> String? {
        guard let profile, let verdict = FitMarkService.mark(item: item, profile: profile)
        else { return nil }
        return FitMarkCopy.label(verdict)
    }
}
