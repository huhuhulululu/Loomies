import SwiftUI
import SwiftData
import ClosetModel
import ClosetCore

/// 检索页（DESIGN §10.2：`Tab(role: .search)` 语义化搜索 tab，系统自动置尾端分离）。
///
/// D212（A2 液态导航）：从 `ClosetGridView` 的 in-toolbar 搜索（`showSearch` 模式）抽出。
/// 搜索是**跨柜的目的地**（DESIGN §2.3/§7 全局检索），不该寄居在衣柜页的一个开关里；
/// 抽成独立 tab 后衣柜页只管网格 + 筛选 + 入库，检索是并列的一等入口。
///
/// ⚠️ **视图主体的三块（`searchField` / `colorFilterBar` + `searchColorChip` /
/// `resultsSection`）刻意留在 `AppRootView.swift` 的 `extension SearchTabView`**：
/// `SearchByColourWiringTests`（OutfitFitMarkTests.swift）与 `SearchDebounceTests`
/// 两道接线门按**文件名** grep `AppRootView.swift`，找 `searchColorChip` /
/// `GarmentColorPalette.entries` / `searchVM.resultsHeadline` /
/// `searchVM.wearSummary(for: item)` / `runDebounced`。那两个测试文件不在本任务（T5）的
/// 文件所有权内、不能改；把这三块留在 `AppRootView.swift` 让门继续如实守着
/// 「检索页真的提供颜色筛 + 计数 + 上次穿着 + 文本走防抖」，而无需触碰所有权外的测试。
/// `body` 与其余 chip/空态在本文件，读起来仍是一条完整的屏幕。
struct SearchTabView: View {
    // 下列存储属性**不加 `private`**：`body` 引用的那三块子视图定义在
    // AppRootView.swift 的同模块 extension 里，需要跨文件读到它们。
    let wardrobe: Wardrobe
    @Environment(\.modelContext) var context
    @State var searchVM = SearchViewModel()
    /// 空态「Add piece」仍是一张 sheet（入库永远是 sheet，绝不做 tab）。
    @State private var showIntake = false
    /// 入库后的诚实回执（照片没处理成功但单品已存）——与衣柜页同一枚底部提示。
    @State private var seedFlashState = FlashState()
    /// 作用域切换器只在多柜时出现；跨柜结果行按各自衣柜主人取 body profile。
    @Query(sort: \Wardrobe.name) private var allWardrobes: [Wardrobe]
    /// 跨柜结果的合身标记需按单品所属衣柜主人取档案（各柜主人可能不同）。
    @Query private var bodyProfiles: [PersonBodyProfile]

    init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                // 作用域切换（DESIGN §2.3 全局检索）；单柜用户不显示无用控件。
                if allWardrobes.count > 1 {
                    scopePicker
                }
                slotFilterBar
                statusFilterBar
                occasionFilterBar
                colorFilterBar
                resultsSection
            }
            .background(DS.bg.ignoresSafeArea())
            .navigationTitle("Search")
            .sheet(isPresented: $showIntake) {
                AddPieceSheet(wardrobe: wardrobe) { flash in
                    // 与 ClosetGridView 入库路径同一枚诚实回执。
                    seedFlashState.show(flash, seconds: 3)
                }
            }
            .overlay(alignment: .bottom) {
                if let flash = seedFlashState.message {
                    CustomerFlashStyle.overlayChip(flash)
                        .padding()
                        .transition(.opacity)
                }
            }
            // 回到本 tab 若柜没变就保留用户当前的搜索/筛选；换柜了才重置作用域重跑。
            .onAppear {
                if searchVM.homeWardrobeID != wardrobe.id { prepareSearch() }
            }
            // 在本 tab 时切柜（Me → 切换）也要跟随（安全默认回本柜作用域）。
            .onChange(of: wardrobe.id) { _, _ in prepareSearch() }
        }
    }

    /// 进入/换柜时的初始化：钉本柜、按多柜与否给出作用域切换、跑一次。
    private func prepareSearch() {
        searchVM.homeWardrobeID = wardrobe.id
        searchVM.hasOtherClosets = allWardrobes.count > 1
        // 每次换柜回到本柜（安全默认：跨柜需用户显式选择）。
        searchVM.scope = .thisCloset
        searchVM.run(in: context)
    }

    // MARK: - 作用域 / 快捷筛（无接线门钉住的这几块留在本文件）

    private var scopePicker: some View {
        Picker("Scope", selection: $searchVM.scope) {
            ForEach(SearchScope.allCases, id: \.rawValue) { s in
                Text(s.displayTitle).tag(s)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.top, 8)
        .accessibilityLabel("Search scope")
        .onChange(of: searchVM.scope) { _, _ in searchVM.run(in: context) }
    }

    /// 槽位快捷过滤 — full GarmentSlot set (incl. accessory) + displayTitle, never raw dump.
    private var slotFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                searchSlotChip(nil, title: "All types")
                ForEach(GarmentSlot.allCases, id: \.rawValue) { slot in
                    searchSlotChip(slot.rawValue, title: slot.displayTitle)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .accessibilityLabel("Filter search by type")
    }

    /// Status facets (same allowed set as grid) — SearchService already filters statusRaw.
    private var statusFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                searchStatusChip(nil, title: "Any status")
                ForEach(
                    Array(ItemStatusService.allowed).sorted(by: {
                        ItemStatusService.displayName($0) < ItemStatusService.displayName($1)
                    }),
                    id: \.self
                ) { key in
                    searchStatusChip(key, title: ItemStatusService.displayName(key))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .accessibilityLabel("Filter search by status")
    }

    /// Occasion facets — same work/casual/date/gala set as QuickAdd / Today occasion.
    private var occasionFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                searchOccasionChip(nil, title: "Any occasion")
                ForEach(Self.searchOccasionKeys, id: \.self) { key in
                    searchOccasionChip(key, title: key.capitalized)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .accessibilityLabel("Filter search by occasion")
    }

    private func searchSlotChip(_ slot: String?, title: String) -> some View {
        let on = searchVM.slotRaw == slot
        return Button {
            searchVM.slotRaw = slot
            searchVM.homeWardrobeID = wardrobe.id
            searchVM.run(in: context)
        } label: {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(on ? DS.accent : DS.surface)
                .foregroundStyle(on ? DS.onAccent : DS.ink)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func searchStatusChip(_ status: String?, title: String) -> some View {
        let on = searchVM.statusRaw == status
        return Button {
            searchVM.statusRaw = status
            searchVM.homeWardrobeID = wardrobe.id
            searchVM.run(in: context)
        } label: {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(on ? DS.accent.opacity(0.9) : DS.surface)
                .foregroundStyle(on ? DS.onAccent : DS.ink)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// Matches QuickAdd / Today occasion picker keys (SearchService contains match).
    private static let searchOccasionKeys = ["work", "casual", "date", "gala"]

    private func searchOccasionChip(_ occasion: String?, title: String) -> some View {
        let on = searchVM.occasion == occasion
        return Button {
            searchVM.occasion = occasion
            searchVM.homeWardrobeID = wardrobe.id
            searchVM.run(in: context)
        } label: {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(on ? DS.accent.opacity(0.85) : DS.surface)
                .foregroundStyle(on ? DS.onAccent : DS.ink)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: - 空态 / 跨柜档案（被 AppRootView.swift 的 resultsSection 调用，故 internal）

    /// 空态：筛不到 vs 空柜——诚实点名筛项，不伪造「试穿」「库存」承诺。
    var searchEmptyState: some View {
        let title = searchVM.emptyStateTitle
        let description = searchVM.emptyStateDescription
        return ContentUnavailableView {
            // A11Y: .combine only on the text column — action buttons stay separate,
            // activatable VoiceOver targets (same fix class as the empty-grid state).
            VStack(spacing: 8) {
                Label(
                    title,
                    systemImage: searchVM.isFiltering ? "magnifyingglass" : "square.grid.2x2")
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title). \(description)")
        } actions: {
            if searchVM.isFiltering {
                Button("Clear search") {
                    searchVM.clearFiltersKeepingScope()
                    searchVM.run(in: context)
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.accent)
                .accessibilityHint("Clears name and filters, keeps this closet")
            } else {
                Button("Add piece") { showIntake = true }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.accent)
            }
        }
    }

    /// 跨柜结果：合身标记须用该单品所属衣柜主人的身体档案，不能用当前柜主人。
    func bodyProfile(for item: Item) -> PersonBodyProfile? {
        guard let pid = item.wardrobe?.owner?.id else { return ownerBodyProfile }
        return bodyProfiles.first { $0.personID == pid }
    }

    private var ownerBodyProfile: PersonBodyProfile? {
        guard let pid = wardrobe.owner?.id else { return nil }
        return bodyProfiles.first { $0.personID == pid }
    }
}
