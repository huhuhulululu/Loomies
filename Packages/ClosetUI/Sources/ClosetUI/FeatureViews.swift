import SwiftUI
import SwiftData
import ClosetModel
import ClosetCore

// MARK: - Item detail

public struct ItemDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var vm: ItemDetailViewModel
    @State private var transferVM: TransferViewModel?
    var bodyProfile: PersonBodyProfile?

    public init(item: Item, bodyProfile: PersonBodyProfile? = nil) {
        _vm = State(initialValue: ItemDetailViewModel(item: item))
        self.bodyProfile = bodyProfile
    }

    public var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $vm.name)
                Picker("Type", selection: $vm.slotRaw) {
                    ForEach(["top","bottom","dress","outerwear","shoes","accessory"], id: \.self) {
                        Text($0.capitalized).tag($0)
                    }
                }
                TextField("Brand", text: $vm.brand)
                TextField("Size", text: $vm.sizeLabel)
                TextField("Occasions (comma)", text: $vm.occasionsText)
            }
            Section("Status") {
                Picker("Status", selection: $vm.statusRaw) {
                    ForEach(vm.statuses, id: \.self) {
                        Text(ItemStatusService.displayName($0)).tag($0)
                    }
                }
            }
            Section("Fit measures (inches, flat)") {
                TextField("Chest flat width", text: $vm.chestFlat)
                TextField("Waist flat width", text: $vm.waistFlat)
                if let fit = vm.fitLabel {
                    LabeledContent("Fit mark", value: fit)
                } else {
                    Text("Enter body profile + flat widths for fit mark.")
                        .font(.caption).foregroundStyle(DS.muted)
                }
            }
            if let msg = Optional(vm.message), !msg.isEmpty {
                Section { Text(msg).foregroundStyle(DS.accent) }
            }
        }
        .navigationTitle(vm.item.name.isEmpty ? "Item" : vm.item.name)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Transfer") { transferVM = TransferViewModel(item: vm.item) }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    vm.save(in: context)
                    vm.refreshFit(profile: bodyProfile)
                }
            }
        }
        .onAppear { vm.refreshFit(profile: bodyProfile) }
        .sheet(item: Binding(
            get: { transferVM.map { TransferBox(vm: $0) } },
            set: { transferVM = $0?.vm }
        )) { box in
            TransferSheet(vm: box.vm)
        }
    }
}

private struct TransferBox: Identifiable {
    let id = UUID()
    let vm: TransferViewModel
}

struct TransferSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var vm: TransferViewModel

    var body: some View {
        NavigationStack {
            Form {
                if vm.destinations.isEmpty {
                    Text("No other wardrobes. Create one in Me.")
                } else {
                    Picker("Move to", selection: $vm.selectedDestinationID) {
                        ForEach(vm.destinations, id: \.id) { w in
                            Text(w.name).tag(Optional(w.id))
                        }
                    }
                }
                if !vm.message.isEmpty {
                    Text(vm.message).foregroundStyle(DS.accent)
                }
            }
            .navigationTitle("Transfer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Move") {
                        vm.transfer(in: context)
                        dismiss()
                    }
                    .disabled(vm.destinations.isEmpty)
                }
            }
            .onAppear { vm.loadDestinations(in: context) }
        }
    }
}

// MARK: - Body profile

public struct BodyProfileView: View {
    @Environment(\.modelContext) private var context
    @State private var vm: BodyProfileViewModel

    public init(personID: UUID) {
        _vm = State(initialValue: BodyProfileViewModel(personID: personID))
    }

    public var body: some View {
        Form {
            Section {
                BodyAvatarView.from(
                    measurements: vm.liveMeasurements,
                    fitCaption: vm.isComplete
                        ? "Fit model reference for \(vm.popularShape.rawValue)."
                        : "Enter all four measures to match a body reference.")
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                .listRowBackground(Color.clear)
            } header: {
                Text("Body reference")
            } footer: {
                Text("360° fit-model guide (drag to rotate) — not a selfie try-on; static frames, no spin animation.")
                    .font(.caption2)
            }

            Section("Measurements (inches)") {
                TextField("Bust", text: $vm.bust)
                    .onChange(of: vm.bust) { _, _ in vm.refreshPreview() }
                TextField("Waist", text: $vm.waist)
                    .onChange(of: vm.waist) { _, _ in vm.refreshPreview() }
                TextField("Hip", text: $vm.hip)
                    .onChange(of: vm.hip) { _, _ in vm.refreshPreview() }
                TextField("High hip", text: $vm.highHip)
                    .onChange(of: vm.highHip) { _, _ in vm.refreshPreview() }
            }
            Section("FFIT") {
                if vm.isComplete, let shape = vm.shapeLabel {
                    LabeledContent("Shape", value: shape)
                } else {
                    Text("Enter all four to unlock body-shape weighting.")
                        .font(.caption).foregroundStyle(DS.muted)
                }
            }
            if !vm.message.isEmpty {
                Section { Text(vm.message).foregroundStyle(DS.accent) }
            }
            Section {
                Button("Save") { vm.save(in: context) }
            }
        }
        .navigationTitle("Body")
        .onAppear { vm.load(in: context) }
    }
}

// MARK: - About

public struct AboutView: View {
    public init() {}

    public var body: some View {
        List {
            Section("Loomies") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")
                LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")
                Text("Daily outfit copilot — you steer, the app assists.")
                    .font(.caption).foregroundStyle(DS.muted)
            }
            Section("Credits") {
                Text("Design tokens inspired by warm neutrals + single accent (DESIGN §10).")
                Text("FFIT body-shape classification (research literature).")
                Text("Weather attribution: WeatherKit when enabled.")
            }
            Section("Privacy") {
                Text("Body measurements stay on-device (not CloudKit). Images never leave for analytics. Telemetry is opt-in anonymous aggregate when enabled.")
                    .font(.caption)
            }
        }
        .navigationTitle("About")
    }
}

// MARK: - Favorites list

public struct FavoritesView: View {
    let wardrobe: Wardrobe
    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    private var outfits: [ClosetModel.Outfit] { OutfitFavoriteService.favorites(in: wardrobe) }

    public var body: some View {
        Group {
            if outfits.isEmpty {
                ContentUnavailableView("No favorites", systemImage: "heart",
                    description: Text("Save a look from Today."))
            } else {
                List(outfits, id: \.id) { o in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(o.name).font(.headline)
                        Text("\((o.items ?? []).count) pieces · \(o.occasionRaw ?? "—")")
                            .font(.caption).foregroundStyle(DS.muted)
                        if o.missing {
                            Text("Missing pieces").font(.caption2).foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
        .navigationTitle("Favorites")
    }
}
