import SwiftUI
import SwiftData
import ClosetModel
import ClosetCore
import ClosetIntake

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

/// 日历 tab 占位（逻辑在 CalendarPlanService）。
public struct CalendarPlaceholderView: View {
    let wardrobe: Wardrobe
    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    public var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Calendar",
                systemImage: "calendar",
                description: Text("Plan outfits by day for \(wardrobe.name.isEmpty ? "this closet" : wardrobe.name).")
            )
            .background(DS.bg.ignoresSafeArea())
            .navigationTitle("Calendar")
        }
    }
}

/// 我的 tab：衣柜切换 + 演示种子 + 设置占位。
public struct MePlaceholderView: View {
    let wardrobe: Wardrobe
    @Environment(\.modelContext) private var context
    @State private var seedMessage: String?

    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    public var body: some View {
        NavigationStack {
            List {
                Section("This closet") {
                    LabeledContent("Name", value: wardrobe.name.isEmpty ? "—" : wardrobe.name)
                    LabeledContent("City", value: wardrobe.locationCity ?? "—")
                    LabeledContent("Items", value: "\((wardrobe.items ?? []).count)")
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
                Section("Profile") {
                    Label("Body measurements", systemImage: "figure.stand")
                    Label("Personal color", systemImage: "paintpalette")
                }
                Section("Data") {
                    Label("Export", systemImage: "square.and.arrow.up")
                    Label("Delete all data", systemImage: "trash")
                }
            }
            .navigationTitle("Me")
        }
    }
}

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
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: DS.radius)
                            .fill(DS.surface)
                            .frame(height: 120)
                            .overlay(Text(item.slotRaw).font(.caption2).foregroundStyle(DS.muted))
                        Text(item.name).font(.caption).lineLimit(1)
                    }
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
                        try? context.save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
