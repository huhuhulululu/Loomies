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
    /// D120：色板筛。站在店里那一刻，用户脑子里的检索词是**颜色 + 品类**。
    public var colorPaletteID: String?
    /// 每件的穿着回读（一次批量取，逐行查会退化成 N 次全表扫描）。
    public private(set) var wearStats: [UUID: WearStatsService.Stats] = [:]
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
            || colorPaletteID != nil
    }

    /// D120：「上次什么时候穿的」是判断「要不要再买一件」的另一半依据。
    /// 批量取一次——每行各查一遍在百件规模上是 N 次全表扫描。
    /// D141：一次取完。此前对结果里出现的**每个柜**各调一次整柜版，
    /// 而每次都要读全表——跨柜命中 5 个柜就是 5 次全表扫描，
    /// 挂在 0.25s 的防抖上每敲一个字重来一遍。要的只是结果这些件。
    private func refreshWearStats(in context: ModelContext) {
        wearStats = WearStatsService.stats(
            forItemIDs: Set(results.map(\.id)), in: context)
    }

    /// 结果计数的用户读法——「你已经有 4 件」。
    /// 只在**真的在筛**时出现：不筛时它等于在数整个衣柜，那句话没有意义。
    public var resultsHeadline: String? {
        guard isFiltering else { return nil }
        return SearchService.resultsHeadline(count: results.count)
    }

    /// 某件的穿着摘要（没算到就说没穿过，不留空行）。
    public func wearSummary(for item: Item) -> String {
        wearStats[item.id]?.summary ?? WearStatsService.neverWornSummary
    }

    /// Empty-list title — filtering vs bare closet (VoiceOver / ContentUnavailable).
    public var emptyStateTitle: String {
        isFiltering ? "No matches" : "No pieces here"
    }

    /// Empty-list body — names facets honestly; no fake “try on” / inventory claims.
    public var emptyStateDescription: String {
        guard isFiltering else { return "Add a piece or load samples, then search." }
        return canBroadenScope
            ? "Try another name, brand, type, colour, status, or occasion filter — or search all closets."
            : "Try another name, brand, type, colour, status, or occasion filter."
    }

    /// D125：文本输入的防抖窗口（秒）。
    ///
    /// `run` 会 fetch 全部 `Item` → 逐件 Unicode 折叠 → 排序，D120 之后
    /// 还要再取一遍整柜穿着统计——而它此前**每敲一个字母跑一次**：
    /// 「navy」四个字母等于四遍全表。0.25 秒是「打字停顿」的常见量级：
    /// 短到用户感觉不出延迟，长到能把一串连打并成一次。
    public static let textDebounce: Double = 0.25

    /// 在途代际号：慢的那次回来时若已被新输入取代，结果必须丢弃，
    /// 否则用户会看到上一个搜索词的结果（与 `applyWeather` 同一条纪律）。
    private var runGeneration = 0

    /// 领一个代号。
    @discardableResult
    private func beginRun() -> Int {
        runGeneration &+= 1
        return runGeneration
    }

    // D146：`applyIfCurrent(generation:results:in:)` 已删——**生产零调用点**。
    // 它模拟的是「异步结果回来时再决定落不落地」，而本页的搜索是**同步**跑的：
    // `run(in:)` 每次现读 `text` 现查，一个迟到的防抖任务醒来也只会照着
    // 当前输入再查一遍。那条「旧结果盖掉新结果」的路根本不存在，
    // 而它的测试却让人以为那道防线被验过了。
    //
    // 复活条件：搜索改成真正异步（后台 actor / 远端），结果回来时才落地。
    // 那时这个方法要回来，并且**测试必须打在真实调用点上**。

    /// 防抖跑一次。`sleep` 期间被新输入取代 → 直接放弃。
    public func runDebounced(in context: ModelContext) async {
        let generation = beginRun()
        try? await Task.sleep(for: .seconds(Self.textDebounce))
        guard generation == runGeneration else { return }
        run(in: context)
    }

    public func run(in context: ModelContext) {
        // 同步跑一次也要**作废在途代号**：否则一次更早发出、更晚回来的
        // 防抖任务仍会被当成「当前代」落地，把这次的结果盖掉。
        // （测试 `aStaleRunDoesNotOverwriteANewerOne` 当场抓到过这一条。）
        beginRun()
        results = SearchService.searchItems(
            .init(text: text, slotRaw: slotRaw, occasion: occasion,
                  statusRaw: statusRaw, wardrobeID: effectiveWardrobeID,
                  colorPaletteID: colorPaletteID),
            in: context)
        refreshWearStats(in: context)
        // 遥测：只发「有没有输入文字」与结果条数——**绝不发搜索词本身**
        TelemetryGate.shared.track(.searchPerformed, payload: [
            "has_text": String(!TextNormalize.isBlank(text)),
            "result_count": String(results.count),
        ])
    }

    /// 全清（含作用域复位）：清空后不得仍停在跨柜而用户不知情。
    public func clear() {
        text = ""
        slotRaw = nil
        occasion = nil
        statusRaw = nil
        // D134：D120 加了颜色筛却没加进这里——用户点了「清除」
        // 仍卡在「没有匹配」，而屏幕上看不出还有哪个筛在生效。
        colorPaletteID = nil
        wearStats = [:]
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
            slotDisplayTitle: item.resolvedSlot.displayTitle,
            statusDisplayName: ItemStatusService.displayName(item.statusRaw),
            locationName: item.location?.name,
            closetName: includesCloset ? (item.wardrobe?.name ?? "") : nil)
    }
}
