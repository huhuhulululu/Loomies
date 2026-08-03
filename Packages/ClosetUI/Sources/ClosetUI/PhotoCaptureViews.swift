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

// MARK: - PHPicker (iOS)

#if os(iOS)
/// 系统相册选图 → JPEG Data。
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
                let data = (obj as? UIImage).flatMap {
                    $0.jpegData(compressionQuality: 0.9)
                }
                DispatchQueue.main.async { self.onPicked(data) }
            }
        }
    }
}
#endif

// MARK: - Closet + sheet

/// Closet「+」：相册入库（mock 打标）或手填快捷。
public struct AddPieceSheet: View {
    let wardrobe: Wardrobe
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .choose
    @State private var showPicker = false
    @State private var intakeVM = IntakeViewModel(
        matting: MockMattingService(),
        tagging: MockTaggingService(tags: ItemTags(
            slot: .top,
            color: GarmentColor(hueDegrees: 0, isNeutral: true),
            occasions: ["casual", "work"], warmth: .light)),
        ocr: MockOCRService(info: LabelInfo()))
    @State private var name = ""
    @State private var slot = "top"
    @State private var occasion = "work"
    @State private var message = ""

    enum Mode { case choose, manual, intake }

    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    public var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .choose: chooseBody
                case .manual: manualBody
                case .intake: intakeBody
                }
            }
            .navigationTitle(mode == .manual ? "Manual add" : "Add piece")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            #if os(iOS)
            .sheet(isPresented: $showPicker) {
                PhotoLibraryPicker { data in
                    showPicker = false
                    guard let data else {
                        message = "No photo selected."
                        return
                    }
                    mode = .intake
                    Task {
                        await intakeVM.process(data)
                        AppLog.info("photo intake bytes=\(data.count)", .intake)
                    }
                }
                .ignoresSafeArea()
            }
            #endif
        }
    }

    private var chooseBody: some View {
        VStack(spacing: 16) {
            Text("Add a garment photo or enter details by hand.")
                .font(.subheadline).foregroundStyle(DS.muted)
                .multilineTextAlignment(.center)
            #if os(iOS)
            Button {
                showPicker = true
            } label: {
                Label("Choose from Photos", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(DS.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: DS.radius))
            }
            #endif
            Button {
                mode = .manual
            } label: {
                Label("Enter manually", systemImage: "keyboard")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(DS.surface)
                    .foregroundStyle(DS.ink)
                    .clipShape(RoundedRectangle(cornerRadius: DS.radius))
            }
            if !message.isEmpty {
                Text(message).font(.caption).foregroundStyle(.orange)
            }
            Spacer()
        }
        .padding(20)
    }

    private var manualBody: some View {
        Form {
            TextField("Name", text: $name)
            Picker("Type", selection: $slot) {
                ForEach(["top", "bottom", "dress", "outerwear", "shoes", "accessory"], id: \.self) {
                    Text($0.capitalized).tag($0)
                }
            }
            Picker("Occasion", selection: $occasion) {
                ForEach(["work", "casual", "date", "gala"], id: \.self) {
                    Text($0.capitalized).tag($0)
                }
            }
            Button("Save") {
                let item = Item(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
                item.slotRaw = slot
                item.occasionsRaw = [occasion, "casual"]
                item.warmthRaw = Warmth.light.rawValue
                item.statusRaw = "available"
                item.colorIsNeutral = true
                item.wardrobe = wardrobe
                context.insert(item)
                ModelSave.save(context, label: "quickAdd")
                AppLog.info("manualAdd \(item.name)", .intake)
                dismiss()
            }
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var intakeBody: some View {
        IntakeView(vm: intakeVM, wardrobe: wardrobe) {
            // 已在 picker 中喂过 data；再点拍时重新选
            #if os(iOS)
            await withCheckedContinuation { cont in
                showPicker = true
                // 简化：二次选择走 manual
                cont.resume(returning: nil as Data?)
            }
            #else
            return nil
            #endif
        }
    }
}
