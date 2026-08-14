import SwiftUI
import UniformTypeIdentifiers
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
        // D214：iOS 26 `Tab` 值语法（`.tabItem` 老写法迁移；TabSkeletonTests 按名对账）。
        // 搜索**不设 tab**（D214 裁决）：网格内联搜索带 facet 继承（状态/类型过滤
        // 跟着进搜索、默认本柜），拆成 Tab(role: .search) 会丢掉它——
        // 且「tab bar 只做导航不放动作」是 DESIGN §10.2 自己的原则。
        TabView {
            Tab("Today", systemImage: "sparkles") {
                CopilotView(wardrobe: wardrobe)
                    // Today 的 VM 是 @State 初值——参数变了它不会重建，
                    // 切柜后会一直停在旧衣柜上（其余三个 tab 持 let wardrobe，天然跟随）。
                    // 用视图身份强制重建：换柜 = 换内容，重置瞬时状态正是想要的（D101）。
                    .id(wardrobe.id)
            }
            Tab("Closet", systemImage: "square.grid.2x2") {
                ClosetGridView(wardrobe: wardrobe)
            }
            Tab("Calendar", systemImage: "calendar") {
                CalendarView(wardrobe: wardrobe)
            }
            Tab("Me", systemImage: "person") {
                MeView(wardrobe: wardrobe)
            }
        }
        // 衣物照片是界面唯一的色彩主角（§10.1）——网格滚动时 bar 让位给照片。
        .minimizesTabBarOnScroll()
        .tint(DS.accent)
    }

    // MARK: - D214

    /// `.onScrollDown` 在 macOS 不存在（`swift test` 编的是 macOS，D92）——
    /// 真机行为只有 xcodebuild + 真机能验，已入 DEVICE-ACCEPTANCE §6。
}

private extension View {
    @ViewBuilder func minimizesTabBarOnScroll() -> some View {
        #if os(iOS)
        self.tabBarMinimizeBehavior(.onScrollDown)
        #else
        self
        #endif
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
    /// D137：带结果位——不再靠关键词猜「这句是不是失败」。
    @State private var dataMessage: FailureCopy.Message?
    /// D122：导入文件选择器。
    @State private var showImportPicker = false
    @State private var sharePayload: String?
    /// 导出包（zip）临时文件；分享面板关闭后清理
    @State private var shareFileURL: URL?
    @State private var isBuildingExport = false
    @State private var includeBodyInExport = false
    @State private var confirmDeleteAll = false
    /// 遥测 opt-in（默认关闭；D86。状态行如实说明当前未接分析服务）
    @State private var telemetryEnabled = TelemetryGate.shared.isEnabled
    /// D118：每日回访的开关与时刻。
    @State private var dailyRitualOn = DailyRitualScheduler.isEnabled
    @State private var dailyRitualHour = DailyRitualScheduler.hour
    /// 授权被拒时如实说，并把开关拨回去——设置里显示「开」而一条都不发是撒谎。
    @State private var dailyRitualNote = DailyRitual.permissionRationale
    @Bindable private var debug = DebugSettings.shared

    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    /// Profile links (body measurements / personal color) are shown only for a
    /// wardrobe with a real owner — never keyed to a random fallback UUID.
    static func profileOwner(of wardrobe: Wardrobe) -> Person? {
        wardrobe.owner
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("This closet") {
                    NavigationLink {
                        ClosetNameEditView(wardrobe: wardrobe)
                    } label: {
                        LabeledContent("Name", value: wardrobe.name.isEmpty ? "—" : wardrobe.name)
                    }
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
                    Button("Load samples") {
                        let outcome = DemoSeedService.seed(wardrobe, in: context)
                        seedMessage = outcome.meDemoFlashMessage
                    }
                    .accessibilityHint(DemoSeedService.loadButtonAccessibilityHint)
                    if let seedMessage {
                        // Me Demo Outcome — fail orange (not muted success chrome).
                        Text(seedMessage)
                            .font(.caption)
                            .foregroundStyle(
                                CustomerFlashStyle.isFailure(seedMessage)
                                    ? Color.orange : DS.muted)
                            .accessibilityLabel(seedMessage)
                    }
                }
                // D118：每日回访。此前这个 App 永远不会主动出现在用户面前
                //（全仓 0 处 UNUserNotificationCenter），而 MARKET §8.1 的
                // D30 留存证伪线正建立在「每天早上用一次」上。
                Section {
                    Toggle("Morning nudge", isOn: Binding(
                        get: { dailyRitualOn },
                        set: { on in
                            dailyRitualOn = on
                            Task { await applyDailyRitual(enabled: on) }
                        }))
                    if dailyRitualOn {
                        Picker("Time", selection: Binding(
                            get: { dailyRitualHour },
                            set: { h in
                                dailyRitualHour = h
                                DailyRitualScheduler.hour = h
                                Task { await applyDailyRitual(enabled: true) }
                            })) {
                            ForEach(DailyRitual.selectableHours, id: \.self) { h in
                                Text(hourLabel(h)).tag(h)
                            }
                        }
                    }
                    // D142：**下一次几点响，写出来。** 用户拨了开关，
                    // 凭什么相信它真的会响？能核对的状态才是诚实的状态。
                    // 不会响时（关着 / 衣柜凑不出一身）这一行不出现——
                    // 写一个永远不会到来的时刻是这条规则要防的事。
                    if let next = DailyRitual.nextNudgeLine(
                        isEnabled: dailyRitualOn,
                        availableItemCount: (wardrobe.items ?? [])
                            .filter({ $0.statusRaw == "available" }).count,
                        hour: dailyRitualHour) {
                        Text(next)
                            .font(DS.Text.meta).foregroundStyle(DS.muted)
                            .accessibilityLabel(next)
                    }
                    Text(dailyRitualNote)
                        .font(DS.Text.meta).foregroundStyle(DS.muted)
                } header: {
                    Text("Daily")
                }
                Section {
                    Toggle("Anonymous usage stats", isOn: Binding(
                        get: { telemetryEnabled },
                        set: { on in
                            telemetryEnabled = on
                            TelemetryGate.shared.setEnabled(on)
                        }))
                    Text(ComplianceCopy.telemetryStatusLine(
                        enabled: telemetryEnabled,
                        hasSink: TelemetryGate.shared.hasSink))
                        .font(.caption2).foregroundStyle(DS.muted)
                    NavigationLink("Help & FAQ") { HelpView() }
                } header: {
                    Text("Privacy")
                }
                Section("Closets") {
                    NavigationLink("Closets & people") {
                        // 传当前柜 id：当前打开的衣柜不给删除动作（防上层持已删模型）
                        WardrobeManageView(currentWardrobeID: wardrobe.id)
                    }
                }
                Section("Looks") {
                    NavigationLink("Favorites") {
                        FavoritesView(wardrobe: wardrobe)
                    }
                    // 打卡此前只写不读：合身备注记错了改不回来，历史也看不到
                    NavigationLink(WearHistoryViewModel.title) {
                        WearHistoryView(wardrobe: wardrobe)
                    }
                }
                Section("Profile") {
                    if let person = wardrobe.owner {
                        NavigationLink {
                            PersonNameEditView(person: person)
                        } label: {
                            LabeledContent("Name", value: person.name.isEmpty ? "—" : person.name)
                        }
                    }
                    // Body / Personal-color need a real owner id — an ownerless
                    // wardrobe must not persist an orphan PersonBodyProfile keyed
                    // to a random UUID (parity with the gated PersonNameEditView).
                    if let person = wardrobe.owner {
                        // D98：场合构成的文案承诺「随时可改」，兑现路径在这里
                        NavigationLink {
                            PrimaryOccasionEditView(person: person)
                        } label: {
                            LabeledContent(
                                PrimaryOccasionEditView.title,
                                value: OccasionMix.parse(person.primaryOccasionRaw)
                                    .map(OccasionMix.displayTitle) ?? OccasionMix.skipTitle)
                        }
                        // D90：冷热偏置此前有字段无入口——同样 60°F，怕冷的人要更厚那档
                        NavigationLink {
                            ColdBiasEditView(person: person)
                        } label: {
                            LabeledContent(ColdBiasEditView.title,
                                           value: ColdBias.title(person.coldBias))
                        }
                    }
                    if let person = MeView.profileOwner(of: wardrobe) {
                        NavigationLink {
                            BodyProfileView(personID: person.id)
                        } label: {
                            Label("Body measurements", systemImage: "figure.stand")
                        }
                        NavigationLink {
                            PersonalColorView(personID: person.id)
                        } label: {
                            Label("Personal color", systemImage: "paintpalette")
                        }
                    }
                }
                Section("Data") {
                    Toggle("Include body measurements in export", isOn: $includeBodyInExport)
                    Button(isBuildingExport
                           ? ExportBundleService.bundleInProgressMessage
                           : "Export my data") {
                        exportBundle()
                    }
                    // 进行中禁用：几百张图的压缩要时间，重复点会起多个后台任务
                    .disabled(isBuildingExport)
                    .accessibilityHint(DataLifecycleService.exportButtonAccessibilityHint)
                    // D122：此前只有出口没有入口——政策里写着「take everything
                    // with you」，可搬出去之后没有任何地方能搬回来。
                    // D134：用户导出拿到的是 **zip**，而导入只收 json——
                    // 往返在真机上根本走不通（Foundation 没有解压 API）。
                    // 补一条「只导数据文件」：它就是导入认的那种格式，
                    // 照片仍走上面的完整包（照片本来也不参与导入）。
                    Button("Export data file (for import)") { exportDataFileOnly() }
                        .accessibilityHint(
                            "Shares a JSON file you can import back into Loomies. "
                            + "Photos are not included.")
                    Button("Import from a data file…") { showImportPicker = true }
                        .accessibilityHint(
                            "Adds a new closet from a Loomies data file. "
                            + "Your current closets are not changed.")
                    Button("Delete all data…", role: .destructive) {
                        confirmDeleteAll = true
                    }
                    .accessibilityHint(DataLifecycleService.deleteAllButtonAccessibilityHint)
                    // D101：此前手写「卸载不会抹掉 iCloud 同步的数据」——两个域的
                    // cloudKitDatabase 都是 .none，什么都没同步。改用 D90 写好却
                    // 一直零调用点的那句正确披露。
                    Text("\(ItemImageStore.backupDisclosure) Use Delete all data to exercise your deletion rights.")
                        .font(.caption2)
                        .foregroundStyle(DS.muted)
                    if let dataMessage {
                        // 结果性由产生它的代码带出来（D137），不靠关键词嗅探
                        Text(dataMessage.text)
                            .font(DS.Text.meta)
                            .foregroundStyle(dataMessage.isFailure ? Color.orange : DS.muted)
                            .accessibilityLabel(dataMessage.text)
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
                            // Honest status (no char count) — same bar as data exportReadyMessage.
                            diagText = DiagnosticsExport.exportReadyMessage
                            #else
                            diagText = String(json.prefix(500)) + (json.count > 500 ? "…" : "")
                            #endif
                            AppLog.notice("diagnostics exported", .diagnostics)
                        } catch {
                            diagText = DiagnosticsExport.exportFailedMessage
                            AppLog.error("diagnostics export failed: \(AppLog.errRef(error))", .diagnostics)
                        }
                    }
                    .accessibilityHint(DiagnosticsExport.exportButtonAccessibilityHint)
                    if let diagText {
                        // Diagnostics ready vs couldn't export — fail orange (parity data export).
                        Text(diagText)
                            .font(.caption)
                            .foregroundStyle(
                                CustomerFlashStyle.isFailure(diagText)
                                    ? Color.orange : DS.muted)
                            .accessibilityLabel(diagText)
                    }
                }
                if debug.panelEnabled {
                    debugSection
                } else {
                    // DEBUG-only：Release/TestFlight 不暴露入口——verbose 会把 debug 级
                    // 明细灌进日志环并渲染在 Me 页（肩窥面）；调试构建外走 -debugPanel 参数。
                    #if DEBUG
                    Section {
                        Button("Enable debug panel") {
                            debug.panelEnabled = true
                        }
                        .foregroundStyle(DS.accent)
                    }
                    #endif
                }
            }
            .navigationTitle("Me")
            // D136：开关此前只从 UserDefaults 播种——用户在 iOS 设置里撤销通知后，
            // 这一行仍显示「开」并承诺「每天早上一条」，而系统层面一条都不会发。
            .task { await reconcileDailyRitual() }
            .fileImporter(
                isPresented: $showImportPicker,
                // zip 也收：用户手上多半是完整包，收下它才能给一句
                // 走得通的指路，而不是「这不是 Loomies 的导出」（那是错的）
                allowedContentTypes: [.json, .zip],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .confirmationDialog(
                "Delete all data?",
                isPresented: $confirmDeleteAll,
                titleVisibility: .visible
            ) {
                Button("Delete everything", role: .destructive) {
                    do {
                        let receipt = try DataLifecycleService.deleteAllUserData(in: context)
                        // D197：主屏 Widget 的快照在**App Group 共享容器**里，
                        // 不在 App 沙盒内 ——「removes everything on this device」
                        // 不能把它漏了。
                        TodayWidgetSnapshotStore.clear(
                            in: TodayWidgetSnapshotStore.sharedDirectory())
                        // D191：临时导出残渣与删库同一下扫掉——
                        //「removes everything on this device … and local photos」要说话算数。
                        // 正常关分享面板会删，但「面板开着时 App 被杀」会留下残渣。
                        ExportBundleService.sweepTemporaryExports()
                        AvatarCinematicExporter.sweepTemporaryExports()
                        // 盘上文件已擦，内存里解码好的位图还在——不清的话
                        // 「已删除全部数据」之后网格仍会画出刚被删掉的照片（D112）。
                        ThumbnailImageCache.shared.removeAll()
                        // D136：删库之后 RootView 回 Onboarding，`CopilotView`
                        // 再也不会挂载——挂起的七条每周提醒**没有任何东西能关掉它们**，
                        // 而 App 里连那个开关都不在了。用户删了全部数据，
                        // 手机却继续每天早上叫他去看一个空 App。
                        DailyRitualScheduler.disable()
                        dailyRitualOn = false
                        dataMessage = .success(receipt.summaryLine)
                        // RootView @Query 空柜 → 自动回 Onboarding。
                    } catch {
                        dataMessage = .failure(.transient(DataLifecycleService.deleteAllFailedMessage))
                        AppLog.error("deleteAll failed: \(AppLog.errRef(error))", .data)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                // D144：披露只有一份。此前这里与 a11y hint 各写一份且已走岔——
                // hint 少说了穿着历史与计划，两处都漏了存放位置与转移历史。
                Text(DataLifecycleService.deleteAllDisclosure)
            }
            #if os(iOS)
            .sheet(item: Binding(
                get: {
                    if let url = shareFileURL { return ShareBox(fileURL: url) }
                    return sharePayload.map { ShareBox(text: $0) }
                },
                set: { box in
                    if box == nil {
                        // 关闭即清理**整个临时目录**（与 cinematic MP4 同纪律）——
                        // 只删 zip 会把 export-<uuid>/ 空目录永久留在 tmp 里
                        if let url = shareFileURL {
                            try? FileManager.default.removeItem(
                                at: url.deletingLastPathComponent())
                        }
                        shareFileURL = nil
                        sharePayload = nil
                    }
                }
            )) { box in
                ActivityView(items: box.activityItems)
            }
            #endif
        }
    }

    /// 导出包：MainActor 读 SwiftData 出计划 → **后台**拷贝+压缩 → 分享面板。
    /// 压缩绝不放主线程（几百张图会冻结 UI 数秒到数分钟；exporter 已有同类判例）。
    /// D122：导入。**只增不改**——建新柜，绝不动用户已有的东西。
    /// 收据如实说明照片没跟过来（JSON 里只有路径没有像素）。
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            // D128：选文件失败多半是权限/文件已不在了 —— 再点一次同一条路
            // 不会变，得先换个文件
            dataMessage = .failure(.needsUserAction(
                "Couldn't open that file", next: "Pick it again from Files"))
            AppLog.error("import picker failed: \(AppLog.errRef(error))", .data)
        case .success(let urls):
            guard let url = urls.first else { return }
            // 安全作用域：文件来自 App 沙盒之外，不 start 会读不到
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard url.pathExtension.lowercased() != "zip" else {
                // Foundation 没有解压 API——与其失败，不如指一条真能走通的路
                dataMessage = .failure(.needsUserAction(
                    "That's the full backup (a .zip)",
                    next: "Use Export data file, or uncompress the zip in Files and pick data.json"))
                return
            }
            do {
                let data = try Data(contentsOf: url)
                let receipt = try ImportService.importSnapshot(data, into: context)
                dataMessage = .success(receipt.summary)
                AppLog.notice("import ok items=\(receipt.itemsAdded)", .data)
            } catch ImportService.ImportError.newerSchema(let found, let supported) {
                dataMessage = .failure(.needsUserAction(
                    "That file is from a newer version of Loomies "
                    + "(format \(found), this app reads \(supported))",
                    next: "Update the app first"))
            } catch {
                // 重试也没用：这个文件不会因为再点一次就变成 Loomies 的导出
                dataMessage = .failure(.needsUserAction(
                    "That file isn't a Loomies export",
                    next: "Choose the JSON you got from Me → Data → Export"))
                AppLog.error("import failed: \(AppLog.errRef(error))", .data)
            }
        }
    }

    /// 与系统实况对账（D136）。授权被撤销 → 把开关拨回去并说清原因。
    private func reconcileDailyRitual() async {
        guard DailyRitualScheduler.isEnabled else {
            dailyRitualOn = false
            return
        }
        let authorized = await DailyRitualScheduler.isAuthorized()
        if authorized {
            dailyRitualOn = true
        } else {
            DailyRitualScheduler.disable()
            dailyRitualOn = false
            dailyRitualNote =
                "Notifications are off for Loomies in iOS Settings — turn them on there first."
        }
    }

    /// 12 小时制标签（en-US 首发市场，§10.5）。
    /// D140：实现挪进 `DailyRitual`——邀请卡上写的时间必须与这里选的逐字一致，
    /// 两份格式化迟早会写出两个时间。
    private func hourLabel(_ h: Int) -> String { DailyRitual.hourLabel(h) }

    /// 开关落地。授权拿不到就把开关拨回去并说明原因——
    /// 设置里显示「开」而系统层面一条都不会发，是最典型的那类不诚实。
    /// D140：开启走 `DailyRitualScheduler.enable`（与 Today 的邀请卡同一条路径）。
    private func applyDailyRitual(enabled: Bool) async {
        guard enabled else {
            DailyRitualScheduler.disable()
            dailyRitualNote = DailyRitual.permissionRationale
            return
        }
        let count = (wardrobe.items ?? []).filter { $0.statusRaw == "available" }.count
        guard await DailyRitualScheduler.enable(availableItemCount: count) else {
            dailyRitualOn = false
            dailyRitualNote =
                "Notifications are off for Loomies in iOS Settings — turn them on there first."
            return
        }
        dailyRitualNote = DailyRitual.shouldSchedule(availableItemCount: count)
            ? DailyRitual.permissionRationale
            : "Starts once your closet can put a full look together."
    }

    /// 仅数据文件（D134）。完整包是 zip、含照片；而**导入只认 JSON**——
    /// 没有这条，用户导出之后无路可回。
    private func exportDataFileOnly() {
        do {
            let data = try DataLifecycleService.exportJSONData(
                in: context, includeBodyDimensions: includeBodyInExport)
            ExportBundleService.sweepTemporaryExports()
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "\(ExportBundleService.temporaryDirectoryPrefix)\(UUID().uuidString)",
                    isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = dir.appendingPathComponent("Loomies-data.json")
            try data.write(to: url, options: .atomic)
            shareFileURL = url
            dataMessage = .success(DataLifecycleService.exportReadyMessage(
                includeBodyDimensions: includeBodyInExport))
        } catch {
            dataMessage = .failure(FailureCopy.classify(
                error, fallback: DataLifecycleService.exportFailedMessage))
            AppLog.error("data-file export failed: \(AppLog.errRef(error))", .data)
        }
    }

    private func exportBundle() {
        guard !isBuildingExport else { return }
        isBuildingExport = true
        dataMessage = .success(ExportBundleService.bundleInProgressMessage)
        do {
            let plan = try ExportBundleService.plan(
                in: context, includeBodyDimensions: includeBodyInExport)
            // 先回收上次遗留的（写入抛错 / 分享前被杀，面板的清理跑不到）
            ExportBundleService.sweepTemporaryExports()
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "\(ExportBundleService.temporaryDirectoryPrefix)\(UUID().uuidString)",
                    isDirectory: true)
            Task {
                let result: Result<ExportBundleService.WriteResult, Error> =
                    await Task.detached(priority: .userInitiated) {
                    do {
                        try FileManager.default.createDirectory(
                            at: dir, withIntermediateDirectories: true)
                        return .success(try ExportBundleService.writeBundle(plan, in: dir))
                    } catch {
                        return .failure(error)
                    }
                }.value
                isBuildingExport = false
                switch result {
                case .success(let out):
                    #if os(iOS)
                    shareFileURL = out.url
                    // 文案按**实际**装进去的照片数说话（部分失败不得被完全静音）
                    dataMessage = .success(ExportBundleService.readyMessage(
                        copied: out.copiedPhotos, planned: out.plannedPhotos))
                    #else
                    // 非 iOS 没有分享面板接管载荷——不得声称「已就绪」
                    dataMessage = .failure(.transient(ExportBundleService.bundleNoHandoffMessage))
                    #endif
                    AppLog.notice("export bundle ready body=\(includeBodyInExport)", .data)
                case .failure(let error):
                    // 失败分支也要收拾自己建的目录
                    try? FileManager.default.removeItem(at: dir)
                    // D141：磁盘满是这条路上最常见的真实原因（整柜照片进 zip），
                    // 而「try again」在那种情况下是把用户往走不通的路上推
                    dataMessage = .failure(FailureCopy.classify(
                        error, fallback: ExportBundleService.bundleFailedMessage))
                    AppLog.error("export bundle failed: \(AppLog.errRef(error))", .data)
                }
            }
        } catch {
            isBuildingExport = false
            dataMessage = .failure(FailureCopy.classify(
                error, fallback: ExportBundleService.bundleFailedMessage))
            AppLog.error("export plan failed: \(AppLog.errRef(error))", .data)
        }
    }

    @ViewBuilder
    private var debugSection: some View {
        Section("Debug") {
            Toggle("Verbose logging", isOn: $debug.verboseLogging)
            Toggle("Force cold start", isOn: $debug.forceColdStart)
            Toggle("Disable 7-day anti-repeat", isOn: $debug.disableAntiRepeat)
            Toggle("Show status on Today", isOn: $debug.showEmptyReason)
            // D142：提审阻断清单此前**零生产调用点**——只有测试在按，
            // 而测试传的是自己编的三个参数：真实的那三个事实此刻是什么，
            // 全仓没有任何一处知道。放在这里，因为提审前唯一会被真人
            // 打开的就是这一面。
            LabeledContent(
                "Release",
                value: ReleaseReadiness.summaryLine(
                    telemetrySinkConnected: TelemetryGate.shared.hasSink))
            ForEach(Array(ReleaseReadiness.currentBlockers(
                telemetrySinkConnected: TelemetryGate.shared.hasSink
            ).enumerated()), id: \.offset) { _, blocker in
                Text(blocker).font(.caption2).foregroundStyle(DS.muted)
            }
            LabeledContent("Log ring", value: "\(AppLog.ring.count) lines")
            Button("Clear log ring") { AppLog.ring.clear() }
            Button("Reset debug flags") { debug.resetAll() }
            Button("Hide debug panel") { debug.panelEnabled = false }
        }
        Section("Recent logs") {
            let lines = AppLog.ring.snapshot().suffix(12).reversed()
            if lines.isEmpty {
                Text("No log lines yet").font(.caption).foregroundStyle(DS.muted)
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

/// 分享载荷：文本（诊断 / 纯 JSON）或文件（导出包 zip）。
/// 二者共用同一 sheet，但文件路径需在关闭后清理（临时文件不得无界积累）。
private struct ShareBox: Identifiable {
    /// 身份**由载荷决定**。此前 `let id = UUID()` 在每次 binding getter 求值时
    /// 都生成新值，SwiftUI 视作 item 变了 → 关掉再开；D87 新增的
    /// isBuildingExport / dataMessage 状态变化让这条更容易发作。
    var id: String { fileURL?.path ?? text ?? "" }
    let text: String?
    let fileURL: URL?

    init(text: String) { self.text = text; self.fileURL = nil }
    init(fileURL: URL) { self.text = nil; self.fileURL = fileURL }

    var activityItems: [Any] {
        if let fileURL { return [fileURL] }
        return [text ?? ""]
    }
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

/// 衣柜浏览网格 + 状态/类型过滤 / 合身标记 / 入库 / 搜索。
public struct ClosetGridView: View {
    let wardrobe: Wardrobe
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showIntake = false
    @State private var showSearch = false
    @State private var showFittingRoom = false
    /// 批量转移（D94）：多选模式与已选 id
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var showBatchMove = false
    @State private var searchVM = SearchViewModel()
    /// 作用域切换器只在多柜时出现；跨柜结果行需按各自衣柜主人取 body profile
    @Query(sort: \Wardrobe.name) private var allWardrobes: [Wardrobe]
    @State private var statusFilter: String = "all"
    /// nil = all types; chips use GarmentSlot + displaySlot name correction.
    @State private var slotFilter: String? = nil
    /// Bottom flash chip: Load samples Outcome + intake post-save honesty (no silent fail).
    /// D183：代际 + 定时清收在 `FlashState` 一处。
    @State private var seedFlashState = FlashState()
    /// Live query so Me → Body edits refresh FitMark badges without tab remount.
    @Query private var bodyProfiles: [PersonBodyProfile]

    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    /// Owner body profile for FitMark (same person as wardrobe.owner).
    /// 按单品所属衣柜的主人取身体档案（跨柜结果里各柜主人可能不同）。
    private func bodyProfile(for item: Item) -> PersonBodyProfile? {
        guard let pid = item.wardrobe?.owner?.id else { return ownerBodyProfile }
        return bodyProfiles.first { $0.personID == pid }
    }

    private var ownerBodyProfile: PersonBodyProfile? {
        guard let pid = wardrobe.owner?.id else { return nil }
        return bodyProfiles.first { $0.personID == pid }
    }

    private var allItems: [Item] {
        (wardrobe.items ?? []).sortedByName()
    }

    private var items: [Item] {
        SearchService.filterItems(
            allItems,
            statusRaw: statusFilter == "all" ? nil : statusFilter,
            slotRaw: slotFilter)
    }

    private var isFacetFiltering: Bool {
        statusFilter != "all" || slotFilter != nil
    }

    public var body: some View {
        NavigationStack {
            Group {
                if showSearch {
                    searchResults
                } else {
                    VStack(spacing: 0) {
                        statusFilterBar
                        typeFilterBar
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
                            // Carry grid status/type facets into search so laundry/status filters stick.
                            searchVM.homeWardrobeID = wardrobe.id
                            searchVM.hasOtherClosets = allWardrobes.count > 1
                            // 每次打开搜索回到本柜（安全默认：跨柜需显式选择）
                            searchVM.scope = .thisCloset
                            searchVM.statusRaw = statusFilter == "all" ? nil : statusFilter
                            searchVM.slotRaw = slotFilter
                            searchVM.run(in: context)
                        }
                    } label: {
                        Image(systemName: showSearch ? "xmark" : "magnifyingglass")
                    }
                    .accessibilityLabel(
                        ClosetGridEmptyCopy.searchToggleAccessibilityLabel(isSearchOpen: showSearch))
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showIntake = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(ClosetGridEmptyCopy.addPieceAccessibilityLabel)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showFittingRoom = true } label: {
                        Image(systemName: "tshirt")
                    }
                    .accessibilityLabel(FittingRoomView.entryAccessibilityLabel)
                }
                // 批量转移（D94）：整柜搬家时逐件点 Move 是折磨
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isSelecting.toggle()
                        if !isSelecting { selectedIDs = [] }
                    } label: {
                        Image(systemName: isSelecting
                              ? "checkmark.circle.fill" : "checkmark.circle")
                    }
                    .accessibilityLabel(isSelecting
                                        ? BatchMoveCopy.exitSelectionLabel
                                        : BatchMoveCopy.enterSelectionLabel)
                }
                if isSelecting {
                    // .bottomBar 在 macOS 不可用；用 primaryAction 保持跨平台可编译
                    ToolbarItem(placement: .primaryAction) {
                        Button(BatchMoveCopy.moveTitle(count: selectedIDs.count)) {
                            showBatchMove = true
                        }
                        .disabled(selectedIDs.isEmpty)
                    }
                }
            }
            .sheet(isPresented: $showBatchMove) {
                BatchMoveSheet(
                    wardrobe: wardrobe,
                    items: items.filter { selectedIDs.contains($0.id) }
                ) { summary in
                    // D183：这里原来只赋值、连计时器都没起——批量移动的回执
                    // 会永久压在屏幕底部。
                    flashSeedChip(summary)
                    isSelecting = false
                    selectedIDs = []
                }
            }
            .sheet(isPresented: $showFittingRoom) {
                FittingRoomView(wardrobe: wardrobe)
            }
            .sheet(isPresented: $showIntake) {
                AddPieceSheet(wardrobe: wardrobe) { flash in
                    // Post-save honesty flash (photo failed processing but item saved)
                    // surfaces here — the sheet that owned statusMessage is already gone.
                    flashSeedChip(flash)
                }
            }
            .overlay(alignment: .bottom) {
                if let seedFlash = seedFlashState.message {
                    // Load samples Outcome — fail orange (parity Favorites / Calendar).
                    CustomerFlashStyle.overlayChip(seedFlash)
                        .padding()
                        .transition(.opacity)
                }
            }
        }
    }

    /// Empty-grid Load samples — same Outcome flash as Today cold-start (no silent fail).
    private func loadSamplesFromEmptyGrid() {
        let outcome = DemoSeedService.seedIfEmpty(wardrobe, in: context)
        flashSeedChip(outcome.flashMessage)
    }

    /// Bottom overlay chip with 3s auto-clear (Load samples Outcome / intake post-save honesty).
    /// D183：代际 + 定时清收在 `FlashState` 一处。
    private func flashSeedChip(_ message: String?) {
        seedFlashState.show(message, seconds: 3)
    }

    private var statusFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Full ItemStatusService.allowed set (displayName), plus All.
                filterChip("all", title: "All")
                ForEach(
                    Array(ItemStatusService.allowed).sorted(by: { ItemStatusService.displayName($0) < ItemStatusService.displayName($1) }),
                    id: \.self
                ) { key in
                    filterChip(key, title: ItemStatusService.displayName(key))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .accessibilityLabel("Filter by status")
    }

    /// Type chips share GarmentSlot.allCases + displayTitle with search/detail Type.
    private var typeFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                typeChip(nil, title: "All types")
                ForEach(GarmentSlot.allCases, id: \.rawValue) { slot in
                    typeChip(slot.rawValue, title: slot.displayTitle)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .accessibilityLabel("Filter by type")
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
                .foregroundStyle(on ? DS.onAccent : DS.ink)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func typeChip(_ slot: String?, title: String) -> some View {
        let on = slotFilter == slot
        return Button {
            slotFilter = slot
        } label: {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(on ? DS.accent.opacity(0.9) : DS.surface)
                .foregroundStyle(on ? DS.onAccent : DS.ink)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// 网格单元。选择模式与普通模式**共用同一份渲染**，避免两套视觉漂移。
    @ViewBuilder
    private func gridCell(_ item: Item, selected: Bool) -> some View {
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
                            .foregroundStyle(DS.onAccent)
                            .clipShape(Capsule())
                    }
                }
                .padding(6)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, DS.accent)
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: DS.radius)
                    .strokeBorder(selected ? DS.accent : .clear, lineWidth: 2))
            Text(item.name).font(.caption).lineLimit(1).foregroundStyle(DS.ink)
            // Location when set (Me Storage / detail assign) — same meta as Search.
            let meta = ClosetItemRowCopy.metaLine(for: item)
            if item.location != nil {
                Text(meta)
                    .font(.caption2)
                    .foregroundStyle(DS.muted)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            item.location == nil
                ? item.name
                : "\(item.name). \(ClosetItemRowCopy.metaLine(for: item))")
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(
                columns: AccessibilityGridColumns.items(
                    for: dynamicTypeSize, regularMinimum: 104, spacing: 12),
                spacing: 12
            ) {
                ForEach(items, id: \.id) { item in
                    // 选择模式下整格是勾选按钮——不得既进详情又勾选（手势打架）
                    if isSelecting {
                        Button {
                            if selectedIDs.contains(item.id) { selectedIDs.remove(item.id) }
                            else { selectedIDs.insert(item.id) }
                        } label: {
                            gridCell(item, selected: selectedIDs.contains(item.id))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(
                            selectedIDs.contains(item.id) ? .isSelected : [])
                    } else {
                    NavigationLink {
                        ItemDetailView(item: item, bodyProfile: ownerBodyProfile)
                    } label: {
                        gridCell(item, selected: false)
                    }
                    .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .overlay {
            if items.isEmpty {
                let title = ClosetGridEmptyCopy.title(isFacetFiltering: isFacetFiltering)
                let description = emptyGridDescription
                ContentUnavailableView {
                    // A11Y: .combine only on the text column — the action
                    // buttons stay separate, activatable VoiceOver targets
                    // (same fix class as IntakeView empty state).
                    VStack(spacing: 8) {
                        Label(title, systemImage: "square.grid.2x2")
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(title). \(description)")
                } actions: {
                    if isFacetFiltering {
                        Button("Clear filters") {
                            statusFilter = "all"
                            slotFilter = nil
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(DS.accent)
                        .accessibilityHint("Resets status and type filters")
                    } else {
                        Button("Load samples") {
                            loadSamplesFromEmptyGrid()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(DS.accent)
                        // Same demo-not-photos VO as Me → Demo Load samples.
                        .accessibilityHint(DemoSeedService.loadButtonAccessibilityHint)
                        Button("Add piece") { showIntake = true }
                    }
                }
            }
        }
    }

    private var emptyGridDescription: String {
        ClosetGridEmptyCopy.description(
            isFacetFiltering: isFacetFiltering,
            hasSlotFilter: slotFilter != nil,
            hasStatusFilter: statusFilter != "all")
    }

    private func fitBadge(for item: Item) -> String? {
        guard let profile = ownerBodyProfile,
              let v = FitMarkService.mark(item: item, profile: profile) else { return nil }
        return FitMarkCopy.label(v)
    }

    /// 色板 chip（D120）。选中态与 `GarmentAttributeControls` 的 chip 同一套语义 token。
    private func searchColorChip(_ id: String?, title: String) -> some View {
        let isOn = searchVM.colorPaletteID == id
        return Button {
            searchVM.colorPaletteID = id
            searchVM.homeWardrobeID = wardrobe.id
            searchVM.run(in: context)
        } label: {
            HStack(spacing: 6) {
                if let id, let entry = GarmentColorPalette.entry(id: id) {
                    Circle()
                        .fill(entry.swatchColor)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().strokeBorder(DS.hairline, lineWidth: 0.5))
                }
                Text(title).font(.caption)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: DS.chipMinHeight)
            .background(isOn ? DS.accent.opacity(0.22) : DS.surface)
            .foregroundStyle(isOn ? DS.accent : DS.ink)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(isOn ? DS.accent : DS.hairline, lineWidth: 1))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var searchResults: some View {
        VStack(spacing: 0) {
            TextField("Search name or brand", text: $searchVM.text)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.top, 12)
                .accessibilityLabel("Search name or brand")
                // D125：连打不再每个字母跑一遍全表扫描（筛选 chip 仍然立刻生效——
                // 那是一次明确动作，不是连续输入）。
                .onChange(of: searchVM.text) { _, _ in
                    searchVM.homeWardrobeID = wardrobe.id
                    Task { await searchVM.runDebounced(in: context) }
                }
            // 作用域切换（DESIGN §2.3 全局检索）；单柜用户不显示无用控件
            if allWardrobes.count > 1 {
                Picker("Scope", selection: $searchVM.scope) {
                    ForEach(SearchScope.allCases, id: \.rawValue) { s in
                        Text(s.displayTitle).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .accessibilityLabel("Search scope")
                .onChange(of: searchVM.scope) { _, _ in searchVM.run(in: context) }
            }
            // 槽位快捷过滤 — full GarmentSlot set (incl. accessory) + displayTitle, never raw dump.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    searchSlotChip(nil, title: "All types")
                    ForEach(GarmentSlot.allCases, id: \.rawValue) { slot in
                        searchSlotChip(slot.rawValue, title: slot.displayTitle)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .accessibilityLabel("Filter search by type")
            // Status facets (same allowed set as grid) — SearchService already filters statusRaw.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    searchStatusChip(nil, title: "Any status")
                    ForEach(
                        Array(ItemStatusService.allowed).sorted(by: {
                            ItemStatusService.displayName($0) < ItemStatusService.displayName($1)
                        }),
                        id: \.self
                    ) { key in
                        searchStatusChip(key, title: ItemStatusService.displayName(key))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .accessibilityLabel("Filter search by status")
            // Occasion facets — same work/casual/date/gala set as QuickAdd / Today occasion.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    searchOccasionChip(nil, title: "Any occasion")
                    ForEach(Self.searchOccasionKeys, id: \.self) { key in
                        searchOccasionChip(key, title: key.capitalized)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .accessibilityLabel("Filter search by occasion")
            // D120：颜色筛。站在店里那一刻，用户脑子里的检索词是**颜色 + 品类**，
            // 不是名字——而这里此前只能按名字/品牌搜。
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    searchColorChip(nil, title: "Any colour")
                    ForEach(GarmentColorPalette.entries) { entry in
                        searchColorChip(entry.id, title: entry.title)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .accessibilityLabel("Filter search by colour")
            // 「你已经有 4 件」——只在真的在筛时出现（不筛时它等于在数整个衣柜）
            if let headline = searchVM.resultsHeadline {
                Text(headline)
                    .font(DS.Text.sectionTitle)
                    .foregroundStyle(DS.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                    .accessibilityAddTraits(.isHeader)
            }
            if searchVM.results.isEmpty {
                searchEmptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(searchVM.results, id: \.id) { item in
                    let meta = ClosetItemRowCopy.metaLine(
                        for: item, includesCloset: searchVM.isCrossCloset)
                    NavigationLink {
                        // 跨柜结果：合身标记须用该单品所属衣柜主人的身体档案，不能用当前柜主人
                        ItemDetailView(item: item, bodyProfile: bodyProfile(for: item))
                    } label: {
                        HStack(spacing: 12) {
                            ItemThumbnailView(item: item, height: 48)
                                .frame(width: 48)
                            VStack(alignment: .leading) {
                                Text(item.name).font(DS.Text.rowTitle)
                                Text(meta)
                                    .font(.caption).foregroundStyle(DS.muted)
                                // 「上次什么时候穿的」是判断「要不要再买一件」的另一半依据
                                Text(searchVM.wearSummary(for: item))
                                    .font(.caption2).foregroundStyle(DS.muted)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            "\(item.name). \(meta). \(searchVM.wearSummary(for: item))")
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var searchEmptyState: some View {
        let title = searchVM.emptyStateTitle
        let description = searchVM.emptyStateDescription
        return ContentUnavailableView {
            // A11Y: .combine only on the text column — the action
            // buttons stay separate, activatable VoiceOver targets
            // (same fix class as the empty-grid state above).
            VStack(spacing: 8) {
                Label(
                    title,
                    systemImage: searchVM.isFiltering ? "magnifyingglass" : "square.grid.2x2")
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title). \(description)")
        } actions: {
            if searchVM.isFiltering {
                Button("Clear search") {
                    searchVM.clearFiltersKeepingScope()
                    searchVM.run(in: context)
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.accent)
                .accessibilityHint("Clears name and filters, keeps this closet")
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
            searchVM.homeWardrobeID = wardrobe.id
            searchVM.run(in: context)
        } label: {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(on ? DS.accent : DS.surface)
                .foregroundStyle(on ? DS.onAccent : DS.ink)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func searchStatusChip(_ status: String?, title: String) -> some View {
        let on = searchVM.statusRaw == status
        return Button {
            searchVM.statusRaw = status
            searchVM.homeWardrobeID = wardrobe.id
            searchVM.run(in: context)
        } label: {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(on ? DS.accent.opacity(0.9) : DS.surface)
                .foregroundStyle(on ? DS.onAccent : DS.ink)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// Matches QuickAdd / Today occasion picker keys (SearchService contains match).
    private static let searchOccasionKeys = ["work", "casual", "date", "gala"]

    private func searchOccasionChip(_ occasion: String?, title: String) -> some View {
        let on = searchVM.occasion == occasion
        return Button {
            searchVM.occasion = occasion
            searchVM.homeWardrobeID = wardrobe.id
            searchVM.run(in: context)
        } label: {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(on ? DS.accent.opacity(0.85) : DS.surface)
                .foregroundStyle(on ? DS.onAccent : DS.ink)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Export feedback decision: "ready" toast only when the JSON actually left the
/// app (share-sheet handoff); otherwise an inline preview — parity with
/// diagnostics (macOS has no share payload).
enum DataExportFeedback {
    /// iOS hands the JSON to the share sheet; other platforms have no handoff.
    static var payloadHandoffAvailable: Bool {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }

    static func message(
        payloadHandedOff: Bool,
        json: String,
        includeBodyDimensions: Bool,
        previewLimit: Int = 500
    ) -> String {
        if payloadHandedOff {
            // Honest body-inclusion toast (not char count); matches toggle state.
            return DataLifecycleService.exportReadyMessage(
                includeBodyDimensions: includeBodyDimensions)
        }
        return String(json.prefix(previewLimit)) + (json.count > previewLimit ? "…" : "")
    }
}
