import SwiftUI
import ClosetIntake
import ClosetModel
import ClosetCore
#if canImport(PhotosUI)
import PhotosUI
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit) && !os(iOS)
import AppKit
#endif

// MARK: - PHPicker

#if os(iOS)
public struct PhotoLibraryPicker: UIViewControllerRepresentable {
    /// 单张回调（保留给相机/单图路径）。
    var onPicked: ((Data?) -> Void)?
    /// 批量回调：交回**图片句柄**而不是 Data——一次性载入 30 张全分辨率会炸内存，
    /// 逐张按需加载（`BatchImageLoader`）。
    var onPickedBatch: (([PHPickerResult]) -> Void)?
    /// 0 = 不限（由 `BatchIntakeQueue.maxSelection` 在回调侧截断并明说）。
    var selectionLimit: Int = 1

    public init(onPicked: @escaping (Data?) -> Void) {
        self.onPicked = onPicked
        self.selectionLimit = 1
    }

    public init(selectionLimit: Int, onPickedBatch: @escaping ([PHPickerResult]) -> Void) {
        self.onPickedBatch = onPickedBatch
        self.selectionLimit = selectionLimit
    }

    public func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = selectionLimit
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    public func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    public func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked, onPickedBatch: onPickedBatch)
    }

    public final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPicked: ((Data?) -> Void)?
        let onPickedBatch: (([PHPickerResult]) -> Void)?
        init(onPicked: ((Data?) -> Void)?, onPickedBatch: (([PHPickerResult]) -> Void)?) {
            self.onPicked = onPicked
            self.onPickedBatch = onPickedBatch
        }

        public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            if let onPickedBatch {
                DispatchQueue.main.async { onPickedBatch(results) }
                return
            }
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                onPicked?(nil)
                return
            }
            provider.loadObject(ofClass: UIImage.self) { obj, _ in
                let data = (obj as? UIImage).flatMap { $0.jpegData(compressionQuality: 0.9) }
                DispatchQueue.main.async { self.onPicked?(data) }
            }
        }
    }
}

/// 逐张按需加载（D92）：批量选择只拿句柄，用到哪张才解码哪张——
/// 30 张全分辨率同时驻留会直接爆内存。
public enum BatchImageLoader {
    /// nil = 这张读不出来（队列记 `.failed`，不是静默跳过）。
    /// `@MainActor`：`PHPickerResult` / `NSItemProvider` 都不是 Sendable，
    /// 跨隔离域传会被并发检查拦下（真机构建才报，macOS 的 swift test 编不到这块）。
    @MainActor
    public static func load(_ result: PHPickerResult) async -> Data? {
        let provider = result.itemProvider
        guard provider.canLoadObject(ofClass: UIImage.self) else { return nil }
        return await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: UIImage.self) { obj, _ in
                let data = (obj as? UIImage).flatMap { $0.jpegData(compressionQuality: 0.9) }
                continuation.resume(returning: data)
            }
        }
    }
}

/// 相机拍照 → JPEG Data。
public struct CameraCapturePicker: UIViewControllerRepresentable {
    var onPicked: (Data?) -> Void

    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        p.delegate = context.coordinator
        p.allowsEditing = false
        return p
    }

    public func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    public func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    public final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPicked: (Data?) -> Void
        init(onPicked: @escaping (Data?) -> Void) { self.onPicked = onPicked }

        public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            onPicked(nil)
        }

        public func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            picker.dismiss(animated: true)
            let img = info[.originalImage] as? UIImage
            onPicked(img?.jpegData(compressionQuality: 0.9))
        }
    }
}
#endif

// MARK: - Item thumbnail

public struct ItemThumbnailView: View {
    let item: Item
    var height: CGFloat = 120

    public var body: some View {
        Group {
            if let data = ItemImageStore.loadData(relativePath: item.localImageRelativePath),
               let ui = platformImage(data) {
                ui
                    .resizable()
                    .scaledToFill()
            } else {
                // Soft gradient + SF Symbol + human label (no raw slotRaw leak).
                let slot = GarmentSlot.resolved(item.slotRaw, name: item.name)
                ZStack {
                    LinearGradient(
                        colors: [
                            slotWash(slot).opacity(0.55),
                            slotWash(slot).opacity(0.22),
                            DS.surface,
                        ],
                        startPoint: .top,
                        endPoint: .bottom)
                    VStack(spacing: 6) {
                        Image(systemName: slot.systemImageName)
                            .font(.system(size: height > 80 ? 22 : 16, weight: .semibold))
                            .foregroundStyle(DS.ink.opacity(0.55))
                            .symbolRenderingMode(.hierarchical)
                        Text(slot.displayTitle)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(DS.muted)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(slot.displayTitle)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: DS.radius))
    }

    private func slotWash(_ slot: GarmentSlot) -> Color {
        switch slot {
        case .top: return DS.accent
        case .bottom: return Color(red: 0.30, green: 0.35, blue: 0.45)
        case .dress: return Color(red: 0.55, green: 0.40, blue: 0.50)
        case .outerwear: return Color(red: 0.45, green: 0.35, blue: 0.30)
        case .shoes: return Color(red: 0.25, green: 0.25, blue: 0.28)
        case .accessory: return Color(red: 0.50, green: 0.42, blue: 0.28)
        }
    }

    private func platformImage(_ data: Data) -> Image? {
        #if canImport(UIKit)
        if let u = UIImage(data: data) { return Image(uiImage: u) }
        #elseif canImport(AppKit) && !os(iOS)
        if let n = NSImage(data: data) { return Image(nsImage: n) }
        #endif
        return nil
    }
}

// MARK: - Add piece sheet

/// Closet「+」：相册 / 相机 / 手填。
public struct AddPieceSheet: View {
    let wardrobe: Wardrobe
    /// Post-save honesty flash handoff: the sheet dismisses on confirm() success,
    /// so a "Added, but the photo won't appear in try-on"-style statusMessage set
    /// by confirm would never render inside the sheet — the parent flashes it.
    let onConfirmFlash: ((String) -> Void)?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .choose
    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var intakeVM = IntakeServiceFactory.makeViewModel()
    /// 手填草稿：落库唯一真相是 `QuickAddDraft.commit`（未选 = 未知，不替用户假设）。
    @State private var draft = QuickAddDraft()
    @State private var message = ""
    #if os(iOS)
    /// 批量选择的**句柄**（不是 Data——30 张全分辨率同时驻留会爆内存）
    @State private var batchResults: [PHPickerResult] = []
    #endif
    /// 批量进度与诚实记账；nil = 不在批量流里
    @State private var batchQueue: BatchIntakeQueue?
    @State private var batchNotice = ""

    enum Mode { case choose, manual, intake }

    public init(wardrobe: Wardrobe, onConfirmFlash: ((String) -> Void)? = nil) {
        self.wardrobe = wardrobe
        self.onConfirmFlash = onConfirmFlash
    }

    /// What to flash on the parent after a successful confirm: confirm() clears
    /// statusMessage at entry, so any non-empty status right after success is a
    /// post-save honesty message (matting / layer normalize / image save failed)
    /// that must not die with the sheet. nil/empty → nothing to flash.
    public static func postConfirmFlash(statusMessage: String?) -> String? {
        guard let statusMessage, !statusMessage.isEmpty else { return nil }
        return statusMessage
    }

    public var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .choose: chooseBody
                case .manual: manualBody
                case .intake: intakeConfirmBody
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(mode == .choose ? "Close" : "Back") {
                        #if os(iOS)
                        // 批量中途退出：已确认的不回滚（用户逐件拍过板），
                        // 但必须说清还剩几张没看——否则用户以为整批都进去了
                        if let queue = batchQueue {
                            batchQueue = nil
                            batchResults = []
                            onConfirmFlash?(queue.summaryOnExit)
                            dismiss()
                            return
                        }
                        #endif
                        if mode == .choose {
                            dismiss()
                        } else {
                            intakeVM.reset()
                            mode = .choose
                        }
                    }
                }
            }
            #if os(iOS)
            .sheet(isPresented: $showLibrary) {
                // 批量为默认路径（DESIGN §F1）；每张仍由用户逐一拍板
                PhotoLibraryPicker(selectionLimit: BatchIntakeQueue.maxSelection) { results in
                    showLibrary = false
                    startBatch(results)
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showCamera) {
                CameraCapturePicker { data in
                    showCamera = false
                    handleCapture(data)
                }
                .ignoresSafeArea()
            }
            #endif
        }
    }

    private var title: String {
        switch mode {
        case .choose: return IntakeEmptyCopy.chooseTitle
        case .manual: return "Manual add"
        case .intake: return "Confirm item"
        }
    }

    private var chooseBody: some View {
        VStack(spacing: 14) {
            // Caption + error only: combined VO; CTAs stay separate focus targets.
            VStack(spacing: 8) {
                Text(IntakeEmptyCopy.description)
                    .font(.subheadline).foregroundStyle(DS.muted)
                    .multilineTextAlignment(.center)
                if !message.isEmpty {
                    Text(message).font(.caption).foregroundStyle(.orange)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(IntakeEmptyCopy.chooseAccessibilityLabel(message: message))
            #if os(iOS)
            Button {
                showLibrary = true
            } label: {
                primaryLabel(BatchIntakeCopy.chooseTitle, systemImage: "photo.on.rectangle")
            }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    showCamera = true
                } label: {
                    primaryLabel("Take photo", systemImage: "camera")
                }
            }
            #endif
            Button {
                mode = .manual
            } label: {
                secondaryLabel("Enter manually", systemImage: "keyboard")
            }
            Spacer()
        }
        .padding(20)
    }

    private var manualBody: some View {
        Form {
            TextField("Name", text: $draft.name)
            Picker("Type", selection: $draft.slotRaw) {
                // Same GarmentSlot set as Closet search / detail (incl. accessory + displayTitle).
                ForEach(GarmentSlot.allCases, id: \.rawValue) { s in
                    Text(s.displayTitle).tag(s.rawValue)
                }
            }
            Picker("Occasion", selection: $draft.occasion) {
                ForEach(["work", "casual", "date", "gala"], id: \.self) {
                    Text($0.capitalized).tag($0)
                }
            }
            // 温区/颜色必须在**入库当场**可填：此前这里硬写 light + 中性，
            // 冷天推荐必空、配色打分恒中性，用户还得逐件进详情页纠正。
            Section("Warmth") { WarmthPicker(warmthRaw: $draft.warmthRaw) }
            Section("Color") { ColorSwatchPicker(paletteID: $draft.colorPaletteID) }
            if !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.orange)
                    .accessibilityLabel(message)
            }
            Button("Save") {
                // 落库唯一真相（断关系 + rollback 的原子性也在里面）
                guard let item = draft.commit(into: wardrobe, context: context) else {
                    message = QuickAddDraft.saveFailedMessage
                    return
                }
                AppLog.info("manualAdd item=\(AppLog.ref(item.id)) slot=\(item.slotRaw)", .intake)
                dismiss()
            }
            .disabled(!draft.canCommit)
        }
    }

    private var intakeConfirmBody: some View {
        Group {
            if intakeVM.isProcessing {
                ProgressView(IntakeEmptyCopy.processingDescription)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(
                        IntakeEmptyCopy.accessibilityLabel(isProcessing: true))
            } else if let draft = Binding($intakeVM.draft) {
                Form {
                    if let data = intakeVM.mattedImage {
                        Section {
                            #if canImport(UIKit)
                            if let ui = UIImage(data: data) {
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 220)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: DS.radius))
                            }
                            #endif
                        }
                    }
                    if let queue = batchQueue, !queue.progressCaption.isEmpty {
                        Section {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(queue.progressCaption)
                                    .font(.caption.weight(.semibold))
                                ProgressView(
                                    value: Double(queue.index), total: Double(max(1, queue.total)))
                                    .tint(DS.accent)
                                if !batchNotice.isEmpty {
                                    Text(batchNotice)
                                        .font(.caption2).foregroundStyle(DS.muted)
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(queue.progressCaption)
                        }
                    }
                    Section("Details") {
                        TextField("Name", text: draft.name)
                        Picker("Type", selection: draft.slot) {
                            ForEach(GarmentSlot.allCases, id: \.self) {
                                Text($0.displayTitle).tag($0)
                            }
                        }
                        // Same occasion set as manual add — empty tags still get a Today-matchable default.
                        Picker("Occasion", selection: occasionBinding(draft)) {
                            ForEach(["work", "casual", "date", "gala"], id: \.self) {
                                Text($0.capitalized).tag($0)
                            }
                        }
                        TextField("Brand", text: brandBinding(draft))
                        TextField("Size", text: sizeBinding(draft))
                        if let sizeHint = PublicSizeReference.displayHint(
                            forLabel: draft.wrappedValue.size ?? ""),
                           !(draft.wrappedValue.size ?? "").isEmpty {
                            Text(sizeHint)
                                .font(.caption2)
                                .foregroundStyle(DS.muted)
                        }
                        TextField("Barcode (UPC/EAN)", text: barcodeBinding(draft))
                        Button("Lookup product (Open Facts)") {
                            let code = draft.wrappedValue.barcode ?? ""
                            Task { await intakeVM.enrichFromPublicBarcode(code) }
                        }
                        .disabled((draft.wrappedValue.barcode ?? "").filter(\.isNumber).count < 8)
                        Text(IntakeServiceFactory.barcodeEntryCaption)
                            .font(.caption2)
                            .foregroundStyle(DS.muted)
                    }
                    // 识别只给建议，不替用户拍板：温区/颜色在确认页当场可改，
                    // 未识别出的保持「未知」而不是被填成薄款中性。
                    Section("Warmth") {
                        WarmthPicker(warmthRaw: warmthBinding(draft))
                    }
                    Section("Color") {
                        ColorSwatchPicker(paletteID: colorBinding(draft))
                    }
                    if let err = intakeVM.lastError, !err.isEmpty {
                        Section {
                            Text(err).font(.caption).foregroundStyle(.orange)
                                .accessibilityLabel(err)
                        }
                    } else if let status = intakeVM.statusMessage, !status.isEmpty {
                        // Barcode hit flash — muted success (not orange fail chrome).
                        Section {
                            Text(status).font(.caption).foregroundStyle(DS.muted)
                                .accessibilityLabel(status)
                        }
                    }
                    Section {
                        Button(batchQueue == nil
                               ? "Add to closet" : BatchIntakeCopy.addAndContinueTitle) {
                            if let item = intakeVM.confirm(into: wardrobe, context: context) {
                                AppLog.info("intake confirmed item=\(AppLog.ref(item.id))", .intake)
                                #if os(iOS)
                                if batchQueue != nil {
                                    // 批量：记账后推进下一张，汇总留到走完再一次说清
                                    recordBatch(.added)
                                    return
                                }
                                #endif
                                // Sheet dismisses now — hand any post-save honesty flash
                                // (matting/layer/image save failed) to the parent first.
                                if let flash = Self.postConfirmFlash(
                                    statusMessage: intakeVM.statusMessage) {
                                    onConfirmFlash?(flash)
                                }
                                dismiss()
                            }
                        }
                        .disabled(!intakeVM.canConfirm)
                        #if os(iOS)
                        // 批量里必须能跳过——不想要的那张不该逼用户入库或整批放弃
                        if batchQueue != nil {
                            Button(BatchIntakeCopy.skipTitle, role: .cancel) {
                                recordBatch(.skipped)
                            }
                        }
                        #endif
                    } footer: {
                        if !intakeVM.canConfirm {
                            Text("Name this piece so it shows up clearly in your closet.")
                        } else {
                            Text("Barcode lookup uses Open Product/Beauty/Food Facts (public, no key). Apparel coverage is thin — miss is normal.")
                        }
                    }
                }
            } else {
                ContentUnavailableView {
                    Label(
                        intakeVM.lastError == nil ? "No photo yet" : "Couldn't use that photo",
                        systemImage: "exclamationmark.triangle")
                } description: {
                    Text(intakeVM.lastError
                         ?? "Pick a photo to cut out, or enter details by hand. Type and brand stay starter guesses.")
                } actions: {
                    #if os(iOS)
                    // 批量里这张处理不了时必须能**继续这一批**——
                    // 否则一张坏图就把用户甩出队列，剩下的全没了下文
                    if batchQueue != nil {
                        Button(BatchIntakeCopy.skipTitle) { recordBatch(.failed) }
                            .buttonStyle(.borderedProminent)
                            .tint(DS.accent)
                    }
                    #endif
                    if batchQueue == nil {
                        Button("Choose another photo") {
                            intakeVM.reset()
                            mode = .choose
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(DS.accent)
                    } else {
                        // 批量里「换一张」会丢掉整个队列 —— 降级为次级动作
                        Button("Choose another photo") {
                            intakeVM.reset()
                            mode = .choose
                        }
                    }
                    Button("Enter manually") {
                        intakeVM.reset()
                        mode = .manual
                    }
                }
            }
        }
    }

    #if os(iOS)
    /// 开始一批。超上限**明说**后截断，不静默丢弃用户的选择。
    private func startBatch(_ results: [PHPickerResult]) {
        guard !results.isEmpty else {
            message = "No image selected."
            return
        }
        batchNotice = BatchIntakeQueue.truncationNotice(picked: results.count) ?? ""
        batchResults = Array(results.prefix(BatchIntakeQueue.maxSelection))
        batchQueue = BatchIntakeQueue(total: batchResults.count)
        Task { await advanceBatch() }
    }

    /// 载入当前这张进确认页。读不出来记 `.failed` 并继续，不静默跳过。
    private func advanceBatch() async {
        guard var queue = batchQueue else { return }
        while !queue.isFinished {
            let idx = queue.index
            guard idx < batchResults.count else { break }
            guard let data = await BatchImageLoader.load(batchResults[idx]) else {
                queue.record(.failed)
                batchQueue = queue
                continue
            }
            batchQueue = queue
            message = ""
            mode = .intake
            await intakeVM.process(data)
            return   // 停在确认页等用户拍板
        }
        finishBatch(queue)
    }

    /// 用户对当前这张拍板后推进。
    private func recordBatch(_ outcome: BatchIntakeQueue.Outcome) {
        guard var queue = batchQueue else { return }
        queue.record(outcome)
        batchQueue = queue
        intakeVM.reset()
        Task { await advanceBatch() }
    }

    private func finishBatch(_ queue: BatchIntakeQueue) {
        batchQueue = nil
        batchResults = []
        onConfirmFlash?(queue.summary)
        dismiss()
    }
    #endif

    private func handleCapture(_ data: Data?) {
        guard let data else {
            message = "No image selected."
            return
        }
        message = ""
        mode = .intake
        Task {
            await intakeVM.process(data)
            // No local `message` mirror: it only renders in choose/manual modes,
            // and the intake empty state already reads intakeVM.lastError.
        }
    }

    private func brandBinding(_ draft: Binding<IntakeDraft>) -> Binding<String> {
        Binding(
            get: { draft.wrappedValue.brand ?? "" },
            set: { draft.wrappedValue.brand = $0.isEmpty ? nil : $0 })
    }

    /// 温区：`Warmth?` ↔ 控件的 `Int?`（nil 一路保持为「未知」，不落成默认档）。
    private func warmthBinding(_ draft: Binding<IntakeDraft>) -> Binding<Int?> {
        Binding(
            get: { draft.wrappedValue.warmth?.rawValue },
            set: { draft.wrappedValue.warmth = $0.flatMap(Warmth.init(rawValue:)) })
    }

    /// 颜色：`GarmentColor?` ↔ 色板 id。识别给出的连续色相按最近色板回显，
    /// 用户没动就原样保留（不因为打开过确认页就把色相量化改写）。
    private func colorBinding(_ draft: Binding<IntakeDraft>) -> Binding<String?> {
        Binding(
            get: {
                guard let c = draft.wrappedValue.color else { return nil }
                return GarmentColorPalette.nearest(to: c)?.id
            },
            set: { id in
                guard let entry = GarmentColorPalette.entry(id: id) else {
                    draft.wrappedValue.color = nil
                    return
                }
                draft.wrappedValue.color = GarmentColor(
                    hueDegrees: entry.hueDegrees, isNeutral: entry.isNeutral)
            })
    }

    private func barcodeBinding(_ draft: Binding<IntakeDraft>) -> Binding<String> {
        Binding(
            get: { draft.wrappedValue.barcode ?? "" },
            set: { draft.wrappedValue.barcode = $0.isEmpty ? nil : $0 })
    }

    private func sizeBinding(_ draft: Binding<IntakeDraft>) -> Binding<String> {
        Binding(
            get: { draft.wrappedValue.size ?? "" },
            set: { draft.wrappedValue.size = $0.isEmpty ? nil : $0 })
    }

    /// Primary occasion for photo confirm (manual add parity). Prefer existing tag/user pick.
    private func occasionBinding(_ draft: Binding<IntakeDraft>) -> Binding<String> {
        let known = ["work", "casual", "date", "gala"]
        return Binding(
            get: {
                let set = draft.wrappedValue.occasions
                if let hit = known.first(where: { set.contains($0) }) { return hit }
                return set.sorted().first ?? "casual"
            },
            set: { primary in
                var next = draft.wrappedValue.occasions.filter { !known.contains($0) }
                next.insert(primary)
                if primary != "casual" { next.insert("casual") }
                draft.wrappedValue.occasions = next
            })
    }

    private func primaryLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(DS.accent)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: DS.radius))
    }

    private func secondaryLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(DS.surface)
            .foregroundStyle(DS.ink)
            .clipShape(RoundedRectangle(cornerRadius: DS.radius))
    }
}
