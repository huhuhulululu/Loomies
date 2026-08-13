import SwiftUI
import SwiftData
import ClosetModel
import ClosetCore

// MARK: - Calendar (full)

/// 日历的**作用域文案**（D102）：日历只列当前衣柜的计划。
/// 空态必须说清这一点——否则用户会以为计划丢了，而不是「换个柜子看」。
public enum CalendarScopeCopy {
    public static let emptyMessage =
        "Save a look from Today, or plan a favorite for a day. "
        + "This calendar shows only the closet you're in."
}

/// Empty calendar list — Attention vs all; points to Today/Favorites (no fake sync).
public enum CalendarEmptyCopy {
    public static func title(attentionOnly: Bool) -> String {
        attentionOnly ? "No items need attention" : "No plans yet"
    }

    public static let description = CalendarScopeCopy.emptyMessage

    /// Toolbar + (same wording as empty-state CTA).
    public static let addPlanAccessibilityLabel = "Plan a favorite"

    /// Plan row swipe-delete hint (parity with Favorites).
    public static let planRowAccessibilityHint = "Swipe to remove"

    /// Plan-day sheet when Favorites is empty — recovery path only (no sync / try-on).
    public static let noFavoritesYet =
        "No favorites yet. Heart a suggestion on Today."
}

/// 穿搭日历：列表 / 关注 / 从收藏排期 / 删除。
public struct CalendarView: View {
    /// 身体档案走 @Query（活查询）：切柜/改体型即刷新，且行构建器里是纯内存查找。
    @Query private var bodyProfiles: [PersonBodyProfile]

    let wardrobe: Wardrobe
    @Environment(\.modelContext) private var context
    @State private var plans: [CalendarPlan] = []
    @State private var showAttentionOnly = false
    @State private var showPlanPicker = false
    @State private var planDate = Date()
    @State private var favorites: [ClosetModel.Outfit] = []
    @State private var message: String?
    @State private var actions = OutfitActionsViewModel()

    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    public var body: some View {
        NavigationStack {
            Group {
                if filteredPlans.isEmpty {
                    let title = CalendarEmptyCopy.title(attentionOnly: showAttentionOnly)
                    ContentUnavailableView {
                        // A11Y: .combine only on the text column — the action
                        // button stays a separate, activatable VoiceOver target
                        // (same fix class as the empty-grid state).
                        VStack(spacing: 8) {
                            Label(title, systemImage: "calendar")
                            Text(CalendarEmptyCopy.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(title). \(CalendarEmptyCopy.description)")
                    } actions: {
                        Button("Plan a favorite") { reloadFavorites(); showPlanPicker = true }
                            .buttonStyle(.borderedProminent).tint(DS.accent)
                            .accessibilityHint("Opens favorites to schedule a look")
                    }
                } else {
                    List {
                        ForEach(filteredPlans, id: \.id) { plan in
                            planRow(plan)
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.plain)
                }
            }
            .background(DS.bg.ignoresSafeArea())
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Toggle(isOn: $showAttentionOnly) {
                        Image(systemName: showAttentionOnly
                              ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                    }
                    .toggleStyle(.button)
                    .accessibilityLabel("Needs attention only")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        reloadFavorites()
                        showPlanPicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(CalendarEmptyCopy.addPlanAccessibilityLabel)
                }
            }
            .onAppear { reload() }
            // D110：切柜时本视图的**结构身份不变**，`onAppear` 不会重触发，
            // 于是 `plans` 里留着上一个柜的行——而滑动删除会真的把它们删掉。
            // 这把 D102 刚关掉的伤害从另一条机制上又打开了一次
            //（D101 的门注释里写「其余三个 tab 天然跟随」，那个前提本身是错的：
            //  持 `let wardrobe` 只让**派生读**跟随，自己的 @State 不跟）。
            .onChange(of: wardrobe.id) { _, _ in
                reload()
                reloadFavorites()
            }
            .sheet(isPresented: $showPlanPicker) { planSheet }
            .overlay(alignment: .bottom) {
                if let message {
                    // Fail orange (parity Favorites / Today); Plan / swipe-delete VO via chip label.
                    CustomerFlashStyle.overlayChip(message)
                        .padding()
                }
            }
        }
    }

    private var filteredPlans: [CalendarPlan] {
        showAttentionOnly ? plans.filter(\.needsAttention) : plans
    }

    private func planRow(_ plan: CalendarPlan) -> some View {
        let items = plan.outfit?.items ?? []
        let occasion = plan.outfit?.occasionRaw
        return HStack(spacing: 12) {
            // Same look preview path as Favorites / Today (owner morph + paper-doll layers).
            lookThumb(items: items, occasion: occasion, width: 56, height: 84)
            VStack(alignment: .leading, spacing: 4) {
                // dayKey 反解（本地正午）：计划日展示不随设备时区漂一天
                Text(CalendarPlanService.displayDate(plan), style: .date).font(.headline)
                Text(lookTitle(plan.outfit))
                    .font(DS.Text.body).foregroundStyle(DS.ink)
                if !items.isEmpty {
                    Text(items.prefix(4).map(\.name).joined(separator: " · "))
                        .font(.caption2).foregroundStyle(DS.muted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if plan.needsAttention {
                Label("Attention", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2).foregroundStyle(.orange)
                    .labelStyle(.iconOnly)
                    .accessibilityLabel("Needs attention")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(CalendarEmptyCopy.planRowAccessibilityHint)
    }

    private var planSheet: some View {
        NavigationStack {
            Form {
                DatePicker("Day", selection: $planDate, displayedComponents: .date)
                if favorites.isEmpty {
                    Text(CalendarEmptyCopy.noFavoritesYet)
                        .font(.caption).foregroundStyle(DS.muted)
                        .accessibilityLabel(CalendarEmptyCopy.noFavoritesYet)
                } else {
                    ForEach(favorites, id: \.id) { outfit in
                        Button {
                            // Same path as Favorites planFavorite — attention toast when missing pieces.
                            let plan = actions.planFavorite(
                                outfit, on: planDate, in: context,
                                lookTitle: lookTitle(outfit))
                            // Surface the honest flash either way; dismiss only on commit
                            // (stay-open-on-fail parity with TransferSheet / ItemDetail delete).
                            message = actions.message
                            if plan != nil {
                                showPlanPicker = false
                                reload()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                lookThumb(
                                    items: outfit.items ?? [],
                                    occasion: outfit.occasionRaw,
                                    width: 40, height: 60)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(lookTitle(outfit))
                                        .foregroundStyle(DS.ink)
                                    Text(FavoritesView.lookMetaLine(outfit, emptyOccasion: "Any"))
                                        .font(.caption).foregroundStyle(DS.muted)
                                }
                                Spacer()
                                Image(systemName: "calendar.badge.plus")
                                    .foregroundStyle(DS.accent)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Plan day")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showPlanPicker = false }
                }
            }
        }
    }

    /// Same title truth as Favorites list / plan flash (trim blank → “Favorite look”).
    private func lookTitle(_ outfit: ClosetModel.Outfit?) -> String {
        guard let outfit else { return "Look" }
        return FavoritesView.lookDisplayTitle(outfit)
    }

    @ViewBuilder
    private func lookThumb(
        items: [Item], occasion: String?, width: CGFloat, height: CGFloat
    ) -> some View {
        BodyAvatarView(
            shape: ownerShape,
            morph: ownerMorph,
            layers: OutfitAvatarComposer.layers(from: items),
            showsFitCaption: false,
            enablesOrbit: false,
            backdrop: .resolved(from: occasion),
            depthIntensity: .off,
            bodySex: BodyProfileService.presentationSex(from: ownerProfile),
            bodyPhenotype: BodyProfileService.presentationPhenotype(from: ownerProfile),
            usesMannequin3D: false)
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// D112：这里原本是**计算属性里发全表 fetch**——而它在行构建器里被读 4-5 次
    /// （shape / morph / sex / phenotype 各一次），于是每滚进一行就是一把主线程 SQLite 往返。
    /// 同模块的 `ClosetGridView` 早就是 `@Query` + 内存 `first {}`（实测约快两个数量级），
    /// 这里收编成同一种写法，不另造。
    private var ownerProfile: PersonBodyProfile? {
        guard let pid = wardrobe.owner?.id else { return nil }
        return bodyProfiles.first { $0.personID == pid }
    }

    private var ownerShape: PopularShape {
        if let p = ownerProfile,
           let s = BodyProfileService.displayPopularShape(from: p) {
            return s
        }
        return .rectangle
    }

    private var ownerMorph: BodyMorphParams {
        guard let p = ownerProfile else {
            return BodyMorphParams.preset(for: ownerShape)
        }
        let m = BodyProfileService.measurements(from: p)
        let shape = BodyProfileService.popularShape(from: p)
        let fine = BodyMorphParams(
            chest: p.fineChest, waist: p.fineWaist,
            hip: p.fineHip, shoulder: 1, height: p.fineHeight)
        return BodyMorphParams.resolve(measurements: m, shape: shape, fineTune: fine)
    }

    private func reload() {
        // D102：此前本柜为空时会**静默回退展示全部衣柜**的计划，行上没有归属标注，
        // 而滑动删除会真的删掉别柜的计划。跨柜是本项目的硬约束（搭配永不跨柜），
        // 日历不该是唯一的例外，更不该是无声的例外。
        plans = CalendarPlanService.plans(for: wardrobe, in: context)
    }

    private func reloadFavorites() {
        favorites = OutfitFavoriteService.favorites(in: wardrobe)
    }

    private func delete(at offsets: IndexSet) {
        var saveFailed = false
        for i in offsets {
            if !CalendarPlanService.remove(filteredPlans[i], in: context) {
                saveFailed = true
            }
        }
        reload()
        // After reload, failed rows reappear; flash so swipe is not silent success.
        if saveFailed {
            message = CalendarPlanService.removeSaveFailedMessage
        }
    }
}

// MARK: - Storage locations

/// Me → Storage empty list — recovery is the Add field above (no fake inventory / try-on).
public enum StorageEmptyCopy {
    public static let title = "No locations yet"
    /// Row swipe-delete hint (parity Calendar / Favorites).
    public static let rowSwipeAccessibilityHint = "Swipe to remove"
}

public struct StorageLocationsView: View {
    let wardrobe: Wardrobe
    @Environment(\.modelContext) private var context
    @State private var nodes: [StorageLocationService.Node] = []
    /// 删除确认的**值类型**快照（绝不在 @State 里持 @Model：对话框消散期间仍会求值）
    @State private var pendingDelete: StorageLocationService.DeletePlan?
    @State private var pendingDeleteID: UUID?
    @State private var newName = ""
    @State private var newParentID: UUID?
    @State private var message = ""

    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    public var body: some View {
        List {
            Section {
                HStack {
                    TextField("New location (e.g. Rail A)", text: $newName)
                    Button("Add") { add() }
                    .disabled(TextNormalize.isBlank(newName))
                }
                // 建子节点入口（此前只能建根节点，树形语义无入口）
                Picker("Inside", selection: $newParentID) {
                    Text(StorageRowCopy.topLevelTitle).tag(Optional<UUID>.none)
                    ForEach(nodes, id: \.id) { node in
                        Text(StorageRowCopy.indentedTitle(node.location.name, depth: node.depth))
                            .tag(Optional(node.location.id))
                    }
                }
                .accessibilityLabel("Parent location")
                if !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(Color.orange)
                        .accessibilityLabel(message)
                }
            }
            Section("Locations") {
                if nodes.isEmpty {
                    Text(StorageEmptyCopy.title)
                        .font(DS.Text.sectionTitle)
                        .foregroundStyle(DS.muted)
                        .accessibilityLabel(StorageEmptyCopy.title)
                } else {
                    ForEach(nodes, id: \.id) { node in
                        HStack {
                            Image(systemName: node.depth == 0 ? "archivebox" : "arrow.turn.down.right")
                                .foregroundStyle(node.depth == 0 ? DS.ink : DS.muted)
                            Text(node.location.name)
                            Spacer()
                            Text("\((node.location.items ?? []).count)")
                                .font(.caption).foregroundStyle(DS.muted)
                        }
                        .padding(.leading, CGFloat(node.depth) * 16)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(StorageRowCopy.accessibilityLabel(
                            name: node.location.name,
                            parentName: node.location.parent?.name,
                            itemCount: (node.location.items ?? []).count))
                        .accessibilityHint(StorageEmptyCopy.rowSwipeAccessibilityHint)
                    }
                    .onDelete(perform: requestDelete)
                }
            }
        }
        .navigationTitle("Storage")
        .confirmationDialog(
            pendingDelete.map { "Delete \($0.name)?" } ?? "",
            isPresented: Binding(get: { pendingDelete != nil },
                                 set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { plan in
            Button("Delete", role: .destructive) { confirmDelete(plan) }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { plan in
            Text(StorageLocationService.deleteWarning(plan))
        }
        .onAppear { reload() }
        // 同 D110：切柜时结构身份不变，onAppear 不重触发——这棵树会留着上一个柜的位置
        .onChange(of: wardrobe.id) { _, _ in reload() }
    }

    private func add() {
        guard let n = TextNormalize.blankToNil(newName) else { return }
        let parent = newParentID.flatMap { id in nodes.first { $0.location.id == id }?.location }
        // 提交前先判重名：诚实报「同名已存在」，而不是笼统的 "Couldn't add — try again"
        guard !StorageLocationService.siblingNameConflicts(n, in: wardrobe, parent: parent) else {
            message = StorageLocationService.duplicateSiblingMessage
            return
        }
        if StorageLocationService.create(name: n, in: wardrobe, parent: parent, context: context) != nil {
            newName = ""
            message = ""
        } else {
            // Keep draft name for retry; do not claim success.
            message = StorageLocationService.createSaveFailedMessage
        }
        reload()
    }

    private func reload() {
        nodes = StorageLocationService.listWithDepth(in: wardrobe)
        // 父节点被删后选择项失效 → 回落顶层，避免 Picker 悬空
        if let pid = newParentID, !nodes.contains(where: { $0.location.id == pid }) {
            newParentID = nil
        }
    }

    /// 删父节点会把子位置与衣物提升到父级——此前完全静默（删「Closet 1」，
    /// 「Rail A」悄悄变成顶层）。有东西被搬动就先说清后果；空叶子直接删。
    private func requestDelete(at offsets: IndexSet) {
        guard let i = offsets.first else { return }
        let target = nodes[i].location
        let plan = StorageLocationService.deletePlan(for: target)
        if plan.needsConfirmation {
            pendingDeleteID = target.id
            pendingDelete = plan
        } else {
            perform(delete: target)
        }
    }

    private func confirmDelete(_ plan: StorageLocationService.DeletePlan) {
        defer { pendingDelete = nil; pendingDeleteID = nil }
        // 按 id 现取现用（快照只承载文案与计数，绝不持模型引用）
        guard let id = pendingDeleteID,
              let target = nodes.first(where: { $0.location.id == id })?.location else { return }
        perform(delete: target)
    }

    private func perform(delete target: StorageLocation) {
        let plan = StorageLocationService.deletePlan(for: target)
        guard DeleteService.deleteLocation(target, in: context) else {
            reload()
            // 失败行 reload 后会重新出现；不闪提示等于静默成功
            message = StorageLocationService.removeSaveFailedMessage
            return
        }
        reload()
        // 提升过东西就说一声去哪了（改名去重也在这条路径上发生）
        message = plan.needsConfirmation ? StorageLocationService.deleteWarning(plan) : ""
    }
}

/// 位置行文案（纯值，可单测——本仓无 ViewInspector，View 本身不可测）。
public enum StorageRowCopy {
    public static let topLevelTitle = "Top level"

    /// Picker 里的层级缩进标题（全角空格，Picker 不渲染前导半角空格）。
    public static func indentedTitle(_ name: String, depth: Int) -> String {
        String(repeating: "　", count: max(0, depth)) + name
    }

    /// VoiceOver：「Rail A, inside Closet 1, 3 pieces」——层级靠缩进的视觉信息
    /// 对 VO 不可达，必须在标签里说出来。
    public static func accessibilityLabel(name: String, parentName: String?, itemCount: Int) -> String {
        var parts = [TextNormalize.blankToNil(name) ?? "Location"]
        if let parent = TextNormalize.blankToNil(parentName) { parts.append("inside \(parent)") }
        parts.append(itemCount == 1 ? "1 piece" : "\(itemCount) pieces")
        return parts.joined(separator: ", ")
    }
}

// MARK: - Personal color

public struct PersonalColorView: View {
    let personID: UUID
    @Environment(\.modelContext) private var context
    @State private var season: PersonalColorSeason = .unknown
    @State private var message = ""

    public init(personID: UUID) { self.personID = personID }

    public var body: some View {
        Form {
            Section {
                Picker("Season", selection: $season) {
                    ForEach(PersonalColorSeason.allCases, id: \.self) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                .pickerStyle(.inline)
            } footer: {
                Text("Optional. Weights today's color score toward this season. Not used for fit math.")
                    .font(.caption2)
            }
            if !message.isEmpty {
                Section {
                    Text(message)
                        .foregroundStyle(
                            message.localizedCaseInsensitiveContains("couldn't")
                                || message.localizedCaseInsensitiveContains("no person")
                                ? Color.orange : DS.accent)
                        .accessibilityLabel(message)
                }
            }
            Section {
                Button("Save") { save() }
            }
        }
        .navigationTitle("Personal color")
        .onAppear { load() }
    }

    private func load() {
        let people = (try? context.fetch(FetchDescriptor<Person>())) ?? []
        if let p = people.first(where: { $0.id == personID }) {
            season = PersonalColorSeason.parse(p.personalColorSeasonRaw)
        }
    }

    private func save() {
        let people = (try? context.fetch(FetchDescriptor<Person>())) ?? []
        guard let p = people.first(where: { $0.id == personID }) else {
            message = ProfileLabels.noPersonMessage
            return
        }
        let oldSeasonRaw = p.personalColorSeasonRaw
        p.personalColorSeasonRaw = season == .unknown ? nil : season.rawValue
        guard ModelSave.save(context, label: "personalColor") else {
            // rollback() 不清内存值只清脏标记 → 先还原字段（ItemStatusService 同款）
            p.personalColorSeasonRaw = oldSeasonRaw
            context.rollback()   // 失败变更不得滞留，否则污染下一次无关 save
            message = ProfileLabels.saveFailedMessage
            AppLog.error("personalColor save failed", .data)
            return
        }
        message = "Saved \(season.displayName)."
    }
}

// MARK: - Closet city edit

public struct ClosetCityEditView: View {
    let wardrobe: Wardrobe
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    /// 城市辅助输入（D107）：选中候选后存标准名，同名城市分得开
    @State private var picker = CityPickerViewModel()

    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    public var body: some View {
        Form {
            CityPickerField(vm: picker, title: "City")
            Text("Used for Open-Meteo live weather (online) and offline climate fallback.")
                .font(.caption).foregroundStyle(DS.muted)
            if !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.orange)
                    .accessibilityLabel(message)
            }
        }
        .navigationTitle("City")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    // Stay open on ModelSave fail — no silent dismiss.
                    let ok = ProfileLabels.applyCity(
                        picker.storedValue ?? "", to: wardrobe, in: context)
                    if let flash = ProfileLabels.editSaveFailureFlash(succeeded: ok) {
                        message = flash
                    } else {
                        dismiss()
                    }
                }
            }
        }
        .onAppear { picker.preload(wardrobe.locationCity) }
    }
}

// MARK: - Closet name edit

/// Me → This closet name (onboarding defaults to "Main"; customer may rename).
public struct ClosetNameEditView: View {
    let wardrobe: Wardrobe
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var message = ""

    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    public var body: some View {
        Form {
            TextField("Closet name", text: $name)
                .textContentType(.organizationName)
            Text("Shown on the Closet tab and in Me.")
                .font(.caption).foregroundStyle(DS.muted)
            if !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.orange)
                    .accessibilityLabel(message)
            }
        }
        .navigationTitle("Closet name")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    // Stay open on ModelSave fail — no silent dismiss (same bar as City).
                    let ok = ProfileLabels.applyWardrobeName(name, to: wardrobe, in: context)
                    if let flash = ProfileLabels.editSaveFailureFlash(succeeded: ok) {
                        message = flash
                    } else {
                        dismiss()
                    }
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear { name = wardrobe.name }
    }
}

// MARK: - Person display name (onboarding)

/// Me → Profile name (cold-start display name; editable after onboarding).
public struct PersonNameEditView: View {
    let person: Person
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var message = ""

    public init(person: Person) { self.person = person }

    public var body: some View {
        Form {
            TextField("Your name", text: $name)
                .textContentType(.name)
            Text("From onboarding — only on this device.")
                .font(.caption).foregroundStyle(DS.muted)
            if !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.orange)
                    .accessibilityLabel(message)
            }
        }
        .navigationTitle("Name")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    // Stay open on ModelSave fail — no silent dismiss (same bar as City).
                    let ok = ProfileLabels.applyPersonName(name, to: person, in: context)
                    if let flash = ProfileLabels.editSaveFailureFlash(succeeded: ok) {
                        message = flash
                    } else {
                        dismiss()
                    }
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear { name = person.name }
    }
}

/// 场合构成编辑面（D98）：Me → Profile → What you dress for。
/// D97 的文案承诺「随时可改」，当时却只有 onboarding 一个写入方。
public struct PrimaryOccasionEditView: View {
    let person: Person
    @Environment(\.modelContext) private var context
    @State private var selection: String?
    @State private var message = ""

    public init(person: Person) { self.person = person }

    public static let title = "What you dress for"

    public var body: some View {
        Form {
            Section {
                Picker(OccasionMix.question, selection: $selection) {
                    Text(OccasionMix.skipTitle).tag(Optional<String>.none)
                    ForEach(OccasionMix.choices, id: \.self) { c in
                        Text(OccasionMix.displayTitle(c)).tag(Optional(c))
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } footer: {
                Text(OccasionMix.hint)
            }
            if !message.isEmpty {
                Section {
                    Text(message).font(.caption).foregroundStyle(Color.orange)
                        .accessibilityLabel(message)
                }
            }
        }
        .navigationTitle(Self.title)
        .onAppear { selection = OccasionMix.parse(person.primaryOccasionRaw) }
        .onChange(of: selection) { _, next in
            guard ProfileLabels.applyPrimaryOccasion(next, to: person, in: context) else {
                message = ProfileLabels.saveFailedMessage
                selection = OccasionMix.parse(person.primaryOccasionRaw)
                return
            }
            message = ""
        }
    }
}

/// 冷热偏置编辑面（D90）：Me → Profile → Temperature preference。
public struct ColdBiasEditView: View {
    let person: Person
    @Environment(\.modelContext) private var context
    @State private var bias: Int = 0
    @State private var message = ""

    public init(person: Person) { self.person = person }

    public static let title = "Temperature preference"

    public var body: some View {
        Form {
            Section {
                Picker(Self.title, selection: $bias) {
                    ForEach(Array(ColdBias.allowedRange), id: \.self) { b in
                        Text(ColdBias.title(b)).tag(b)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } footer: {
                Text(ColdBias.explainer)
            }
            if !message.isEmpty {
                Section {
                    Text(message).font(.caption).foregroundStyle(Color.orange)
                        .accessibilityLabel(message)
                }
            }
        }
        .navigationTitle(Self.title)
        .onAppear { bias = ColdBias.clamp(person.coldBias) }
        .onChange(of: bias) { _, next in
            // 选中即落库；失败不静默——回滚到实际值并说明
            guard ProfileLabels.applyColdBias(next, to: person, in: context) else {
                message = ProfileLabels.saveFailedMessage
                bias = ColdBias.clamp(person.coldBias)
                return
            }
            message = ""
        }
    }
}

/// Pure Me-profile helpers (testable without SwiftUI). ModelSave false → return false (no silent OK).
public enum ProfileLabels {
    public static let saveFailedMessage = "Couldn't save — try again"
    public static let noPersonMessage = "No person profile yet — finish Onboarding."

    /// Me City / Closet name / Person name Save: stay open + flash; never silent dismiss on fail.
    public static func editSaveFailureFlash(succeeded: Bool) -> String? {
        succeeded ? nil : saveFailedMessage
    }

    @discardableResult
    public static func applyPersonName(
        _ raw: String, to person: Person, in context: ModelContext
    ) -> Bool {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        let old = person.name
        person.name = t
        guard ModelSave.save(context, label: "personName") else {
            person.name = old
            context.rollback()   // 失败变更不得滞留，否则污染下一次无关 save
            AppLog.error("person rename save failed", .data)
            return false
        }
        AppLog.notice("person renamed", .data)
        return true
    }

    /// 冷热偏置落库（D90）。此前 `Person.coldBias` 有字段、进导出、无 UI 无消费者——
    /// 用户永远设不了它，而导出里躺着一个恒为 0 的「个人偏好」。
    /// 场合构成改写（D98）。D97 的文案承诺「随时可改」，而当时只有 onboarding
    /// 一个写入方——承诺必须有兑现路径。nil = 改回「没想好」（不是单向门）。
    @discardableResult
    public static func applyPrimaryOccasion(
        _ raw: String?, to person: Person, in context: ModelContext
    ) -> Bool {
        // 脏值拒绝：不得写进引擎不认的场合
        if raw != nil, OccasionMix.parse(raw) == nil {
            AppLog.error("rejected unknown primary occasion", .data)
            return false
        }
        let next = OccasionMix.parse(raw)
        let old = person.primaryOccasionRaw
        guard next != old else { return true }
        person.primaryOccasionRaw = next
        guard ModelSave.save(context, label: "primaryOccasion") else {
            person.primaryOccasionRaw = old
            context.rollback()   // 失败变更不得滞留，否则污染下一次无关 save
            AppLog.error("primary occasion save failed", .data)
            return false
        }
        AppLog.notice("primary occasion set", .data)
        return true
    }

    @discardableResult
    public static func applyColdBias(
        _ raw: Int, to person: Person, in context: ModelContext
    ) -> Bool {
        let clamped = ColdBias.clamp(raw)
        let old = person.coldBias
        guard clamped != old else { return true }
        person.coldBias = clamped
        guard ModelSave.save(context, label: "coldBias") else {
            person.coldBias = old
            context.rollback()   // 失败变更不得滞留，否则污染下一次无关 save
            AppLog.error("cold bias save failed", .data)
            return false
        }
        AppLog.notice("cold bias set \(clamped)", .data)
        return true
    }

    @discardableResult
    public static func applyWardrobeName(
        _ raw: String, to wardrobe: Wardrobe, in context: ModelContext
    ) -> Bool {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        // 撞同 owner 其他衣柜名拒绝（自身大小写调整不算冲突）——与 create 同守卫。
        if WardrobeManageActions.nameConflicts(
            t, among: wardrobe.owner?.wardrobes ?? [], excluding: wardrobe) {
            AppLog.error("wardrobe rename duplicate blocked", .data)
            return false
        }
        let old = wardrobe.name
        wardrobe.name = t
        guard ModelSave.save(context, label: "closetName") else {
            wardrobe.name = old
            context.rollback()   // 失败变更不得滞留，否则污染下一次无关 save
            AppLog.error("wardrobe rename save failed", .data)
            return false
        }
        AppLog.notice("wardrobe renamed \(AppLog.ref(wardrobe.id))", .data)
        return true
    }

    /// Me → City — empty clears city (valid); ModelSave failure returns false.
    @discardableResult
    public static func applyCity(
        _ raw: String, to wardrobe: Wardrobe, in context: ModelContext
    ) -> Bool {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let old = wardrobe.locationCity
        wardrobe.locationCity = t.isEmpty ? nil : t
        guard ModelSave.save(context, label: "closetCity") else {
            wardrobe.locationCity = old
            context.rollback()   // 失败变更不得滞留，否则污染下一次无关 save
            AppLog.error("closet city save failed", .data)
            return false
        }
        AppLog.notice("closet city changed hasCity=\(wardrobe.locationCity != nil)", .data)
        return true
    }
}
