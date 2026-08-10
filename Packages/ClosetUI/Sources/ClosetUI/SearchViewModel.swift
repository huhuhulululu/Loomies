import Foundation
import Observation
import SwiftData
import ClosetModel
import ClosetCore

/// 全局查找 UI 逻辑（DESIGN §F3）：跨柜属性/标签检索。
@MainActor
@Observable
public final class SearchViewModel {
    public var text: String = ""
    public var slotRaw: String?
    public var occasion: String?
    public var statusRaw: String?
    /// nil = 跨全部衣柜
    public var wardrobeID: UUID?
    public private(set) var results: [Item] = []

    public init() {}

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
        isFiltering
            ? "Try another name, brand, type, status, or occasion filter."
            : "Add a piece or load samples, then search."
    }

    public func run(in context: ModelContext) {
        results = SearchService.searchItems(
            .init(text: text, slotRaw: slotRaw, occasion: occasion,
                  statusRaw: statusRaw, wardrobeID: wardrobeID),
            in: context)
    }

    public func clear() {
        text = ""
        slotRaw = nil
        occasion = nil
        statusRaw = nil
        wardrobeID = nil
        results = []
    }

    /// Drop query facets but keep wardrobe scope (Closet search is in-cabinet).
    public func clearFiltersKeepingWardrobe() {
        let wid = wardrobeID
        clear()
        wardrobeID = wid
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
    /// Search list subtitle and Closet grid caption. Empty location omitted (not "nil").
    public static func metaLine(
        slotDisplayTitle: String,
        statusDisplayName: String,
        locationName: String? = nil
    ) -> String {
        var parts = [slotDisplayTitle, statusDisplayName]
        if let loc = locationName?.trimmingCharacters(in: .whitespacesAndNewlines), !loc.isEmpty {
            parts.append(loc)
        }
        return parts.joined(separator: " · ")
    }

    /// Convenience from live `Item` (displaySlot truth + human status).
    public static func metaLine(for item: Item) -> String {
        metaLine(
            slotDisplayTitle: GarmentSlot.resolved(item.slotRaw, name: item.name).displayTitle,
            statusDisplayName: ItemStatusService.displayName(item.statusRaw),
            locationName: item.location?.name)
    }
}
