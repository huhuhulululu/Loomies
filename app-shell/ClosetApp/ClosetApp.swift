// App 入口（本地 Xcode / 模拟器可跑）。
// 默认双域均为本地（cloudKitDatabase: .none）——无 CloudKit 容器也能起。
// 真机接 CloudKit：把 mainConfig 的 cloudKitDatabase 改为 .private("iCloud.com.pinglin.closet")
// 并在 Signing & Capabilities 加 iCloud（CloudKit）。
import SwiftUI
import SwiftData
import ClosetModel
import ClosetCore
import ClosetUI

@main
struct ClosetApp: App {
    let container: ModelContainer

    init() {
        let mainSchema = Schema([
            Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self,
        ])
        // 本地/模拟器默认：主域也不上 CloudKit，避免无 container 启动失败。
        // 真机 CloudKit：.private("iCloud.com.pinglin.closet")
        let mainConfig = ModelConfiguration(
            "main", schema: mainSchema,
            cloudKitDatabase: .none)

        // 身体维度本地域（D5，永不进 CloudKit）
        let localConfig = ModelConfiguration(
            "local", schema: Schema([PersonBodyProfile.self]),
            cloudKitDatabase: .none)

        do {
            container = try ModelContainer(
                for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
                    Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
                configurations: mainConfig, localConfig)
        } catch {
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

/// 根导航：无衣柜 → Onboarding；有衣柜 → AppRootView（4-tab）。
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Wardrobe.name) private var wardrobes: [Wardrobe]
    @State private var onboarding = OnboardingViewModel()

    var body: some View {
        if let first = wardrobes.first {
            AppRootView(wardrobe: first)
        } else {
            OnboardingScreen(vm: onboarding) {
                _ = onboarding.finish(in: modelContext)
            }
        }
    }
}

/// 最小 onboarding 屏（2 题：名 + 城）；身体四围可后续在 Me 补。
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
                    Button("Get started") { onFinish() }
                        .disabled(!vm.canFinish)
                }
            }
            .navigationTitle("Welcome")
            .background(DS.bg)
        }
    }
}
