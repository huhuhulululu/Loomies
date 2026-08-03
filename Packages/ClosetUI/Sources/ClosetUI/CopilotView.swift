import SwiftUI
import SwiftData
import ClosetModel
import ClosetCore

/// copilot 主屏（DESIGN §F4/§10）：锚定 → 补全；打卡；状态条 / 耗时。
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
                VStack(alignment: .leading, spacing: 24) {
                    if vm.isColdStart { coldStartBanner }
                    if debug.showEmptyReason && !vm.statusMessage.isEmpty {
                        statusBanner
                    }
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
            .task {
                vm.wornWithin7DaysIDs = CheckInViewModel.recentlyWornIDs(in: context)
                // 离线城市气候表；日后可换 WeatherKit 实现同一协议
                await vm.applyWeather(CityClimateWeatherProvider())
                // 注入体型加权（若有档案）
                if let pid = vm.wardrobe.owner?.id {
                    let profiles = (try? context.fetch(FetchDescriptor<PersonBodyProfile>())) ?? []
                    if let p = profiles.first(where: { $0.personID == pid }) {
                        vm.bodyShape = BodyProfileService.bodyShape(from: p)
                    }
                }
                AppLog.debug("Copilot appear items=\(vm.availableItems.count) temp=\(vm.daytimeTempF)", .copilot)
            }
        }
    }

    private var statusBanner: some View {
        Text(vm.statusMessage)
            .font(.caption)
            .foregroundStyle(DS.muted)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.radius))
    }

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

            if !vm.isColdStart {
                Toggle("Just decide for me (full-auto)", isOn: $vm.fullAuto)
                    .tint(DS.accent)
            }

            HStack {
                Label(
                    String(format: "%.0f°F · %@", vm.daytimeTempF, vm.wardrobe.locationCity ?? "default climate"),
                    systemImage: "cloud.sun")
                    .font(.caption)
                    .foregroundStyle(DS.muted)
                Spacer()
                if let shape = vm.bodyShape {
                    Text(shape.rawValue)
                        .font(.caption2)
                        .foregroundStyle(DS.muted)
                }
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
            Text(vm.availableItems.isEmpty
                 ? "No available pieces — add some in Closet"
                 : "Anchor a few pieces")
                .font(.subheadline).foregroundStyle(DS.muted)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
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
            RoundedRectangle(cornerRadius: DS.radius)
                .fill(DS.surface)
                .frame(height: 72)
                .overlay(Text(item.slotRaw).font(.caption2).foregroundStyle(DS.muted))
            Text(item.name).font(.caption).lineLimit(1)
        }
        .padding(6)
        .background(anchored ? DS.accent.opacity(0.15) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: DS.radius)
                .stroke(anchored ? DS.accent : DS.muted.opacity(0.2), lineWidth: anchored ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.radius))
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if vm.suggestions.isEmpty {
                Text(vm.statusMessage.isEmpty
                     ? "Tap the button for suggestions from your closet."
                     : vm.statusMessage)
                    .font(.subheadline).foregroundStyle(DS.muted)
            } else {
                Text("Suggestions")
                    .font(.title3.weight(.semibold))
                ForEach(Array(vm.suggestions.enumerated()), id: \.offset) { _, scored in
                    suggestionCard(scored)
                }
            }
        }
    }

    private func suggestionCard(_ scored: ScoredOutfit) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(scored.outfit.items.count)-piece look")
                .font(.headline).foregroundStyle(DS.ink)
            ForEach(scored.score.reasons, id: \.self) { reason in
                Label(reason, systemImage: "checkmark.circle")
                    .font(.caption).foregroundStyle(DS.muted)
            }
            let names = itemNames(for: scored)
            if !names.isEmpty {
                Text(names.joined(separator: " · "))
                    .font(.caption).foregroundStyle(DS.ink)
            }
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(DS.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.radius))
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
}
