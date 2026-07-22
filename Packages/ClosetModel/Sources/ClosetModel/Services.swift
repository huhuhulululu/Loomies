import Foundation
import SwiftData

/// 单品状态（枚举，String 存储 CloudKit 安全）。
public enum ItemStatus: String, Sendable, CaseIterable {
    case available, inWash, dryCleaning, lent, idle, pending
}

/// 跨衣柜不变量（DESIGN §2.3，用户硬约束）：Outfit 只能引用本衣柜内的 Item。
public enum WardrobeInvariant {
    public static func isValid(_ outfit: Outfit) -> Bool {
        guard let ownerID = outfit.wardrobe?.id else { return false }
        return (outfit.items ?? []).allSatisfy { $0.wardrobe?.id == ownerID }
    }
}

/// 转移服务（DESIGN §2.3 转移级联表）：转移单品 → 原柜引用它的 Outfit 标缺件 → 相关 CalendarPlan 标待处理；
/// 转回自动恢复。应用层强制（CloudKit 最终一致下不能靠 SwiftData delete rule 表达）。
public enum TransferService {

    public static func transfer(_ item: Item, to wardrobe: Wardrobe, in context: ModelContext) {
        item.wardrobe = wardrobe
        item.revision += 1

        // 重算所有引用该单品的搭配的缺件状态（marking + restore 都在此）
        let affected = item.outfits ?? []
        for outfit in affected {
            recomputeMissing(outfit)
            propagateToCalendarPlans(outfit, in: context)
        }
        try? context.save()
    }

    /// 重算某搭配的缺件状态：有成员不在本搭配所属衣柜 → 缺件。
    public static func recomputeMissing(_ outfit: Outfit) {
        guard let ownerID = outfit.wardrobe?.id else { outfit.missing = false; return }
        outfit.missing = (outfit.items ?? []).contains { $0.wardrobe?.id != ownerID }
    }

    /// 引用该搭配的 CalendarPlan → needsAttention 跟随搭配缺件状态。
    private static func propagateToCalendarPlans(_ outfit: Outfit, in context: ModelContext) {
        let plans = (try? context.fetch(FetchDescriptor<CalendarPlan>())) ?? []
        for plan in plans where plan.outfit?.id == outfit.id {
            plan.needsAttention = outfit.missing
        }
    }
}
