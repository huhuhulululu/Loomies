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
    // 不带 sort：单键排序下同名衣柜的菜单顺序会随 fetch 漂移。
    // 排序/显示名/active 解析统一走 ClosetUI 的 WardrobeSwitcher（唯一真相）。
    @Query private var allWardrobes: [Wardrobe]
    private var wardrobes: [Wardrobe] { WardrobeSwitcher.ordered(allWardrobes) }
    @State private var onboarding = OnboardingViewModel()
    @State private var activeID: UUID?
    @State private var showSwitcher = false

    private var activeWardrobe: Wardrobe? {
        WardrobeSwitcher.resolveActive(id: activeID, among: allWardrobes)
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
                                        // 同名衣柜靠城市/主人区分——菜单里两行一模一样时用户无从选择
                                        Button(WardrobeSwitcher.menuTitle(w, among: wardrobes)) {
                                            activeID = w.id
                                            WardrobeSwitcher.trackSwitch()
                                            AppLog.info("switch wardrobe \(AppLog.ref(w.id))", .app)
                                        }
                                    }
                                } label: {
                                    Label(WardrobeSwitcher.menuTitle(wardrobe, among: wardrobes),
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
        .onChange(of: allWardrobes.count) { _, _ in
            // 删掉当前柜后 activeID 会失效——回落排序首位而不是留在空屏
            if WardrobeSwitcher.resolveActive(id: activeID, among: allWardrobes)?.id != activeID {
                activeID = WardrobeSwitcher.resolveActive(id: nil, among: allWardrobes)?.id
            }
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
