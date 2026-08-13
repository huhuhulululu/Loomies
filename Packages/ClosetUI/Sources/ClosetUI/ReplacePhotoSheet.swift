import SwiftUI
import SwiftData
import ClosetIntake
import ClosetModel
import ClosetCore

/// 给已经在柜里的单品补/换一张照片（D185）。
///
/// 入库失败的三条提示一直写着「re-add the photo later」，而这条路以前不存在——
/// 唯一的「re-add」是删掉重来，那会把引用它的搭配标成永久缺件、
/// 让穿着历史里这件显示成「no longer in this closet」。
///
/// 刻意做得比入库面窄：只换图，不碰任何属性。属性在详情页本来就能改，
/// 再摆一遍等于两个可以互相打架的编辑入口。
public struct ReplacePhotoSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let item: Item
    /// 换完把结果告诉详情页（成功失败都要说，不静默）。
    var onFinished: (ItemPhotoService.Outcome) -> Void

    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var isWorking = false

    public init(item: Item, onFinished: @escaping (ItemPhotoService.Outcome) -> Void) {
        self.item = item
        self.onFinished = onFinished
    }

    public static let caption =
        "The photo is cut out on this device and stored locally — same as adding a piece."

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    ItemThumbnailView(item: item, height: 180)
                        .listRowInsets(EdgeInsets())
                }
                Section {
                    if isWorking {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Cutting out the piece…")
                                .font(.caption).foregroundStyle(DS.muted)
                        }
                    } else {
                        #if os(iOS)
                        Button { showCamera = true } label: {
                            Label("Take photo", systemImage: "camera")
                        }
                        Button { showLibrary = true } label: {
                            Label("Choose from library", systemImage: "photo.on.rectangle")
                        }
                        #else
                        Text("Photo capture is available on iPhone.")
                            .font(.caption).foregroundStyle(DS.muted)
                        #endif
                    }
                } footer: {
                    Text(Self.caption)
                }
            }
            .navigationTitle(ItemPhotoService.entryTitle(
                hasPhoto: item.localImageRelativePath != nil))
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isWorking)
                }
            }
            #if os(iOS)
            .sheet(isPresented: $showLibrary) {
                PhotoLibraryPicker { data in apply(data) }
            }
            .sheet(isPresented: $showCamera) {
                CameraCapturePicker { data in apply(data) }
            }
            #endif
        }
    }

    private func apply(_ data: Data?) {
        guard let data else { return }   // 用户取消：什么都不做
        isWorking = true
        Task { @MainActor in
            let outcome = await ItemPhotoService.replacePhoto(
                for: item, imageData: data, matting: IntakeServiceFactory.makeMatting(),
                in: context)
            isWorking = false
            onFinished(outcome)
            // 失败留在原地可重试；成功才关（与入库/转移面同一条纪律）
            if outcome == .replaced { dismiss() }
        }
    }
}

extension View {
    /// `.navigationBarTitleDisplayMode` 只有 iOS 有；mac 上编不过。
    @ViewBuilder
    func navigationBarTitleDisplayModeInline() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
