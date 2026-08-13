import SwiftUI
import SwiftData
import ClosetModel
import ClosetCore

/// 手动打卡（DESIGN §F5）：自己选今天穿了哪几件 + 可选合身反馈。
/// 与 Today「Wore it」是**同一套语义**（都写一条 WearRecord），
/// 只是这里由用户挑件，那里用 copilot 建议——不是第二个打卡概念。
public struct CheckInView: View {
    let wardrobe: Wardrobe
    /// 成功回执交回 Today 闪现——表单关闭后回执不该跟着消失
    /// （与「Wore it」的 feedbackChip 对等：两条打卡路径都给得到确认）。
    let onLoggedFlash: ((String) -> Void)?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var vm: CheckInViewModel

    public init(wardrobe: Wardrobe, onLoggedFlash: ((String) -> Void)? = nil) {
        self.wardrobe = wardrobe
        self.onLoggedFlash = onLoggedFlash
        _vm = State(initialValue: CheckInViewModel(wardrobe: wardrobe))
    }

    public static let entryButtonTitle = "Log what I wore"
    public static let emptyMessage = "No pieces here yet. Add one in Closet."
    public static let unavailableToggleTitle = "Include laundry / lent pieces"
    /// 只记今天（DESIGN §F5「今天穿了这套」）；补记过去日期是 v1.x 议题。
    public static let todayOnlyCaption = "Logs today's wear."

    public var body: some View {
        NavigationStack {
            List {
                if vm.selectableItems.isEmpty {
                    Section {
                        Text(Self.emptyMessage)
                            .font(.caption).foregroundStyle(DS.muted)
                            .accessibilityLabel(Self.emptyMessage)
                    }
                } else {
                    Section {
                        ForEach(vm.selectableItems, id: \.id) { item in
                            Button { vm.toggle(item) } label: {
                                HStack(spacing: 12) {
                                    ItemThumbnailView(item: item, height: 40)
                                        .frame(width: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                        Text(ClosetItemRowCopy.metaLine(for: item))
                                            .font(.caption2).foregroundStyle(DS.muted)
                                    }
                                    Spacer()
                                    if vm.isSelected(item) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(DS.accent)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(item.name)
                            .accessibilityAddTraits(vm.isSelected(item) ? [.isSelected] : [])
                        }
                    } header: {
                        Text("Pieces")
                    } footer: {
                        Text(Self.todayOnlyCaption)
                    }
                }
                Section {
                    Toggle(Self.unavailableToggleTitle, isOn: $vm.includesUnavailableItems)
                }
                Section {
                    Picker(FitFeedbackCopy.prompt, selection: $vm.fitVerdict) {
                        Text(FitFeedbackCopy.skipTitle).tag(Optional<FitVerdict>.none)
                        ForEach(FitFeedbackCopy.options, id: \.rawValue) { v in
                            Text(FitFeedbackCopy.choiceTitle(v)).tag(Optional(v))
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel(FitFeedbackCopy.prompt)
                } footer: {
                    // D196：这一问现在**会被拿去做事**（报够两次就成为合身标记），
                    // 那就得说出口——问了不用糟，用了不说同样糟。
                    Text(FitFeedbackCopy.usageDisclosure)
                    Text(FitFeedbackCopy.exportDisclosure)
                }
                if !vm.message.isEmpty {
                    Section {
                        Text(vm.message)
                            .foregroundStyle(CustomerFlashStyle.isFailure(vm.message)
                                             ? Color.orange : DS.accent)
                            .accessibilityLabel(vm.message)
                    }
                }
            }
            .navigationTitle("Log wear")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") {
                        guard vm.checkIn(in: context) != nil else { return }
                        // 合身备注写失败时打卡本身已成功，但**留在表单**把话说清楚，
                        // 不静默关闭假装一切正常（didFail 驱动，不嗅探文案关键词）。
                        guard !vm.didFail else { return }
                        onLoggedFlash?(vm.message)
                        dismiss()
                    }
                    .disabled(!vm.canCheckIn)
                }
            }
        }
    }
}
