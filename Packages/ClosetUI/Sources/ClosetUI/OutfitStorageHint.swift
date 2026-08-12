import Foundation
import ClosetModel
import ClosetCore

/// 推荐卡的「去哪拿」提示（D90，缺口 #15；DESIGN §10.3 省一次跳转）。
///
/// 用户决定「今天穿这套」之后的下一个动作是把它们取出来——此前得逐件点进详情页
/// 才知道在哪。纯值逻辑，可单测（本仓无 ViewInspector，View 本身不可测）。
public enum OutfitStorageHint {

    /// 单套的存放位置摘要。全无位置 → nil（不显示空行，也不编「Unknown」）。
    /// 部分有位置 → 只说知道的，并**如实**补一句还有几件没标，
    /// 免得用户以为列出的就是全部。
    public static func text(pairs: [(piece: String, location: String?)]) -> String? {
        var byLocation: [String: [String]] = [:]
        var unplaced = 0
        for pair in pairs {
            guard let loc = TextNormalize.blankToNil(pair.location) else {
                unplaced += 1
                continue
            }
            let piece = TextNormalize.blankToNil(pair.piece) ?? "Piece"
            byLocation[loc, default: []].append(piece)
        }
        guard !byLocation.isEmpty else { return nil }

        let placedTail = unplaced > 0
            ? " · \(unplaced) not placed"
            : ""
        // 全在一个位置**且没有漏网的**：说一句就够，不重复罗列每件。
        // 有没标位置的件时不能说 "All"——那句话与后半句自相矛盾。
        if byLocation.count == 1, unplaced == 0, let (loc, _) = byLocation.first {
            return "All in \(loc)"
        }
        // 位置按名排序、位置内单品按名排序——顺序不得随传入顺序漂移
        let body = byLocation.keys.sorted()
            .map { loc in "\(loc): \(byLocation[loc]!.sorted().joined(separator: ", "))" }
            .joined(separator: " · ")
        return body + placedTail
    }

    /// 从衣柜单品解析。只算这套里的件（跨柜边界由调用方传入的 items 保证）。
    @MainActor
    public static func text(forItemIDs ids: [String], in items: [Item]) -> String? {
        let wanted = Set(ids)
        let pairs = items
            .filter { wanted.contains($0.id.uuidString) }
            .map { (piece: $0.name, location: $0.location?.name) }
        return text(pairs: pairs)
    }
}

/// 冷启动双路径文案（D91，DESIGN §475）。真实起步那条要给**具体到能立刻做**的动作，
/// 不是「去 Closet 加点东西」这种没有下一步的句子。
public enum CopilotColdStartCopy {
    // 文案必须描述按钮**实际**做的事：它开的是「相册/相机/手填」选择器，
    // 不是直接举起相机（D98：原文案 "Shoot today's outfit" 与行为不符）。
    public static let realStartTitle = "Add 3 pieces — about 30 seconds"
    public static let realStartAccessibilityHint =
        "Opens the add-piece sheet: choose photos, take one, or type details"

    /// D116：衣柜还太小、又没挑定任何一件时说的话。
    /// 此前这里是 `"Cold start: anchor at least one piece first."`——
    /// 「cold start」「anchor」是**引擎的词**，不是用户的词；
    /// 而这句话出现在第一次真正用 App 的那一刻，是整个产品的第一印象。
    public static let pickOnePrompt =
        "Pick a piece you feel like wearing — I'll build the rest around it."

    /// 一件都没有时。指出去哪拿衣服，而不是陈述一个状态。
    public static let emptyClosetPrompt =
        "Your closet is empty. Add a few pieces, or load samples to look around first."
}
