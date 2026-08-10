import Foundation
import SwiftData
import ClosetCore

/// 数据生命周期（DESIGN §10.6）：全量导出 + 删除全部（CCPA 删除权）。
/// 导出默认不含身体围度；删除会清空本地域 PersonBodyProfile 与本地单品图目录。
public enum DataLifecycleService {

    // MARK: - Export

    public struct ExportSnapshot: Codable, Sendable, Equatable {
        public var schemaVersion: Int
        public var exportedAt: String
        public var includeBodyDimensions: Bool
        public var persons: [PersonDTO]
        public var wardrobes: [WardrobeDTO]
        public var locations: [LocationDTO]
        public var items: [ItemDTO]
        public var outfits: [OutfitDTO]
        public var wearRecords: [WearRecordDTO]
        public var plans: [PlanDTO]
        public var bodyProfiles: [BodyProfileDTO]?
    }

    public struct PersonDTO: Codable, Sendable, Equatable {
        public var id: String
        public var name: String
        public var coldBias: Int
        public var personalColorSeasonRaw: String?
    }

    public struct WardrobeDTO: Codable, Sendable, Equatable {
        public var id: String
        public var name: String
        public var locationCity: String?
        public var ownerID: String?
    }

    public struct LocationDTO: Codable, Sendable, Equatable {
        public var id: String
        public var name: String
        public var wardrobeID: String?
        public var parentID: String?
    }

    public struct ItemDTO: Codable, Sendable, Equatable {
        public var id: String
        public var name: String
        public var wardrobeID: String?
        public var locationID: String?
        public var statusRaw: String
        public var slotRaw: String
        public var subtype: String?
        public var occasionsRaw: [String]
        public var warmthRaw: Int?
        public var colorHue: Double?
        public var colorIsNeutral: Bool
        public var attributesRaw: [String]
        public var brand: String?
        public var sizeLabel: String?
        public var sizeSystemRaw: String?
        public var chestFlatWidthInches: Double?
        public var waistFlatWidthInches: Double?
        public var hipFlatWidthInches: Double?
        public var localImageRelativePath: String?
        public var barcode: String?
    }

    public struct OutfitDTO: Codable, Sendable, Equatable {
        public var id: String
        public var name: String
        public var wardrobeID: String?
        public var itemIDs: [String]
        public var missing: Bool
        public var permanentlyMissing: Bool
        public var occasionRaw: String?
        public var isFavorite: Bool
        public var sourceRaw: String?
        public var notes: String?
    }

    public struct WearRecordDTO: Codable, Sendable, Equatable {
        public var id: String
        public var date: String
        public var outfitID: String?
        public var wardrobeSnapshotID: String?
        public var wornItemIDs: [String]
        public var fitFeedback: String?
    }

    public struct PlanDTO: Codable, Sendable, Equatable {
        public var id: String
        public var date: String
        public var outfitID: String?
        public var needsAttention: Bool
        /// 日历日键（加法字段；旧数据/旧导出为 nil）。
        public var dayKey: String?
    }

    public struct BodyProfileDTO: Codable, Sendable, Equatable {
        public var id: String
        public var personID: String
        public var bustInches: Double?
        public var waistInches: Double?
        public var hipInches: Double?
        public var highHipInches: Double?
        public var popularShapeOverrideRaw: String?
        public var shapeSourceRaw: String?
        public var highHipInferred: Bool
        public var fineChest: Double
        public var fineWaist: Double
        public var fineHip: Double
        public var fineHeight: Double
        public var presentationSexRaw: String?
        public var presentationPhenotypeRaw: String?
    }

    public static func exportSnapshot(
        in context: ModelContext,
        includeBodyDimensions: Bool = false,
        now: Date = Date()
    ) throws -> ExportSnapshot {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        let persons = try context.fetch(FetchDescriptor<Person>())
        let wardrobes = try context.fetch(FetchDescriptor<Wardrobe>())
        let locations = try context.fetch(FetchDescriptor<StorageLocation>())
        let items = try context.fetch(FetchDescriptor<Item>())
        let outfits = try context.fetch(FetchDescriptor<Outfit>())
        let wears = try context.fetch(FetchDescriptor<WearRecord>())
        let plans = try context.fetch(FetchDescriptor<CalendarPlan>())

        let personDTOs = persons
            .map { PersonDTO(id: $0.id.uuidString, name: $0.name, coldBias: $0.coldBias,
                             personalColorSeasonRaw: $0.personalColorSeasonRaw) }
            .sorted { ($0.name, $0.id) < ($1.name, $1.id) }   // 同名按 id 决胜——导出快照可复现

        let wardrobeDTOs = wardrobes
            .map { WardrobeDTO(id: $0.id.uuidString, name: $0.name, locationCity: $0.locationCity,
                               ownerID: $0.owner?.id.uuidString) }
            .sorted { ($0.name, $0.id) < ($1.name, $1.id) }   // 同名按 id 决胜——导出快照可复现

        let locationDTOs = locations
            .map { LocationDTO(id: $0.id.uuidString, name: $0.name,
                               wardrobeID: $0.wardrobe?.id.uuidString,
                               parentID: $0.parent?.id.uuidString) }
            .sorted { ($0.name, $0.id) < ($1.name, $1.id) }   // 同名按 id 决胜——导出快照可复现

        let itemDTOs = items
            .map {
                ItemDTO(
                    id: $0.id.uuidString, name: $0.name, wardrobeID: $0.wardrobe?.id.uuidString,
                    locationID: $0.location?.id.uuidString, statusRaw: $0.statusRaw, slotRaw: $0.slotRaw,
                    subtype: $0.subtype, occasionsRaw: $0.occasionsRaw, warmthRaw: $0.warmthRaw,
                    colorHue: $0.colorHue, colorIsNeutral: $0.colorIsNeutral, attributesRaw: $0.attributesRaw,
                    brand: $0.brand, sizeLabel: $0.sizeLabel, sizeSystemRaw: $0.sizeSystemRaw,
                    chestFlatWidthInches: $0.chestFlatWidthInches,
                    waistFlatWidthInches: $0.waistFlatWidthInches,
                    hipFlatWidthInches: $0.hipFlatWidthInches,
                    localImageRelativePath: $0.localImageRelativePath,
                    barcode: $0.barcode
                )
            }
            .sorted { ($0.name, $0.id) < ($1.name, $1.id) }   // 同名按 id 决胜——导出快照可复现

        let outfitDTOs = outfits
            .map {
                OutfitDTO(
                    id: $0.id.uuidString, name: $0.name, wardrobeID: $0.wardrobe?.id.uuidString,
                    itemIDs: ($0.items ?? []).map(\.id.uuidString).sorted(),
                    missing: $0.missing, permanentlyMissing: $0.permanentlyMissing,
                    occasionRaw: $0.occasionRaw, isFavorite: $0.isFavorite,
                    sourceRaw: $0.sourceRaw, notes: $0.notes
                )
            }
            .sorted { ($0.name, $0.id) < ($1.name, $1.id) }   // 同名按 id 决胜——导出快照可复现

        let wearDTOs = wears
            .map {
                WearRecordDTO(
                    id: $0.id.uuidString, date: iso.string(from: $0.date),
                    outfitID: $0.outfitID?.uuidString,
                    wardrobeSnapshotID: $0.wardrobeSnapshotID?.uuidString,
                    wornItemIDs: $0.wornItemIDs, fitFeedback: $0.fitFeedback
                )
            }
            .sorted { ($0.date, $0.id) < ($1.date, $1.id) }   // 同刻按 id 决胜——导出快照可复现

        let planDTOs = plans
            .map {
                PlanDTO(
                    id: $0.id.uuidString, date: iso.string(from: $0.date),
                    outfitID: $0.outfit?.id.uuidString, needsAttention: $0.needsAttention,
                    dayKey: $0.dayKey.isEmpty ? nil : $0.dayKey
                )
            }
            .sorted { ($0.date, $0.id) < ($1.date, $1.id) }   // 同刻按 id 决胜——导出快照可复现

        var bodyDTOs: [BodyProfileDTO]? = nil
        if includeBodyDimensions {
            let profiles = try context.fetch(FetchDescriptor<PersonBodyProfile>())
            bodyDTOs = profiles.map {
                BodyProfileDTO(
                    id: $0.id.uuidString, personID: $0.personID.uuidString,
                    bustInches: $0.bustInches, waistInches: $0.waistInches,
                    hipInches: $0.hipInches, highHipInches: $0.highHipInches,
                    popularShapeOverrideRaw: $0.popularShapeOverrideRaw,
                    shapeSourceRaw: $0.shapeSourceRaw, highHipInferred: $0.highHipInferred,
                    fineChest: $0.fineChest, fineWaist: $0.fineWaist,
                    fineHip: $0.fineHip, fineHeight: $0.fineHeight,
                    presentationSexRaw: $0.presentationSexRaw,
                    presentationPhenotypeRaw: $0.presentationPhenotypeRaw
                )
            }
            .sorted { $0.personID < $1.personID }
        }

        return ExportSnapshot(
            schemaVersion: 1,
            exportedAt: iso.string(from: now),
            includeBodyDimensions: includeBodyDimensions,
            persons: personDTOs,
            wardrobes: wardrobeDTOs,
            locations: locationDTOs,
            items: itemDTOs,
            outfits: outfitDTOs,
            wearRecords: wearDTOs,
            plans: planDTOs,
            bodyProfiles: bodyDTOs
        )
    }

    public static func exportJSONData(
        in context: ModelContext,
        includeBodyDimensions: Bool = false,
        pretty: Bool = true
    ) throws -> Data {
        let snap = try exportSnapshot(in: context, includeBodyDimensions: includeBodyDimensions)
        let enc = JSONEncoder()
        if pretty { enc.outputFormatting = [.prettyPrinted, .sortedKeys] }
        // 历史脏数据兜底：守卫前落库的 nan/inf 不得把导出永久锁死（默认 .throw 会）。
        enc.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
        return try enc.encode(snap)
    }

    public static func exportJSONString(
        in context: ModelContext,
        includeBodyDimensions: Bool = false
    ) throws -> String {
        let data = try exportJSONData(in: context, includeBodyDimensions: includeBodyDimensions)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    /// Customer toast after Export — states body inclusion honestly (matches the Me toggle).
    public static func exportReadyMessage(includeBodyDimensions: Bool) -> String {
        if includeBodyDimensions {
            return "Export ready — includes body measurements."
        }
        return "Export ready — body measurements omitted."
    }

    /// Me → Export my data button VoiceOver hint (share sheet + body toggle honesty).
    public static var exportButtonAccessibilityHint: String {
        "Opens the share sheet. Body measurements follow the toggle above."
    }

    /// Me → Delete all data button VoiceOver hint (confirm first; permanent wipe).
    public static var deleteAllButtonAccessibilityHint: String {
        "Asks for confirmation, then permanently removes closets, pieces, looks, and body data from this device."
    }

    /// Customer toast after Export throws — never dump raw system errors in Me UI.
    public static var exportFailedMessage: String {
        "Couldn't export — try again"
    }

    /// Customer toast after Delete all throws — honest, non-technical.
    public static var deleteAllFailedMessage: String {
        "Couldn't delete data — try again"
    }

    // MARK: - Delete all

    public struct DeleteReceipt: Codable, Sendable, Equatable {
        public var deletedAt: String
        public var deletedPersons: Int
        public var deletedWardrobes: Int
        public var deletedLocations: Int
        public var deletedItems: Int
        public var deletedOutfits: Int
        public var deletedWearRecords: Int
        public var deletedPlans: Int
        public var deletedBodyProfiles: Int
        public var wipedItemImages: Bool

        /// Customer toast after Delete all — must mention body profiles when wiped (matches confirm copy).
        public var summaryLine: String {
            var parts = [
                "\(deletedItems) items",
                "\(deletedOutfits) looks",
                "\(deletedWardrobes) closets",
            ]
            if deletedBodyProfiles > 0 {
                parts.append("\(deletedBodyProfiles) body profiles")
            }
            if deletedWearRecords > 0 {
                parts.append("\(deletedWearRecords) wear records")
            }
            return "Deleted " + parts.joined(separator: ", ") + "."
        }
    }

    /// 二次确认后调用：清空全部用户实体 + 可选本地单品图目录。
    /// WearRecord 一并删除（与单品级联删不同——整库重置，不保留统计）。
    /// CloudKit 私有库若启用由系统随本地删同步；当前默认 off。
    @discardableResult
    public static func deleteAllUserData(
        in context: ModelContext,
        wipeItemImages: Bool = true,
        now: Date = Date()
    ) throws -> DeleteReceipt {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        func wipeAll<T: PersistentModel>(_ type: T.Type) throws -> Int {
            let rows = try context.fetch(FetchDescriptor<T>())
            let n = rows.count
            for row in rows { context.delete(row) }
            return n
        }

        // 先断关系多的一侧，再删根；SwiftData 会处理 cascade。
        let deletedPlans = try wipeAll(CalendarPlan.self)
        let deletedWearRecords = try wipeAll(WearRecord.self)
        let deletedOutfits = try wipeAll(Outfit.self)
        let deletedItems = try wipeAll(Item.self)
        let deletedLocations = try wipeAll(StorageLocation.self)
        let deletedWardrobes = try wipeAll(Wardrobe.self)
        let deletedPersons = try wipeAll(Person.self)
        let deletedBodyProfiles = try wipeAll(PersonBodyProfile.self)

        guard ModelSave.save(context, label: "deleteAllUserData") else {
            context.rollback()   // 失败删除不得滞留，否则污染下一次无关 save
            throw DeleteError.saveFailed
        }

        var wipedImages = false
        if wipeItemImages {
            wipedImages = wipeItemImageDirectory()
        }

        let receipt = DeleteReceipt(
            deletedAt: iso.string(from: now),
            deletedPersons: deletedPersons,
            deletedWardrobes: deletedWardrobes,
            deletedLocations: deletedLocations,
            deletedItems: deletedItems,
            deletedOutfits: deletedOutfits,
            deletedWearRecords: deletedWearRecords,
            deletedPlans: deletedPlans,
            deletedBodyProfiles: deletedBodyProfiles,
            wipedItemImages: wipedImages
        )
        AppLog.notice("deleteAllUserData \(receipt.summaryLine)", .data)
        return receipt
    }

    /// 清空 Application Support/ItemImages 下文件；目录本身保留。
    @discardableResult
    public static func wipeItemImageDirectory() -> Bool {
        let dir = ItemImageStore.rootDirectory
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return false
        }
        var any = false
        for url in entries {
            do {
                try fm.removeItem(at: url)
                any = true
            } catch {
                AppLog.error("wipe item image failed: \(AppLog.errRef(error))", .data)
            }
        }
        return any || entries.isEmpty
    }
}
