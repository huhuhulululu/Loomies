// Loomies App 入口。CloudKit 默认 off。
import SwiftUI
import SwiftData
import ClosetModel
import ClosetCore
import ClosetUI
import UIKit
import UserNotifications

/// 通知点击 → 标记本次打开来自早上那条提醒（D118）。
///
/// 没有这个标记就**无法知道通知到底有没有用**——而加通知的全部理由
/// 就是 MARKET §8.1 的 D30 留存线。这个类必须活到 App 生命周期结束，
/// 所以由 `@UIApplicationDelegateAdaptor` 持有，不能是临时对象。
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate,
                                UIApplicationDelegate {
    @MainActor
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // `UIApplicationDelegate` 让这个类成了 MainActor 隔离的，而委托回调的参数
    // 不是 Sendable —— 必须 `nonisolated` 再自己跳回主线程。
    // 这类错误 macOS 的 `swift test` **一个都报不出来**（D92 实证），只有 xcodebuild 会。
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let identifier = response.notification.request.identifier
        guard identifier.hasPrefix(DailyRitualScheduler.requestIdentifierPrefix) else { return }
        await MainActor.run { DailyRitualScheduler.markOpenedFromNudge() }
    }

    /// App 在前台时到点：不弹横幅（用户已经在用了，弹一下是打扰）。
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        []
    }
}

@main
struct ClosetApp: App {
    @UIApplicationDelegateAdaptor(NotificationRouter.self) private var notificationRouter
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
                            // D98：**不再自动播种 demo**。播 9 件会越过冷启动阈值(8)，
                            // 于是整个激活面（预赋进度/里程碑/真实起步）在真实首启路径上
                            // 永远不渲染，DESIGN §475 的「双路径」被替用户决定成了 demo。
                            // 现在空衣柜进 Today，横幅的两个按钮才是真正的分叉。
                            activeID = w.id
                        }
                    }
                }
            }
        }
        .onChange(of: allWardrobes.count) { _, _ in
            // 「删除全部数据」后库空了：in-memory 的 onboarding VM 仍带着
            // completed=true 与已删模型的引用，欢迎页会再也建不出新衣柜（D98）。
            // 库空 = 重新开始，VM 必须跟着复位。
            if allWardrobes.isEmpty {
                onboarding = OnboardingViewModel()
                activeID = nil
                return
            }
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
    /// 城市辅助输入（D107）：选中候选后写回 vm.city 的是**标准名**
    @State private var cityPicker = CityPickerViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("About you") {
                    // 姓名不在 DESIGN §474 的个性化三题里，也不喂任何下游——
                    // 标成可选，别让它当激活闸门（D98）
                    TextField("Name (optional)", text: $vm.displayName)
                        .textContentType(.name)
                    // 城市辅助输入（D107）：从候选里选，存的是标准名，
                    // 天气据此查——「Springfield」到底是哪个不再靠猜
                    CityPickerField(vm: cityPicker)
                        .onChange(of: cityPicker.query) { _, _ in
                            vm.city = cityPicker.storedValue ?? ""
                        }
                }
                // 场合构成（D97，DESIGN §474 个性化三题之一）。可跳过——
                // 不答就是不答，系统用中性默认，不记成用户的选择。
                Section {
                    Picker(OccasionMix.question, selection: $vm.primaryOccasion) {
                        Text(OccasionMix.skipTitle).tag(Optional<String>.none)
                        ForEach(OccasionMix.choices, id: \.self) { c in
                            Text(OccasionMix.displayTitle(c)).tag(Optional(c))
                        }
                    }
                } footer: {
                    Text(OccasionMix.hint)
                }
                Section {
                    Text("Optional — pick a look-alike. You can refine measurements later.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    // 同意门必须与它守的控件同屏（D101）：D98 把快选接进了门，
                    // 却没给这一屏任何授权入口——选完必被拒，用户无处授权。
                    Toggle(BodyDataConsent.grantTitle, isOn: Binding(
                        get: { vm.hasBodyDataConsent },
                        set: { $0 ? vm.grantBodyDataConsent() : vm.revokeBodyDataConsent() }))
                    if !vm.hasBodyDataConsent {
                        Text(BodyDataConsent.explainer)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Picker("Body type", selection: $vm.popularShapePick) {
                        Text("Skip for now").tag(Optional<PopularShape>.none)
                        Text("Hourglass").tag(Optional(PopularShape.hourglass))
                        Text("Pear").tag(Optional(PopularShape.pear))
                        Text("Apple").tag(Optional(PopularShape.apple))
                        Text("Rectangle").tag(Optional(PopularShape.rectangle))
                        Text("Inverted triangle").tag(Optional(PopularShape.invertedTriangle))
                    }
                    .disabled(!vm.hasBodyDataConsent)
                } header: {
                    Text("Body (optional)")
                }
                Section {
                    Text("Next you'll pick how to start — shoot what you're wearing, or try sample pieces first.")
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
