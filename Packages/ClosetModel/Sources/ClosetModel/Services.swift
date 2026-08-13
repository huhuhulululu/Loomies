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
    public static func transfer(
        _ item: Item, to wardrobe: Wardrobe, in context: ModelContext, on date: Date = Date()
    ) -> Bool {
        // D145：**转到它已经在的那个柜 = 什么都不该发生。**
        // 没有这道守卫的话，下面会照常把 `item.location` 抹掉
        //（理由是「位置属源柜，转移即脱离」——可这次根本没换柜），
        // 还写一条「从 A 到 A」的历史。批量版 `transferAll` 与单件 VM
        // 各自在外面挡了一次，唯独服务自己没挡——挡在调用方的不变量，
        // 迟早会有第三个调用方不知道。
        guard item.wardrobe?.id != wardrobe.id else { return true }
        let previousWardrobe = item.wardrobe
        let previousLocation = item.location
        let previousRevision = item.revision
        item.wardrobe = wardrobe
        item.location = nil   // 位置属源柜（同柜不变量），转移即脱离
        item.revision += 1
        // 历史与移动**同一次 save**：失败一起回滚，历史不得声称发生过没发生的事
        let record = TransferRecord(
            itemID: item.id, from: previousWardrobe?.id, to: wardrobe.id, date: date)
        context.insert(record)

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
            // 断关系 + rollback：pending insert 的历史一并丢弃（delete 只删行，脏标记滞留）
            record.itemID = nil
            context.rollback()   // 失败变更不得滞留，否则污染下一次无关 save
            AppLog.error("transfer save failed item=\(AppLog.ref(item.id))", .data)
            return false
        }
        return true
    }

    // MARK: - 批量转移（D94）

    /// 批量结果。**逐项如实**：搬了几件、几件本来就在那、几件失败。
    public struct BatchOutcome: Sendable, Equatable {
        public let moved: Int
        public let alreadyThere: Int
        public let failed: Int

        /// 零项不提（噪音），且**全失败不得说成 "Moved 0"** 这种像成功的话。
        public var summary: String {
            var parts: [String] = []
            if moved > 0 { parts.append("Moved \(moved) \(moved == 1 ? "piece" : "pieces")") }
            if alreadyThere > 0 { parts.append("\(alreadyThere) already there") }
            if failed > 0 {
                parts.append("\(failed) couldn't be moved")
            }
            guard !parts.isEmpty else { return "Nothing to move." }
            return parts.joined(separator: " · ") + "."
        }
    }

    /// 逐件走同一条 `transfer` 路径——批量不另开一套语义
    /// （搭配缺件重算、历史、原子性全都跟着走）。
    @discardableResult
    public static func transferAll(
        _ items: [Item], to wardrobe: Wardrobe, in context: ModelContext, on date: Date = Date()
    ) -> BatchOutcome {
        var moved = 0, already = 0, failed = 0
        // 顺序确定：同名按 id 决胜（批量结果可复现）
        for item in items.sorted(by: { ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString) }) {
            if item.wardrobe?.id == wardrobe.id {
                already += 1
                continue
            }
            if transfer(item, to: wardrobe, in: context, on: date) { moved += 1 } else { failed += 1 }
        }
        return BatchOutcome(moved: moved, alreadyThere: already, failed: failed)
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
