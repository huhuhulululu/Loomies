import SwiftUI
import SwiftData
import ClosetModel
import ClosetCore
import ClosetIntake
#if canImport(UIKit)
import UIKit
#endif

/// App 导航壳（DESIGN §10.2：底部 TabView ≤5 tab）。
/// Today / Closet / Calendar / Me；入库经 Closet「+」sheet。
public struct AppRootView: View {
    let wardrobe: Wardrobe
    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    public var body: some View {
        TabView {
            CopilotView(wardrobe: wardrobe)
                .tabItem { Label("Today", systemImage: "sparkles") }
            ClosetGridView(wardrobe: wardrobe)
                .tabItem { Label("Closet", systemImage: "square.grid.2x2") }
            CalendarView(wardrobe: wardrobe)
                .tabItem { Label("Calendar", systemImage: "calendar") }
            MeView(wardrobe: wardrobe)
                .tabItem { Label("Me", systemImage: "person") }
        }
        .tint(DS.accent)
    }
}

/// 兼容旧名。
public typealias CalendarPlaceholderView = CalendarView
public typealias MePlaceholderView = MeView

/// 我的 tab：衣柜 / 体型 / 色彩 / 存放 / 数据生命周期 / 诊断。
public struct MeView: View {
    let wardrobe: Wardrobe
    @Environment(\.modelContext) private var context
    @State private var seedMessage: String?
    @State private var diagText: String?
    @State private var dataMessage: String?
    @State private var sharePayload: String?
    @State private var includeBodyInExport = false
    @State private var confirmDeleteAll = false
    @Bindable private var debug = DebugSettings.shared

    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    /// Profile links (body measurements / personal color) are shown only for a
    /// wardrobe with a real owner — never keyed to a random fallback UUID.
    static func profileOwner(of wardrobe: Wardrobe) -> Person? {
        wardrobe.owner
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("This closet") {
                    NavigationLink {
                        ClosetNameEditView(wardrobe: wardrobe)
                    } label: {
                        LabeledContent("Name", value: wardrobe.name.isEmpty ? "—" : wardrobe.name)
                    }
                    NavigationLink {
                        ClosetCityEditView(wardrobe: wardrobe)
                    } label: {
                        LabeledContent("City", value: wardrobe.locationCity ?? "Set city")
                    }
                    LabeledContent("Items", value: "\((wardrobe.items ?? []).count)")
                    LabeledContent("Available", value: "\((wardrobe.items ?? []).filter { $0.statusRaw == "available" }.count)")
                    NavigationLink("Storage locations") {
                        StorageLocationsView(wardrobe: wardrobe)
                    }
                }
                Section("Demo") {
                    Button("Load samples") {
                        let outcome = DemoSeedService.seed(wardrobe, in: context)
                        seedMessage = outcome.meDemoFlashMessage
                    }
                    .accessibilityHint(DemoSeedService.loadButtonAccessibilityHint)
                    if let seedMessage {
                        // Me Demo Outcome — fail orange (not muted success chrome).
                        Text(seedMessage)
                            .font(.caption)
                            .foregroundStyle(
                                CustomerFlashStyle.isFailure(seedMessage)
                                    ? Color.orange : DS.muted)
                            .accessibilityLabel(seedMessage)
                    }
                }
                Section("Wardrobes") {
                    NavigationLink("Manage wardrobes") {
                        WardrobeManageView()
                    }
                }
                Section("Looks") {
                    NavigationLink("Favorites") {
                        FavoritesView(wardrobe: wardrobe)
                    }
                }
                Section("Profile") {
                    if let person = wardrobe.owner {
                        NavigationLink {
                            PersonNameEditView(person: person)
                        } label: {
                            LabeledContent("Name", value: person.name.isEmpty ? "—" : person.name)
                        }
                    }
                    // Body / Personal-color need a real owner id — an ownerless
                    // wardrobe must not persist an orphan PersonBodyProfile keyed
                    // to a random UUID (parity with the gated PersonNameEditView).
                    if let person = MeView.profileOwner(of: wardrobe) {
                        NavigationLink {
                            BodyProfileView(personID: person.id)
                        } label: {
                            Label("Body measurements", systemImage: "figure.stand")
                        }
                        NavigationLink {
                            PersonalColorView(personID: person.id)
                        } label: {
                            Label("Personal color", systemImage: "paintpalette")
                        }
                    }
                }
                Section("Data") {
                    Toggle("Include body measurements in export", isOn: $includeBodyInExport)
                    Button("Export my data") {
                        do {
                            let json = try DataLifecycleService.exportJSONString(
                                in: context, includeBodyDimensions: includeBodyInExport)
                            #if os(iOS)
                            sharePayload = json
                            #endif
                            // Honest "ready" toast only when the payload was actually
                            // handed off (share sheet); otherwise inline preview —
                            // parity with diagnostics below.
                            dataMessage = DataExportFeedback.message(
                                payloadHandedOff: DataExportFeedback.payloadHandoffAvailable,
                                json: json,
                                includeBodyDimensions: includeBodyInExport)
                            AppLog.notice("data export ready body=\(includeBodyInExport)", .data)
                        } catch {
                            dataMessage = DataLifecycleService.exportFailedMessage
                            AppLog.error("data export failed: \(AppLog.errRef(error))", .data)
                        }
                    }
                    .accessibilityHint(DataLifecycleService.exportButtonAccessibilityHint)
                    Button("Delete all data…", role: .destructive) {
                        confirmDeleteAll = true
                    }
                    .accessibilityHint(DataLifecycleService.deleteAllButtonAccessibilityHint)
                    Text("Uninstalling the app does not erase iCloud-synced data. Use Delete all data to exercise your deletion rights.")
                        .font(.caption2)
                        .foregroundStyle(DS.muted)
                    if let dataMessage {
                        // Export ready vs couldn't export/delete — fail orange (parity Demo seed).
                        Text(dataMessage)
                            .font(.caption)
                            .foregroundStyle(
                                CustomerFlashStyle.isFailure(dataMessage)
                                    ? Color.orange : DS.muted)
                            .accessibilityLabel(dataMessage)
                    }
                }
                Section("About") {
                    NavigationLink("About Loomies") { AboutView() }
                }
                Section("Support") {
                    Button("Export diagnostics") {
                        do {
                            let json = try DiagnosticsExport.jsonString(
                                in: context,
                                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0",
                                build: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0",
                                flags: debug.flagsForDiagnostics)
                            #if os(iOS)
                            sharePayload = json
                            // Honest status (no char count) — same bar as data exportReadyMessage.
                            diagText = DiagnosticsExport.exportReadyMessage
                            #else
                            diagText = String(json.prefix(500)) + (json.count > 500 ? "…" : "")
                            #endif
                            AppLog.notice("diagnostics exported", .diagnostics)
                        } catch {
                            diagText = DiagnosticsExport.exportFailedMessage
                            AppLog.error("diagnostics export failed: \(AppLog.errRef(error))", .diagnostics)
                        }
                    }
                    .accessibilityHint(DiagnosticsExport.exportButtonAccessibilityHint)
                    if let diagText {
                        // Diagnostics ready vs couldn't export — fail orange (parity data export).
                        Text(diagText)
                            .font(.caption)
                            .foregroundStyle(
                                CustomerFlashStyle.isFailure(diagText)
                                    ? Color.orange : DS.muted)
                            .accessibilityLabel(diagText)
                    }
                }
                if debug.panelEnabled {
                    debugSection
                } else {
                    // DEBUG-only：Release/TestFlight 不暴露入口——verbose 会把 debug 级
                    // 明细灌进日志环并渲染在 Me 页（肩窥面）；调试构建外走 -debugPanel 参数。
                    #if DEBUG
                    Section {
                        Button("Enable debug panel") {
                            debug.panelEnabled = true
                        }
                        .foregroundStyle(DS.accent)
                    }
                    #endif
                }
            }
            .navigationTitle("Me")
            .confirmationDialog(
                "Delete all data?",
                isPresented: $confirmDeleteAll,
                titleVisibility: .visible
            ) {
                Button("Delete everything", role: .destructive) {
                    do {
                        let receipt = try DataLifecycleService.deleteAllUserData(in: context)
                        dataMessage = receipt.summaryLine
                        // RootView @Query 空柜 → 自动回 Onboarding。
                    } catch {
                        dataMessage = DataLifecycleService.deleteAllFailedMessage
                        AppLog.error("deleteAll failed: \(AppLog.errRef(error))", .data)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes closets, pieces, looks, wear history, plans, and local photos. Body measurements are also removed. This cannot be undone.")
            }
            #if os(iOS)
            .sheet(item: Binding(
                get: { sharePayload.map { ShareBox(text: $0) } },
                set: { sharePayload = $0?.text }
            )) { box in
                ActivityView(items: [box.text])
            }
            #endif
        }
    }

    @ViewBuilder
    private var debugSection: some View {
        Section("Debug") {
            Toggle("Verbose logging", isOn: $debug.verboseLogging)
            Toggle("Force cold start", isOn: $debug.forceColdStart)
            Toggle("Disable 7-day anti-repeat", isOn: $debug.disableAntiRepeat)
            Toggle("Show status on Today", isOn: $debug.showEmptyReason)
            LabeledContent("Log ring", value: "\(AppLog.ring.count) lines")
            Button("Clear log ring") { AppLog.ring.clear() }
            Button("Reset debug flags") { debug.resetAll() }
            Button("Hide debug panel") { debug.panelEnabled = false }
        }
        Section("Recent logs") {
            let lines = AppLog.ring.snapshot().suffix(12).reversed()
            if lines.isEmpty {
                Text("No log lines yet").font(.caption).foregroundStyle(DS.muted)
            } else {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, e in
                    Text(e.lineText)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(DS.muted)
                }
            }
        }
    }
}

private struct ShareBox: Identifiable {
    let id = UUID()
    let text: String
}

#if os(iOS)
/// 系统分享 sheet（诊断 JSON）。
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

/// 衣柜浏览网格 + 状态/类型过滤 / 合身标记 / 入库 / 搜索。
public struct ClosetGridView: View {
    let wardrobe: Wardrobe
    @Environment(\.modelContext) private var context
    @State private var showIntake = false
    @State private var showSearch = false
    @State private var showFittingRoom = false
    @State private var searchVM = SearchViewModel()
    @State private var statusFilter: String = "all"
    /// nil = all types; chips use GarmentSlot + displaySlot name correction.
    @State private var slotFilter: String? = nil
    /// Bottom flash chip: Load samples Outcome + intake post-save honesty (no silent fail).
    @State private var seedFlash: String?
    /// Toast 代际：同文案连发时旧计时器不得提前清掉新 toast。
    @State private var seedFlashToken = 0
    /// Live query so Me → Body edits refresh FitMark badges without tab remount.
    @Query private var bodyProfiles: [PersonBodyProfile]

    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    /// Owner body profile for FitMark (same person as wardrobe.owner).
    private var ownerBodyProfile: PersonBodyProfile? {
        guard let pid = wardrobe.owner?.id else { return nil }
        return bodyProfiles.first { $0.personID == pid }
    }

    private var allItems: [Item] {
        (wardrobe.items ?? []).sorted { ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString) }
    }

    private var items: [Item] {
        SearchService.filterItems(
            allItems,
            statusRaw: statusFilter == "all" ? nil : statusFilter,
            slotRaw: slotFilter)
    }

    private var isFacetFiltering: Bool {
        statusFilter != "all" || slotFilter != nil
    }

    public var body: some View {
        NavigationStack {
            Group {
                if showSearch {
                    searchResults
                } else {
                    VStack(spacing: 0) {
                        statusFilterBar
                        typeFilterBar
                        grid
                    }
                }
            }
            .background(DS.bg.ignoresSafeArea())
            .navigationTitle(wardrobe.name.isEmpty ? "Closet" : wardrobe.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showSearch.toggle()
                        if showSearch {
                            // Carry grid status/type facets into search so laundry/status filters stick.
                            searchVM.wardrobeID = wardrobe.id
                            searchVM.statusRaw = statusFilter == "all" ? nil : statusFilter
                            searchVM.slotRaw = slotFilter
                            searchVM.run(in: context)
                        }
                    } label: {
                        Image(systemName: showSearch ? "xmark" : "magnifyingglass")
                    }
                    .accessibilityLabel(
                        ClosetGridEmptyCopy.searchToggleAccessibilityLabel(isSearchOpen: showSearch))
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showIntake = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(ClosetGridEmptyCopy.addPieceAccessibilityLabel)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showFittingRoom = true } label: {
                        Image(systemName: "tshirt")
                    }
                    .accessibilityLabel(FittingRoomView.entryAccessibilityLabel)
                }
            }
            .sheet(isPresented: $showFittingRoom) {
                FittingRoomView(wardrobe: wardrobe)
            }
            .sheet(isPresented: $showIntake) {
                AddPieceSheet(wardrobe: wardrobe) { flash in
                    // Post-save honesty flash (photo failed processing but item saved)
                    // surfaces here — the sheet that owned statusMessage is already gone.
                    flashSeedChip(flash)
                }
            }
            .overlay(alignment: .bottom) {
                if let seedFlash {
                    // Load samples Outcome — fail orange (parity Favorites / Calendar).
                    CustomerFlashStyle.overlayChip(seedFlash)
                        .padding()
                        .transition(.opacity)
                }
            }
        }
    }

    /// Empty-grid Load samples — same Outcome flash as Today cold-start (no silent fail).
    private func loadSamplesFromEmptyGrid() {
        let outcome = DemoSeedService.seedIfEmpty(wardrobe, in: context)
        flashSeedChip(outcome.flashMessage)
    }

    /// Bottom overlay chip with 3s auto-clear (Load samples Outcome / intake post-save honesty).
    private func flashSeedChip(_ message: String?) {
        seedFlashToken &+= 1
        let token = seedFlashToken
        seedFlash = message
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if seedFlashToken == token { seedFlash = nil }
        }
    }

    private var statusFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Full ItemStatusService.allowed set (displayName), plus All.
                filterChip("all", title: "All")
                ForEach(
                    Array(ItemStatusService.allowed).sorted(by: { ItemStatusService.displayName($0) < ItemStatusService.displayName($1) }),
                    id: \.self
                ) { key in
                    filterChip(key, title: ItemStatusService.displayName(key))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .accessibilityLabel("Filter by status")
    }

    /// Type chips share GarmentSlot.allCases + displayTitle with search/detail Type.
    private var typeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                typeChip(nil, title: "All types")
                ForEach(GarmentSlot.allCases, id: \.rawValue) { slot in
                    typeChip(slot.rawValue, title: slot.displayTitle)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .accessibilityLabel("Filter by type")
    }

    private func filterChip(_ key: String, title: String) -> some View {
        let on = statusFilter == key
        return Button {
            statusFilter = key
        } label: {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(on ? DS.accent : DS.surface)
                .foregroundStyle(on ? Color.white : DS.ink)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func typeChip(_ slot: String?, title: String) -> some View {
        let on = slotFilter == slot
        return Button {
            slotFilter = slot
        } label: {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(on ? DS.accent.opacity(0.9) : DS.surface)
                .foregroundStyle(on ? Color.white : DS.ink)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12)], spacing: 12) {
                ForEach(items, id: \.id) { item in
                    NavigationLink {
                        ItemDetailView(item: item, bodyProfile: ownerBodyProfile)
                    } label: {
                        VStack(spacing: 6) {
                            ZStack(alignment: .bottomTrailing) {
                                ItemThumbnailView(item: item, height: 120)
                                VStack(alignment: .trailing, spacing: 2) {
                                    if item.statusRaw != "available" {
                                        Text(ItemStatusService.displayName(item.statusRaw))
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.orange.opacity(0.9))
                                            .foregroundStyle(.white)
                                            .clipShape(Capsule())
                                    }
                                    if let fit = fitBadge(for: item) {
                                        Text(fit)
                                            .font(.caption2.weight(.semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(DS.accent.opacity(0.9))
                                            .foregroundStyle(.white)
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(6)
                            }
                            Text(item.name).font(.caption).lineLimit(1).foregroundStyle(DS.ink)
                            // Location when set (Me Storage / detail assign) — same meta as Search.
                            let meta = ClosetItemRowCopy.metaLine(for: item)
                            if item.location != nil {
                                Text(meta)
                                    .font(.caption2)
                                    .foregroundStyle(DS.muted)
                                    .lineLimit(1)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            item.location == nil
                                ? item.name
                                : "\(item.name). \(ClosetItemRowCopy.metaLine(for: item))")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .overlay {
            if items.isEmpty {
                let title = ClosetGridEmptyCopy.title(isFacetFiltering: isFacetFiltering)
                let description = emptyGridDescription
                ContentUnavailableView {
                    // A11Y: .combine only on the text column — the action
                    // buttons stay separate, activatable VoiceOver targets
                    // (same fix class as IntakeView empty state).
                    VStack(spacing: 8) {
                        Label(title, systemImage: "square.grid.2x2")
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(title). \(description)")
                } actions: {
                    if isFacetFiltering {
                        Button("Clear filters") {
                            statusFilter = "all"
                            slotFilter = nil
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(DS.accent)
                        .accessibilityHint("Resets status and type filters")
                    } else {
                        Button("Load samples") {
                            loadSamplesFromEmptyGrid()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(DS.accent)
                        // Same demo-not-photos VO as Me → Demo Load samples.
                        .accessibilityHint(DemoSeedService.loadButtonAccessibilityHint)
                        Button("Add piece") { showIntake = true }
                    }
                }
            }
        }
    }

    private var emptyGridDescription: String {
        ClosetGridEmptyCopy.description(
            isFacetFiltering: isFacetFiltering,
            hasSlotFilter: slotFilter != nil,
            hasStatusFilter: statusFilter != "all")
    }

    private func fitBadge(for item: Item) -> String? {
        guard let profile = ownerBodyProfile,
              let v = FitMarkService.mark(item: item, profile: profile) else { return nil }
        return FitMarkCopy.label(v)
    }

    private var searchResults: some View {
        VStack(spacing: 0) {
            TextField("Search name or brand", text: $searchVM.text)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.top, 12)
                .accessibilityLabel("Search name or brand")
                .onChange(of: searchVM.text) { _, _ in
                    searchVM.wardrobeID = wardrobe.id
                    searchVM.run(in: context)
                }
            // 槽位快捷过滤 — full GarmentSlot set (incl. accessory) + displayTitle, never raw dump.
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
            // Status facets (same allowed set as grid) — SearchService already filters statusRaw.
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
            // Occasion facets — same work/casual/date/gala set as QuickAdd / Today occasion.
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
            if searchVM.results.isEmpty {
                searchEmptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(searchVM.results, id: \.id) { item in
                    NavigationLink {
                        ItemDetailView(item: item, bodyProfile: ownerBodyProfile)
                    } label: {
                        HStack(spacing: 12) {
                            ItemThumbnailView(item: item, height: 48)
                                .frame(width: 48)
                            VStack(alignment: .leading) {
                                Text(item.name).font(.headline)
                                Text(ClosetItemRowCopy.metaLine(for: item))
                                    .font(.caption).foregroundStyle(DS.muted)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            "\(item.name). \(ClosetItemRowCopy.metaLine(for: item))")
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var searchEmptyState: some View {
        let title = searchVM.emptyStateTitle
        let description = searchVM.emptyStateDescription
        return ContentUnavailableView {
            // A11Y: .combine only on the text column — the action
            // buttons stay separate, activatable VoiceOver targets
            // (same fix class as the empty-grid state above).
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
                    searchVM.clearFiltersKeepingWardrobe()
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

    private func searchSlotChip(_ slot: String?, title: String) -> some View {
        let on = searchVM.slotRaw == slot
        return Button {
            searchVM.slotRaw = slot
            searchVM.wardrobeID = wardrobe.id
            searchVM.run(in: context)
        } label: {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(on ? DS.accent : DS.surface)
                .foregroundStyle(on ? Color.white : DS.ink)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func searchStatusChip(_ status: String?, title: String) -> some View {
        let on = searchVM.statusRaw == status
        return Button {
            searchVM.statusRaw = status
            searchVM.wardrobeID = wardrobe.id
            searchVM.run(in: context)
        } label: {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(on ? DS.accent.opacity(0.9) : DS.surface)
                .foregroundStyle(on ? Color.white : DS.ink)
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
            searchVM.wardrobeID = wardrobe.id
            searchVM.run(in: context)
        } label: {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(on ? DS.accent.opacity(0.85) : DS.surface)
                .foregroundStyle(on ? Color.white : DS.ink)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// 模拟器快捷入库（不依赖相机）：手填 name/slot → 落库。
struct QuickAddSheet: View {
    let wardrobe: Wardrobe
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var draft = QuickAddDraft()
    @State private var message = ""

    /// Customer toast when ModelSave fails — same bar as manual Add (no silent stay).
    static let saveFailedMessage = IntakeViewModel.confirmSaveFailedMessage

    /// Order-preserving dedup — the picker occasion may already be "casual".
    /// nonisolated: pure helper, callable off the View's MainActor isolation.
    nonisolated static func dedupOccasions(_ raw: [String]) -> [String] {
        QuickAddDraft.dedupOccasions(raw)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $draft.name)
                Picker("Type", selection: $draft.slotRaw) {
                    ForEach(GarmentSlot.allCases, id: \.rawValue) { s in
                        Text(s.displayTitle).tag(s.rawValue)
                    }
                }
                Picker("Occasion", selection: $draft.occasion) {
                    ForEach(["work", "casual", "date", "gala"], id: \.self) {
                        Text($0.capitalized).tag($0)
                    }
                }
                // D83：温区/颜色不再硬编码（light + 中性）——冷天必空推荐与配色恒中性的根因
                Section("Warmth") { WarmthPicker(warmthRaw: $draft.warmthRaw) }
                Section("Color") { ColorSwatchPicker(paletteID: $draft.colorPaletteID) }
                if !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(Color.orange)
                        .accessibilityLabel(message)
                }
            }
            .navigationTitle("Add piece")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard draft.commit(into: wardrobe, context: context) != nil else {
                            // Stay on form with toast (no silent dismiss); next Save retries.
                            message = Self.saveFailedMessage
                            return
                        }
                        dismiss()
                    }
                    .disabled(!draft.canCommit)
                }
            }
        }
    }
}

/// Export feedback decision: "ready" toast only when the JSON actually left the
/// app (share-sheet handoff); otherwise an inline preview — parity with
/// diagnostics (macOS has no share payload).
enum DataExportFeedback {
    /// iOS hands the JSON to the share sheet; other platforms have no handoff.
    static var payloadHandoffAvailable: Bool {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }

    static func message(
        payloadHandedOff: Bool,
        json: String,
        includeBodyDimensions: Bool,
        previewLimit: Int = 500
    ) -> String {
        if payloadHandedOff {
            // Honest body-inclusion toast (not char count); matches toggle state.
            return DataLifecycleService.exportReadyMessage(
                includeBodyDimensions: includeBodyDimensions)
        }
        return String(json.prefix(previewLimit)) + (json.count > previewLimit ? "…" : "")
    }
}
