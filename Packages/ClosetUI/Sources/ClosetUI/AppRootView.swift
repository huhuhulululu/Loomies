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
            CalendarView(wardrobe: wardrobe)
                .tabItem { Label("Calendar", systemImage: "calendar") }
            MeView(wardrobe: wardrobe)
                .tabItem { Label("Me", systemImage: "person") }
        }
        .tint(DS.accent)
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
    @State private var dataMessage: String?
    @State private var sharePayload: String?
    /// 导出包（zip）临时文件；分享面板关闭后清理
    @State private var shareFileURL: URL?
    @State private var isBuildingExport = false
    @State private var includeBodyInExport = false
    @State private var confirmDeleteAll = false
    /// 遥测 opt-in（默认关闭；D86。状态行如实说明当前未接分析服务）
    @State private var telemetryEnabled = TelemetryGate.shared.isEnabled
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
                Section {
                    Toggle("Anonymous usage stats", isOn: Binding(
                        get: { telemetryEnabled },
                        set: { on in
                            telemetryEnabled = on
                            TelemetryGate.shared.setEnabled(on)
                        }))
                    Text(ComplianceCopy.telemetryStatusLine(enabled: telemetryEnabled))
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
                    Button("Delete all data…", role: .destructive) {
                        confirmDeleteAll = true
                    }
                    .accessibilityHint(DataLifecycleService.deleteAllButtonAccessibilityHint)
                    Text("Uninstalling the app does not erase iCloud-synced data. Use Delete all data to exercise your deletion rights.")
                        .font(.caption2)
                        .foregroundStyle(DS.muted)
                    if let dataMessage {
                        // Export ready vs couldn't export/delete — fail orange (parity Demo seed).
                        Text(dataMessage)
                            .font(.caption)
                            .foregroundStyle(
                                CustomerFlashStyle.isFailure(dataMessage)
                                    ? Color.orange : DS.muted)
                            .accessibilityLabel(dataMessage)
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
            .confirmationDialog(
                "Delete all data?",
                isPresented: $confirmDeleteAll,
                titleVisibility: .visible
            ) {
                Button("Delete everything", role: .destructive) {
                    do {
                        let receipt = try DataLifecycleService.deleteAllUserData(in: context)
                        dataMessage = receipt.summaryLine
                        // RootView @Query 空柜 → 自动回 Onboarding。
                    } catch {
                        dataMessage = DataLifecycleService.deleteAllFailedMessage
                        AppLog.error("deleteAll failed: \(AppLog.errRef(error))", .data)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes closets, pieces, looks, wear history, plans, and local photos. Body measurements are also removed. This cannot be undone.")
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
    private func exportBundle() {
        guard !isBuildingExport else { return }
        isBuildingExport = true
        dataMessage = ExportBundleService.bundleInProgressMessage
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
                    dataMessage = ExportBundleService.readyMessage(
                        copied: out.copiedPhotos, planned: out.plannedPhotos)
                    #else
                    // 非 iOS 没有分享面板接管载荷——不得声称「已就绪」
                    dataMessage = ExportBundleService.bundleNoHandoffMessage
                    #endif
                    AppLog.notice("export bundle ready body=\(includeBodyInExport)", .data)
                case .failure(let error):
                    // 失败分支也要收拾自己建的目录
                    try? FileManager.default.removeItem(at: dir)
                    dataMessage = ExportBundleService.bundleFailedMessage
                    AppLog.error("export bundle failed: \(AppLog.errRef(error))", .data)
                }
            }
        } catch {
            isBuildingExport = false
            dataMessage = ExportBundleService.bundleFailedMessage
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
    @State private var seedFlash: String?
    /// Toast 代际：同文案连发时旧计时器不得提前清掉新 toast。
    @State private var seedFlashToken = 0
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
        (wardrobe.items ?? []).sorted { ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString) }
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
                    seedFlash = summary
                    seedFlashToken += 1
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
                if let seedFlash {
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
    private func flashSeedChip(_ message: String?) {
        seedFlashToken &+= 1
        let token = seedFlashToken
        seedFlash = message
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if seedFlashToken == token { seedFlash = nil }
        }
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
                .foregroundStyle(on ? Color.white : DS.ink)
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
                .foregroundStyle(on ? Color.white : DS.ink)
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
                            .foregroundStyle(.white)
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
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12)], spacing: 12) {
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

    private var searchResults: some View {
        VStack(spacing: 0) {
            TextField("Search name or brand", text: $searchVM.text)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.top, 12)
                .accessibilityLabel("Search name or brand")
                .onChange(of: searchVM.text) { _, _ in
                    searchVM.homeWardrobeID = wardrobe.id
                    searchVM.run(in: context)
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
                                Text(item.name).font(.headline)
                                Text(meta)
                                    .font(.caption).foregroundStyle(DS.muted)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(item.name). \(meta)")
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
                .foregroundStyle(on ? Color.white : DS.ink)
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
                .foregroundStyle(on ? Color.white : DS.ink)
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
                .foregroundStyle(on ? Color.white : DS.ink)
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
