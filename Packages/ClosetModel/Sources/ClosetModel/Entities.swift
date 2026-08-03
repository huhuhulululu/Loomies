import Foundation
import SwiftData

// CloudKit 私有库兼容约束（DESIGN §4.2/§11.1）：
// 所有属性 optional 或带默认值；禁 @Attribute(.unique)；关系 optional 且声明 inverse。
// 枚举以 String 存（CloudKit 安全）。身体维度属 PersonBodyProfile 本地域（D5，不进 CloudKit）。

@Model
public final class Person {
    public var id: UUID = UUID()
    public var name: String = ""
    public var coldBias: Int = 0   // 怕冷(+)/怕热(-)偏置
    @Relationship(deleteRule: .cascade, inverse: \Wardrobe.owner)
    public var wardrobes: [Wardrobe]? = []
    public init(name: String = "") { self.name = name }
}

/// 身体维度：独立本地存储域（D5，不进 CloudKit），以 personID 软引用 Person。
@Model
public final class PersonBodyProfile {
    public var id: UUID = UUID()
    public var personID: UUID = UUID()
    public var bustInches: Double?
    public var waistInches: Double?
    public var hipInches: Double?
    public var highHipInches: Double?
    public init(personID: UUID) { self.personID = personID }
}

@Model
public final class Wardrobe {
    public var id: UUID = UUID()
    public var name: String = ""
    public var locationCity: String?   // 决定天气源
    public var owner: Person?
    @Relationship(deleteRule: .cascade, inverse: \Item.wardrobe)
    public var items: [Item]? = []
    @Relationship(deleteRule: .cascade, inverse: \Outfit.wardrobe)
    public var outfits: [Outfit]? = []
    @Relationship(deleteRule: .cascade, inverse: \StorageLocation.wardrobe)
    public var locations: [StorageLocation]? = []
    public init(name: String = "", locationCity: String? = nil) {
        self.name = name; self.locationCity = locationCity
    }
}

/// 存放位置树（自引用）。
@Model
public final class StorageLocation {
    public var id: UUID = UUID()
    public var name: String = ""
    public var wardrobe: Wardrobe?
    public var parent: StorageLocation?
    @Relationship(deleteRule: .nullify, inverse: \StorageLocation.parent)
    public var children: [StorageLocation]? = []
    @Relationship(inverse: \Item.location)
    public var items: [Item]? = []
    public init(name: String = "") { self.name = name }
}

@Model
public final class Item {
    public var id: UUID = UUID()
    public var name: String = ""
    public var wardrobe: Wardrobe?
    public var location: StorageLocation?
    public var statusRaw: String = "available"   // 可用/在洗/干洗/外借/闲置/待处理
    public var revision: Int = 0                 // 每次本地变更自增（合并修复器用）
    public var outfits: [Outfit]? = []           // Outfit.items 的反向（多对多）
    // 推荐引擎所需属性（CloudKit 安全：枚举存 raw、Set 存 Array）
    public var slotRaw: String = "top"           // GarmentSlot
    public var subtype: String?
    public var occasionsRaw: [String] = []       // Set<String> 存为数组
    public var warmthRaw: Int?                   // Warmth rawValue
    public var colorHue: Double?
    public var colorIsNeutral: Bool = false
    public var attributesRaw: [String] = []      // StyleAttribute rawValue 数组
    // 尺码（F2，洗标 OCR 落点）：品牌 + 标称码原文（忠实保真，不跨品牌换算）
    public var brand: String?
    public var sizeLabel: String?                // 原始尺码标签 "M"/"8"/"160/84A"
    public var sizeSystemRaw: String?            // SizeSystem rawValue（us/eu/...）
    // 平铺实测（F2 实测层，optional；喂 FitEngine 最小合身标记）— 加法 schema，不破冻
    public var chestFlatWidthInches: Double?     // 上装胸宽
    public var waistFlatWidthInches: Double?     // 裤/裙腰宽
    public var hipFlatWidthInches: Double?       // 臀宽（可选）
    public init(name: String = "") { self.name = name }
}

@Model
public final class Outfit {
    public var id: UUID = UUID()
    public var name: String = ""
    public var wardrobe: Wardrobe?
    @Relationship(inverse: \Item.outfits)
    public var items: [Item]? = []
    public var missing: Bool = false             // 缺件置灰（转移后成员离柜）
    public var permanentlyMissing: Bool = false  // 永久缺件（成员被删）
    public init(name: String = "") { self.name = name }
}

@Model
public final class WearRecord {
    public var id: UUID = UUID()
    public var date: Date = Date.distantPast
    public var outfitID: UUID?
    public var wardrobeSnapshotID: UUID?         // 固化衣柜快照（转移不改历史统计口径）
    public var wornItemIDs: [String] = []        // 当天穿了哪些单品（uuidString，喂防重复）
    public var fitFeedback: String?              // 紧/合/松
    public init(date: Date, outfitID: UUID? = nil) { self.date = date; self.outfitID = outfitID }
}

@Model
public final class CalendarPlan {
    public var id: UUID = UUID()
    public var date: Date = Date.distantPast
    public var outfit: Outfit?
    public var needsAttention: Bool = false      // 引用缺件搭配时标记
    public init(date: Date) { self.date = date }
}

