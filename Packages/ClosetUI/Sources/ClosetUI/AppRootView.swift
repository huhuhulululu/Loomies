import SwiftUI
import ClosetModel
import ClosetCore

/// App 导航壳（DESIGN §10.2：底部 TabView ≤5 tab）。
/// Today / Closet / Calendar / Me；入库经 Closet「+」sheet（真机接相机）。
/// 真机 target 再加 Liquid Glass、tabBarMinimizeBehavior、WeatherKit。
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
            MePlaceholderView()
                .tabItem { Label("Me", systemImage: "person") }
        }
        .tint(DS.accent)
    }
}

/// 日历 tab 占位（逻辑在 CalendarPlanService；完整 UI 待 Xcode 渲染迭代）。
public struct CalendarPlaceholderView: View {
    let wardrobe: Wardrobe
    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    public var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Calendar",
                systemImage: "calendar",
                description: Text("Plan outfits by day. Plans for \(wardrobe.name.isEmpty ? "this closet" : wardrobe.name) will show here.")
            )
            .background(DS.bg.ignoresSafeArea())
            .navigationTitle("Calendar")
        }
    }
}

/// 我的 tab 占位（设置 IA 见 DESIGN §10.6；身体档案/导出待接）。
public struct MePlaceholderView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    Label("Body measurements", systemImage: "figure.stand")
                    Label("Personal color", systemImage: "paintpalette")
                }
                Section("Closets & units") {
                    Label("Wardrobes", systemImage: "cabinet")
                    Label("Units", systemImage: "ruler")
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

/// 衣柜浏览网格（DESIGN §10：白底统一影调网格，百件级性能预算 §11.4）。
public struct ClosetGridView: View {
    let wardrobe: Wardrobe
    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    private var items: [Item] {
        (wardrobe.items ?? []).sorted { $0.name < $1.name }
    }

    public var body: some View {
        NavigationStack {
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
            .background(DS.bg.ignoresSafeArea())
            .navigationTitle(wardrobe.name.isEmpty ? "Closet" : wardrobe.name)
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView("Empty closet", systemImage: "square.grid.2x2",
                        description: Text("Add your first piece from the Today tab."))
                }
            }
        }
    }
}
