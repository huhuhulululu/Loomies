import SwiftUI
import ClosetModel
import ClosetCore

/// copilot 主屏（DESIGN §F4/§10）：用户锚定几件 → 求 AI 补全候选供选；full-auto 可选。
/// 渲染需 iOS 模拟器；本文件经 swift build 验证编译。真机 target 再加 Liquid Glass 自定义玻璃与 WeatherKit 接线。
public struct CopilotView: View {
    @State private var vm: CopilotViewModel

    public init(wardrobe: Wardrobe) {
        _vm = State(initialValue: CopilotViewModel(wardrobe: wardrobe))
    }

    private let occasions = ["work", "date", "gala", "casual"]

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    controls
                    if !vm.fullAuto { anchorGrid }
                    suggestionsSection
                }
                .padding(20)
            }
            .background(DS.bg.ignoresSafeArea())
            .navigationTitle("Today")
        }
    }

    // 场合 + full-auto 开关 + 求建议
    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Occasion", selection: $vm.occasion) {
                ForEach(occasions, id: \.self) { Text($0.capitalized).tag($0) }
            }
            .pickerStyle(.segmented)

            Toggle("Just decide for me (full-auto)", isOn: $vm.fullAuto)
                .tint(DS.accent)

            Button {
                vm.refresh()
            } label: {
                Text(vm.fullAuto ? "Pick my outfit" : "Complete my look")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(DS.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: DS.radius))
            }
        }
    }

    // 可用单品网格，点选锚定（copilot：你先选几件）
    private var anchorGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Anchor a few pieces")
                .font(.subheadline).foregroundStyle(DS.muted)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                ForEach(vm.availableItems, id: \.id) { item in
                    Button {
                        vm.toggleAnchor(item)
                    } label: {
                        itemChip(item)
                    }
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

    // 补全候选：每套显示件数 + 「为什么推荐」reasons
    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if vm.suggestions.isEmpty {
                Text("Tap the button for suggestions built from your closet.")
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(DS.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.radius))
    }
}
