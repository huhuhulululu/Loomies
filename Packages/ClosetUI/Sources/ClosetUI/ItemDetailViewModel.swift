import Foundation
import Observation
import SwiftData
import ClosetModel
import ClosetCore

/// 单品详情/编辑（管理环缺口）。
@MainActor
@Observable
public final class ItemDetailViewModel {
    public let item: Item
    public var name: String
    public var slotRaw: String
    public var brand: String
    public var sizeLabel: String
    public var statusRaw: String
    public var occasionsText: String  // comma-separated
    public var chestFlat: String
    public var waistFlat: String
    /// Me Storage location — nil = unassigned. Save applies via `StorageLocationService.assign`.
    public var locationID: UUID?
    public private(set) var fitLabel: String?
    /// Measurement-ease caption under the badge (proportion guide, not try-on).
    public private(set) var fitDetail: String?
    public private(set) var message: String = ""
    /// Set after a successful delete so the detail screen can dismiss.
    public private(set) var didDelete = false

    public init(item: Item) {
        self.item = item
        self.name = item.name
        // Type picker uses GarmentSlot.allCases rawValues — show resolved product truth
        // (dirty storage "top" + "Navy Blazer" → outerwear), same as Closet/Search labels.
        self.slotRaw = GarmentSlot.resolved(item.slotRaw, name: item.name).rawValue
        self.brand = item.brand ?? ""
        self.sizeLabel = item.sizeLabel ?? ""
        self.statusRaw = item.statusRaw
        self.occasionsText = item.occasionsRaw.joined(separator: ", ")
        self.chestFlat = item.chestFlatWidthInches.map { String($0) } ?? ""
        self.waistFlat = item.waistFlatWidthInches.map { String($0) } ?? ""
        self.locationID = item.location?.id
    }

    public var statuses: [String] { Array(ItemStatusService.allowed).sorted() }

    /// Locations in this piece’s closet (for detail picker). Empty → Me → Storage first.
    public var storageLocations: [StorageLocation] {
        guard let w = item.wardrobe else { return [] }
        return StorageLocationService.list(in: w)
    }

    /// Empty-storage caption under Location picker (points to Me).
    public static let noStorageLocationsCaption =
        "No locations yet. Add them in Me → Storage locations."

    /// Live FitMark from form fields (name/type/flat widths) so users see verdict before Save.
    public func refreshFit(profile: PersonBodyProfile?) {
        guard let profile else {
            fitLabel = nil
            fitDetail = nil
            return
        }
        if let v = FitMarkService.mark(
            slotRaw: slotRaw,
            name: name,
            chestFlatWidthInches: Double(chestFlat.trimmingCharacters(in: .whitespacesAndNewlines)),
            waistFlatWidthInches: Double(waistFlat.trimmingCharacters(in: .whitespacesAndNewlines)),
            profile: profile
        ) {
            fitLabel = FitMarkCopy.label(v)
            fitDetail = FitMarkCopy.detail(v)
        } else {
            fitLabel = nil
            fitDetail = nil
        }
    }

    /// Customer toast when ModelSave fails on detail Save.
    public static let saveFailedMessage = "Couldn't save — try again"

    /// Customer toast when DeleteService fails (no silent dismiss; keeps image).
    /// Same string as `DeleteError.saveFailed` so Me/detail share one voice.
    public static let deleteFailedMessage =
        DeleteError.saveFailed.errorDescription ?? "Couldn't delete — try again"

    public func save(in context: ModelContext) {
        let occ = occasionsText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let edited = ItemEditorService.apply(
            .init(name: name, slotRaw: slotRaw, occasionsRaw: occ,
                  brand: brand, sizeLabel: sizeLabel,
                  chestFlatWidthInches: Double(chestFlat.trimmingCharacters(in: .whitespacesAndNewlines)),
                  waistFlatWidthInches: Double(waistFlat.trimmingCharacters(in: .whitespacesAndNewlines)),
                  replaceFlatWidths: true),
            to: item, in: context)
        let statusOk = ItemStatusService.setStatus(item, to: statusRaw, in: context)
        let locationOk = applyLocation(in: context)
        if edited && statusOk && locationOk {
            // Form follows resolved storage (e.g. top + "Navy Blazer" → outerwear).
            // Only on committed save — on failure the services roll item back in
            // memory, so re-reading here would silently discard typed fields.
            name = item.name
            slotRaw = GarmentSlot.resolved(item.slotRaw, name: item.name).rawValue
            chestFlat = item.chestFlatWidthInches.map { String($0) } ?? ""
            waistFlat = item.waistFlatWidthInches.map { String($0) } ?? ""
            locationID = item.location?.id
            message = "Saved."
            AppLog.info("ItemDetail save \(item.name) slot=\(item.slotRaw)", .app)
        } else if !locationOk && edited && statusOk {
            // Only location failed — specific toast (Me Storage parity).
            message = StorageLocationService.assignSaveFailedMessage
            AppLog.error("ItemDetail location assign failed \(item.name)", .app)
        } else {
            message = Self.saveFailedMessage
            AppLog.error(
                "ItemDetail save failed \(item.name) edit=\(edited) status=\(statusOk) loc=\(locationOk)",
                .app)
        }
    }

    /// Resolves picker `locationID` against this wardrobe and assigns (nil clears).
    @discardableResult
    func applyLocation(in context: ModelContext) -> Bool {
        let target: StorageLocation?
        if let id = locationID {
            guard let found = storageLocations.first(where: { $0.id == id }) else {
                // Stale id (deleted location) — do not silently drop picker state.
                return false
            }
            target = found
        } else {
            target = nil
        }
        // Skip write when unchanged (avoids extra ModelSave / revision bump).
        if item.location?.id == target?.id { return true }
        return StorageLocationService.assign(item, to: target, in: context)
    }

    /// Permanently remove the piece (outfits mark permanentlyMissing; wear history kept).
    /// On save failure: keeps the local image, does not set `didDelete` (no silent success toast).
    public func delete(in context: ModelContext) {
        let path = item.localImageRelativePath
        let label = item.name
        let ok = DeleteService.deleteItem(item, in: context)
        if ok {
            ItemImageStore.delete(relativePath: path)
            didDelete = true
            message = "Deleted."
            AppLog.info("ItemDetail delete \(label)", .app)
        } else {
            didDelete = false
            message = Self.deleteFailedMessage
            AppLog.error("ItemDetail delete failed \(label)", .app)
        }
    }
}
