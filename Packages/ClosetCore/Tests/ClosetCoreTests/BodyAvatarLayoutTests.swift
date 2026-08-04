import Testing
@testable import ClosetCore

struct BodyAvatarLayoutTests {

    @Test func anchorsCoverAllSlotsWithValidRects() {
        for slot in BodyAvatarSlot.allCases {
            let f = BodyAvatarAnchors.frame(for: slot)
            #expect(f.x >= 0 && f.y >= 0)
            #expect(f.width > 0 && f.height > 0)
            #expect(f.x + f.width <= 1.001)
            #expect(f.y + f.height <= 1.001)
        }
    }

    @Test func zOrderShoesUnderOuterwear() {
        #expect(BodyAvatarAnchors.zIndex(for: .shoes) < BodyAvatarAnchors.zIndex(for: .bottom))
        #expect(BodyAvatarAnchors.zIndex(for: .bottom) < BodyAvatarAnchors.zIndex(for: .top))
        #expect(BodyAvatarAnchors.zIndex(for: .top) < BodyAvatarAnchors.zIndex(for: .outerwear))
    }

    @Test func defaultFitPullsTopsUpForShoulder() {
        let top = BodyAvatarLayer.defaultFit(for: .top)
        #expect(top.scale > 1.0)
        #expect(top.offsetY < 0)
        let shoes = BodyAvatarLayer.defaultFit(for: .shoes)
        #expect(shoes.offsetY >= 0)
    }

    @Test func composerAppliesDefaultFit() {
        let layers = BodyAvatarComposer.layers(slots: [.top: "tee"])
        #expect(layers.count == 1)
        #expect(layers[0].fitScale > 1.0)
        #expect(layers[0].fitOffsetY < 0)
    }

    @Test func garmentLayoutAppliesFitScaleAndOffset() {
        let base = BodyAvatarLayer(
            id: "t", slot: .top,
            frame: BodyAvatarAnchors.frame(for: .top),
            zIndex: 3, fitScale: 1.0, fitOffsetY: 0)
        let fitted = BodyAvatarLayer(
            id: "t2", slot: .top,
            frame: BodyAvatarAnchors.frame(for: .top),
            zIndex: 3, fitScale: 1.08, fitOffsetY: -0.02)
        let morph = BodyMorphParams.neutral
        let a = BodyAvatarGarmentLayout.pixelFrame(
            layer: base, canvasWidth: 100, canvasHeight: 150, morph: morph)
        let b = BodyAvatarGarmentLayout.pixelFrame(
            layer: fitted, canvasWidth: 100, canvasHeight: 150, morph: morph)
        #expect(b.width > a.width)
        #expect(b.height > a.height)
        // 负 offsetY → 框整体上移（midY 更小）
        #expect((b.y + b.height / 2) < (a.y + a.height / 2))
    }

    @Test func garmentLayoutRespectsMorphWidth() {
        let layer = BodyAvatarLayer(
            id: "t", slot: .top,
            frame: BodyAvatarAnchors.frame(for: .top),
            zIndex: 3, fitScale: 1.0, fitOffsetY: 0)
        let wide = BodyMorphParams(chest: 1.1, waist: 1.0, hip: 1.0, shoulder: 1.05, height: 1)
        let narrow = BodyMorphParams(chest: 0.92, waist: 1.0, hip: 1.0, shoulder: 0.95, height: 1)
        let w = BodyAvatarGarmentLayout.pixelFrame(
            layer: layer, canvasWidth: 200, canvasHeight: 300, morph: wide)
        let n = BodyAvatarGarmentLayout.pixelFrame(
            layer: layer, canvasWidth: 200, canvasHeight: 300, morph: narrow)
        #expect(w.width > n.width)
    }

    @Test func fullCanvasVisualLargerThanSlotFrame() {
        // 有图层按全身画布铺，避免「槽位套槽位」双重缩小
        let visual = BodyAvatarLayer(
            id: "tee", slot: .top,
            frame: BodyAvatarAnchors.frame(for: .top),
            zIndex: 3,
            localRelativePath: "ItemImages/x.png",
            fitScale: 1.0, fitOffsetY: 0)
        let placeholder = BodyAvatarLayer(
            id: "ph", slot: .top,
            frame: BodyAvatarAnchors.frame(for: .top),
            zIndex: 3, fitScale: 1.0, fitOffsetY: 0)
        let morph = BodyMorphParams.neutral
        let full = BodyAvatarGarmentLayout.displayFrame(
            layer: visual, canvasWidth: 200, canvasHeight: 300, morph: morph)
        let slot = BodyAvatarGarmentLayout.displayFrame(
            layer: placeholder, canvasWidth: 200, canvasHeight: 300, morph: morph)
        #expect(visual.hasVisual)
        #expect(!placeholder.hasVisual)
        #expect(full.width > slot.width * 1.2)
        #expect(full.height > slot.height * 1.5)
        #expect(abs(full.x + full.width / 2 - 100) < 1)
    }

    @Test func scaleClampsExtremeMeasurements() {
        let tiny = BodyMeasurements(bust: 20, waist: 18, hip: 22, highHip: 20)
        let s = BodyAvatarScaler.scale(from: tiny)
        #expect(s.widthScale >= 0.88)
        let huge = BodyMeasurements(bust: 60, waist: 55, hip: 65, highHip: 60)
        let h = BodyAvatarScaler.scale(from: huge)
        #expect(h.widthScale <= 1.14)
    }

    @Test func scaleNeutralNearOne() {
        let m = BodyMeasurements(bust: 36, waist: 28, hip: 38, highHip: 34)
        let s = BodyAvatarScaler.scale(from: m)
        #expect(abs(s.widthScale - 1.0) < 0.05)
    }

    @Test func dressDropsTopAndBottom() {
        let layers = BodyAvatarComposer.layers(slots: [
            .dress: "dressA", .top: "topA", .bottom: "botA", .shoes: "shoeA"
        ])
        let slots = Set(layers.map(\.slot))
        #expect(slots.contains(.dress))
        #expect(!slots.contains(.top))
        #expect(!slots.contains(.bottom))
        #expect(slots.contains(.shoes))
        #expect(layers.map(\.zIndex) == layers.map(\.zIndex).sorted())
    }

    @Test func assetNamesForAllPopularShapes() {
        for shape in PopularShape.allCases {
            let n = BodyAvatarAsset.croquisName(for: shape)
            #expect(n.hasPrefix("croquis_"))
            #expect(n.contains("yaw000"))
        }
        #expect(BodyAvatarAsset.allNames.count == PopularShape.allCases.count * BodyAvatarYaw.allCases.count)
        #expect(BodyAvatarAsset.angleCount == 8)
    }

    @Test func yawStepsWrapAround() {
        #expect(BodyAvatarYaw.deg0.stepped(by: 1) == .deg45)
        #expect(BodyAvatarYaw.deg315.stepped(by: 1) == .deg0)
        #expect(BodyAvatarYaw.deg0.stepped(by: -1) == .deg315)
        #expect(BodyAvatarYaw.deg90.stepped(by: 2) == .deg180)
    }

    @Test func yawNearestSnapsTo45() {
        #expect(BodyAvatarYaw.nearest(degrees: 10) == .deg0)
        #expect(BodyAvatarYaw.nearest(degrees: 50) == .deg45)
        #expect(BodyAvatarYaw.nearest(degrees: 200) == .deg180)
        #expect(BodyAvatarYaw.nearest(degrees: -10) == .deg0)
    }

    @Test func multiAngleAssetNamesUnique() {
        let names = BodyAvatarAsset.allNames
        #expect(Set(names).count == names.count)
        #expect(BodyAvatarAsset.croquisName(for: .pear, yaw: .deg180) == "croquis_pear_yaw180")
    }

    @Test func resolveShapeDefaultsRectangleWhenNil() {
        #expect(BodyAvatarComposer.resolveShape(from: nil) == .rectangle)
    }

    @Test func mapSlotUnderstandsAliases() {
        #expect(BodyAvatarComposer.mapSlot("outer") == .outerwear)
        #expect(BodyAvatarComposer.mapSlot("top") == .top)
        #expect(BodyAvatarComposer.mapSlot("accessory") == nil)
    }

    @Test func layersPreferLocalRelativePath() {
        let layers = BodyAvatarComposer.layers(slotImages: [
            .top: BodyAvatarSlotImage(id: "a", localRelativePath: "ItemImages/a.jpg"),
            .bottom: BodyAvatarSlotImage(id: "b", bundleName: "bot"),
            .shoes: BodyAvatarSlotImage(id: "c"),
        ])
        #expect(layers.count == 3)
        #expect(layers.first(where: { $0.slot == .top })?.localRelativePath == "ItemImages/a.jpg")
        #expect(layers.first(where: { $0.slot == .top })?.hasVisual == true)
        #expect(layers.first(where: { $0.slot == .shoes })?.hasVisual == false)
    }
}
