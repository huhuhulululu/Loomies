import SwiftUI
import SwiftData
import ClosetModel
import ClosetCore

/// Today 首屏 = **Avatar + 今日 look**（方案 B）+ copilot 交互。
/// 大人体是表达层；机制仍是锚定 → 补全（D19），非 VTON。
public struct CopilotView: View {
    @Environment(\.modelContext) private var context
    @State private var vm: CopilotViewModel
    @State private var checkInNote: String?
    @State private var actions = OutfitActionsViewModel()
    private var debug: DebugSettings { DebugSettings.shared }

    public init(wardrobe: Wardrobe) {
        _vm = State(initialValue: CopilotViewModel(wardrobe: wardrobe))
    }

    private let occasions = ["work", "date", "gala", "casual"]

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroAvatar
                    if vm.isColdStart { coldStartBanner }
                    controls
                    if !vm.fullAuto || vm.isColdStart { anchorGrid }
                    suggestionsSection
                    if let checkInNote {
                        Text(checkInNote)
                            .font(.caption).foregroundStyle(DS.accent)
                    }
                }
                .padding(20)
            }
            .background(DS.bg.ignoresSafeArea())
            .navigationTitle("Today")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .task { await bootstrap() }
        }
    }

    // MARK: - Hero（首屏视觉主角）

    private var heroAvatar: some View {
        VStack(spacing: 10) {
            BodyAvatarView(
                shape: heroShape,
                morph: bodyMorph,
                layers: heroLayers,
                fitCaption: heroCaption,
                showsFitCaption: true,
                enablesOrbit: true)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 320)
            .background(
                RoundedRectangle(cornerRadius: DS.radius)
                    .fill(Color(red: 158 / 255, green: 158 / 255, blue: 158 / 255))
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.radius))

            HStack {
                Label(
                    String(format: "%.0f°F · %@", vm.daytimeTempF, vm.wardrobe.locationCity ?? "climate"),
                    systemImage: "cloud.sun")
                Spacer()
                Text(vm.occasion.capitalized)
                if let shape = vm.bodyShape {
                    Text("· \(shape.popularCategory.rawValue)")
                }
            }
            .font(.caption)
            .foregroundStyle(DS.muted)

            if let scored = vm.selectedSuggestion {
                HStack(spacing: 8) {
                    actionBtn("Save") {
                        actions.saveFavorite(scored: scored, occasion: vm.occasion,
                                             in: vm.wardrobe, context: context)
                        checkInNote = actions.message
                    }
                    actionBtn("Plan today") {
                        actions.planToday(scored: scored, occasion: vm.occasion,
                                          in: vm.wardrobe, context: context)
                        checkInNote = actions.message
                    }
                    actionBtn("I wore this") { checkIn(scored) }
                }
            }
        }
    }

    private var heroShape: PopularShape {
        if let pid = vm.wardrobe.owner?.id {
            let profiles = (try? context.fetch(FetchDescriptor<PersonBodyProfile>())) ?? []
            if let p = profiles.first(where: { $0.personID == pid }),
               let s = BodyProfileService.displayPopularShape(from: p) {
                return s
            }
        }
        return vm.bodyShape?.popularCategory ?? .rectangle
    }

    private var heroLayers: [BodyAvatarLayer] {
        if let scored = vm.selectedSuggestion {
            return OutfitAvatarComposer.layers(
                itemIDs: scored.outfit.itemIDs, in: vm.wardrobe)
        }
        // 无建议时：已锚定单品叠上，给「正在搭」的感觉
        let anchored = (vm.wardrobe.items ?? []).filter { vm.anchorIDs.contains($0.id) }
        if !anchored.isEmpty {
            return OutfitAvatarComposer.layers(from: anchored)
        }
        return []
    }

    private var heroCaption: String {
        if let scored = vm.selectedSuggestion {
            let names = itemNames(for: scored)
            if names.isEmpty {
                return "\(scored.outfit.items.count)-piece look · proportion guide, not photo try-on"
            }
            return names.joined(separator: " · ")
        }
        if !vm.anchorIDs.isEmpty {
            return "Anchored pieces — complete a look below"
        }
        if vm.isColdStart {
            return "Load samples or add pieces, then complete a look"
        }
        return "Your body · today’s look — pick or complete below"
    }

    // MARK: - Controls / anchors

    private var coldStartBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Getting started")
                .font(.subheadline.weight(.semibold))
            Text("Your closet is still small. Anchor at least one piece, or load samples from Closet or Me.")
                .font(.caption).foregroundStyle(DS.muted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.accent.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DS.radius))
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Occasion", selection: $vm.occasion) {
                ForEach(occasions, id: \.self) { Text($0.capitalized).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: vm.occasion) { _, _ in
                // 换场合不自动刷，避免误触；用户点主按钮
            }

            if !vm.isColdStart {
                Toggle("Just decide for me (full-auto)", isOn: $vm.fullAuto)
                    .tint(DS.accent)
            }

            if debug.showEmptyReason && !vm.statusMessage.isEmpty {
                Text(vm.statusMessage)
                    .font(.caption2)
                    .foregroundStyle(DS.muted)
            }

            Button {
                vm.wornWithin7DaysIDs = DebugSettings.shared.disableAntiRepeat
                    ? [] : CheckInViewModel.recentlyWornIDs(in: context)
                vm.refresh()
            } label: {
                Text(vm.fullAuto && !vm.isColdStart ? "Pick my outfit" : "Complete my look")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(DS.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: DS.radius))
            }
        }
    }

    private var anchorGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(vm.availableItems.isEmpty
                     ? "No available pieces — add some in Closet"
                     : "Anchor a few pieces")
                    .font(.subheadline).foregroundStyle(DS.muted)
                Spacer()
                if !vm.anchorIDs.isEmpty {
                    Button("Clear") { vm.clearAnchors() }
                        .font(.caption)
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 10)], spacing: 10) {
                ForEach(vm.availableItems, id: \.id) { item in
                    Button { vm.toggleAnchor(item) } label: { itemChip(item) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func itemChip(_ item: Item) -> some View {
        let anchored = vm.isAnchored(item)
        return VStack(spacing: 6) {
            ItemThumbnailView(item: item, height: 64)
            Text(item.name).font(.caption2).lineLimit(1)
        }
        .padding(6)
        .background(anchored ? DS.accent.opacity(0.15) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: DS.radius)
                .stroke(anchored ? DS.accent : DS.muted.opacity(0.2), lineWidth: anchored ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.radius))
    }

    // MARK: - Suggestions list（次要；点选切换英雄区）

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if vm.suggestions.isEmpty {
                if !vm.statusMessage.isEmpty && !vm.isColdStart {
                    Text(vm.statusMessage)
                        .font(.subheadline).foregroundStyle(DS.muted)
                }
            } else {
                Text("Other looks")
                    .font(.title3.weight(.semibold))
                ForEach(Array(vm.suggestions.enumerated()), id: \.offset) { idx, scored in
                    suggestionRow(scored, index: idx)
                }
            }
        }
    }

    private func suggestionRow(_ scored: ScoredOutfit, index: Int) -> some View {
        let selected = index == vm.selectedSuggestionIndex
        return Button {
            vm.selectSuggestion(at: index)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Look \(index + 1) · \(scored.outfit.items.count) pieces")
                        .font(.headline).foregroundStyle(DS.ink)
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(DS.accent)
                    }
                }
                let names = itemNames(for: scored)
                if !names.isEmpty {
                    Text(names.joined(separator: " · "))
                        .font(.caption).foregroundStyle(DS.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                ForEach(scored.score.reasons.prefix(2), id: \.self) { reason in
                    Text(reason)
                        .font(.caption2).foregroundStyle(DS.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(selected ? DS.accent.opacity(0.08) : DS.surface)
            .overlay(
                RoundedRectangle(cornerRadius: DS.radius)
                    .stroke(selected ? DS.accent : Color.clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.radius))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Body / actions

    private var bodyMorph: BodyMorphParams {
        if let pid = vm.wardrobe.owner?.id {
            let profiles = (try? context.fetch(FetchDescriptor<PersonBodyProfile>())) ?? []
            if let p = profiles.first(where: { $0.personID == pid }) {
                let m = BodyProfileService.measurements(from: p)
                let shape = BodyProfileService.popularShape(from: p)
                let fine = BodyMorphParams(
                    chest: p.fineChest, waist: p.fineWaist,
                    hip: p.fineHip, shoulder: 1, height: p.fineHeight)
                return BodyMorphParams.resolve(measurements: m, shape: shape, fineTune: fine)
            }
        }
        return BodyMorphParams.preset(for: vm.bodyShape?.popularCategory ?? .rectangle)
    }

    private func itemNames(for scored: ScoredOutfit) -> [String] {
        let ids = Set(scored.outfit.itemIDs)
        return (vm.wardrobe.items ?? [])
            .filter { ids.contains($0.id.uuidString) }
            .map(\.name)
            .sorted()
    }

    private func actionBtn(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(DS.surface)
                .foregroundStyle(DS.accent)
                .clipShape(RoundedRectangle(cornerRadius: DS.radius))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.radius)
                        .stroke(DS.accent.opacity(0.4), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func checkIn(_ scored: ScoredOutfit) {
        let ids = Set(scored.outfit.itemIDs)
        let items = (vm.wardrobe.items ?? []).filter { ids.contains($0.id.uuidString) }
        guard !items.isEmpty else { return }
        _ = CheckInService.recordWear(items: items, on: Date(), in: vm.wardrobe, in: context)
        vm.wornWithin7DaysIDs = CheckInViewModel.recentlyWornIDs(in: context)
        checkInNote = "Checked in \(items.count) pieces. They'll be de-prioritized for 7 days."
        AppLog.info("ui checkIn \(items.count)", .copilot)
    }

    private func bootstrap() async {
        vm.wornWithin7DaysIDs = CheckInViewModel.recentlyWornIDs(in: context)
        await vm.applyWeather(CityClimateWeatherProvider())
        if let pid = vm.wardrobe.owner?.id {
            let profiles = (try? context.fetch(FetchDescriptor<PersonBodyProfile>())) ?? []
            if let p = profiles.first(where: { $0.personID == pid }) {
                vm.bodyShape = BodyProfileService.bodyShape(from: p)
            }
        }
        // 非冷启动：默认 full-auto 拉一版，首屏立刻有 look
        if !vm.isColdStart {
            vm.fullAuto = true
            vm.refresh()
        }
        AppLog.debug("Copilot hero appear items=\(vm.availableItems.count) temp=\(vm.daytimeTempF)", .copilot)
    }
}
