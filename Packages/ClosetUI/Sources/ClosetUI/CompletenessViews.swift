import SwiftUI
import SwiftData
import ClosetModel
import ClosetCore

// MARK: - Calendar (full)

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

    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    public var body: some View {
        NavigationStack {
            Group {
                if filteredPlans.isEmpty {
                    ContentUnavailableView {
                        Label(
                            showAttentionOnly ? "No items need attention" : "No plans yet",
                            systemImage: "calendar")
                    } description: {
                        Text("Save a look from Today, or plan a favorite for a day.")
                    } actions: {
                        Button("Plan a favorite") { reloadFavorites(); showPlanPicker = true }
                            .buttonStyle(.borderedProminent).tint(DS.accent)
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
                }
            }
            .onAppear { reload() }
            .sheet(isPresented: $showPlanPicker) { planSheet }
            .overlay(alignment: .bottom) {
                if let message {
                    Text(message)
                        .font(.caption)
                        .padding(8)
                        .background(DS.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
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
                Text(plan.date, style: .date).font(.headline)
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
    }

    private var planSheet: some View {
        NavigationStack {
            Form {
                DatePicker("Day", selection: $planDate, displayedComponents: .date)
                if favorites.isEmpty {
                    Text("No favorites yet. Heart a suggestion on Today.")
                        .font(.caption).foregroundStyle(DS.muted)
                } else {
                    ForEach(favorites, id: \.id) { outfit in
                        Button {
                            _ = CalendarPlanService.plan(outfit: outfit, on: planDate, in: context)
                            message = "Planned \(lookTitle(outfit))"
                            showPlanPicker = false
                            reload()
                        } label: {
                            HStack(spacing: 12) {
                                lookThumb(
                                    items: outfit.items ?? [],
                                    occasion: outfit.occasionRaw,
                                    width: 40, height: 60)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(lookTitle(outfit))
                                        .foregroundStyle(DS.ink)
                                    Text("\((outfit.items ?? []).count) pieces · \(outfit.occasionRaw?.capitalized ?? "Any")")
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

    private func lookTitle(_ outfit: ClosetModel.Outfit?) -> String {
        guard let outfit else { return "Look" }
        if outfit.name.isEmpty { return "Favorite look" }
        return outfit.name
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
            depthIntensity: .off)
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
        for i in offsets {
            CalendarPlanService.remove(filteredPlans[i], in: context)
        }
        reload()
    }
}

// MARK: - Storage locations

public struct StorageLocationsView: View {
    let wardrobe: Wardrobe
    @Environment(\.modelContext) private var context
    @State private var locations: [StorageLocation] = []
    @State private var newName = ""

    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    public var body: some View {
        List {
            Section {
                HStack {
                    TextField("New location (e.g. Rail A)", text: $newName)
                    Button("Add") {
                        let n = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !n.isEmpty else { return }
                        _ = StorageLocationService.create(name: n, in: wardrobe, context: context)
                        newName = ""
                        reload()
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            Section("Locations") {
                if locations.isEmpty {
                    Text("No locations yet.").font(.caption).foregroundStyle(DS.muted)
                } else {
                    ForEach(locations, id: \.id) { loc in
                        HStack {
                            Image(systemName: "archivebox")
                            Text(loc.name)
                            Spacer()
                            Text("\((loc.items ?? []).count)")
                                .font(.caption).foregroundStyle(DS.muted)
                        }
                    }
                }
            }
        }
        .navigationTitle("Storage")
        .onAppear { reload() }
    }

    private func reload() {
        locations = StorageLocationService.list(in: wardrobe)
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
                Section { Text(message).foregroundStyle(DS.accent) }
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
            message = "No person profile yet — finish Onboarding."
            return
        }
        p.personalColorSeasonRaw = season == .unknown ? nil : season.rawValue
        ModelSave.save(context, label: "personalColor")
        message = "Saved \(season.displayName)."
    }
}

// MARK: - Closet city edit

public struct ClosetCityEditView: View {
    let wardrobe: Wardrobe
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var city: String = ""

    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    public var body: some View {
        Form {
            TextField("City", text: $city)
            Text("Used for offline climate estimate and future WeatherKit.")
                .font(.caption).foregroundStyle(DS.muted)
        }
        .navigationTitle("City")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let t = city.trimmingCharacters(in: .whitespacesAndNewlines)
                    wardrobe.locationCity = t.isEmpty ? nil : t
                    ModelSave.save(context, label: "closetCity")
                    dismiss()
                }
            }
        }
        .onAppear { city = wardrobe.locationCity ?? "" }
    }
}
