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
                    ForEach(GarmentSlot.allCases, id: \.rawValue) { slot in
                        Text(slot.displayTitle).tag(slot.rawValue)
                    }
                }
                TextField("Brand", text: $vm.brand)
                TextField("Size", text: $vm.sizeLabel)
                if let sizeHint = PublicSizeReference.displayHint(forLabel: vm.sizeLabel),
                   !vm.sizeLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(sizeHint)
                        .font(.caption2)
                        .foregroundStyle(DS.muted)
                }
                TextField("Occasions (comma)", text: $vm.occasionsText)
            }
            Section("Status") {
                Picker("Status", selection: $vm.statusRaw) {
                    ForEach(vm.statuses, id: \.self) {
                        Text(ItemStatusService.displayName($0)).tag($0)
                    }
                }
            }
            Section("Storage") {
                if vm.storageLocations.isEmpty {
                    Text(ItemDetailViewModel.noStorageLocationsCaption)
                        .font(.caption)
                        .foregroundStyle(DS.muted)
                        .accessibilityLabel(ItemDetailViewModel.noStorageLocationsCaption)
                } else {
                    Picker("Location", selection: $vm.locationID) {
                        Text("None").tag(Optional<UUID>.none)
                        ForEach(vm.storageLocations, id: \.id) { loc in
                            Text(loc.name).tag(Optional(loc.id))
                        }
                    }
                    .accessibilityLabel("Storage location")
                }
            }
            Section("Fit measures (inches, flat)") {
                TextField("Chest flat width", text: $vm.chestFlat)
                TextField("Waist flat width", text: $vm.waistFlat)
                if let fit = vm.fitLabel {
                    LabeledContent("Fit mark", value: fit)
                    if let detail = vm.fitDetail {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(DS.muted)
                    }
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
                Section {
                    Text(msg)
                        .foregroundStyle(
                            msg.localizedCaseInsensitiveContains("couldn't")
                                ? Color.orange : DS.accent)
                        .accessibilityLabel(msg)
                }
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
                // 空白名第一道 gate（QuickAdd/Closet name 同规则）；服务层 blank-name 拒绝兜底。
                .disabled(TextNormalize.isBlank(vm.name))
            }
        }
        .confirmationDialog(
            "Delete this piece?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                vm.delete(in: context)
                // Only leave the screen when save committed (honest failure stays on form).
                if vm.didDelete { dismiss() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone. Favorite looks keep a missing-piece flag.")
        }
        .onAppear { vm.refreshFit(profile: bodyProfile) }
        // Live FitMark as the customer types flat widths / changes type (before Save).
        .onChange(of: vm.chestFlat) { _, _ in vm.refreshFit(profile: bodyProfile) }
        .onChange(of: vm.waistFlat) { _, _ in vm.refreshFit(profile: bodyProfile) }
        .onChange(of: vm.slotRaw) { _, _ in vm.refreshFit(profile: bodyProfile) }
        .onChange(of: vm.name) { _, _ in vm.refreshFit(profile: bodyProfile) }
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
                    Text(TransferViewModel.noOtherWardrobesMessage)
                        .accessibilityLabel(TransferViewModel.noOtherWardrobesMessage)
                } else {
                    Picker("Move to", selection: $vm.selectedDestinationID) {
                        ForEach(vm.destinations, id: \.id) { w in
                            Text(w.name).tag(Optional(w.id))
                        }
                    }
                }
                if !vm.message.isEmpty {
                    Text(vm.message)
                        .foregroundStyle(vm.didTransfer ? DS.accent : Color.orange)
                        .accessibilityLabel(vm.message)
                }
            }
            .navigationTitle("Transfer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Move") {
                        // Stay open on fail so "Pick a wardrobe" is visible (no silent dismiss).
                        if vm.transfer(in: context) { dismiss() }
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
                    fitCaption: previewCaption,
                    bodySex: vm.bodySex,
                    bodyPhenotype: vm.bodyPhenotype,
                    usesMannequin3D: false)
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                .listRowBackground(Color.clear)
                if !NudeBodyBaseSpec.isHardRequirementMet {
                    Label {
                        Text(NudeBodyBaseSpec.certificationGaps.first
                            ?? "Need certified real-human photos (♀ pasties+thong / ♂ thong).")
                            .font(.caption2)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    .listRowBackground(Color.orange.opacity(0.08))
                } else {
                    Label {
                        Text("Catalog basewear: \(NudeBodyBaseSpec.basewearDescription(for: vm.bodySex))")
                            .font(.caption2)
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .listRowBackground(Color.green.opacity(0.06))
                }
            } header: {
                Text("Your body reference")
            } footer: {
                Text("Catalog model + your proportions. Drag to turn · clothes layer on top. Measurements stay on device.")
                    .font(.caption2)
            }

            Section {
                Picker("Sex", selection: Binding(
                    get: { vm.bodySex },
                    set: { vm.selectBodySex($0, in: context) }
                )) {
                    ForEach(AvatarBodySex.allCases, id: \.rawValue) { sex in
                        Text(sex.displayTitle).tag(sex)
                    }
                }
                .pickerStyle(.segmented)
                // 肤色圆点：表型 catalog 模特即时预览
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 72), spacing: 8)],
                    spacing: 10
                ) {
                    ForEach(AvatarBodyPhenotype.allCases, id: \.rawValue) { p in
                        Button {
                            vm.selectBodyPhenotype(p, in: context)
                        } label: {
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(Self.phenotypeSwatch(p))
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle().strokeBorder(
                                            vm.bodyPhenotype == p ? DS.accent : Color.primary.opacity(0.12),
                                            lineWidth: vm.bodyPhenotype == p ? 2.5 : 1))
                                Text(p.displayTitle)
                                    .font(.caption2)
                                    .foregroundStyle(vm.bodyPhenotype == p ? DS.ink : DS.muted)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(p.displayTitle) phenotype")
                        .accessibilityAddTraits(vm.bodyPhenotype == p ? .isSelected : [])
                    }
                }
            } header: {
                Text("Model look · sex & skin tone")
            } footer: {
                Text("Presentation only — not a medical category. Clothes layer on the model; this is not a selfie try-on.")
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
                Section {
                    Text(vm.message)
                        .foregroundStyle(
                            vm.message.localizedCaseInsensitiveContains("couldn't")
                                ? Color.orange : DS.accent)
                        .accessibilityLabel(vm.message)
                }
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

    /// 表型肤色 swatch（与程序化 3D `skinRGB` 同源，Me 选人种即时对照）。
    private static func phenotypeSwatch(_ p: AvatarBodyPhenotype) -> Color {
        let s = p.skinRGB
        return Color(red: s.r, green: s.g, blue: s.b)
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
            // Visual chrome only — VoiceOver uses the Slider’s label/value/hint.
            .accessibilityHidden(true)
            Slider(value: value, in: 0.90...1.10, step: 0.01)
                .tint(DS.accent)
                .accessibilityLabel(Self.morphSliderAccessibilityLabel(title: title))
                .accessibilityValue(Self.morphSliderAccessibilityValue(value.wrappedValue))
                .accessibilityHint(Self.morphSliderAccessibilityHint)
        }
    }

    /// Fine-tune slider VoiceOver — names the axis (not bare “slider”).
    static func morphSliderAccessibilityLabel(title: String) -> String {
        "\(title) fine-tune"
    }

    /// Multiplier spoken as “times” so VO doesn’t skip the × glyph.
    static func morphSliderAccessibilityValue(_ multiplier: Double) -> String {
        String(format: "%.2f times", multiplier)
    }

    static let morphSliderAccessibilityHint =
        "Multiplier from 0.90 to 1.10 on top of measures or preset"

    @ViewBuilder
    private func shapePickCard(_ shape: PopularShape) -> some View {
        let selected = vm.selectedPopular == shape
        Button {
            vm.selectPopularShape(shape, in: context)
        } label: {
            VStack(spacing: 6) {
                // 全 nude 多人种栅格（不用 pastie/thong croquis）
                FullNudeBodyImageView(
                    sex: vm.bodySex,
                    phenotype: vm.bodyPhenotype,
                    morph: BodyMorphParams.resolve(
                        measurements: nil, shape: shape, fineTune: .neutral),
                    shape: shape,
                    yaw: .deg0,
                    logicalWidth: 72)
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
                    // A11Y: grow tap target to 44pt without changing the icon visual.
                    .frame(width: Self.measureStepperHitArea, height: Self.measureStepperHitArea)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Self.measureStepAccessibilityLabel(title: title, direction: .decrease))
            Text(vm.displayValue(inches: value))
                .font(.body.monospacedDigit().weight(.medium))
                .frame(minWidth: 48)
                .accessibilityLabel("\(title) \(vm.displayValue(inches: value)) \(vm.unitLabel)")
            Button { step(vm.usesMetric ? 1 : 0.5) } label: {
                Image(systemName: "plus.circle.fill").foregroundStyle(DS.accent)
                    // A11Y: grow tap target to 44pt without changing the icon visual.
                    .frame(width: Self.measureStepperHitArea, height: Self.measureStepperHitArea)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Self.measureStepAccessibilityLabel(title: title, direction: .increase))
            Text(vm.unitLabel)
                .font(.caption)
                .foregroundStyle(DS.muted)
                .frame(width: 24, alignment: .leading)
                .accessibilityHidden(true)
        }
    }

    /// Icon-only measure steppers — VoiceOver names the field (not bare “minus/plus”).
    enum MeasureStepDirection: Sendable {
        case decrease, increase
    }

    /// A11Y: measure steppers keep the small icon visual but the tap target
    /// meets the 44pt HIG minimum. `nonisolated` so tests can pin without
    /// MainActor hops.
    nonisolated static let measureStepperHitArea: CGFloat = 44

    static func measureStepAccessibilityLabel(
        title: String, direction: MeasureStepDirection
    ) -> String {
        switch direction {
        case .decrease: return "Decrease \(title)"
        case .increase: return "Increase \(title)"
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
                Text("Weather: Open-Meteo (open data) when online; offline city climate fallback. Optional WeatherKit later.")
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

/// Empty Favorites list — points to Today Save; no fake “sync” / try-on claims.
public enum FavoritesEmptyCopy {
    public static let title = "No favorites"
    public static let description =
        "Save a look from Today. Swipe to plan a day or remove it."
    /// Row swipe VO (parity Calendar plan rows).
    public static let rowSwipeAccessibilityHint =
        "Swipe right to plan today, swipe left to remove"
}

public struct FavoritesView: View {
    @Environment(\.modelContext) private var context
    let wardrobe: Wardrobe
    @State private var outfits: [ClosetModel.Outfit] = []
    @State private var actions = OutfitActionsViewModel()
    @State private var flashMessage: String?

    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    public var body: some View {
        Group {
            if outfits.isEmpty {
                ContentUnavailableView {
                    Label(FavoritesEmptyCopy.title, systemImage: "heart")
                } description: {
                    Text(FavoritesEmptyCopy.description)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "\(FavoritesEmptyCopy.title). \(FavoritesEmptyCopy.description)")
            } else {
                List {
                    ForEach(outfits, id: \.id) { o in
                        favoriteRow(o)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    planToday(o)
                                } label: {
                                    Label("Plan today", systemImage: "calendar.badge.plus")
                                }
                                .tint(DS.accent)
                            }
                    }
                    .onDelete(perform: unfavorite)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Favorites")
        .onAppear { reload() }
        .overlay(alignment: .bottom) {
            if let flashMessage {
                CustomerFlashStyle.overlayChip(flashMessage)
                    .padding()
                    .transition(.opacity)
            }
        }
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
                depthIntensity: .off,
                bodySex: BodyProfileService.presentationSex(from: ownerProfile),
                bodyPhenotype: BodyProfileService.presentationPhenotype(from: ownerProfile),
                usesMannequin3D: false)
            .frame(width: 72, height: 108)
            .allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 4) {
                Text(Self.lookDisplayTitle(o)).font(.headline)
                Text(Self.lookMetaLine(o))
                    .font(.caption).foregroundStyle(DS.muted)
                if o.missing || o.permanentlyMissing {
                    Text("Missing pieces").font(.caption2).foregroundStyle(.orange)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(FavoritesEmptyCopy.rowSwipeAccessibilityHint)
        .contextMenu {
            Button {
                planToday(o)
            } label: {
                Label("Plan for today", systemImage: "calendar.badge.plus")
            }
        }
    }

    private func planToday(_ outfit: ClosetModel.Outfit) {
        // Parity Calendar plan picker: titled flash + attention when pieces missing.
        _ = actions.planFavorite(
            outfit, in: context,
            lookTitle: Self.lookDisplayTitle(outfit))
        flash(actions.message)
    }

    /// Favorites row title for flash / VO (empty storage → “Favorite look”).
    public static func lookDisplayTitle(_ outfit: ClosetModel.Outfit) -> String {
        let t = outfit.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Favorite look" : t
    }

    /// Secondary line: piece count · human occasion (capitalized; not raw `work`).
    /// `emptyOccasion` is “—” on Favorites list, “Any” on Calendar plan picker.
    public static func lookMetaLine(
        _ outfit: ClosetModel.Outfit,
        emptyOccasion: String = "—"
    ) -> String {
        let count = (outfit.items ?? []).count
        let raw = outfit.occasionRaw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let occ = raw.isEmpty ? emptyOccasion : raw.capitalized
        return "\(count) pieces · \(occ)"
    }

    private func flash(_ message: String) {
        flashMessage = message
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if flashMessage == message { flashMessage = nil }
        }
    }

    private func reload() {
        outfits = OutfitFavoriteService.favorites(in: wardrobe)
    }

    private func unfavorite(at offsets: IndexSet) {
        var saveFailed = false
        for i in offsets {
            if !OutfitFavoriteService.setFavorite(outfits[i], false, in: context) {
                saveFailed = true
            }
        }
        reload()
        // After reload, failed rows reappear; flash so swipe is not silent success.
        if saveFailed {
            flash(OutfitFavoriteService.toggleSaveFailedMessage)
        }
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
