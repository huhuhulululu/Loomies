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
    /// 个人色彩季型可选（R11），raw 字符串；加法字段
    public var personalColorSeasonRaw: String?
    @Relationship(deleteRule: .cascade, inverse: \Wardrobe.owner)
    public var wardrobes: [Wardrobe]? = []
    public init(name: String = "") { self.name = name }
}

/// 身体维度：独立本地存储域（D5，不进 CloudKit），以 personID 软引用 Person。
/// 双轨：快选大众体型（popularShapeOverride）+ 四围实测（R13 合身门）。
@Model
public final class PersonBodyProfile {
    public var id: UUID = UUID()
    public var personID: UUID = UUID()
    public var bustInches: Double?
    public var waistInches: Double?
    public var hipInches: Double?
    public var highHipInches: Double?
    /// 用户手选大众 5 类（PopularShape.rawValue）；可与实测并存。
    public var popularShapeOverrideRaw: String?
    /// none | visualPick | measured | mixed | provisional
    public var shapeSourceRaw: String?
    /// highHip 是否由腰臀启发式推断（非卷尺实测）。
    public var highHipInferred: Bool = false
    /// BodyMorph 精调乘数（1 = 不偏置）；会话间持久化。
    public var fineChest: Double = 1
    public var fineWaist: Double = 1
    public var fineHip: Double = 1
    public var fineHeight: Double = 1
    /// 展示用身体性别底座：`female` | `male`（AvatarBodySex.rawValue；默认女）。
    public var presentationSexRaw: String?
    /// 展示用人种/表型：`AvatarBodyPhenotype.rawValue`（多人种全 nude 底座）。
    public var presentationPhenotypeRaw: String?
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
    public var barcode: String?                  // 零售条码数字（UPC/EAN/GTIN，Open*Facts 查得；加法 schema）
    // 平铺实测（F2 实测层，optional；喂 FitEngine 最小合身标记）— 加法 schema，不破冻
    public var chestFlatWidthInches: Double?     // 上装胸宽
    public var waistFlatWidthInches: Double?     // 裤/裙腰宽
    public var hipFlatWidthInches: Double?       // 臀宽（可选）
    // 护理与备注（D93，DESIGN §90/§95）——加法 schema，不破冻
    /// CareSymbol rawValue 数组（结构化护理，可由洗标 OCR 填充）
    public var careRaw: [String] = []
    /// 自由备注。**不可信输入**（DESIGN §321）：长度上限与归一在 `ItemNotes`，
    /// 落库前必过 `ItemNotes.sanitize`。
    public var notes: String?
    /// 本地文件相对路径（Application Support/ItemImages/…）；不进 CloudKit 也可仅本机。
    public var localImageRelativePath: String?
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
    // 加法 schema（§11.1 不破冻）
    public var occasionRaw: String?              // 场合
    public var isFavorite: Bool = false          // 收藏
    public var sourceRaw: String?                // copilot | manual
    public var notes: String?
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

/// 转移历史（D94，缺口 #12）。DESIGN 的 Item 属性清单里一直挂着「转移历史」，
/// 而实现只是改 `item.wardrobe`——东西去哪了、什么时候走的，没有任何痕迹。
///
/// **软 UUID 引用**（与 `WearRecord` 同法，不用关系）：删掉一个衣柜不该把
/// 「它曾经在这里」这段事实一并抹掉，而级联关系会。
@Model
public final class TransferRecord {
    public var id: UUID = UUID()
    public var date: Date = Date.distantPast
    public var itemID: UUID?
    public var fromWardrobeID: UUID?
    public var toWardrobeID: UUID?
    public init(itemID: UUID, from: UUID?, to: UUID?, date: Date = Date()) {
        self.itemID = itemID
        self.fromWardrobeID = from
        self.toWardrobeID = to
        self.date = date
    }
}

@Model
public final class CalendarPlan {
    public var id: UUID = UUID()
    public var date: Date = Date.distantPast
    public var outfit: Outfit?
    public var needsAttention: Bool = false      // 引用缺件搭配时标记
    // 加法 schema（§11.1 不破冻）
    /// 日历日键 "yyyy-MM-dd"（写入时区语义固化）。date 是本地午夜瞬时值，
    /// 跨时区后会漂到前一天——查询/去重/展示以 dayKey 为准；空串=旧数据，退回 date 解释。
    public var dayKey: String = ""
    public init(date: Date) { self.date = date }
}

