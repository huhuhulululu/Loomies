import SwiftUI
import SwiftData
import ClosetModel
import ClosetCore

/// 手动打卡（DESIGN §F5）：自己选今天穿了哪几件 + 可选合身反馈。
/// 与 Today「Wore it」是**同一套语义**（都写一条 WearRecord），
/// 只是这里由用户挑件，那里用 copilot 建议——不是第二个打卡概念。
public struct CheckInView: View {
    let wardrobe: Wardrobe
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var vm: CheckInViewModel

    public init(wardrobe: Wardrobe) {
        self.wardrobe = wardrobe
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
                        if vm.checkIn(in: context) != nil { dismiss() }
                        // 失败留在表单（vm.message 已给诚实提示），不静默关闭
                    }
                    .disabled(!vm.canCheckIn)
                }
            }
        }
    }
}
