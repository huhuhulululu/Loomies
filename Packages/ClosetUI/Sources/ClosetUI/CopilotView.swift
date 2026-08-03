import SwiftUI
import SwiftData
import ClosetModel
import ClosetCore

/// copilot 主屏（DESIGN §F4/§10）：锚定 → 补全候选；可打卡；冷启动提示。
public struct CopilotView: View {
    @Environment(\.modelContext) private var context
    @State private var vm: CopilotViewModel
    @State private var checkInNote: String?

    public init(wardrobe: Wardrobe) {
        _vm = State(initialValue: CopilotViewModel(wardrobe: wardrobe))
    }

    private let occasions = ["work", "date", "gala", "casual"]

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if vm.isColdStart {
                        coldStartBanner
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
            .onAppear {
                // 注入近 7 天穿着，供防重复
                vm.wornWithin7DaysIDs = CheckInViewModel.recentlyWornIDs(in: context)
            }
        }
    }

    private var coldStartBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Getting started")
                .font(.subheadline.weight(.semibold))
            Text("Your closet is still small. Anchor at least one piece, or load samples from the Closet or Me tab.")
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

            Button {
                vm.wornWithin7DaysIDs = CheckInViewModel.recentlyWornIDs(in: context)
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
                Text(vm.isColdStart
                     ? "Pick an anchor piece, then tap Complete my look."
                     : "Tap the button for suggestions from your closet.")
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
            // 显示单品名（从 wardrobe 反查 id）
            let names = itemNames(for: scored)
            if !names.isEmpty {
                Text(names.joined(separator: " · "))
                    .font(.caption).foregroundStyle(DS.ink)
            }
            Button {
                checkIn(scored)
            } label: {
                Text("I wore this")
                    .font(.subheadline.weight(.semibold))
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

    private func checkIn(_ scored: ScoredOutfit) {
        let ids = Set(scored.outfit.itemIDs)
        let items = (vm.wardrobe.items ?? []).filter { ids.contains($0.id.uuidString) }
        guard !items.isEmpty else { return }
        _ = CheckInService.recordWear(items: items, on: Date(), in: vm.wardrobe, in: context)
        vm.wornWithin7DaysIDs = CheckInViewModel.recentlyWornIDs(in: context)
        checkInNote = "Checked in \(items.count) pieces. They'll be de-prioritized for 7 days."
    }
}
