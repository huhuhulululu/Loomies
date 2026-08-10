import SwiftUI
import SwiftData
import ClosetModel
import ClosetCore

// MARK: - Create action (honest ModelSave; testable without SwiftUI)

/// Me → Wardrobes list create path — same honesty bar as `WardrobeSwitcherViewModel`.
public enum WardrobeManageActions {
    public static let needNameMessage = "Enter a closet name."
    public static let createFailedMessage = "Couldn't create closet — try again"
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
        var autoCreatedPerson: Person?
        let person = existingPeople.first ?? {
            let p = Person(name: "Me")
            context.insert(p)
            autoCreatedPerson = p
            return p
        }()
        let city = rawCity.trimmingCharacters(in: .whitespacesAndNewlines)
        let w = Wardrobe(name: name, locationCity: city.isEmpty ? nil : city)
        w.owner = person
        context.insert(w)
        guard ModelSave.save(context, label: "wardrobeCreate") else {
            context.delete(w)
            // Auto-created "Me" was never committed — drop it too, else the next
            // unrelated save persists an ownerless Person as silent fallback.
            if let autoCreatedPerson { context.delete(autoCreatedPerson) }
            AppLog.error("wardrobe manage create save failed", .data)
            return (createFailedMessage, nil)
        }
        AppLog.notice("wardrobe created \(name)", .data)
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
