import SwiftUI
import SwiftData
import ClosetModel
import ClosetCore

// MARK: - Create action (honest ModelSave; testable without SwiftUI)

/// Me → Wardrobes list create path — same honesty bar as `WardrobeSwitcherViewModel`.
public enum WardrobeManageActions {
    public static let needNameMessage = "Enter a closet name."
    public static let createFailedMessage = "Couldn't create closet — try again"
    /// 重名衣柜会让 Transfer 默认目的地 / active 衣柜漂移且 UI 无法区分。
    public static let duplicateNameMessage = "A closet with that name already exists."

    // MARK: - 删除（D85：服务层早就绪，此前零 UI 入口）

    /// 删除动作结果。**带类型化的 blockedReason**——View 靠它升级到二段确认，
    /// 不得靠 message 字符串相等（润色文案就会静默失效且无测试会红）。
    /// `isFailure` 由返回值驱动，不再让 UI 嗅探关键词着色。
    public struct DeleteOutcome: Sendable, Equatable {
        public let message: String
        public let deleted: Bool
        public let blockedReason: DeleteError?
        public var isFailure: Bool { !deleted }
    }

    public static let currentClosetBlockedMessage =
        "This is the closet you're in. Switch closets first."
    public static let currentClosetRowAccessibilityHint =
        "Current closet — switch closets before deleting it"
    public static let rowSwipeAccessibilityHint = "Swipe to delete"
    public static let peopleSectionFooter =
        "Deleting a person also deletes their body measurements."

    public static func deletedMessage(_ name: String) -> String {
        "Deleted \(TextNormalize.blankToNil(name) ?? "closet")."
    }

    public static func deleteConfirmTitle(_ name: String) -> String {
        "Delete \(TextNormalize.blankToNil(name) ?? "this closet")?"
    }

    /// 删除确认的警告文案。必须**完整**告知级联面（照片、日历计划），
    /// 并说明穿着历史保留——不得声称做了没做的事，也不得隐瞒做了的事。
    /// 计数为 0 的项不出现在句子里（「0 pieces」是噪音，且会让空柜读起来像有内容）。
    public static func forceDeleteWarning(
        itemCount: Int, lookCount: Int, planCount: Int, foreignLookCount: Int = 0
    ) -> String {
        var parts: [String] = []
        if itemCount > 0 { parts.append("\(itemCount) pieces") }
        if lookCount > 0 { parts.append("\(lookCount) looks") }
        if planCount > 0 { parts.append("\(planCount) calendar plans") }
        guard !parts.isEmpty else { return WardrobeDeleteConfirm.emptyMessage }
        var text = "This also deletes " + parts.joined(separator: ", ")
            + ", and their local photos."
        // D139：**别的柜里**用到这些件的搭配会被标为永久缺件（D103 修的是行为，
        // 文案一直没跟上）——那是用户最想不到的后果，不说的话他会在别的柜里
        // 发现搭配坏了，而无从知道是自己刚才那一下。
        if foreignLookCount > 0 {
            let looks = foreignLookCount == 1 ? "1 look" : "\(foreignLookCount) looks"
            text += " \(looks) in other closets will be marked as missing pieces."
        }
        // D139：此前这里写「Wear history is kept」——记录行确实留着，
        // 但唯一能读它的界面按已删柜过滤，**技术上为真、实际为假**。
        // 一句读不到的「保留」比不提更糟：它让人以为还能找回来。
        return text
    }

    /// 当前打开的衣柜不可删（上层持有已删模型 / 删到零柜回落 Onboarding 会造重复 Person）。
    public static func canDelete(_ wardrobe: Wardrobe, currentWardrobeID: UUID?) -> Bool {
        wardrobe.id != currentWardrobeID
    }

    @discardableResult
    public static func delete(
        _ wardrobe: Wardrobe, force: Bool, in context: ModelContext
    ) -> DeleteOutcome {
        let name = wardrobe.name
        do {
            try DeleteService.deleteWardrobe(wardrobe, force: force, in: context)
            AppLog.notice("wardrobe deleted \(AppLog.ref(wardrobe.id)) force=\(force)", .data)
            return DeleteOutcome(message: deletedMessage(name), deleted: true, blockedReason: nil)
        } catch let err as DeleteError {
            return DeleteOutcome(
                message: err.errorDescription ?? "Couldn't delete — try again",
                deleted: false, blockedReason: err)
        } catch {
            return DeleteOutcome(
                message: DeleteError.saveFailed.errorDescription ?? "Couldn't delete — try again",
                deleted: false, blockedReason: .saveFailed)
        }
    }

    @discardableResult
    public static func deletePerson(_ person: Person, in context: ModelContext) -> DeleteOutcome {
        let name = person.name
        do {
            try DeleteService.deletePerson(person, in: context)
            AppLog.notice("person deleted \(AppLog.ref(person.id))", .data)
            return DeleteOutcome(
                message: "Deleted \(TextNormalize.blankToNil(name) ?? "person").",
                deleted: true, blockedReason: nil)
        } catch let err as DeleteError {
            return DeleteOutcome(
                message: err.errorDescription ?? "Couldn't delete — try again",
                deleted: false, blockedReason: err)
        } catch {
            return DeleteOutcome(
                message: DeleteError.saveFailed.errorDescription ?? "Couldn't delete — try again",
                deleted: false, blockedReason: .saveFailed)
        }
    }

    /// 同 owner 下同名（大小写/空白不敏感）。excluding 用于重命名时排除自身。
    public static func nameConflicts(
        _ name: String, among wardrobes: [Wardrobe], excluding: Wardrobe? = nil
    ) -> Bool {
        guard let t = TextNormalize.blankToNil(name)?.lowercased() else { return false }
        return wardrobes.contains { $0.id != excluding?.id && $0.name.lowercased() == t }
    }
    /// List meta when closet has no city (Title Case; not lowercase “no city”).
    public static let noCityCaption = "No city"
    /// Empty “Your closets” section — recovery is Add closet below (no fake sync).
    public static let emptyListMessage = "No closets yet. Add one below."

    public static func createdMessage(_ name: String) -> String { "Created \(name)." }

    /// Row subtitle: “N items · City” / “N items · No city”.
    public static func listSubtitle(itemCount: Int, locationCity: String?) -> String {
        let city = locationCity?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cityPart = city.isEmpty ? noCityCaption : city
        return "\(itemCount) items · \(cityPart)"
    }

    /// Inserts a closet; rolls back on save failure. Returns customer message + wardrobe if committed.
    @discardableResult
    public static func create(
        name rawName: String,
        city rawCity: String,
        existingPeople: [Person],
        in context: ModelContext
    ) -> (message: String, wardrobe: Wardrobe?) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return (needNameMessage, nil)
        }
        if let owner = existingPeople.first,
           nameConflicts(name, among: owner.wardrobes ?? []) {
            return (duplicateNameMessage, nil)
        }
        let person = existingPeople.first ?? {
            let p = Person(name: "Me")
            context.insert(p)
            return p
        }()
        let city = rawCity.trimmingCharacters(in: .whitespacesAndNewlines)
        let w = Wardrobe(name: name, locationCity: city.isEmpty ? nil : city)
        w.owner = person
        context.insert(w)
        guard ModelSave.save(context, label: "wardrobeCreate") else {
            // 先解开内存关系（rollback 不回写内存幻影），再 rollback 丢弃全部 pending insert
            //（含自动创建的 "Me" person）+ 清脏标记——delete 只删行，脏标记会滞留。
            w.owner = nil
            context.rollback()   // 一并丢弃自动创建的 "Me" pending insert；失败变更不得滞留
            AppLog.error("wardrobe manage create save failed", .data)
            return (createFailedMessage, nil)
        }
        AppLog.notice("wardrobe created \(AppLog.ref(w.id))", .data)
        return (createdMessage(name), w)
    }
}

/// 删柜确认的判空与文案（纯值逻辑，可测）。
///
/// D88 教训两条：
/// 1. 判空只看 `itemCount` 是**谎报**——DeleteService 的阻断判据同样只看 items，
///    于是「0 件单品但有 look / 日历计划」的柜子会走 force=false 直接删成功，
///    级联抹掉全部 look 与计划，而用户看到的确认文案写着「This closet is empty.」。
/// 2. 两层 `.confirmationDialog` 叠在同一 view 上、在同一 runloop 内切换，
///    第二层会被 SwiftUI 吞掉（表现为「点了删除什么也没发生」）；而它的文案与
///    第一层逐字相同、零新增披露。故收敛为**一次确认**：非空柜直接升级按钮措辞。
public enum WardrobeDeleteConfirm {
    public static let emptyMessage = "This closet is empty."

    public struct Counts: Sendable, Equatable {
        public let itemCount: Int
        public let lookCount: Int
        public let planCount: Int
        /// **别的柜里**会被标为永久缺件的搭配数（D139）。
        public let foreignLookCount: Int
        public init(
            itemCount: Int, lookCount: Int, planCount: Int, foreignLookCount: Int = 0
        ) {
            self.itemCount = itemCount
            self.lookCount = lookCount
            self.planCount = planCount
            self.foreignLookCount = foreignLookCount
        }
    }

    /// 「空」= 删了不会连带抹掉任何东西。三个计数都得为 0。
    public static func isEffectivelyEmpty(_ c: Counts) -> Bool {
        c.itemCount == 0 && c.lookCount == 0 && c.planCount == 0
    }

    public static func message(_ c: Counts) -> String {
        isEffectivelyEmpty(c)
            ? emptyMessage
            : WardrobeManageActions.forceDeleteWarning(
                itemCount: c.itemCount, lookCount: c.lookCount, planCount: c.planCount,
                foreignLookCount: c.foreignLookCount)
    }

    /// 非空柜的按钮措辞升级——用户在同一个框里既看到后果又看到「anyway」。
    public static func confirmTitle(_ c: Counts) -> String {
        isEffectivelyEmpty(c) ? "Delete" : "Delete anyway"
    }

    /// 非空柜一次确认即 force 删除（后果已在同一个框里完整披露）。
    public static func needsForce(_ c: Counts) -> Bool { !isEffectivelyEmpty(c) }
}

/// 衣柜列表 / 新建（接 Root 切换前的管理面）。
/// 删除确认的**值类型**快照：绝不在 @State 里持 @Model——对话框消散动画期间仍会
/// 重新求值 title/message，读已 `context.delete` 的模型属性是未定义行为。
public struct PendingWardrobeDelete: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let itemCount: Int
    public let lookCount: Int
    public let planCount: Int
    /// 别的柜里会被标为永久缺件的搭配数（D139）。
    public let foreignLookCount: Int

    public var counts: WardrobeDeleteConfirm.Counts {
        .init(itemCount: itemCount, lookCount: lookCount, planCount: planCount,
              foreignLookCount: foreignLookCount)
    }

    @MainActor
    public init(wardrobe: Wardrobe, in context: ModelContext) {
        self.id = wardrobe.id
        self.name = wardrobe.name
        self.itemCount = (wardrobe.items ?? []).count
        // 判据与执行同源（`DeleteService`）——两处各写一份的话，
        // 对话框迟早说的和实际做的不是一回事。
        self.foreignLookCount = DeleteService.foreignOutfitsAffected(byDeleting: wardrobe)
        let outfits = wardrobe.outfits ?? []
        self.lookCount = outfits.count
        let outfitIDs = Set(outfits.map(\.id))
        let plans = (try? context.fetch(FetchDescriptor<CalendarPlan>())) ?? []
        self.planCount = plans.filter { $0.outfit.map { outfitIDs.contains($0.id) } == true }.count
    }
}

public struct WardrobeManageView: View {
    @Environment(\.modelContext) private var context
    /// 不带 sort：同名衣柜跨 owner 合法，单键排序的行序会随 fetch 漂移——
    /// 而这是个带滑动删除的破坏性列表，行序不稳 = 确认框里的名字可能不是刚划的那行。
    @Query private var allWardrobes: [Wardrobe]
    /// (name, id) 双键——与 People 分区、listWithDepth 同一约定
    private var wardrobes: [Wardrobe] {
        allWardrobes.sortedByName()
    }
    @Query private var people: [Person]
    @State private var newName = ""
    /// D110：此前这里是裸 TextField——D107 的 ADR 写「两处都换了」，
    /// 却漏审了这**第三个写入方**，新建衣柜的城市从此没有校验也没有标准名。
    @State private var cityPicker = CityPickerViewModel()
    @State private var message = ""
    @State private var messageIsFailure = false
    @State private var pendingDelete: PendingWardrobeDelete?
    @State private var pendingPersonDelete: (id: UUID, name: String)?
    let currentWardrobeID: UUID?

    public init(currentWardrobeID: UUID? = nil) {
        self.currentWardrobeID = currentWardrobeID
    }

    public var body: some View {
        List {
            Section("Your closets") {
                if wardrobes.isEmpty {
                    Text(WardrobeManageActions.emptyListMessage)
                        .font(.caption)
                        .foregroundStyle(DS.muted)
                        .accessibilityLabel(WardrobeManageActions.emptyListMessage)
                } else {
                    ForEach(wardrobes, id: \.id) { w in
                        let isCurrent = !WardrobeManageActions.canDelete(
                            w, currentWardrobeID: currentWardrobeID)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(w.name.isEmpty ? "Untitled" : w.name).font(.headline)
                                if isCurrent {
                                    Text("Current")
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(DS.accent.opacity(0.18))
                                        .foregroundStyle(DS.accent)
                                        .clipShape(Capsule())
                                }
                            }
                            Text(WardrobeManageActions.listSubtitle(
                                itemCount: (w.items ?? []).count,
                                locationCity: w.locationCity))
                                .font(.caption).foregroundStyle(DS.muted)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityHint(isCurrent
                            ? WardrobeManageActions.currentClosetRowAccessibilityHint
                            : WardrobeManageActions.rowSwipeAccessibilityHint)
                        .swipeActions(edge: .trailing) {
                            if !isCurrent {
                                Button("Delete", role: .destructive) {
                                    // 值类型快照：对话框不得持 @Model（删后重求值是未定义行为）
                                    pendingDelete = PendingWardrobeDelete(wardrobe: w, in: context)
                                }
                            }
                        }
                    }
                }
            }
            Section {
                if people.isEmpty {
                    Text("No people yet.").font(.caption).foregroundStyle(DS.muted)
                } else {
                    ForEach(people.sortedByName(),
                            id: \.id) { person in
                        let closetCount = (person.wardrobes ?? []).count
                        let blocked = closetCount > 0
                        VStack(alignment: .leading, spacing: 4) {
                            Text(person.name.isEmpty ? "Unnamed" : person.name).font(.headline)
                            Text(blocked
                                 ? (DeleteError.personHasWardrobes.errorDescription ?? "")
                                 : "No closets")
                                .font(.caption).foregroundStyle(DS.muted)
                        }
                        .accessibilityElement(children: .combine)
                        .swipeActions(edge: .trailing) {
                            if !blocked {
                                Button("Delete", role: .destructive) {
                                    pendingPersonDelete = (person.id, person.name)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("People")
            } footer: {
                Text(WardrobeManageActions.peopleSectionFooter)
            }
            Section("Add closet") {
                TextField("Name", text: $newName)
                CityPickerField(vm: cityPicker, title: "City")
                Button("Create") { create() }
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if !message.isEmpty {
                Section {
                    // 着色由动作返回值驱动（旧的关键词嗅探对「当前柜不可删」这类
                    // 不含 couldn't 的诚实阻断会误判为成功色）
                    Text(message)
                        .foregroundStyle(messageIsFailure ? Color.orange : DS.accent)
                        .accessibilityLabel(message)
                }
            }
        }
        .navigationTitle("Closets & people")
        .confirmationDialog(
            pendingDelete.map { WardrobeManageActions.deleteConfirmTitle($0.name) } ?? "",
            isPresented: Binding(get: { pendingDelete != nil },
                                 set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { snap in
            // 一次确认：后果已在 message 里完整披露，非空柜按钮直接说 "Delete anyway"
            Button(WardrobeDeleteConfirm.confirmTitle(snap.counts), role: .destructive) {
                performDelete(snap, force: WardrobeDeleteConfirm.needsForce(snap.counts))
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { snap in
            Text(WardrobeDeleteConfirm.message(snap.counts))
        }
        .confirmationDialog(
            pendingPersonDelete.map { "Delete \($0.name)?" } ?? "",
            isPresented: Binding(get: { pendingPersonDelete != nil },
                                 set: { if !$0 { pendingPersonDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { performPersonDelete() }
            Button("Cancel", role: .cancel) { pendingPersonDelete = nil }
        } message: {
            Text(WardrobeManageActions.peopleSectionFooter)
        }
    }

    private func performDelete(_ snap: PendingWardrobeDelete, force: Bool) {
        // 按 id 现取现用（快照只承载文案与计数，绝不持模型引用）
        guard let target = wardrobes.first(where: { $0.id == snap.id }) else {
            pendingDelete = nil
            return
        }
        guard WardrobeManageActions.canDelete(target, currentWardrobeID: currentWardrobeID) else {
            message = WardrobeManageActions.currentClosetBlockedMessage
            messageIsFailure = true
            pendingDelete = nil
            return
        }
        let out = WardrobeManageActions.delete(target, force: force, in: context)
        pendingDelete = nil
        message = out.message
        messageIsFailure = out.isFailure
    }

    private func performPersonDelete() {
        guard let pending = pendingPersonDelete,
              let person = people.first(where: { $0.id == pending.id }) else {
            pendingPersonDelete = nil
            return
        }
        let out = WardrobeManageActions.deletePerson(person, in: context)
        pendingPersonDelete = nil
        message = out.message
        messageIsFailure = out.isFailure
    }

    private func create() {
        let result = WardrobeManageActions.create(
            name: newName,
            city: cityPicker.storedValue ?? "",
            existingPeople: people,
            in: context)
        message = result.message
        messageIsFailure = result.wardrobe == nil
        if result.wardrobe != nil {
            newName = ""
            cityPicker.preload(nil)
        }
    }
}
