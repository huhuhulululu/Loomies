import SwiftUI
import SwiftData
import ClosetModel
import ClosetCore
import ClosetIntake

/// 入库单屏确认（DESIGN §F1 第 5 步）：AI 预填草稿 → 用户改 → 确认落库。
/// 相机/PHPicker 采集是 iOS 设备侧（外部把 imageData 传给 vm.process）；本视图经 swift build 验证。
public struct IntakeView: View {
    @Environment(\.modelContext) private var context
    @State private var vm: IntakeViewModel
    let wardrobe: Wardrobe
    /// 采集闭包（真机接相机/PHPicker；预览/测试传桩）。
    let capture: () async -> Data?

    private let slots = GarmentSlot.allCases

    public init(vm: IntakeViewModel, wardrobe: Wardrobe, capture: @escaping () async -> Data?) {
        _vm = State(initialValue: vm)
        self.wardrobe = wardrobe
        self.capture = capture
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let draft = Binding($vm.draft) {
                    confirmForm(draft)
                } else {
                    emptyState
                }
            }
            .padding(20)
            .background(DS.bg.ignoresSafeArea())
            .navigationTitle("Add item")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            if vm.isProcessing { ProgressView("Processing…") }
            Text("Snap a photo of a piece. We'll cut it out and pre-fill the details.")
                .font(.subheadline).foregroundStyle(DS.muted)
                .multilineTextAlignment(.center)
            Button {
                Task {
                    if let data = await capture() { await vm.process(data) }
                }
            } label: {
                Text("Add a photo")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(DS.accent).foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: DS.radius))
            }
        }
    }

    private func confirmForm(_ draft: Binding<IntakeDraft>) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LabeledField("Name") { TextField("Name", text: draft.name) }
                LabeledField("Type") {
                    Picker("Type", selection: draft.slot) {
                        ForEach(slots, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }.pickerStyle(.menu)
                }
                LabeledField("Brand") {
                    TextField("Brand", text: Binding(draft.brand, replacingNilWith: ""))
                }
                LabeledField("Size") {
                    TextField("Size", text: Binding(draft.size, replacingNilWith: ""))
                }
                Button {
                    vm.confirm(into: wardrobe, context: context)
                } label: {
                    Text("Add to closet")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(DS.accent).foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: DS.radius))
                }
                .padding(.top, 8)
            }
        }
    }
}

private struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content
    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundStyle(DS.muted)
            content
                .padding(10)
                .background(DS.surface)
                .clipShape(RoundedRectangle(cornerRadius: DS.radius))
        }
    }
}

private extension Binding where Value == String {
    /// optional String 绑定 → 非 nil String 绑定（空串写回 nil）。
    init(_ source: Binding<String?>, replacingNilWith empty: String) {
        self.init(
            get: { source.wrappedValue ?? empty },
            set: { source.wrappedValue = $0.isEmpty ? nil : $0 })
    }
}
