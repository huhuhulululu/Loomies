import SwiftUI
import SwiftData
import ClosetModel
import ClosetCore

/// 试衣间（手动拼贴入口）：按槽位挑本柜单品 → 纸娃娃上身（正面）→ 存为收藏 look。
public struct FittingRoomView: View {
    let wardrobe: Wardrobe
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var vm: FittingRoomViewModel
    @State private var lookName = ""
    /// 身体档案走 @Query（活查询）：改体型即刷新，且不在渲染路径里发 fetch。
    @Query private var bodyProfiles: [PersonBodyProfile]

    public init(wardrobe: Wardrobe) {
        self.wardrobe = wardrobe
        _vm = State(initialValue: FittingRoomViewModel(wardrobe: wardrobe))
    }

    /// Closet 工具栏入口 VO 文案（journey 测试可钉）。
    public static let entryAccessibilityLabel = "Fitting room"
    public static let saveButtonTitle = "Save look"

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // 与 Today/Favorites 同源体型/morph（正面、无 orbit——试穿聚焦搭配本身）
                    BodyAvatarView(
                        shape: ownerShape,
                        morph: ownerMorph,
                        layers: vm.layers,
                        showsFitCaption: false,
                        enablesOrbit: false,
                        backdrop: .studio,
                        depthIntensity: .off,
                        bodySex: BodyProfileService.presentationSex(from: ownerProfile),
                        bodyPhenotype: BodyProfileService.presentationPhenotype(from: ownerProfile),
                        usesMannequin3D: false)
                    .frame(maxWidth: .infinity)
                    .frame(height: 340)
                    .accessibilityLabel(avatarAccessibilityLabel)

                    ForEach(FittingRoomViewModel.slotOrder, id: \.self) { slot in
                        slotSection(slot)
                    }

                    saveBar
                }
                .padding()
            }
            .background(DS.bg.ignoresSafeArea())
            .navigationTitle("Fitting room")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear") { vm.clear() }
                        .disabled(vm.selectedItems.isEmpty)
                        .accessibilityLabel("Clear selection")
                }
            }
            .overlay(alignment: .bottom) {
                if let message = vm.message {
                    CustomerFlashStyle.overlayChip(message)
                        .padding()
                }
            }
        }
    }

    @ViewBuilder
    private func slotSection(_ slot: BodyAvatarSlot) -> some View {
        let items = vm.items(for: slot)
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(Self.slotTitle(slot))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.muted)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(items, id: \.id) { item in
                            itemChip(item)
                        }
                    }
                }
            }
        }
    }

    private func itemChip(_ item: Item) -> some View {
        let selected = vm.isSelected(item)
        return Button {
            vm.toggle(item)
        } label: {
            VStack(spacing: 6) {
                ItemThumbnailView(item: item, height: 84)
                    .frame(width: 64, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(selected ? DS.accent : DS.hairline,
                                          lineWidth: selected ? 2 : 0.5))
                Text(item.name)
                    .font(.caption2)
                    .lineLimit(1)
                    .frame(width: 72)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.name)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityHint(selected ? "Double tap to take off" : "Double tap to try on")
    }

    private var saveBar: some View {
        VStack(spacing: 10) {
            TextField("Look name (optional)", text: $lookName)
                .textFieldStyle(.roundedBorder)
            Button(Self.saveButtonTitle) {
                if vm.saveAsFavorite(named: lookName, in: context) != nil {
                    lookName = ""
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.accent)
            .disabled(!vm.canSave)
            .frame(maxWidth: .infinity)
            .accessibilityHint("Saves the current pieces as a favorite look")
        }
        .padding(.top, 6)
    }

    private var avatarAccessibilityLabel: String {
        vm.selectedItems.isEmpty
            ? "Avatar with no pieces on — pick pieces below to try on"
            : "Avatar wearing \(vm.selectedItems.map(\.name).joined(separator: ", "))"
    }

    static func slotTitle(_ slot: BodyAvatarSlot) -> String {
        GarmentSlot(rawValue: slot.rawValue)?.displayTitle ?? slot.rawValue.capitalized
    }

    // 与 FavoritesView 同源的 owner 体型推导
    /// D112：这里原本是**计算属性里发全表 fetch**——而它在行构建器里被读 4-5 次
    /// （shape / morph / sex / phenotype 各一次），于是每滚进一行就是一把主线程 SQLite 往返。
    /// 同模块的 `ClosetGridView` 早就是 `@Query` + 内存 `first {}`（实测约快两个数量级），
    /// 这里收编成同一种写法，不另造。
    private var ownerProfile: PersonBodyProfile? {
        guard let pid = wardrobe.owner?.id else { return nil }
        return bodyProfiles.first { $0.personID == pid }
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
