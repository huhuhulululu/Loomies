import Foundation

/// outfit 语法违规类型（DESIGN §F4：成套完整性 + 互斥）。
public enum GrammarViolation: Sendable, Equatable {
    case missingTop            // 无连衣裙且无上装
    case missingBottom         // 无连衣裙且无下装
    case missingShoes          // 鞋必选
    case dressWithSeparates    // 连衣裙不应与单独上装/下装同现
    case duplicate(GarmentSlot)      // 基底槽位重复（如两件下装）
    case duplicateSubtype(String)    // 同型外套重复（如两件 blazer）
}

/// outfit 语法校验（纯函数）。
public enum OutfitGrammar {

    public static func isValid(_ items: [CandidateItem]) -> Bool {
        violations(items).isEmpty
    }

    public static func violations(_ items: [CandidateItem]) -> [GrammarViolation] {
        var result: [GrammarViolation] = []
        let tops = items.filter { $0.slot == .top }
        let bottoms = items.filter { $0.slot == .bottom }
        let dresses = items.filter { $0.slot == .dress }
        let shoesItems = items.filter { $0.slot == .shoes }
        let outerwear = items.filter { $0.slot == .outerwear }

        if dresses.isEmpty {
            if tops.isEmpty { result.append(.missingTop) }
            if bottoms.isEmpty { result.append(.missingBottom) }
        } else if !tops.isEmpty || !bottoms.isEmpty {
            result.append(.dressWithSeparates)
        }
        if shoesItems.isEmpty { result.append(.missingShoes) }

        if tops.count > 1 { result.append(.duplicate(.top)) }
        if bottoms.count > 1 { result.append(.duplicate(.bottom)) }
        if dresses.count > 1 { result.append(.duplicate(.dress)) }
        if shoesItems.count > 1 { result.append(.duplicate(.shoes)) }

        var subtypeCounts: [String: Int] = [:]
        for o in outerwear {
            // 归一化（trim + 小写），与 CandidateFilter 场合归一化一致：写入端大小写不一致不能逃脱互斥。
            if let st = o.subtype {
                let key = st.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                // 纯空白 subtype 归一化为 ""：视为无 subtype，不参与互斥计数。
                guard !key.isEmpty else { continue }
                subtypeCounts[key, default: 0] += 1
            }
        }
        // 排序遍历：Dictionary 迭代序随进程 hash seed，violations 是 public API，
        // 多个重复 subtype 时返回顺序不得漂移。
        for st in subtypeCounts.filter({ $0.value > 1 }).keys.sorted() {
            result.append(.duplicateSubtype(st))
        }
        return result
    }
}
