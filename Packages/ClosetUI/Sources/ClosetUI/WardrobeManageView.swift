import SwiftUI
import SwiftData
import ClosetModel
import ClosetCore

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
                ForEach(wardrobes, id: \.id) { w in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(w.name.isEmpty ? "Untitled" : w.name).font(.headline)
                        Text("\((w.items ?? []).count) items · \(w.locationCity ?? "no city")")
                            .font(.caption).foregroundStyle(DS.muted)
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
                Section { Text(message).foregroundStyle(DS.accent) }
            }
        }
        .navigationTitle("Wardrobes")
    }

    private func create() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let person = people.first ?? {
            let p = Person(name: "Me"); context.insert(p); return p
        }()
        let w = Wardrobe(name: name, locationCity: newCity.isEmpty ? nil : newCity)
        w.owner = person
        context.insert(w)
        ModelSave.save(context, label: "wardrobeCreate")
        newName = ""; newCity = ""
        message = "Created \(name)."
        AppLog.notice("wardrobe created \(name)", .data)
    }
}
