import Foundation

/// 外套细分型的按名推断（D130）。
///
/// `OutfitGrammar` 会按 `subtype` 拒绝「一套里两件 blazer」——而
/// `Item.subtype` **生产里没有任何写入方**：入库不写、编辑器不写，
/// 只有导入会写（而导出源本身也从没设过）。规则写了、测了，永远不触发。
///
/// 不删规则（它编码的是真实穿搭常识），给它一个**真实来源**：按名字判型。
/// 这正是 `GarmentSlot.resolved` 已经在用的手法——数据本来就有，只是没人读。
///
/// 判断标准同 D123 的 OCR：**宁缺勿错**。判错型会把两件本可同穿的衣服
/// 判成冲突，用户看不到他期待的那套，而且无从得知为什么。
public enum GarmentSubtype {

    /// 名称关键词 → 型。顺序有意义：更具体的排前面
    /// （"leather jacket" 要在 "jacket" 之前命中）。
    private static let rules: [(keywords: [String], subtype: String)] = [
        (["trench"], "trench"),
        (["puffer", "down jacket"], "puffer"),
        (["denim jacket", "jean jacket"], "denim jacket"),
        (["leather jacket", "biker"], "leather jacket"),
        (["blazer"], "blazer"),
        (["peacoat", "pea coat"], "peacoat"),
        (["parka"], "parka"),
        (["cardigan"], "cardigan"),
    ]

    /// 这些词出现时**不判型**：它们说明这不是一件外套
    /// （「blazer dress」是连衣裙，不是西装外套）。
    private static let disqualifiers = ["dress", "skirt", "trouser", "pant", "jean short"]

    public static func inferred(name: String) -> String? {
        let key = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !key.isEmpty else { return nil }
        guard !disqualifiers.contains(where: { key.contains($0) }) else { return nil }
        for rule in rules where rule.keywords.contains(where: { key.contains($0) }) {
            return rule.subtype
        }
        return nil
    }
}
