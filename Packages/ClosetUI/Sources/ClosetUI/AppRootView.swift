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

    public var body: some View {
        NavigationStack {
            List {
                Section("This closet") {
                    LabeledContent("Name", value: wardrobe.name.isEmpty ? "—" : wardrobe.name)
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
                    Button("Load sample pieces") {
                        let n = DemoSeedService.seed(wardrobe, in: context)
                        seedMessage = n == 0 ? "Already seeded." : "Added \(n) sample pieces."
                    }
                    if let seedMessage {
                        Text(seedMessage).font(.caption).foregroundStyle(DS.muted)
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
                    NavigationLink {
                        BodyProfileView(personID: wardrobe.owner?.id ?? UUID())
                    } label: {
                        Label("Body measurements", systemImage: "figure.stand")
                    }
                    NavigationLink {
                        PersonalColorView(personID: wardrobe.owner?.id ?? UUID())
                    } label: {
                        Label("Personal color", systemImage: "paintpalette")
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
                            dataMessage = "Export ready (\(json.count) chars)."
                            #else
                            dataMessage = String(json.prefix(400)) + (json.count > 400 ? "…" : "")
                            #endif
                            AppLog.notice("data export ready body=\(includeBodyInExport)", .data)
                        } catch {
                            dataMessage = "Export failed: \(error.localizedDescription)"
                            AppLog.error("data export failed: \(error)", .data)
                        }
                    }
                    Button("Delete all data…", role: .destructive) {
                        confirmDeleteAll = true
                    }
                    Text("Uninstalling the app does not erase iCloud-synced data. Use Delete all data to exercise your deletion rights.")
                        .font(.caption2)
                        .foregroundStyle(DS.muted)
                    if let dataMessage {
                        Text(dataMessage).font(.caption).foregroundStyle(DS.muted)
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
                            diagText = "Diagnostics ready (\(json.count) chars) — share sheet."
                            #else
                            diagText = String(json.prefix(500)) + (json.count > 500 ? "…" : "")
                            #endif
                            AppLog.notice("diagnostics exported", .diagnostics)
                        } catch {
                            diagText = "Export failed: \(error.localizedDescription)"
                            AppLog.error("diagnostics export failed: \(error)", .diagnostics)
                        }
                    }
                    if let diagText {
                        Text(diagText).font(.caption).foregroundStyle(DS.muted)
                    }
                }
                if debug.panelEnabled {
                    debugSection
                } else {
                    Section {
                        Button("Enable debug panel") {
                            debug.panelEnabled = true
                        }
                        .foregroundStyle(DS.accent)
                    }
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
                        dataMessage = "Delete failed: \(error.localizedDescription)"
                        AppLog.error("deleteAll failed: \(error)", .data)
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
                Text("No log lines yet.").font(.caption).foregroundStyle(DS.muted)
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

/// 衣柜浏览网格 + 状态过滤 / 合身标记 / 入库 / 搜索。
public struct ClosetGridView: View {
    let wardrobe: Wardrobe
    @Environment(\.modelContext) private var context
    @State private var showIntake = false
    @State private var showSearch = false
    @State private var searchVM = SearchViewModel()
    @State private var statusFilter: String = "all"
    @State private var bodyProfile: PersonBodyProfile?

    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    private var allItems: [Item] {
        (wardrobe.items ?? []).sorted { $0.name < $1.name }
    }

    private var items: [Item] {
        if statusFilter == "all" { return allItems }
        return allItems.filter { $0.statusRaw == statusFilter }
    }

    public var body: some View {
        NavigationStack {
            Group {
                if showSearch {
                    searchResults
                } else {
                    VStack(spacing: 0) {
                        statusFilterBar
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
                            searchVM.wardrobeID = wardrobe.id
                            searchVM.run(in: context)
                        }
                    } label: {
                        Image(systemName: showSearch ? "xmark" : "magnifyingglass")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showIntake = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showIntake) {
                AddPieceSheet(wardrobe: wardrobe)
            }
            .onAppear { loadBodyProfile() }
        }
    }

    private var statusFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip("all", title: "All")
                filterChip("available", title: "Available")
                filterChip("inWash", title: "In wash")
                filterChip("dryCleaning", title: "Dry clean")
                filterChip("idle", title: "Idle")
                filterChip("lent", title: "Lent")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
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
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12)], spacing: 12) {
                ForEach(items, id: \.id) { item in
                    NavigationLink {
                        ItemDetailView(item: item, bodyProfile: bodyProfile)
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
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .overlay {
            if items.isEmpty {
                ContentUnavailableView {
                    Label("Empty closet", systemImage: "square.grid.2x2")
                } description: {
                    Text(statusFilter == "all"
                         ? "Add a piece or load samples to try copilot."
                         : "No pieces in this status.")
                } actions: {
                    if statusFilter == "all" {
                        Button("Load samples") {
                            _ = DemoSeedService.seedIfEmpty(wardrobe, in: context)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(DS.accent)
                        Button("Add piece") { showIntake = true }
                    } else {
                        Button("Show all") { statusFilter = "all" }
                    }
                }
            }
        }
    }

    private func fitBadge(for item: Item) -> String? {
        guard let bodyProfile,
              let v = FitMarkService.mark(item: item, profile: bodyProfile) else { return nil }
        return FitMarkCopy.label(v)
    }

    private func loadBodyProfile() {
        guard let pid = wardrobe.owner?.id else { bodyProfile = nil; return }
        let all = (try? context.fetch(FetchDescriptor<PersonBodyProfile>())) ?? []
        bodyProfile = all.first { $0.personID == pid }
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
            // 槽位快捷过滤
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    searchSlotChip(nil, title: "All types")
                    ForEach(["top", "bottom", "dress", "outerwear", "shoes"], id: \.self) { s in
                        searchSlotChip(s, title: s.capitalized)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            if searchVM.results.isEmpty {
                searchEmptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(searchVM.results, id: \.id) { item in
                    NavigationLink {
                        ItemDetailView(item: item, bodyProfile: bodyProfile)
                    } label: {
                        HStack(spacing: 12) {
                            ItemThumbnailView(item: item, height: 48)
                                .frame(width: 48)
                            VStack(alignment: .leading) {
                                Text(item.name).font(.headline)
                                Text("\(item.slotRaw.capitalized) · \(ItemStatusService.displayName(item.statusRaw))")
                                    .font(.caption).foregroundStyle(DS.muted)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var searchEmptyState: some View {
        ContentUnavailableView {
            Label(
                searchVM.isFiltering ? "No matches" : "No pieces here",
                systemImage: searchVM.isFiltering ? "magnifyingglass" : "square.grid.2x2")
        } description: {
            Text(searchVM.isFiltering
                 ? "Try another name, brand, or type filter."
                 : "Add a piece or load samples, then search.")
        } actions: {
            if searchVM.isFiltering {
                Button("Clear search") {
                    searchVM.clearFiltersKeepingWardrobe()
                    searchVM.run(in: context)
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.accent)
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
    }
}

/// 模拟器快捷入库（不依赖相机）：手填 name/slot → 落库。
struct QuickAddSheet: View {
    let wardrobe: Wardrobe
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var slot = "top"
    @State private var occasion = "work"

    private let slots = ["top", "bottom", "dress", "outerwear", "shoes", "accessory"]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Picker("Type", selection: $slot) {
                    ForEach(slots, id: \.self) { Text($0.capitalized).tag($0) }
                }
                Picker("Occasion", selection: $occasion) {
                    ForEach(["work", "casual", "date", "gala"], id: \.self) {
                        Text($0.capitalized).tag($0)
                    }
                }
            }
            .navigationTitle("Add piece")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let item = Item(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
                        item.slotRaw = slot
                        item.occasionsRaw = [occasion, "casual"]
                        item.warmthRaw = Warmth.light.rawValue
                        item.statusRaw = "available"
                        item.colorIsNeutral = true
                        item.wardrobe = wardrobe
                        context.insert(item)
                        ModelSave.save(context, label: "quickAdd")
                        AppLog.info("quickAdd \(item.name)", .intake)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
