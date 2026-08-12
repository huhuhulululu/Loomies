import Foundation
import SwiftData
import ClosetModel
import ClosetIntake
import ClosetCore

/// 手动新增草稿（D83 / D88）：Closet「+」→「Enter manually」的落库唯一真相。
/// 此前温区硬编码 `Warmth.light` + 颜色恒中性，导致冷天必空推荐、配色打分恒中性；
/// 未选 = 未知（nil），不替用户假设。
///
/// D88 教训：这段逻辑最初只接进了 `QuickAddSheet`——一个零呈现点的死 View——
/// 而用户真正点到的手填面照旧硬编码。现在 `AddPieceSheet.manualBody` 直接用它，
/// `WiringLintTests` 的三条门（孤儿 View / 伪造默认值 / create 失败用 delete）守住回归。
public struct QuickAddDraft: Equatable, Sendable {

    /// ModelSave 失败时的用户文案——与照片入库确认同一条（失败不得静默关面）。
    @MainActor public static let saveFailedMessage = IntakeViewModel.confirmSaveFailedMessage
    public var name: String
    public var slotRaw: String
    /// D114：场合是**多选**（与详情页同一控件/同一语义）。空集 = 未知，不硬过滤。
    /// 此前是单个 `String`，一条黑裤子只能二选一「上班」或「约会」，
    /// 而拍照批量建的衣柜每件只带一个场合，换个场合就被硬门筛成零。
    public var occasions: Set<String>
    /// nil = 温区未知（不硬过滤）
    public var warmthRaw: Int?
    /// nil = 颜色未知
    public var colorPaletteID: String?

    public init(
        name: String = "",
        slotRaw: String = GarmentSlot.top.rawValue,
        occasions: Set<String> = [],
        warmthRaw: Int? = nil,
        colorPaletteID: String? = nil
    ) {
        self.name = name
        self.slotRaw = slotRaw
        self.occasions = occasions
        self.warmthRaw = warmthRaw
        self.colorPaletteID = colorPaletteID
    }

    public var canCommit: Bool { !TextNormalize.isBlank(name) }

    /// Order-preserving dedup — the picker occasion may already be "casual".
    public static func dedupOccasions(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        return raw.filter { seen.insert($0).inserted }
    }

    /// 落库。失败返回 nil（断关系 + rollback，无幻影，调用方留在表单可重试）。
    @MainActor
    @discardableResult
    public func commit(into wardrobe: Wardrobe, context: ModelContext) -> Item? {
        guard let trimmed = TextNormalize.blankToNil(name) else { return nil }
        let item = Item(name: trimmed)
        let draftSlot = GarmentSlot(rawValue: slotRaw) ?? .top
        item.slotRaw = IntakeViewModel.persistSlot(draftSlot: draftSlot, name: trimmed).rawValue
        // D103：此前这里偷偷追加 "casual"，晚宴礼服因此成了休闲日的合法候选
        //（场合硬门被架空），详情页还显示一个用户没选过的场合。
        // 用户选了什么就是什么；没选由三值语义处理（空集 = 未知 = 不硬过滤）。
        item.occasionsRaw = occasions.sorted()   // 确定顺序（导出快照可复现）
        item.warmthRaw = warmthRaw
        item.statusRaw = "available"
        if let swatch = GarmentColorPalette.entry(id: colorPaletteID) {
            item.colorIsNeutral = swatch.isNeutral
            // 中性色也存 hue（色板槽位，打分层忽略）——否则回读丢选中态
            item.colorHue = swatch.hueDegrees
        } else {
            // 未选颜色：保持「未知」而非谎报中性（Adapter 的中性语义只给显式中性）
            item.colorIsNeutral = false
            item.colorHue = nil
        }
        item.wardrobe = wardrobe
        context.insert(item)
        guard ModelSave.save(context, label: "quickAdd") else {
            // 断关系 + rollback（delete 只删行，wardrobe.items 幻影与脏标记滞留）
            item.wardrobe = nil
            context.rollback()
            AppLog.error("quickAdd save failed", .intake)
            return nil
        }
        AppLog.info("quickAdd item=\(AppLog.ref(item.id)) slot=\(item.slotRaw)", .intake)
        // 遥测：槽位是白名单键（无名称、无图像、无身体维度）；默认关闭且当前无 sink
        TelemetryGate.shared.track(.itemConfirmed, payload: ["slot": item.slotRaw])
        return item
    }
}
