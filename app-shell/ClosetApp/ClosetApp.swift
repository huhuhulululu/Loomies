// Loomies App 入口。CloudKit 默认 off。
import SwiftUI
import SwiftData
import ClosetModel
import ClosetCore
import ClosetUI

@main
struct ClosetApp: App {
    let container: ModelContainer

    init() {
        _ = DebugSettings.shared
        AppLog.notice("Loomies launch", .app)
        // 遥测（默认关、当前无 sink）：只带 schema 版本，无任何身份字段
        TelemetryGate.shared.track(.appLaunch)

        do {
            // 装配单一入口（D84）：实体清单 + 双域 config + migrationPlan 全在 LoomiesStore，
            // 这里不再手搓——加实体漏改一处即启动崩溃。
            container = try LoomiesStore.makeContainer()
            AppLog.info("ModelContainer ready", .data)
        } catch {
            // errRef：\(error) 全量 dump 携带容器路径（日志隐私不变量，与 Packages 同标准）
            AppLog.fault("ModelContainer failed: \(AppLog.errRef(error))", .data)
            fatalError("ModelContainer failed: \(AppLog.errRef(error))")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Wardrobe.name) private var wardrobes: [Wardrobe]
    @State private var onboarding = OnboardingViewModel()
    @State private var activeID: UUID?
    @State private var showSwitcher = false

    private var activeWardrobe: Wardrobe? {
        if let id = activeID, let w = wardrobes.first(where: { $0.id == id }) { return w }
        return wardrobes.first
    }

    var body: some View {
        Group {
            if let wardrobe = activeWardrobe {
                AppRootView(wardrobe: wardrobe)
                    .safeAreaInset(edge: .top, spacing: 0) {
                        if wardrobes.count > 1 {
                            HStack {
                                Menu {
                                    ForEach(wardrobes, id: \.id) { w in
                                        Button(w.name.isEmpty ? "Closet" : w.name) {
                                            activeID = w.id
                                            AppLog.info("switch wardrobe \(AppLog.ref(w.id))", .app)
                                        }
                                    }
                                } label: {
                                    Label(wardrobe.name.isEmpty ? "Closet" : wardrobe.name,
                                          systemImage: "cabinet")
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                }
                                Spacer()
                            }
                            .background(.ultraThinMaterial)
                        }
                    }
            } else {
                OnboardingScreen(vm: onboarding) {
                    if onboarding.finish(in: modelContext) {
                        if let w = onboarding.wardrobe {
                            _ = DemoSeedService.seedIfEmpty(w, in: modelContext)
                            activeID = w.id
                        }
                    }
                }
            }
        }
        .onChange(of: wardrobes.count) { _, _ in
            if activeID == nil { activeID = wardrobes.first?.id }
        }
    }
}

struct OnboardingScreen: View {
    @Bindable var vm: OnboardingViewModel
    var onFinish: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("About you") {
                    TextField("Name", text: $vm.displayName)
                        .textContentType(.name)
                    TextField("Home city", text: $vm.city)
                        .textContentType(.addressCity)
                }
                Section {
                    Text("Optional — pick a look-alike. You can refine measurements later.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Body type", selection: $vm.popularShapePick) {
                        Text("Skip for now").tag(Optional<PopularShape>.none)
                        Text("Hourglass").tag(Optional(PopularShape.hourglass))
                        Text("Pear").tag(Optional(PopularShape.pear))
                        Text("Apple").tag(Optional(PopularShape.apple))
                        Text("Rectangle").tag(Optional(PopularShape.rectangle))
                        Text("Inverted triangle").tag(Optional(PopularShape.invertedTriangle))
                    }
                } header: {
                    Text("Body (optional)")
                }
                Section {
                    Text("We'll add sample pieces so you can try outfit suggestions right away.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button("Get started") { onFinish() }
                        .disabled(!vm.canFinish)
                }
                if !vm.message.isEmpty {
                    Section {
                        // Fail/validation orange (not muted success chrome); VO hears the toast.
                        Text(vm.message)
                            .foregroundStyle(
                                CustomerFlashStyle.isFailure(vm.message)
                                    || vm.message == OnboardingViewModel.needNameAndCityMessage
                                    ? Color.orange : .secondary)
                            .accessibilityLabel(vm.message)
                    }
                }
            }
            .navigationTitle("Welcome")
        }
    }
}
