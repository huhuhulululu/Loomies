import SwiftUI
import ClosetModel
import ClosetCore

/// App 导航壳（DESIGN §10.2：底部 TabView）。组装 copilot 主屏 + 衣柜浏览。
/// 入库（IntakeView）经 Closet 页「+」以 sheet 呈现（真机接相机/服务）；本壳经 swift build 验证。
/// 真机 target 再加 Liquid Glass 自定义玻璃、tabBarMinimizeBehavior、日历/我的页。
public struct AppRootView: View {
    let wardrobe: Wardrobe
    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    public var body: some View {
        TabView {
            CopilotView(wardrobe: wardrobe)
                .tabItem { Label("Today", systemImage: "sparkles") }
            ClosetGridView(wardrobe: wardrobe)
                .tabItem { Label("Closet", systemImage: "square.grid.2x2") }
        }
        .tint(DS.accent)
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
