import SwiftUI
import SwiftData
import ClosetModel
import ClosetCore

// MARK: - Calendar (full)

/// Empty calendar list — Attention vs all; points to Today/Favorites (no fake sync).
public enum CalendarEmptyCopy {
    public static func title(attentionOnly: Bool) -> String {
        attentionOnly ? "No items need attention" : "No plans yet"
    }

    public static let description =
        "Save a look from Today, or plan a favorite for a day."

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
                    .font(.caption).foregroundStyle(DS.muted)
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

    private var ownerProfile: PersonBodyProfile? {
        guard let pid = wardrobe.owner?.id else { return nil }
        let profiles = (try? context.fetch(FetchDescriptor<PersonBodyProfile>())) ?? []
        return profiles.first(where: { $0.personID == pid })
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
        plans = CalendarPlanService.plans(for: wardrobe, in: context)
        // 若本柜为空，仍展示全部（跨柜计划可见）
        if plans.isEmpty {
            plans = CalendarPlanService.allPlans(in: context)
        }
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
                        .font(.caption)
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
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("Storage")
        .onAppear { reload() }
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

    private func delete(at offsets: IndexSet) {
        var saveFailed = false
        for i in offsets {
            if !DeleteService.deleteLocation(nodes[i].location, in: context) {
                saveFailed = true
            }
        }
        reload()
        // After reload, failed rows reappear; flash so swipe is not silent success.
        if saveFailed {
            message = StorageLocationService.removeSaveFailedMessage
        }
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
                Text("Optional style hint (R11). Not used for fit math.")
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
    @State private var city: String = ""
    @State private var message = ""

    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    public var body: some View {
        Form {
            TextField("City", text: $city)
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
                    let ok = ProfileLabels.applyCity(city, to: wardrobe, in: context)
                    if let flash = ProfileLabels.editSaveFailureFlash(succeeded: ok) {
                        message = flash
                    } else {
                        dismiss()
                    }
                }
            }
        }
        .onAppear { city = wardrobe.locationCity ?? "" }
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
