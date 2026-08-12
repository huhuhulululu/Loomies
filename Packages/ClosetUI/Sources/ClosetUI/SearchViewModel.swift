import Foundation
import Observation
import SwiftData
import ClosetModel
import ClosetCore

/// 检索作用域（DESIGN §2.3/§7 承诺的全局检索）。默认本柜（安全默认：
/// 跨柜结果需用户显式选择，避免在不知情下持续看到别柜单品）。
public enum SearchScope: String, CaseIterable, Sendable {
    case thisCloset, allClosets

    public var displayTitle: String {
        switch self {
        case .thisCloset: return "This closet"
        case .allClosets: return "All closets"
        }
    }
}

/// 全局查找 UI 逻辑（DESIGN §F3）：跨柜属性/标签检索。
@MainActor
@Observable
public final class SearchViewModel {
    public var text: String = ""
    public var slotRaw: String?
    public var occasion: String?
    public var statusRaw: String?
    /// 用户当前所在衣柜（作用域为 .thisCloset 时的钉柜对象）。
    public var homeWardrobeID: UUID?
    /// 作用域切换器只在多柜时才有意义（单柜用户不该看到无用控件）。
    public var hasOtherClosets: Bool = false
    public var scope: SearchScope = .thisCloset
    public private(set) var results: [Item] = []

    public init() {}

    /// 实际下发给 SearchService 的柜 id（nil = 跨全部衣柜）。
    public var effectiveWardrobeID: UUID? {
        scope == .allClosets ? nil : homeWardrobeID
    }

    /// 结果可能来自多个衣柜 → 行内必须显示所属衣柜，否则同名单品分不清。
    /// 只看 scope：切换器本就只在多柜时出现，用户显式选了「全部」就该看到归属。
    public var isCrossCloset: Bool { scope == .allClosets }

    /// 本柜无结果、但还有别的柜可搜 → 提供「搜全部衣柜」的可行动出口。
    public var canBroadenScope: Bool {
        isFiltering && scope == .thisCloset && hasOtherClosets
    }

    /// True when text or any facet filter is active (drives empty-state copy).
    public var isFiltering: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || slotRaw != nil
            || occasion != nil
            || statusRaw != nil
    }

    /// Empty-list title — filtering vs bare closet (VoiceOver / ContentUnavailable).
    public var emptyStateTitle: String {
        isFiltering ? "No matches" : "No pieces here"
    }

    /// Empty-list body — names facets honestly; no fake “try on” / inventory claims.
    public var emptyStateDescription: String {
        guard isFiltering else { return "Add a piece or load samples, then search." }
        return canBroadenScope
            ? "Try another name, brand, type, status, or occasion filter — or search all closets."
            : "Try another name, brand, type, status, or occasion filter."
    }

    public func run(in context: ModelContext) {
        results = SearchService.searchItems(
            .init(text: text, slotRaw: slotRaw, occasion: occasion,
                  statusRaw: statusRaw, wardrobeID: effectiveWardrobeID),
            in: context)
    }

    /// 全清（含作用域复位）：清空后不得仍停在跨柜而用户不知情。
    public func clear() {
        text = ""
        slotRaw = nil
        occasion = nil
        statusRaw = nil
        homeWardrobeID = nil
        hasOtherClosets = false
        scope = .thisCloset
        results = []
    }

    /// Drop query facets but keep the search scope（chips 的「Clear search」不该把用户踢回本柜）。
    public func clearFiltersKeepingScope() {
        let home = homeWardrobeID
        let others = hasOtherClosets
        let currentScope = scope
        clear()
        homeWardrobeID = home
        hasOtherClosets = others
        scope = currentScope
    }
}

// MARK: - Closet grid empty (parity with search empty honesty + a11y)

/// Grid (non-search) empty titles/bodies — facet-aware; never invents inventory.
public enum ClosetGridEmptyCopy {
    public static func title(isFacetFiltering: Bool) -> String {
        isFacetFiltering ? "No matches" : "Empty closet"
    }

    /// `hasSlotFilter` / `hasStatusFilter` mirror chip state (status ≠ all, type ≠ nil).
    public static func description(
        isFacetFiltering: Bool,
        hasSlotFilter: Bool,
        hasStatusFilter: Bool
    ) -> String {
        if !isFacetFiltering {
            return "Add a piece or load samples to try copilot."
        }
        if hasSlotFilter && hasStatusFilter {
            return "No pieces match this status and type."
        }
        if hasSlotFilter {
            return "No pieces of this type."
        }
        return "No pieces in this status."
    }

    /// Toolbar magnifying glass / close — VoiceOver (icon-only buttons).
    public static func searchToggleAccessibilityLabel(isSearchOpen: Bool) -> String {
        isSearchOpen ? "Close search" : "Search closet"
    }

    /// Toolbar + — same wording as empty-state “Add piece” CTA.
    public static let addPieceAccessibilityLabel = "Add piece"
}

// MARK: - Closet / Search row meta (slot · status · optional storage)

/// Secondary line under piece name — resolved type + status; location when assigned in detail.
public enum ClosetItemRowCopy {
    /// 跨柜结果里没有归属柜的单品（脏数据）——不得吐空段。
    public static let unknownClosetName = "No closet"

    /// Search list subtitle and Closet grid caption. Empty location omitted (not "nil").
    /// `closetName` 只在跨柜结果里给（同名单品必须能分辨来自哪个柜）。
    public static func metaLine(
        slotDisplayTitle: String,
        statusDisplayName: String,
        locationName: String? = nil,
        closetName: String? = nil
    ) -> String {
        var parts: [String] = []
        if let closet = closetName {
            parts.append(TextNormalize.blankToNil(closet) ?? unknownClosetName)
        }
        parts.append(contentsOf: [slotDisplayTitle, statusDisplayName])
        if let loc = TextNormalize.blankToNil(locationName) {
            parts.append(loc)
        }
        return parts.joined(separator: " · ")
    }

    /// Convenience from live `Item` (displaySlot truth + human status).
    public static func metaLine(for item: Item, includesCloset: Bool = false) -> String {
        metaLine(
            slotDisplayTitle: GarmentSlot.resolved(item.slotRaw, name: item.name).displayTitle,
            statusDisplayName: ItemStatusService.displayName(item.statusRaw),
            locationName: item.location?.name,
            closetName: includesCloset ? (item.wardrobe?.name ?? "") : nil)
    }
}
