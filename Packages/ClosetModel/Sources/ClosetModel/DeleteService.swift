import Foundation
import SwiftData

public enum DeleteError: Error, Equatable {
    case wardrobeNotEmpty   // 衣柜仍有单品，阻断式删除拒绝
    case personHasWardrobes // 人名下仍有衣柜，阻断式删除拒绝
}

/// 删除级联语义（DESIGN §2.3 删除表，应用层强制）。
public enum DeleteService {

    /// 衣柜删除：阻断式——有单品则拒绝，除非 force（整柜级联删 Item/位置/搭配，WearRecord 保留）。
    public static func deleteWardrobe(_ wardrobe: Wardrobe, force: Bool, in context: ModelContext) throws {
        if !force, !(wardrobe.items ?? []).isEmpty {
            throw DeleteError.wardrobeNotEmpty
        }
        // Wardrobe.items/outfits/locations 为 .cascade → context.delete 级联；
        // WearRecord 无 wardrobe 关系（仅 UUID 软引用）→ 不级联，保留。
        context.delete(wardrobe)
        try? context.save()
    }

    /// 人物删除：阻断式——名下有衣柜则拒绝（须先处置）。
    public static func deletePerson(_ person: Person, in context: ModelContext) throws {
        if !(person.wardrobes ?? []).isEmpty {
            throw DeleteError.personHasWardrobes
        }
        context.delete(person)
        try? context.save()
    }

    /// 单品删除：含它的 Outfit 标「永久缺件」（与转移缺件区分）；WearRecord 保留（统计完整性）。
    public static func deleteItem(_ item: Item, in context: ModelContext) {
        for outfit in (item.outfits ?? []) {
            outfit.permanentlyMissing = true
        }
        context.delete(item)   // WearRecord 用 UUID 软引用，不级联，保留
        try? context.save()
    }

    /// 存放位置节点删除：子树上的 Item 位置归属提升至父节点；子位置也提升至父。
    public static func deleteLocation(_ location: StorageLocation, in context: ModelContext) {
        let parent = location.parent
        for item in (location.items ?? []) {
            item.location = parent
        }
        for child in (location.children ?? []) {
            child.parent = parent
        }
        context.delete(location)
        try? context.save()
    }
}
