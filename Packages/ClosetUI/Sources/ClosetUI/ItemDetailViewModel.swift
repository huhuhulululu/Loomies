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
    /// 适穿温区（天气硬过滤输入）；nil = 未知（不硬过滤，不替用户假设）。
    public var warmthRaw: Int?
    /// 颜色色板 id（配色打分输入）；nil = 未知。
    public var colorPaletteID: String?
    /// 风格属性（体型加权输入）。
    public var attributes: Set<StyleAttribute> = []
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
        self.warmthRaw = item.warmthRaw
        // 已存颜色 → 最近色板选中态；中性无 hue 时也能回读（hue nil → 用 0 参与中性匹配）
        let initialPalette = Self.paletteID(
            hue: item.colorHue, isNeutral: item.colorIsNeutral)
        self.colorPaletteID = initialPalette
        self.initialColorPaletteID = initialPalette
        self.attributes = Set(item.attributesRaw.compactMap { StyleAttribute(rawValue: $0) })
    }

    /// 打开详情页时的色板选中态。用户没动过色板就不带 color patch——
    /// colorPaletteID 是 nearest() 量化值，无条件回写会把入库识别的连续色相
    /// （例如 15°）静默改写成最近色板值（28°），而用户只是改了个名字。
    private let initialColorPaletteID: String?

    /// 用户是否真的改动过颜色选择。
    var colorWasEdited: Bool { colorPaletteID != initialColorPaletteID }

    /// 单品颜色 → 色板 id（无颜色信息时 nil＝未知，不假装用户选过）。
    static func paletteID(hue: Double?, isNeutral: Bool) -> String? {
        if let hue {
            return GarmentColorPalette.nearest(
                to: GarmentColor(hueDegrees: hue, isNeutral: isNeutral))?.id
        }
        // 存量行（hue 未知 + 中性标记）无法还原是哪个中性色 → 诚实显示未知，不猜
        return nil
    }

    public var statuses: [String] { Array(ItemStatusService.allowed).sorted() }

    /// 带层级深度的位置（详情 Picker 用缩进消歧义：同柜可有两个同名不同父的位置）。
    public var storageLocationNodes: [StorageLocationService.Node] {
        guard let w = item.wardrobe else { return [] }
        return StorageLocationService.listWithDepth(in: w)
    }

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
            // 只发判定档位——**不含任何围度值**（bust/waist/hip 是红线键，整包会被拒）
            TelemetryGate.shared.track(.fitMarkShown, payload: ["verdict": String(describing: v)])
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
        let swatch = GarmentColorPalette.entry(id: colorPaletteID)
        let edited = ItemEditorService.apply(
            .init(name: name, slotRaw: slotRaw, occasionsRaw: occ,
                  brand: brand, sizeLabel: sizeLabel,
                  warmthRaw: warmthRaw,
                  chestFlatWidthInches: Double(chestFlat.trimmingCharacters(in: .whitespacesAndNewlines)),
                  waistFlatWidthInches: Double(waistFlat.trimmingCharacters(in: .whitespacesAndNewlines)),
                  replaceFlatWidths: true,
                  replaceWarmth: true,
                  attributesRaw: attributes.map(\.rawValue).sorted(),
                  // 中性色的 hue 只是色板槽位（打分层面被忽略：ColorHarmony 见中性即
                  // 返回 .neutral，60-30-10 直接滤掉中性），但**必须存**——否则回读时
                  // 7 个中性色塌成同一状态，用户选的 Black 退出重进就变回「未选」。
                  colorHue: colorWasEdited ? swatch?.hueDegrees : item.colorHue,
                  // 取消选择 = 回到未知，不得回落旧值（否则中性是有进无出的单向门）
                  colorIsNeutral: colorWasEdited
                    ? (swatch?.isNeutral ?? false) : item.colorIsNeutral,
                  replaceColor: colorWasEdited),
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
            AppLog.info("ItemDetail save item=\(AppLog.ref(item.id)) slot=\(item.slotRaw)", .app)
        } else if !locationOk && edited && statusOk {
            // Only location failed — specific toast (Me Storage parity).
            message = StorageLocationService.assignSaveFailedMessage
            AppLog.error("ItemDetail location assign failed item=\(AppLog.ref(item.id))", .app)
        } else {
            message = Self.saveFailedMessage
            AppLog.error(
                "ItemDetail save failed item=\(AppLog.ref(item.id)) edit=\(edited) status=\(statusOk) loc=\(locationOk)",
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
        let label = AppLog.ref(item.id)   // 日志安全标识：删除日志不携带用户命名
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
