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
    @State private var confirmDelete = false
    var bodyProfile: PersonBodyProfile?

    public init(item: Item, bodyProfile: PersonBodyProfile? = nil) {
        _vm = State(initialValue: ItemDetailViewModel(item: item))
        self.bodyProfile = bodyProfile
    }

    public var body: some View {
        Form {
            Section {
                ItemThumbnailView(item: vm.item, height: 200)
                    .listRowInsets(EdgeInsets())
            }
            Section("Details") {
                TextField("Name", text: $vm.name)
                Picker("Type", selection: $vm.slotRaw) {
                    ForEach(["top", "bottom", "dress", "outerwear", "shoes", "accessory"], id: \.self) {
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
            Section {
                Button("Delete piece", role: .destructive) {
                    confirmDelete = true
                }
                Text("Looks that used this piece keep wear history but mark missing.")
                    .font(.caption2)
                    .foregroundStyle(DS.muted)
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
        .confirmationDialog(
            "Delete this piece?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                vm.delete(in: context)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone. Favorite looks keep a missing-piece flag.")
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

// MARK: - Body profile (dual-track: quick pick + measures)

public struct BodyProfileView: View {
    @Environment(\.modelContext) private var context
    @State private var vm: BodyProfileViewModel

    public init(personID: UUID) {
        _vm = State(initialValue: BodyProfileViewModel(personID: personID))
    }

    public var body: some View {
        Form {
            Section {
                BodyAvatarView(
                    shape: vm.popularShape,
                    morph: vm.morph,
                    fitCaption: previewCaption)
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                .listRowBackground(Color.clear)
            } header: {
                Text("Body reference")
            } footer: {
                Text("360° + continuous morph (chest/waist/hip). Pasties + thong base for lingerie layering.")
                    .font(.caption2)
            }

            Section {
                LabeledContent("Fit confidence", value: vm.confidence.userLabel)
                LabeledContent("Measures", value: "\(vm.measureProgress)/4")
                LabeledContent("Morph", value: morphSummary)
            }

            Section {
                Text("Which looks most like you?")
                    .font(.subheadline.weight(.medium))
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(BodyProfileViewModel.allPopular, id: \.rawValue) { shape in
                        shapePickCard(shape)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            } header: {
                Text("Quick pick (preset)")
            } footer: {
                Text("Sets a base shape; fine-tune with sliders or measures below.")
                    .font(.caption2)
            }

            Section {
                morphSlider("Chest", value: $vm.fineChest)
                morphSlider("Waist", value: $vm.fineWaist)
                morphSlider("Hip", value: $vm.fineHip)
                morphSlider("Height", value: $vm.fineHeight)
                Button("Reset fine-tune") { vm.resetFineTune(in: context) }
                    .font(.caption)
            } header: {
                Text("Continuous fine-tune")
            } footer: {
                Text("Stepless multipliers on top of measures/preset (0.90–1.10). Live preview.")
                    .font(.caption2)
            }
            .onChange(of: vm.fineChest) { _, _ in vm.refreshPreview(); vm.saveFineTune(in: context) }
            .onChange(of: vm.fineWaist) { _, _ in vm.refreshPreview(); vm.saveFineTune(in: context) }
            .onChange(of: vm.fineHip) { _, _ in vm.refreshPreview(); vm.saveFineTune(in: context) }
            .onChange(of: vm.fineHeight) { _, _ in vm.refreshPreview(); vm.saveFineTune(in: context) }

            Section {
                Toggle("Use centimeters", isOn: $vm.usesMetric)
            }

            Section {
                measureRow(title: "Bust", value: vm.bustInches) {
                    vm.stepBust($0); vm.refreshPreview()
                }
                measureRow(title: "Waist", value: vm.waistInches) {
                    vm.stepWaist($0); vm.refreshPreview()
                }
                measureRow(title: "Hip", value: vm.hipInches) {
                    vm.stepHip($0); vm.refreshPreview()
                }
                measureRow(title: "High hip", value: vm.highHipInches, inferred: vm.highHipInferred) {
                    vm.stepHighHip($0); vm.refreshPreview()
                }
                if vm.highHipInferred {
                    Text("High hip is estimated")
                        .font(.caption2).foregroundStyle(.orange)
                }
                Button("Estimate high hip from waist & hip") {
                    vm.applyInferredHighHip()
                }
                .disabled(vm.waistInches == nil || vm.hipInches == nil)
            } header: {
                Text("Measurements (\(vm.unitLabel))")
            } footer: {
                Button(vm.showMeasureTips ? "Hide measuring tips" : "How to measure") {
                    vm.showMeasureTips.toggle()
                }
                .font(.caption)
            }

            if vm.showMeasureTips {
                Section("Measuring tips") {
                    Text("Stand relaxed, soft tape snug (not tight).")
                    Text("Bust: fullest point. Waist: natural waist. Hip: fullest seat.")
                    Text("High hip: ~3–4 in (7–10 cm) below the waist, at the hip bones.")
                        .font(.caption)
                        .foregroundStyle(DS.muted)
                }
            }

            Section("Shape analysis") {
                if let shape = vm.shapeLabel {
                    LabeledContent("FFIT", value: shape)
                } else if vm.selectedPopular != nil {
                    Text("Visual type set. Enter four measures for FFIT classification.")
                        .font(.caption).foregroundStyle(DS.muted)
                } else {
                    Text("Pick a look-alike or enter measures to unlock body-shape weighting.")
                        .font(.caption).foregroundStyle(DS.muted)
                }
            }

            if !vm.message.isEmpty {
                Section { Text(vm.message).foregroundStyle(DS.accent) }
            }

            Section {
                Button("Save measurements") { vm.save(in: context) }
            }
        }
        .navigationTitle("Body")
        .onAppear { vm.load(in: context) }
    }

    private var previewCaption: String {
        if vm.confidence == .none && vm.selectedPopular == nil {
            return "Pick a body type or enter measures."
        }
        return "\(vm.displayTitle(vm.popularShape)) · \(vm.confidence.userLabel)"
    }

    private var morphSummary: String {
        let m = vm.morph
        return String(format: "C%.2f W%.2f H%.2f", m.chest, m.waist, m.hip)
    }

    private func morphSlider(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.2f×", value.wrappedValue))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DS.muted)
            }
            Slider(value: value, in: 0.90...1.10, step: 0.01)
                .tint(DS.accent)
        }
    }

    @ViewBuilder
    private func shapePickCard(_ shape: PopularShape) -> some View {
        let selected = vm.selectedPopular == shape
        Button {
            vm.selectPopularShape(shape, in: context)
        } label: {
            VStack(spacing: 6) {
                Group {
                    if let img = BodyAvatarView.bundleImage(
                        named: BodyAvatarAsset.croquisName(for: shape, yaw: .deg0))
                        ?? BodyAvatarView.bundleImage(named: BodyAvatarAsset.legacyFrontName(for: shape)) {
                        img.resizable().aspectRatio(contentMode: .fit)
                    } else {
                        PlaceholderCroquis(shape: shape)
                    }
                }
                .frame(height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(vm.displayTitle(shape))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DS.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .padding(6)
            .background(DS.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.radius))
            .overlay(
                RoundedRectangle(cornerRadius: DS.radius)
                    .stroke(selected ? DS.accent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(vm.displayTitle(shape))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func measureRow(
        title: String,
        value: Double?,
        inferred: Bool = false,
        step: @escaping (Double) -> Void
    ) -> some View {
        HStack {
            Text(title)
            if inferred {
                Text("est.").font(.caption2).foregroundStyle(.orange)
            }
            Spacer()
            Button { step(vm.usesMetric ? -1 : -0.5) } label: {
                Image(systemName: "minus.circle.fill").foregroundStyle(DS.accent)
            }
            .buttonStyle(.plain)
            Text(vm.displayValue(inches: value))
                .font(.body.monospacedDigit().weight(.medium))
                .frame(minWidth: 48)
            Button { step(vm.usesMetric ? 1 : 0.5) } label: {
                Image(systemName: "plus.circle.fill").foregroundStyle(DS.accent)
            }
            .buttonStyle(.plain)
            Text(vm.unitLabel)
                .font(.caption)
                .foregroundStyle(DS.muted)
                .frame(width: 24, alignment: .leading)
        }
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
    @Environment(\.modelContext) private var context
    let wardrobe: Wardrobe
    @State private var outfits: [ClosetModel.Outfit] = []

    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    public var body: some View {
        Group {
            if outfits.isEmpty {
                ContentUnavailableView("No favorites", systemImage: "heart",
                    description: Text("Save a look from Today. Swipe a saved look to remove it."))
            } else {
                List {
                    ForEach(outfits, id: \.id) { o in
                        favoriteRow(o)
                    }
                    .onDelete(perform: unfavorite)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Favorites")
        .onAppear { reload() }
    }

    private func favoriteRow(_ o: ClosetModel.Outfit) -> some View {
        HStack(spacing: 12) {
            // 与 Today 同源体型/morph，避免收藏列表永远 rectangle
            BodyAvatarView(
                shape: ownerShape,
                morph: ownerMorph,
                layers: OutfitAvatarComposer.layers(from: o.items ?? []),
                showsFitCaption: false,
                enablesOrbit: false,
                backdrop: .resolved(from: o.occasionRaw),
                depthIntensity: .off)
            .frame(width: 72, height: 108)
            .allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 4) {
                Text(o.name.isEmpty ? "Favorite look" : o.name).font(.headline)
                Text("\((o.items ?? []).count) pieces · \(o.occasionRaw ?? "—")")
                    .font(.caption).foregroundStyle(DS.muted)
                if o.missing || o.permanentlyMissing {
                    Text("Missing pieces").font(.caption2).foregroundStyle(.orange)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Swipe to remove from favorites")
    }

    private func reload() {
        outfits = OutfitFavoriteService.favorites(in: wardrobe)
    }

    private func unfavorite(at offsets: IndexSet) {
        for i in offsets {
            OutfitFavoriteService.setFavorite(outfits[i], false, in: context)
        }
        reload()
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
}
