// App 入口（本地 Xcode / 模拟器可跑）。
// CloudKit 默认 off；真机改为 .private("iCloud.com.pinglin.closet") 并加 Capability。
import SwiftUI
import SwiftData
import ClosetModel
import ClosetCore
import ClosetUI

@main
struct ClosetApp: App {
    let container: ModelContainer

    init() {
        // 拉起 DebugSettings（读 launch args / LOOMIES_DEBUG=1）
        _ = DebugSettings.shared
        AppLog.notice("Loomies launch", .app)

        let mainSchema = Schema([
            Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self,
        ])
        let mainConfig = ModelConfiguration(
            "main", schema: mainSchema,
            cloudKitDatabase: .none)
        let localConfig = ModelConfiguration(
            "local", schema: Schema([PersonBodyProfile.self]),
            cloudKitDatabase: .none)

        do {
            container = try ModelContainer(
                for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
                    Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
                configurations: mainConfig, localConfig)
            AppLog.info("ModelContainer ready", .data)
        } catch {
            AppLog.fault("ModelContainer failed: \(error)", .data)
            fatalError("ModelContainer failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

/// 根导航：无衣柜 → Onboarding；有 → 可选柜 + AppRoot。
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Wardrobe.name) private var wardrobes: [Wardrobe]
    @Query private var people: [Person]
    @State private var onboarding = OnboardingViewModel()
    @State private var activeID: UUID?

    private var activeWardrobe: Wardrobe? {
        if let id = activeID, let w = wardrobes.first(where: { $0.id == id }) { return w }
        return wardrobes.first
    }

    var body: some View {
        if let wardrobe = activeWardrobe {
            AppRootView(wardrobe: wardrobe)
        } else {
            OnboardingScreen(vm: onboarding) {
                if onboarding.finish(in: modelContext) {
                    // 首启自动灌演示种子，模拟器立刻能玩 copilot
                    if let w = onboarding.wardrobe {
                        _ = DemoSeedService.seedIfEmpty(w, in: modelContext)
                        activeID = w.id
                    }
                }
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
                    Text("We'll add a few sample pieces so you can try outfit suggestions right away.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button("Get started") { onFinish() }
                        .disabled(!vm.canFinish)
                }
            }
            .navigationTitle("Welcome")
        }
    }
}
