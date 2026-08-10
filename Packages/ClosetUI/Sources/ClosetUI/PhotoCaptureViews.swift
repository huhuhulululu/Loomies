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
    var onPicked: (Data?) -> Void

    public func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    public func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    public func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    public final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPicked: (Data?) -> Void
        init(onPicked: @escaping (Data?) -> Void) { self.onPicked = onPicked }

        public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                onPicked(nil)
                return
            }
            provider.loadObject(ofClass: UIImage.self) { obj, _ in
                let data = (obj as? UIImage).flatMap { $0.jpegData(compressionQuality: 0.9) }
                DispatchQueue.main.async { self.onPicked(data) }
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
    @State private var name = ""
    @State private var slot = "top"
    @State private var occasion = "work"
    @State private var message = ""

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
                PhotoLibraryPicker { data in
                    showLibrary = false
                    handleCapture(data)
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
                primaryLabel("Choose from Photos", systemImage: "photo.on.rectangle")
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
            TextField("Name", text: $name)
            Picker("Type", selection: $slot) {
                // Same GarmentSlot set as Closet search / detail (incl. accessory + displayTitle).
                ForEach(GarmentSlot.allCases, id: \.rawValue) { s in
                    Text(s.displayTitle).tag(s.rawValue)
                }
            }
            Picker("Occasion", selection: $occasion) {
                ForEach(["work", "casual", "date", "gala"], id: \.self) {
                    Text($0.capitalized).tag($0)
                }
            }
            if !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.orange)
                    .accessibilityLabel(message)
            }
            Button("Save") {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                let item = Item(name: trimmed)
                // Same persistSlot truth as photo confirm (blazer name → outerwear).
                let draftSlot = GarmentSlot(rawValue: slot) ?? .top
                item.slotRaw = IntakeViewModel.persistSlot(draftSlot: draftSlot, name: trimmed).rawValue
                // Picker occasion may already be "casual" — dedup at write (parity QuickAddSheet).
                item.occasionsRaw = QuickAddSheet.dedupOccasions([occasion, "casual"])
                item.warmthRaw = Warmth.light.rawValue
                item.statusRaw = "available"
                item.colorIsNeutral = true
                item.wardrobe = wardrobe
                context.insert(item)
                guard ModelSave.save(context, label: "quickAdd") else {
                    context.delete(item)
                    message = IntakeViewModel.confirmSaveFailedMessage
                    AppLog.error("manualAdd save failed", .intake)
                    return
                }
                AppLog.info("manualAdd item=\(AppLog.ref(item.id)) slot=\(item.slotRaw)", .intake)
                dismiss()
            }
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                        Button("Add to closet") {
                            if let item = intakeVM.confirm(into: wardrobe, context: context) {
                                AppLog.info("intake confirmed item=\(AppLog.ref(item.id))", .intake)
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
                    Button("Choose another photo") {
                        intakeVM.reset()
                        mode = .choose
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.accent)
                    Button("Enter manually") {
                        intakeVM.reset()
                        mode = .manual
                    }
                }
            }
        }
    }

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
