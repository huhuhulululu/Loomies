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

/// 衣柜列表 / 新建（接 Root 切换前的管理面）。
public struct WardrobeManageView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Wardrobe.name) private var wardrobes: [Wardrobe]
    @Query private var people: [Person]
    @State private var newName = ""
    @State private var newCity = ""
    @State private var message = ""

    public init() {}

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
                        VStack(alignment: .leading, spacing: 4) {
                            Text(w.name.isEmpty ? "Untitled" : w.name).font(.headline)
                            Text(WardrobeManageActions.listSubtitle(
                                itemCount: (w.items ?? []).count,
                                locationCity: w.locationCity))
                                .font(.caption).foregroundStyle(DS.muted)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            Section("Add closet") {
                TextField("Name", text: $newName)
                TextField("City", text: $newCity)
                Button("Create") { create() }
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if !message.isEmpty {
                Section {
                    Text(message)
                        .foregroundStyle(
                            message.localizedCaseInsensitiveContains("couldn't")
                                ? Color.orange : DS.accent)
                        .accessibilityLabel(message)
                }
            }
        }
        .navigationTitle("Wardrobes")
    }

    private func create() {
        let result = WardrobeManageActions.create(
            name: newName,
            city: newCity,
            existingPeople: people,
            in: context)
        message = result.message
        if result.wardrobe != nil {
            newName = ""
            newCity = ""
        }
    }
}
