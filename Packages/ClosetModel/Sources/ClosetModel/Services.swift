import Foundation
import SwiftData
import ClosetCore

// 单品状态枚举复用 ClosetCore.ItemStatus（见 Adapter.swift）；此处只存 statusRaw String。

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

    /// Customer toast when ModelSave fails on Move (sheet stays open).
    public static let saveFailedMessage = "Couldn't move — try again"

    /// Moves item. Returns `false` when ModelSave fails (in-memory wardrobe/missing rolled back).
    @discardableResult
    public static func transfer(_ item: Item, to wardrobe: Wardrobe, in context: ModelContext) -> Bool {
        let previousWardrobe = item.wardrobe
        let previousLocation = item.location
        let previousRevision = item.revision
        item.wardrobe = wardrobe
        item.location = nil   // 位置属源柜（同柜不变量），转移即脱离
        item.revision += 1

        // 重算所有引用该单品的搭配的缺件状态（marking + restore 都在此）
        let affected = item.outfits ?? []
        for outfit in affected {
            recomputeMissing(outfit)
            propagateToCalendarPlans(outfit, in: context)
        }
        guard ModelSave.save(context, label: "transfer") else {
            item.wardrobe = previousWardrobe
            item.location = previousLocation
            item.revision = previousRevision
            for outfit in affected {
                recomputeMissing(outfit)
                propagateToCalendarPlans(outfit, in: context)
            }
            context.rollback()   // 失败变更不得滞留，否则污染下一次无关 save
            AppLog.error("transfer save failed \(item.name)", .data)
            return false
        }
        return true
    }

    /// 重算某搭配的缺件状态：有成员不在本搭配所属衣柜 → 缺件。
    public static func recomputeMissing(_ outfit: Outfit) {
        guard let ownerID = outfit.wardrobe?.id else { outfit.missing = false; return }
        outfit.missing = (outfit.items ?? []).contains { $0.wardrobe?.id != ownerID }
    }

    /// 引用该搭配的 CalendarPlan → needsAttention 与 plan/refresh 同公式（不落盘，
    /// 由 transfer 结尾单次 save——中途 save 会提前提交 pending 变更）。
    private static func propagateToCalendarPlans(_ outfit: Outfit, in context: ModelContext) {
        CalendarPlanService.recomputeAttention(for: outfit, in: context)
    }
}
