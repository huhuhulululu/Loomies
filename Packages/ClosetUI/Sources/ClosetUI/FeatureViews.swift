import SwiftUI
import SwiftData
import ClosetModel
import ClosetCore
import ClosetIntake

// MARK: - Item detail

public struct ItemDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var vm: ItemDetailViewModel
    @State private var transferVM: TransferViewModel?
    @State private var confirmDelete = false
    @State private var showReplacePhoto = false
    var bodyProfile: PersonBodyProfile?

    public init(item: Item, bodyProfile: PersonBodyProfile? = nil) {
        _vm = State(initialValue: ItemDetailViewModel(item: item))
        self.bodyProfile = bodyProfile
    }

    /// 拆成子视图：整个 Form 放在一个表达式里会让类型检查超时（本波实测）。
    @ViewBuilder
    private var detailsSection: some View {
        Section("Details") {
            TextField("Name", text: $vm.name)
                .wordsCapitalized()
            Picker("Type", selection: $vm.slotRaw) {
                ForEach(GarmentSlot.allCases, id: \.rawValue) { slot in
                    Text(slot.displayTitle).tag(slot.rawValue)
                }
            }
            TextField("Brand", text: $vm.brand)
                .wordsCapitalized()
                .autocorrectionDisabled()
            TextField("Size", text: $vm.sizeLabel)
                .charactersCapitalized()   // M / XL / 8
                .autocorrectionDisabled()
            if let sizeHint = PublicSizeReference.displayHint(forLabel: vm.sizeLabel),
               !vm.sizeLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(sizeHint)
                    .font(.caption2)
                    .foregroundStyle(DS.muted)
            }
            // D108：场合是**硬过滤**输入，引擎只认固定几个值。
            // 此前是逗号分隔自由文本——打错一个字母这件衣服就永远不再被推荐，
            // 而用户看不到任何异样。
            OccasionChips(selection: $vm.occasions, custom: vm.customOccasions)
        }
    }

    /// D185：补/换图。入库失败的三条提示一直叫用户「re-add the photo later」，
    /// 而这条路以前根本不存在（唯一的 re-add 是删掉重来，那是有损的）。
    @ViewBuilder
    private var photoSection: some View {
        Section {
            ItemThumbnailView(item: vm.item, height: 200)
                .listRowInsets(EdgeInsets())
            Button {
                showReplacePhoto = true
            } label: {
                Label(photoEntryTitle, systemImage: "photo.badge.plus")
            }
        }
    }

    private var photoEntryTitle: String {
        ItemPhotoService.entryTitle(hasPhoto: vm.item.localImageRelativePath != nil)
    }

    @ViewBuilder
    private var fitMeasuresSection: some View {
        // D180：鞋与配饰出不了合身结论，就别摆一组填了也没用的输入框。
        if vm.showsFitMeasures {
            Section("Fit measures (flat)") {
                // D108：单位可切（此前写死英寸），数值走小数键盘（此前默认字母键盘），
                // 解析失败当场提示（此前静默丢弃，保存后字段变空）
                Picker("Unit", selection: $vm.measureUnit) {
                    ForEach(MeasurementEntry.Unit.allCases, id: \.rawValue) { unit in
                        Text(unit.suffix).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                TextField(MeasurementEntry.placeholder("Chest flat width", unit: vm.measureUnit),
                          text: $vm.chestFlat)
                    .decimalKeyboard()
                TextField(MeasurementEntry.placeholder("Waist flat width", unit: vm.measureUnit),
                          text: $vm.waistFlat)
                    .decimalKeyboard()
                TextField(MeasurementEntry.placeholder("Hip flat width", unit: vm.measureUnit),
                          text: $vm.hipFlat)
                    .decimalKeyboard()
                if let warning = vm.measurementInputWarning {
                    Text(warning).font(.caption2).foregroundStyle(.orange)
                        .accessibilityLabel(warning)
                }
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
        }
    }

    public var body: some View {
        Form {
            photoSection
            detailsSection
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
                        // 位置成树之后同柜可合法存在两个 "Attic"（不同父下）——
                        // 裸 name 会让用户看到两行一模一样的文字，选不清是哪个。
                        ForEach(vm.storageLocationNodes, id: \.location.id) { node in
                            Text(StorageRowCopy.indentedTitle(
                                node.location.name, depth: node.depth))
                                .tag(Optional(node.location.id))
                        }
                    }
                    .accessibilityLabel("Storage location")
                }
            }
            // D83 属性录入：推荐引擎的三条输入链（天气门 / 配色 / 体型加权）
            Section("Warmth") {
                WarmthPicker(warmthRaw: $vm.warmthRaw)
            }
            Section("Color") {
                ColorSwatchPicker(paletteID: $vm.colorPaletteID)
            }
            Section("Cut details") {
                StyleAttributePicker(attributes: $vm.attributes)
            }
            Section("Care") {
                CareSymbolPicker(selection: $vm.care)
                if let warning = vm.careConflictWarning {
                    Text(warning).font(.caption2).foregroundStyle(.orange)
                        .accessibilityLabel(warning)
                }
            }
            Section("Notes") {
                TextField(ItemNotes.entryHint, text: $vm.notes, axis: .vertical)
                    .lineLimit(1...4)
                Text("\(ItemNotes.remaining(vm.notes)) left")
                    .font(.caption2).foregroundStyle(DS.muted)
            }
            // D119：记了就要给用户看。此前每次打卡都落了 WearRecord，
            // 而这一页从来没回答过「这件我穿过几次 / 上次什么时候穿的」。
            Section("Wear") {
                Text(vm.wearSummary).font(DS.Text.body).foregroundStyle(DS.ink)
                    .accessibilityLabel(vm.wearSummary)
            }
            // 「距上次洗涤已穿几次」（D106，DESIGN §219 点名的零成本差异点）——
            // 只做显性化，不给洗衣建议（面料/体感/季节 App 都不知道）
            if let laundry = vm.laundryCaption {
                Section("Laundry") {
                    Text(laundry).font(DS.Text.body).foregroundStyle(DS.ink)
                        .accessibilityLabel(laundry)
                }
            }
            // 转移历史（D94）：东西从哪来的，此前完全没有痕迹
            if !vm.transferHistory.isEmpty {
                Section("Move history") {
                    ForEach(vm.transferHistory, id: \.id) { record in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(TransferHistory.line(record, resolving: vm.closetNames))
                                .font(.caption)
                            Text(record.date, style: .date)
                                .font(.caption2).foregroundStyle(DS.muted)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            fitMeasuresSection
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
        .onAppear {
            vm.refreshFit(profile: bodyProfile)
            vm.loadHistory(in: context)
        }
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
        .sheet(isPresented: $showReplacePhoto) {
            ReplacePhotoSheet(item: vm.item) { outcome in
                vm.reportPhotoOutcome(outcome)
            }
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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var vm: BodyProfileViewModel

    /// 身体维度单独同意（DESIGN §2.2）：未同意时**只出说明卡**，录入面整段不渲染。
    /// 此前这里只是在顶部多加一张卡，其后的四围输入 / Save / 精调滑杆全部照常可用
    /// 且点一下就落库——门画了但没关上（真相由 `vm.hasBodyDataConsent` 提供）。
    @State private var consentGranted = BodyDataConsent.shared.isGranted

    public init(personID: UUID) {
        _vm = State(initialValue: BodyProfileViewModel(personID: personID))
    }

    public var body: some View {
        Form {
            if !consentGranted {
                consentCard
            } else {
                entryBody
            }
        }
        .navigationTitle("Body")
        .onAppear {
            consentGranted = vm.hasBodyDataConsent
            if consentGranted { vm.load(in: context) }
        }
    }

    /// 未同意时的唯一内容：说明 + 授权 / 暂不。
    private var consentCard: some View {
        Section {
            Text(BodyDataConsent.explainer)
                .font(.callout)
            Button(BodyDataConsent.grantTitle) {
                vm.grantBodyDataConsent()
                consentGranted = true
                vm.load(in: context)
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.accent)
            Button(BodyDataConsent.declineTitle) { dismiss() }
                .foregroundStyle(DS.muted)
        } header: {
            Text(BodyDataConsent.title)
        }
    }

    @ViewBuilder
    private var entryBody: some View {
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
                    columns: AccessibilityGridColumns.items(
                        for: dynamicTypeSize, regularMinimum: 72, spacing: 8),
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
                    columns: AccessibilityGridColumns.items(
                        for: dynamicTypeSize, regularCount: 3, spacing: 12),
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
                    .font(DS.Text.body)
                    .font(.caption).foregroundStyle(DS.muted)
            }
            Section("Open source & data") {
                // 逐项署名（§4.3 许可红线）；名称排序确定，来源单一真相在 ClosetCore
                ForEach(ComplianceCopy.attributions) { credit in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(credit.name).font(.subheadline.weight(.semibold))
                        Text(credit.license).font(.caption2).foregroundStyle(DS.muted)
                        Text(credit.usage).font(.caption2).foregroundStyle(DS.muted)
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                }
            }
            Section("Privacy") {
                // 只说做得到的：旧文案承诺的「telemetry opt-in when enabled」当时并不存在
                Text(ComplianceCopy.privacySummary)
                    .font(.caption)
                NavigationLink("Help & FAQ") { HelpView() }
            }
            Section("Policies") {
                // 应用内全文（外链到未上线域名 = 死链，违反 UI 诚实铁律）
                ForEach(ComplianceCopy.policyDocuments(hasSink: TelemetryGate.shared.hasSink)) { doc in
                    NavigationLink(doc.title) { PolicyDocumentView(document: doc) }
                }
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
    /// 身体档案走 @Query（活查询）：切柜/改体型即刷新，且行构建器里是纯内存查找。
    @Query private var bodyProfiles: [PersonBodyProfile]

    @Environment(\.modelContext) private var context
    let wardrobe: Wardrobe
    @State private var outfits: [ClosetModel.Outfit] = []
    @State private var actions = OutfitActionsViewModel()
    /// D183：代际 + 定时清收在 `FlashState` 一处（原来三个视图各写一份，时长还不同）。
    @State private var flashState = FlashState()

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
            // 同 D110：切柜时结构身份不变，onAppear 不重触发——收藏页会留着上一个柜的搭配，
            // 而行上的删除/排期会真的作用到那个柜。
            .onChange(of: wardrobe.id) { _, _ in reload() }
        .overlay(alignment: .bottom) {
            if let flashMessage = flashState.message {
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
                Text(Self.lookDisplayTitle(o)).font(DS.Text.rowTitle)
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

    private func flash(_ message: String) { flashState.show(message) }

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

    /// D112：这里原本是**计算属性里发全表 fetch**——而它在行构建器里被读 4-5 次
    /// （shape / morph / sex / phenotype 各一次），于是每滚进一行就是一把主线程 SQLite 往返。
    /// 同模块的 `ClosetGridView` 早就是 `@Query` + 内存 `first {}`（实测约快两个数量级），
    /// 这里收编成同一种写法，不另造。
    private var ownerProfile: PersonBodyProfile? {
        guard let pid = wardrobe.owner?.id else { return nil }
        return bodyProfiles.first { $0.personID == pid }
    }

    /// D175：推导收进 `OwnerBodyDerivation`（四个视图此前各写一份、零测试）。
    private var ownerShape: PopularShape { OwnerBodyDerivation.shape(from: ownerProfile) }

    private var ownerMorph: BodyMorphParams { OwnerBodyDerivation.morph(from: ownerProfile) }
}

/// 批量转移文案与面（D94，缺口 #12）。整柜搬家时逐件点 Move 是折磨。
public enum BatchMoveCopy {
    public static let enterSelectionLabel = "Select pieces to move"
    public static let exitSelectionLabel = "Done selecting"
    public static func moveTitle(count: Int) -> String {
        count == 0 ? "Move…" : "Move \(count) \(count == 1 ? "piece" : "pieces")…"
    }
    /// 与单件 Move 同一句（不得两处各写各的）。`@MainActor` 源常量在 nonisolated
    /// 上下文不能当默认值，故用计算属性取。
    @MainActor
    public static var noDestinationMessage: String { TransferViewModel.noOtherWardrobesMessage }
}

/// 批量移动目的地选择。逐件走同一条 `TransferService.transfer`（历史与缺件重算跟着走）。
public struct BatchMoveSheet: View {
    let wardrobe: Wardrobe
    let items: [Item]
    let onDone: (String) -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allWardrobes: [Wardrobe]
    @State private var destinationID: UUID?
    @State private var message = ""

    public init(wardrobe: Wardrobe, items: [Item], onDone: @escaping (String) -> Void) {
        self.wardrobe = wardrobe
        self.items = items
        self.onDone = onDone
    }

    private var destinations: [Wardrobe] {
        WardrobeSwitcher.ordered(allWardrobes.filter { $0.id != wardrobe.id })
    }

    public var body: some View {
        NavigationStack {
            Form {
                if destinations.isEmpty {
                    Text(BatchMoveCopy.noDestinationMessage)
                        .accessibilityLabel(BatchMoveCopy.noDestinationMessage)
                } else {
                    Picker("Move to", selection: $destinationID) {
                        Text("Choose…").tag(Optional<UUID>.none)
                        ForEach(destinations, id: \.id) { w in
                            Text(WardrobeSwitcher.menuTitle(w, among: destinations))
                                .tag(Optional(w.id))
                        }
                    }
                    Section {
                        Text("\(items.count) selected")
                            .font(.caption).foregroundStyle(DS.muted)
                    }
                }
                if !message.isEmpty {
                    Text(message).font(.caption).foregroundStyle(.orange)
                        .accessibilityLabel(message)
                }
            }
            .navigationTitle(BatchMoveCopy.moveTitle(count: items.count))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Move") {
                        guard let id = destinationID,
                              let dest = destinations.first(where: { $0.id == id }) else { return }
                        let outcome = TransferService.transferAll(items, to: dest, in: context)
                        // 有失败就留在表单说清楚，不静默关闭当成功
                        guard outcome.failed == 0 else {
                            message = outcome.summary
                            return
                        }
                        onDone(outcome.summary)
                        dismiss()
                    }
                    .disabled(destinationID == nil || items.isEmpty)
                }
            }
        }
    }
}
