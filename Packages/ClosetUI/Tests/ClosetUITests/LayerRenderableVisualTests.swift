import Foundation
import Testing
import ClosetCore
import ClosetModel
@testable import ClosetUI

@Suite("Layer renderable visual (hasVisual vs load)")
struct LayerRenderableVisualTests {

    @Test func missingLocalPathIsNotRenderableDespiteHasVisual() {
        let layer = BodyAvatarLayer(
            id: "ghost-top",
            slot: .top,
            frame: BodyAvatarAnchors.frame(for: .top),
            zIndex: 2,
            localRelativePath: "ItemImages/does-not-exist-\(UUID().uuidString).png")
        #expect(layer.hasVisual, "metadata still claims a path")
        #expect(BodyAvatarView.layerImage(layer) == nil)
        #expect(!BodyAvatarView.hasRenderableVisual(layer))
    }

    @Test func emptyLayerIsNeitherHasVisualNorRenderable() {
        let layer = BodyAvatarLayer(
            id: "bare",
            slot: .bottom,
            frame: BodyAvatarAnchors.frame(for: .bottom),
            zIndex: 1)
        #expect(!layer.hasVisual)
        #expect(!BodyAvatarView.hasRenderableVisual(layer))
    }

    @Test func loadableLocalImageIsRenderable() throws {
        let id = UUID()
        // Minimal valid 1×1 PNG
        let png = Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")!
        let rel = try #require(ItemImageStore.save(data: png, for: id, ext: "png"))
        defer { ItemImageStore.delete(relativePath: rel) }

        let layer = BodyAvatarLayer(
            id: id.uuidString,
            slot: .top,
            frame: BodyAvatarAnchors.frame(for: .top),
            zIndex: 2,
            localRelativePath: rel)
        #expect(layer.hasVisual)
        #expect(BodyAvatarView.hasRenderableVisual(layer))
        #expect(BodyAvatarView.layerImage(layer) != nil)
    }

    @Test func corruptLocalBytesNotRenderableDespiteHasVisual() throws {
        let id = UUID()
        let rel = try #require(ItemImageStore.save(data: Data("not-an-image".utf8), for: id, ext: "png"))
        defer { ItemImageStore.delete(relativePath: rel) }

        let layer = BodyAvatarLayer(
            id: id.uuidString,
            slot: .outerwear,
            frame: BodyAvatarAnchors.frame(for: .outerwear),
            zIndex: 3,
            localRelativePath: rel)
        #expect(layer.hasVisual)
        #expect(ItemImageStore.loadData(relativePath: rel) != nil, "bytes exist on disk")
        #expect(BodyAvatarView.layerImage(layer) == nil, "decode must fail")
        #expect(!BodyAvatarView.hasRenderableVisual(layer))
    }

    @Test func heroCaptionDoesNotClaimVisibleWhenOnlyPlaceholders() {
        let ghost = BodyAvatarLayer(
            id: "ghost",
            slot: .top,
            frame: BodyAvatarAnchors.frame(for: .top),
            zIndex: 2,
            localRelativePath: "ItemImages/missing-\(UUID().uuidString).png")
        #expect(ghost.hasVisual)
        #expect(OutfitAvatarComposer.hasVisibleGarments([ghost]), "path-only API still true")
        let caption = CopilotHeroFitCaption.text(
            layers: [ghost],
            hasSelectedSuggestion: true,
            hasAnchors: false,
            isColdStart: false)
        #expect(caption.contains("add item photos"))
        #expect(!caption.contains("proportion guide"))
    }

    /// Gap: empty-dress capsule used to gate only on `heroLayers.isEmpty`, so
    /// path-only / failed-decode layers suppressed the overlay (placeholders only).
    @Test func emptyDressOverlayShowsForPlaceholderOnlyLayers() throws {
        #expect(CopilotEmptyDressOverlay.shouldShow(layers: []))

        let ghost = BodyAvatarLayer(
            id: "ghost-top",
            slot: .top,
            frame: BodyAvatarAnchors.frame(for: .top),
            zIndex: 2,
            localRelativePath: "ItemImages/missing-\(UUID().uuidString).png")
        #expect(ghost.hasVisual)
        #expect(!BodyAvatarView.hasRenderableVisual(ghost))
        #expect(CopilotEmptyDressOverlay.shouldShow(layers: [ghost]))

        let bare = BodyAvatarLayer(
            id: "bare",
            slot: .bottom,
            frame: BodyAvatarAnchors.frame(for: .bottom),
            zIndex: 1)
        #expect(CopilotEmptyDressOverlay.shouldShow(layers: [bare, ghost]))

        let id = UUID()
        let png = Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")!
        let rel = try #require(ItemImageStore.save(data: png, for: id, ext: "png"))
        defer { ItemImageStore.delete(relativePath: rel) }
        let real = BodyAvatarLayer(
            id: id.uuidString,
            slot: .top,
            frame: BodyAvatarAnchors.frame(for: .top),
            zIndex: 2,
            localRelativePath: rel)
        #expect(BodyAvatarView.hasRenderableVisual(real))
        #expect(!CopilotEmptyDressOverlay.shouldShow(layers: [real]))
        #expect(!CopilotEmptyDressOverlay.shouldShow(layers: [ghost, real]))
    }

    /// Placeholder VoiceOver uses GarmentSlot.displayTitle, not raw enum/slotRaw.
    @Test func slotAccessibilityLabelUsesDisplayTitleNotRaw() {
        #expect(BodyAvatarView.slotAccessibilityLabel(.outerwear) == "Outerwear")
        #expect(BodyAvatarView.slotAccessibilityLabel(.top) == "Top")
        #expect(BodyAvatarView.slotAccessibilityLabel(.bottom) == "Bottom")
        #expect(BodyAvatarView.slotAccessibilityLabel(.shoes) == "Shoes")
        #expect(BodyAvatarView.slotAccessibilityLabel(.dress) == "Dress")
        for slot in BodyAvatarSlot.allCases {
            let label = BodyAvatarView.slotAccessibilityLabel(slot)
            #expect(label != slot.rawValue)
            #expect(label == label.capitalized || label.contains(" "))
        }
    }

    /// Gap: all-failed-decode look rendered colored slot placeholders while the
    /// capsule said "Undressed" — suppress placeholders when nothing decodes.
    @Test func onCanvasGarmentLayersSuppressesPlaceholdersWhenNothingDecodes() throws {
        let ghost = BodyAvatarLayer(
            id: "ghost-top",
            slot: .top,
            frame: BodyAvatarAnchors.frame(for: .top),
            zIndex: 2,
            localRelativePath: "ItemImages/missing-\(UUID().uuidString).png")
        let ghost2 = BodyAvatarLayer(
            id: "ghost-bottom",
            slot: .bottom,
            frame: BodyAvatarAnchors.frame(for: .bottom),
            zIndex: 1,
            localRelativePath: "ItemImages/missing-\(UUID().uuidString).png")

        #expect(BodyAvatarView.onCanvasGarmentLayers([]).isEmpty)
        #expect(BodyAvatarView.onCanvasGarmentLayers([ghost]).isEmpty)
        #expect(BodyAvatarView.onCanvasGarmentLayers([ghost, ghost2]).isEmpty)

        // Partial decode: keep all layers — failed slots still render placeholders.
        let id = UUID()
        let png = Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")!
        let rel = try #require(ItemImageStore.save(data: png, for: id, ext: "png"))
        defer { ItemImageStore.delete(relativePath: rel) }
        let real = BodyAvatarLayer(
            id: id.uuidString,
            slot: .top,
            frame: BodyAvatarAnchors.frame(for: .top),
            zIndex: 2,
            localRelativePath: rel)
        let mixed = BodyAvatarView.onCanvasGarmentLayers([ghost, real])
        #expect(mixed.count == 2)
    }
}
