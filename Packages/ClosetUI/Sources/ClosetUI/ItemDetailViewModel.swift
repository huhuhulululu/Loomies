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
    /// 场合。**引擎只认固定几个值**（`CandidateFilter` 硬过滤），
    /// 此前这里是逗号分隔的自由文本——打错一个字母，这件衣服就永远不再被推荐，
    /// 而用户看不到任何异样（D108）。改为多选，同时保留用户已存的自定义值不丢。
    public var occasions: Set<String>
    /// 用户历史上存过、但不在标准集里的值（不静默删除别人的数据）。
    public private(set) var customOccasions: [String]
    public var chestFlat: String
    public var waistFlat: String
    /// 适穿温区（天气硬过滤输入）；nil = 未知（不硬过滤，不替用户假设）。
    public var warmthRaw: Int?
    /// 颜色色板 id（配色打分输入）；nil = 未知。
    public var colorPaletteID: String?
    /// 风格属性（体型加权输入）。
    public var attributes: Set<StyleAttribute> = []
    /// 护理符号（结构化，D93）
    /// 臀宽（D100）：下装的真约束——腰上合、臀上卡的裤子太常见了
    public var hipFlat: String = ""
    /// 录入单位（D108）。存储层一律英寸，只在录入/显示处换算；
    /// 此前详情页写死「inches」，而身体档案那边早有公制偏好。
    public var measureUnit: MeasurementEntry.Unit = .inches
    /// 三个尺寸框里有没有「输入了但解析不出来」的——此前静默丢弃，保存后字段变空。
    public var measurementInputWarning: String? {
        let bad = [chestFlat, waistFlat, hipFlat].contains {
            MeasurementEntry.isUnparseable($0)
        }
        return bad ? MeasurementEntry.unparseableMessage : nil
    }
    public var care: Set<CareSymbol> = []
    /// 自由备注（不可信输入；落库前过 ItemNotes.sanitize）
    public var notes: String = ""

    /// 护理组合互斥提示（不阻止——洗标本身可能印得矛盾，用户说了算）
    public var careConflictWarning: String? { CareSymbol.conflictWarning(care) }

    /// 「距上次洗涤已穿几次」（D106）；nil = 没有可说的（0 次不显示噪音）。
    public private(set) var laundryCaption: String?

    /// 转移历史（D94）与衣柜名映射；`load` 时取一次，不逐行 fetch。
    public private(set) var transferHistory: [TransferRecord] = []
    public private(set) var closetNames: [UUID: String] = [:]

    /// 详情页出现时调用。历史是只读的，与表单字段互不影响。
    public func loadHistory(in context: ModelContext) {
        laundryCaption = LaundryTracking.caption(item, in: context)
        transferHistory = TransferHistory.forItem(item.id, in: context)
        closetNames = TransferHistory.closetNames(in: context)
    }
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
        let stored = Set(item.occasionsRaw.map {
            $0.trimmingCharacters(in: .whitespaces).lowercased()
        }.filter { !$0.isEmpty })
        self.occasions = stored
        // 标准集之外的存量值原样保留——不静默删掉用户的数据
        self.customOccasions = stored.subtracting(OccasionMix.choices).sorted()
        // D108：按录入单位回显，且不带浮点噪音（此前 String(15.000000000000002)）
        let unit = MeasurementEntry.Unit.inches
        self.chestFlat = MeasurementEntry.text(fromInches: item.chestFlatWidthInches, unit: unit)
        self.waistFlat = MeasurementEntry.text(fromInches: item.waistFlatWidthInches, unit: unit)
        self.hipFlat = MeasurementEntry.text(fromInches: item.hipFlatWidthInches, unit: unit)
        self.locationID = item.location?.id
        self.warmthRaw = item.warmthRaw
        // 已存颜色 → 最近色板选中态；中性无 hue 时也能回读（hue nil → 用 0 参与中性匹配）
        let initialPalette = Self.paletteID(
            hue: item.colorHue, isNeutral: item.colorIsNeutral)
        self.colorPaletteID = initialPalette
        self.initialColorPaletteID = initialPalette
        self.attributes = Set(item.attributesRaw.compactMap { StyleAttribute(rawValue: $0) })
        self.care = Set(CareSymbol.parse(item.careRaw))
        self.notes = item.notes ?? ""
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
            chestFlatWidthInches: MeasurementEntry.inches(from: chestFlat, unit: measureUnit),
            waistFlatWidthInches: MeasurementEntry.inches(from: waistFlat, unit: measureUnit),
            // D101：此前这里漏传臀宽，于是网格徽章（走 mark(item:)，带臀宽）
            // 与详情页对同一件衣服给出不同判定
            hipFlatWidthInches: MeasurementEntry.inches(from: hipFlat, unit: measureUnit),
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
        // 确定顺序（导出快照可复现；与 attributesRaw / careRaw 同约定）
        let occ = occasions.sorted()
        let swatch = GarmentColorPalette.entry(id: colorPaletteID)
        let edited = ItemEditorService.apply(
            .init(name: name, slotRaw: slotRaw, occasionsRaw: occ,
                  brand: brand, sizeLabel: sizeLabel,
                  warmthRaw: warmthRaw,
                  chestFlatWidthInches: MeasurementEntry.inches(from: chestFlat, unit: measureUnit),
                  waistFlatWidthInches: MeasurementEntry.inches(from: waistFlat, unit: measureUnit),
                  hipFlatWidthInches: MeasurementEntry.inches(from: hipFlat, unit: measureUnit),
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
                  replaceColor: colorWasEdited,
                  careRaw: CareSymbol.persistOrder(care).map(\.rawValue),
                  notes: notes, replaceNotes: true),
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
            ItemImageStore.deleteAll(relativePath: path)
            // 缓存里还留着已删的图会继续显示（D109）
            ThumbnailImageCache.shared.evict(path: path)
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
