import Foundation
import Observation
import SwiftData
import ClosetModel
import ClosetCore

/// 试衣间（DESIGN §7 v1.0「手动拼贴」）：按槽位任意挑本柜单品 → 纸娃娃上身 →
/// 可存为收藏 look。与 copilot 互补——copilot 是「AI 补全整套」，这里是「用户自己搭」。
/// 正面试穿（侧背叠衣是结构性缺口，见 per-yaw 层图立项）。
@MainActor
@Observable
public final class FittingRoomViewModel {
    public let wardrobe: Wardrobe
    /// 槽位 → 选中单品（displaySlot 纠偏后的槽位；dress 与 top/bottom 互斥）。
    public private(set) var selection: [BodyAvatarSlot: Item] = [:]
    public var message: String?

    public init(wardrobe: Wardrobe) {
        self.wardrobe = wardrobe
    }

    /// UI 展示槽位顺序（裙在前明确「二选一」语义）。
    public static let slotOrder: [BodyAvatarSlot] = [.dress, .outerwear, .top, .bottom, .shoes]

    public static let emptySaveMessage = "Pick at least one piece first."
    public static let saveFailedMessage = "Couldn't save look — try again"
    public static func savedMessage(name: String) -> String { "Saved \(name) to Favorites." }
    /// 空白名兜底（用户可改；与 OutfitActions 命名快照同风格）。
    public static let defaultLookName = "Fitting room look"

    /// 本柜可穿单品（available + displaySlot 归位 + 稳定排序）。
    public func items(for slot: BodyAvatarSlot) -> [Item] {
        (wardrobe.items ?? [])
            .filter { $0.statusRaw == "available" }
            .filter { BodyAvatarComposer.displaySlot(slotRaw: $0.slotRaw, itemName: $0.name) == slot }
            .sorted { ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString) }
    }

    public func isSelected(_ item: Item) -> Bool {
        selection.values.contains { $0.id == item.id }
    }

    /// 选/取消：同件再点取消；裙 ↔ 上下装互斥（grammar 语义前置到 UX）；跨柜静默拒绝。
    public func toggle(_ item: Item) {
        guard item.wardrobe?.id == wardrobe.id else {
            AppLog.error("fittingRoom foreign item blocked item=\(AppLog.ref(item.id))", .app)
            return
        }
        guard let slot = BodyAvatarComposer.displaySlot(
            slotRaw: item.slotRaw, itemName: item.name) else { return }
        if selection[slot]?.id == item.id {
            selection[slot] = nil
            return
        }
        if slot == .dress {
            selection[.top] = nil
            selection[.bottom] = nil
        } else if slot == .top || slot == .bottom {
            selection[.dress] = nil
        }
        selection[slot] = item
    }

    public func clear() { selection = [:] }

    public var selectedItems: [Item] {
        Self.slotOrder.compactMap { selection[$0] }
    }

    public var canSave: Bool { !selection.isEmpty }

    /// 纸娃娃层（与推荐/收藏同一条 composer 链）。
    public var layers: [BodyAvatarLayer] {
        selection.isEmpty ? [] : OutfitAvatarComposer.layers(from: selectedItems)
    }

    /// 存为收藏 look（source=fittingRoom）；失败保留选区可重试，不弹成功文案。
    @discardableResult
    public func saveAsFavorite(named rawName: String?, in context: ModelContext) -> ClosetModel.Outfit? {
        guard canSave else {
            message = Self.emptySaveMessage
            return nil
        }
        let name = TextNormalize.blankToNil(rawName) ?? Self.defaultLookName
        do {
            let outfit = try OutfitFavoriteService.saveFavorite(
                name: name,
                itemIDs: selectedItems.map { $0.id.uuidString },
                occasion: nil,
                in: wardrobe,
                source: "fittingRoom",
                context: context)
            message = Self.savedMessage(name: name)
            return outfit
        } catch {
            message = Self.saveFailedMessage
            AppLog.error("fittingRoom save failed: \(AppLog.errRef(error))", .app)
            return nil
        }
    }
}
