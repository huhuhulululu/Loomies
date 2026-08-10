import Foundation
import SwiftData
import ClosetCore

public enum DeleteError: Error, Equatable, LocalizedError {
    case wardrobeNotEmpty   // 衣柜仍有单品，阻断式删除拒绝
    case personHasWardrobes // 人名下仍有衣柜，阻断式删除拒绝
    case saveFailed         // ModelSave failed after delete (not silent success)

    /// Customer-facing en-US (Me delete flows; never raw enum dump).
    public var errorDescription: String? {
        switch self {
        case .wardrobeNotEmpty:
            return "This closet still has pieces. Remove or move them first."
        case .personHasWardrobes:
            return "This person still has closets. Remove them first."
        case .saveFailed:
            return "Couldn't delete — try again"
        }
    }
}

/// 删除级联语义（DESIGN §2.3 删除表，应用层强制）。
public enum DeleteService {

    /// 衣柜删除：阻断式——有单品则拒绝，除非 force（整柜级联删 Item/位置/搭配，WearRecord 保留）。
    /// Throws `saveFailed` when ModelSave does not commit (caller must not toast success).
    public static func deleteWardrobe(_ wardrobe: Wardrobe, force: Bool, in context: ModelContext) throws {
        if !force, !(wardrobe.items ?? []).isEmpty {
            throw DeleteError.wardrobeNotEmpty
        }
        // Wardrobe.items/outfits/locations 为 .cascade → context.delete 级联；
        // WearRecord 无 wardrobe 关系（仅 UUID 软引用）→ 不级联，保留。
        // 绑定本柜搭配的 CalendarPlan 一并删除——否则 outfit 级联删后 plan 成孤儿
        //（outfit 被 nullify + needsAttention 残留），与级联语义不一致。
        let outfitIDs = Set((wardrobe.outfits ?? []).map(\.id))
        if !outfitIDs.isEmpty {
            let plans = (try? context.fetch(FetchDescriptor<CalendarPlan>())) ?? []
            for plan in plans where plan.outfit.map({ outfitIDs.contains($0.id) }) == true {
                context.delete(plan)
            }
        }
        // 先收集团片相对路径——save 提交后才删文件（失败回滚时单品仍在，图须保留）。
        let imagePaths = (wardrobe.items ?? []).compactMap(\.localImageRelativePath)
        context.delete(wardrobe)
        guard ModelSave.save(context, label: "deleteWardrobe") else {
            context.rollback()   // 失败删除不得滞留，否则污染下一次无关 save
            throw DeleteError.saveFailed
        }
        for path in imagePaths {
            ItemImageStore.delete(relativePath: path)
        }
    }

    /// 人物删除：阻断式——名下有衣柜则拒绝（须先处置）。
    /// Throws `saveFailed` when ModelSave does not commit.
    public static func deletePerson(_ person: Person, in context: ModelContext) throws {
        if !(person.wardrobes ?? []).isEmpty {
            throw DeleteError.personHasWardrobes
        }
        // PersonBodyProfile 以 personID 软引用（D5 本地域）——最敏感数据不得
        // 在其人删除后残留；随同一 save 删除，失败同路径 rollback。
        let profiles = (try? context.fetch(FetchDescriptor<PersonBodyProfile>())) ?? []
        for profile in profiles where profile.personID == person.id {
            context.delete(profile)
        }
        context.delete(person)
        guard ModelSave.save(context, label: "deletePerson") else {
            context.rollback()   // 失败删除不得滞留
            throw DeleteError.saveFailed
        }
    }

    /// 单品删除：含它的 Outfit 标「永久缺件」（与转移缺件区分）；WearRecord 保留（统计完整性）。
    /// Calendar plans bound to those looks flip needsAttention (Attention filter).
    /// 本地图随 commit 一并删除（与 deleteWardrobe 同责任模型——不再外包给调用方；
    /// 调用方重复删幂等无害）。失败保留文件（DB 行还在，删图会产生反向孤儿）。
    /// - Returns: `true` when the save committed (caller may dismiss).
    @discardableResult
    public static func deleteItem(_ item: Item, in context: ModelContext) -> Bool {
        let imagePath = item.localImageRelativePath
        let affected = item.outfits ?? []
        let previousFlags = affected.map(\.permanentlyMissing)
        for outfit in affected {
            outfit.permanentlyMissing = true
        }
        // Refresh before delete so outfit.id still matches plan.outfit.
        // 不落盘重算——本操作仅结尾一次 save（中途 save 会提前提交 permanentlyMissing）。
        for outfit in affected {
            CalendarPlanService.recomputeAttention(for: outfit, in: context)
        }
        context.delete(item)   // WearRecord 用 UUID 软引用，不级联，保留
        guard ModelSave.save(context, label: "deleteItem") else {
            // 内存值还原（rollback 不回写已置的内存属性）+ rollback 清脏标记
            for (index, outfit) in affected.enumerated() {
                outfit.permanentlyMissing = previousFlags[index]
                CalendarPlanService.recomputeAttention(for: outfit, in: context)
            }
            context.rollback()   // 失败删除不得滞留，否则污染下一次无关 save
            AppLog.error("deleteItem save failed item=\(AppLog.ref(item.id))", .data)
            return false
        }
        ItemImageStore.delete(relativePath: imagePath)
        return true
    }

    /// 存放位置节点删除：子树上的 Item 位置归属提升至父节点；子位置也提升至父。
    @discardableResult
    public static func deleteLocation(_ location: StorageLocation, in context: ModelContext) -> Bool {
        let parent = location.parent
        let items = location.items ?? []
        let children = location.children ?? []
        // 内存值快照（rollback 不回写已置的内存属性）——失败路径须逐一还原
        let previousItemLocations = items.map { ($0, $0.location) }
        let previousChildParents = children.map { ($0, $0.parent) }
        for item in items {
            item.location = parent
        }
        for child in children {
            child.parent = parent
        }
        context.delete(location)
        guard ModelSave.save(context, label: "deleteLocation") else {
            // 内存值还原 + rollback 清脏标记——失败提升不得留在 UI 内存态
            for (item, previous) in previousItemLocations {
                item.location = previous
            }
            for (child, previous) in previousChildParents {
                child.parent = previous
            }
            context.rollback()   // 失败删除不得滞留
            AppLog.error("deleteLocation save failed location=\(AppLog.ref(location.id))", .data)
            return false
        }
        return true
    }
}
