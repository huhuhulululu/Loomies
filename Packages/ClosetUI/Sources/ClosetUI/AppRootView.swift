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
            CalendarPlaceholderView(wardrobe: wardrobe)
                .tabItem { Label("Calendar", systemImage: "calendar") }
            MePlaceholderView(wardrobe: wardrobe)
                .tabItem { Label("Me", systemImage: "person") }
        }
        .tint(DS.accent)
    }
}

/// 日历：列出计划 + 缺件 needsAttention（CalendarPlanService）。
public struct CalendarPlaceholderView: View {
    let wardrobe: Wardrobe
    @Environment(\.modelContext) private var context
    @State private var plans: [CalendarPlan] = []

    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    public var body: some View {
        NavigationStack {
            Group {
                if plans.isEmpty {
                    ContentUnavailableView(
                        "No plans yet",
                        systemImage: "calendar",
                        description: Text("Plan outfits from Today suggestions (coming soon). Plans for \(wardrobe.name.isEmpty ? "this closet" : wardrobe.name) show here.")
                    )
                } else {
                    List(plans, id: \.id) { plan in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(plan.date, style: .date)
                                    .font(.headline)
                                Text(plan.outfit?.name.isEmpty == false
                                     ? (plan.outfit?.name ?? "Outfit")
                                     : "Outfit")
                                    .font(.caption)
                                    .foregroundStyle(DS.muted)
                            }
                            Spacer()
                            if plan.needsAttention {
                                Label("Needs attention", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(DS.bg.ignoresSafeArea())
            .navigationTitle("Calendar")
            .onAppear { reload() }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        reload()
                        AppLog.debug("calendar reload \(plans.count)", .app)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    private func reload() {
        let all = (try? context.fetch(FetchDescriptor<CalendarPlan>())) ?? []
        plans = all.sorted { $0.date > $1.date }
    }
}

/// 我的 tab：衣柜信息 + 演示种子 + 调试台 + 诊断导出。
public struct MePlaceholderView: View {
    let wardrobe: Wardrobe
    @Environment(\.modelContext) private var context
    @State private var seedMessage: String?
    @State private var diagText: String?
    @State private var sharePayload: String?
    @Bindable private var debug = DebugSettings.shared

    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    public var body: some View {
        NavigationStack {
            List {
                Section("This closet") {
                    LabeledContent("Name", value: wardrobe.name.isEmpty ? "—" : wardrobe.name)
                    LabeledContent("City", value: wardrobe.locationCity ?? "—")
                    LabeledContent("Items", value: "\((wardrobe.items ?? []).count)")
                    LabeledContent("Available", value: "\((wardrobe.items ?? []).filter { $0.statusRaw == "available" }.count)")
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
                        // soft person id from wardrobe owner or zero UUID fallback
                        BodyProfileView(personID: wardrobe.owner?.id ?? UUID())
                    } label: {
                        Label("Body measurements", systemImage: "figure.stand")
                    }
                    Label("Personal color", systemImage: "paintpalette")
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

/// 衣柜浏览网格 + 入库 / 搜索 / 空柜种子。
public struct ClosetGridView: View {
    let wardrobe: Wardrobe
    @Environment(\.modelContext) private var context
    @State private var showIntake = false
    @State private var showSearch = false
    @State private var searchVM = SearchViewModel()

    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    private var items: [Item] {
        (wardrobe.items ?? []).sorted { $0.name < $1.name }
    }

    public var body: some View {
        NavigationStack {
            Group {
                if showSearch {
                    searchResults
                } else {
                    grid
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
                // 模拟器：mock 采集（空 data → process 仍可走 mock tagging 若接 IntakeViewModel）
                // 简化：手动快捷加一件 demo 单品表单
                QuickAddSheet(wardrobe: wardrobe)
            }
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12)], spacing: 12) {
                ForEach(items, id: \.id) { item in
                    NavigationLink {
                        ItemDetailView(item: item)
                    } label: {
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: DS.radius)
                                .fill(DS.surface)
                                .frame(height: 120)
                                .overlay(
                                    VStack {
                                        Text(item.slotRaw).font(.caption2).foregroundStyle(DS.muted)
                                        if item.statusRaw != "available" {
                                            Text(ItemStatusService.displayName(item.statusRaw))
                                                .font(.caption2).foregroundStyle(.orange)
                                        }
                                    }
                                )
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
                    Text("Add a piece or load samples to try copilot.")
                } actions: {
                    Button("Load samples") {
                        _ = DemoSeedService.seedIfEmpty(wardrobe, in: context)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.accent)
                    Button("Add piece") { showIntake = true }
                }
            }
        }
    }

    private var searchResults: some View {
        VStack(spacing: 0) {
            TextField("Search name or brand", text: $searchVM.text)
                .textFieldStyle(.roundedBorder)
                .padding()
                .onChange(of: searchVM.text) { _, _ in
                    searchVM.wardrobeID = wardrobe.id
                    searchVM.run(in: context)
                }
            List(searchVM.results, id: \.id) { item in
                VStack(alignment: .leading) {
                    Text(item.name).font(.headline)
                    Text("\(item.slotRaw) · \(item.statusRaw)")
                        .font(.caption).foregroundStyle(DS.muted)
                }
            }
            .listStyle(.plain)
        }
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
