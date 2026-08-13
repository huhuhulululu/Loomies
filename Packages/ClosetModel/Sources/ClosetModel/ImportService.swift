import Foundation
import SwiftData
import ClosetCore

/// 数据导入（D122）。
///
/// 隐私政策里写着「Export my data … so you can take everything with you」——
/// 可搬出去之后**没有任何地方能搬回来**：换手机、误删、从别的 App 迁过来，
/// 用户都得把几小时的录入重做一遍。一条只出不进的通道算不上数据可携带性。
///
/// 三条取舍都关系到「会不会把用户已有的东西弄坏」：
/// 1. **只增不改**——永远建新衣柜，绝不覆盖或合并。合并要用户逐条裁决冲突，
///    那是一整个交互；在没有它之前，「不碰你已有的东西」是唯一安全的默认。
/// 2. **如实报告**——导入了几件、照片没跟过来，都要说出口。
/// 3. **不可信输入**——文件可能来自任何人：坏 JSON、更高的 schema 版本、
///    指向本机不存在的图片路径，都不能让 App 崩或写脏库。
public enum ImportService {

    public enum ImportError: Error, Equatable {
        /// 解不出快照（不是本 App 的导出，或文件坏了）。
        case unreadable
        /// 来自更新版本的 App——**不猜**，让用户先升级。
        case newerSchema(found: Int, supported: Int)
        /// 落库失败（已整体回滚）。
        case saveFailed
    }

    /// 本 App 能读的最高快照版本。
    public static let supportedSchemaVersion = 1

    public struct Receipt: Equatable, Sendable {
        public let wardrobesAdded: Int
        public let itemsAdded: Int
        public let outfitsAdded: Int
        /// 指向本机不存在的图片、被清掉的件数。
        public let imagePathsCleared: Int

        /// 用户读得懂的收据。**必须点名照片没跟过来**——
        /// JSON 里只有路径没有像素，不说清用户会以为图也回来了。
        public var summary: String {
            guard wardrobesAdded > 0 || itemsAdded > 0 else {
                return "Nothing to import — that file had no closets or pieces."
            }
            let pieces = itemsAdded == 1 ? "1 piece" : "\(itemsAdded) pieces"
            let closets = wardrobesAdded == 1 ? "1 closet" : "\(wardrobesAdded) closets"
            return "Imported \(pieces) into \(closets). "
                + "Photos aren't part of the data file — add them again when you like."
        }
    }

    /// 导入一个导出快照。抛错时**什么都不会留下**。
    @MainActor
    @discardableResult
    public static func importSnapshot(_ data: Data, into context: ModelContext) throws -> Receipt {
        let snapshot: DataLifecycleService.ExportSnapshot
        do {
            let decoder = JSONDecoder()
            // 导出侧把 nan/inf 编成字符串（历史脏数据兜底），读回来要对称
            decoder.nonConformingFloatDecodingStrategy = .convertFromString(
                positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
            snapshot = try decoder.decode(
                DataLifecycleService.ExportSnapshot.self, from: data)
        } catch {
            AppLog.error("import decode failed: \(AppLog.errRef(error))", .data)
            throw ImportError.unreadable
        }
        guard snapshot.schemaVersion <= supportedSchemaVersion else {
            AppLog.notice("import refused: schema \(snapshot.schemaVersion)", .data)
            throw ImportError.newerSchema(
                found: snapshot.schemaVersion, supported: supportedSchemaVersion)
        }

        // 记下新建的对象，失败时逐一断关系再 rollback（D112 纪律）
        var newWardrobes: [Wardrobe] = []
        var newItems: [Item] = []
        var newOutfits: [Outfit] = []
        var imagePathsCleared = 0

        // 导入的 id 一律**重新生成**：原 id 可能与本机已有对象撞车，
        // 而撞车的后果是悄悄改写用户已有的数据。
        var wardrobeMap: [String: Wardrobe] = [:]
        let existingNames = Set((try? context.fetch(FetchDescriptor<Wardrobe>()))?
            .map(\.name) ?? [])

        for dto in snapshot.wardrobes {
            let w = Wardrobe(name: uniqueName(dto.name, taken: existingNames.union(
                newWardrobes.map(\.name))))
            w.locationCity = TextNormalize.blankToNil(dto.locationCity)
            context.insert(w)
            wardrobeMap[dto.id] = w
            newWardrobes.append(w)
        }

        var itemMap: [String: Item] = [:]
        for dto in snapshot.items {
            let item = Item(name: dto.name)
            item.slotRaw = dto.slotRaw
            item.statusRaw = dto.statusRaw
            item.subtype = dto.subtype
            item.occasionsRaw = dto.occasionsRaw
            item.warmthRaw = dto.warmthRaw
            item.colorHue = dto.colorHue
            item.colorIsNeutral = dto.colorIsNeutral
            item.attributesRaw = dto.attributesRaw
            item.brand = dto.brand
            item.sizeLabel = dto.sizeLabel
            item.chestFlatWidthInches = dto.chestFlatWidthInches
            item.waistFlatWidthInches = dto.waistFlatWidthInches
            item.hipFlatWidthInches = dto.hipFlatWidthInches
            item.barcode = dto.barcode
            item.careRaw = dto.careRaw
            item.notes = dto.notes
            // 图片路径指向的是**导出那台设备**的文件。留着会让网格显示一批
            // 永远加载不出来的空格子——照片不在 JSON 里，如实清掉并在收据里说明。
            if TextNormalize.blankToNil(dto.localImageRelativePath) != nil {
                imagePathsCleared += 1
            }
            item.localImageRelativePath = nil
            if let wid = dto.wardrobeID, let w = wardrobeMap[wid] {
                item.wardrobe = w
            } else if let first = newWardrobes.first {
                item.wardrobe = first          // 快照里没柜归属 → 落到导入的第一个柜
            }
            context.insert(item)
            itemMap[dto.id] = item
            newItems.append(item)
        }

        for dto in snapshot.outfits {
            let outfit = Outfit(name: dto.name)
            if let wid = dto.wardrobeID, let w = wardrobeMap[wid] { outfit.wardrobe = w }
            outfit.items = dto.itemIDs.compactMap { itemMap[$0] }
            outfit.isFavorite = dto.isFavorite
            context.insert(outfit)
            newOutfits.append(outfit)
        }

        guard ModelSave.save(context, label: "importSnapshot") else {
            // 断关系再 rollback：不断的话幻影会被下一次无关 save 写进库（D112）
            for outfit in newOutfits { outfit.wardrobe = nil; outfit.items = [] }
            for item in newItems { item.wardrobe = nil }
            for w in newWardrobes { w.owner = nil }
            context.rollback()
            AppLog.error("import save failed", .data)
            throw ImportError.saveFailed
        }
        AppLog.notice(
            "import +\(newWardrobes.count) closets +\(newItems.count) items", .data)
        return Receipt(
            wardrobesAdded: newWardrobes.count,
            itemsAdded: newItems.count,
            outfitsAdded: newOutfits.count,
            imagePathsCleared: imagePathsCleared)
    }

    /// 同名不覆盖：`Home` → `Home (imported)` → `Home (imported 2)`。
    /// 用户得能一眼认出哪个是刚导进来的。
    static func uniqueName(_ raw: String, taken: Set<String>) -> String {
        let base = TextNormalize.blankToNil(raw) ?? "Imported closet"
        guard taken.contains(base) else { return base }
        let suffixed = "\(base) (imported)"
        guard taken.contains(suffixed) else { return suffixed }
        var n = 2
        while taken.contains("\(base) (imported \(n))") { n += 1 }
        return "\(base) (imported \(n))"
    }
}
