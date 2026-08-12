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

    @Test func zIndexDistinctAcrossCoexistingSlots() {
        // 叠层确定性：可同时出现的槽位 zIndex 必须互不相同。
        // top 与 dress 互斥（composer 中 dress 会剔除 top/bottom），共享 z=3 是有意为之。
        var z: [BodyAvatarSlot: Int] = [:]
        for slot in BodyAvatarSlot.allCases {
            z[slot] = BodyAvatarAnchors.zIndex(for: slot)
        }
        #expect(z.count == BodyAvatarSlot.allCases.count)
        // top/dress 是唯一的共享对；其余两两不同
        #expect(z[.top] == z[.dress])
        let coexisting: [BodyAvatarSlot] = [.outerwear, .top, .bottom, .shoes]
        let coexistingZ = coexisting.map { z[$0]! }
        #expect(Set(coexistingZ).count == coexistingZ.count)
        // 顺序钉死：鞋 < 下装 < 上装/裙 < 外套
        #expect(z[.shoes]! < z[.bottom]!)
        #expect(z[.bottom]! < z[.top]!)
        #expect(z[.top]! < z[.outerwear]!)
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

    @Test func scaleInvalidMeasurementsStayNeutral() {
        // NaN/≤0 围度 → 该字段中性 1.0（与 BodyMorphParams.from 一致），不得钳到极瘦 scaleLo
        let nanBust = BodyMeasurements(bust: .nan, waist: 28, hip: 38, highHip: 34)
        let s = BodyAvatarScaler.scale(from: nanBust)
        #expect(s.widthScale == 1)
        #expect(s.hipScale == 1)
        #expect(s.waistScale == 1)
        let zeroHip = BodyMeasurements(bust: 36, waist: 28, hip: 0, highHip: 0)
        let z = BodyAvatarScaler.scale(from: zeroHip)
        #expect(z.widthScale == 1)
        let infWaist = BodyMeasurements(bust: 36, waist: .infinity, hip: 38, highHip: 34)
        #expect(BodyAvatarScaler.scale(from: infWaist).waistScale == 1)
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
        #expect(BodyAvatarAsset.photorealFrontName(sex: .female) == "photoreal_female_front")
        #expect(BodyAvatarAsset.photorealFrontName(sex: .male) == "photoreal_male_front")
        #expect(
            BodyAvatarAsset.facePlateName(sex: .female, phenotype: .eastAsian)
                == "face_female_eastAsian")
        #expect(BodyAvatarAsset.facePlateFallbackName(sex: .male) == "face_male_eastAsian")
        // Phenotype-specific preferred; eastAsian is soft fallback only.
        #expect(
            BodyAvatarAsset.resolveFacePlateName(
                sex: .female,
                phenotype: .african,
                available: { $0 == "face_female_african" || $0 == "face_female_eastAsian" })
                == "face_female_african")
        #expect(
            BodyAvatarAsset.resolveFacePlateName(
                sex: .female,
                phenotype: .african,
                available: { $0 == "face_female_eastAsian" })
                == "face_female_eastAsian")
        #expect(
            BodyAvatarAsset.resolveFacePlateName(
                sex: .female,
                phenotype: .eastAsian,
                available: { _ in false }) == nil)
        #expect(BodyAvatarAsset.allFacePlateNames.count
            == AvatarBodySex.allCases.count * AvatarBodyPhenotype.allCases.count)
    }

    @Test func resolvePhotorealFrameUsesExactYawWithoutSilentFrontFallback() {
        let set: Set<String> = [
            "photoreal_female_front",
            "photoreal_female_yaw045",
            "photoreal_male_yaw315",
        ]
        #expect(
            BodyAvatarAsset.resolvePhotorealFrameName(
                sex: .female, phenotype: .eastAsian, yaw: .deg45,
                available: { set.contains($0) })
                == "photoreal_female_yaw045")
        #expect(
            BodyAvatarAsset.resolvePhotorealFrameName(
                sex: .female, phenotype: .eastAsian, yaw: .deg90,
                available: { set.contains($0) }) == nil)
        #expect(
            BodyAvatarAsset.resolvePhotorealFrameName(
                sex: .male, phenotype: .eastAsian, yaw: .deg315,
                available: { set.contains($0) })
                == "photoreal_male_yaw315")
        #expect(
            BodyAvatarAsset.resolvePhotorealFrontName(
                sex: .female, phenotype: .eastAsian,
                available: { set.contains($0) })
                == "photoreal_female_front")
    }

    /// Shape 维度（+64 正面档）：体型专属真图存在时优先命中——每人种不再只有一个
    /// 体型靠 warp 拉伸；缺 shape 帧时链路与无 shape 完全一致（向后兼容）。
    @Test func resolvePrefersShapeSpecificFrameWhenAvailable() {
        let set: Set<String> = [
            "photoreal_female_african_pear_front",
            "photoreal_female_african_front",
            "photoreal_female_front",
        ]
        // shape 专属正面优先
        #expect(
            BodyAvatarAsset.resolvePhotorealFrameName(
                sex: .female, phenotype: .african, shape: .pear, yaw: .deg0,
                available: { set.contains($0) })
                == "photoreal_female_african_pear_front")
        // 缺 shape 帧 → 回退表型正面（与旧链一致）
        #expect(
            BodyAvatarAsset.resolvePhotorealFrameName(
                sex: .female, phenotype: .african, shape: .hourglass, yaw: .deg0,
                available: { set.contains($0) })
                == "photoreal_female_african_front")
        // shape == nil → 行为与旧签名完全相同
        #expect(
            BodyAvatarAsset.resolvePhotorealFrameName(
                sex: .female, phenotype: .african, shape: nil, yaw: .deg0,
                available: { set.contains($0) })
                == "photoreal_female_african_front")
    }

    /// Shape × yaw（¾ 档预留）：转角也先找 shape 专属帧；缺帧不得跨人回退。
    @Test func resolveShapeYawFrameAndIdentityGuardStillHolds() {
        let set: Set<String> = [
            "photoreal_female_african_pear_yaw045",
            "photoreal_female_african_pear_front",
            "photoreal_female_african_front",
            "photoreal_female_yaw045",
        ]
        #expect(
            BodyAvatarAsset.resolvePhotorealFrameName(
                sex: .female, phenotype: .african, shape: .pear, yaw: .deg45,
                available: { set.contains($0) })
                == "photoreal_female_african_pear_yaw045")
        // 缺 shape yaw → 回退表型 yaw（无）→ D69 守卫：有表型正面不得用通用轨
        let noShapeYaw: Set<String> = [
            "photoreal_female_african_pear_front",
            "photoreal_female_african_front",
            "photoreal_female_yaw045",
        ]
        #expect(
            BodyAvatarAsset.resolvePhotorealFrameName(
                sex: .female, phenotype: .african, shape: .pear, yaw: .deg45,
                available: { noShapeYaw.contains($0) }) == nil)
    }

    /// 命名与清单：shape token 规则 + 正面档导入清单 2×8×5=80 + carriesShape 判定
    ///（View 靠它决定「真体型图命中时旁路 shape preset warp，防双重效果」）。
    @Test func shapeFrameNamingInventoryAndCarriesShape() {
        #expect(
            BodyAvatarAsset.photorealFrameName(
                sex: .male, phenotype: .latinx, shape: .invertedTriangle, yaw: .deg0)
                == "photoreal_male_latinx_invertedTriangle_front")
        #expect(
            BodyAvatarAsset.photorealFrameName(
                sex: .female, phenotype: .eastAsian, shape: .rectangle, yaw: .deg90)
                == "photoreal_female_eastAsian_rectangle_yaw090")
        let fronts = BodyAvatarAsset.allPhotorealShapeFrontNames
        #expect(fronts.count == 80)
        #expect(Set(fronts).count == 80)
        #expect(fronts.contains("photoreal_female_african_pear_front"))
        #expect(BodyAvatarAsset.photorealNameCarriesShape("photoreal_female_african_pear_front"))
        #expect(!BodyAvatarAsset.photorealNameCarriesShape("photoreal_female_african_front"))
        #expect(!BodyAvatarAsset.photorealNameCarriesShape("photoreal_female_yaw045"))
    }

    @Test func resolvePhotorealFrameDoesNotSwapIdentityForOtherPhenotypes() {
        // D69: african has own front + only generic sex yaw045 exists → do NOT use generic yaw
        let set: Set<String> = [
            "photoreal_female_african_front",
            "photoreal_female_yaw045",
            "photoreal_female_african_yaw045",
        ]
        #expect(
            BodyAvatarAsset.resolvePhotorealFrameName(
                sex: .female, phenotype: .african, yaw: .deg45,
                available: { set.contains($0) })
                == "photoreal_female_african_yaw045")
        let noPhenotypeYaw: Set<String> = [
            "photoreal_female_african_front",
            "photoreal_female_yaw045",
        ]
        #expect(
            BodyAvatarAsset.resolvePhotorealFrameName(
                sex: .female, phenotype: .african, yaw: .deg45,
                available: { noPhenotypeYaw.contains($0) }) == nil)
        // eastAsian still uses generic orbit when phenotype yaw missing
        #expect(
            BodyAvatarAsset.resolvePhotorealFrameName(
                sex: .female, phenotype: .eastAsian, yaw: .deg45,
                available: { noPhenotypeYaw.contains($0) || $0 == "photoreal_female_front" })
                == "photoreal_female_yaw045")
    }

    @Test func resolvePhotorealFrontPrefersPhenotypeThenGeneric() {
        let african = NudeBodyBaseSpec.photorealFrontName(sex: .male, phenotype: .african)
        #expect(
            BodyAvatarAsset.resolvePhotorealFrontName(
                sex: .male,
                phenotype: .african,
                available: { $0 == african }) == african)
        #expect(
            BodyAvatarAsset.resolvePhotorealFrontName(
                sex: .male,
                phenotype: .african,
                available: { $0 == "photoreal_male_front" })
                == "photoreal_male_front")
        #expect(
            BodyAvatarAsset.resolvePhotorealFrontName(
                sex: .female,
                phenotype: .eastAsian,
                available: { _ in false }) == nil)
        #expect(
            BodyAvatarAsset.photorealFrameName(sex: .female, yaw: .deg0)
                == "photoreal_female_front")
        #expect(
            BodyAvatarAsset.photorealFrameName(
                sex: .female, phenotype: .latinx, yaw: .deg135)
                == "photoreal_female_latinx_yaw135")
        #expect(
            BodyAvatarAsset.allPhotorealFrameNames.count
                == AvatarBodySex.allCases.count
                * AvatarBodyPhenotype.allCases.count
                * BodyAvatarYaw.allCases.count)
    }

    @Test func resolveShapeDefaultsRectangleWhenNil() {
        #expect(BodyAvatarComposer.resolveShape(from: nil) == .rectangle)
    }

    @Test func mapSlotUnderstandsAliases() {
        #expect(BodyAvatarComposer.mapSlot("outer") == .outerwear)
        #expect(BodyAvatarComposer.mapSlot("top") == .top)
        #expect(BodyAvatarComposer.mapSlot("accessory") == nil)
        #expect(BodyAvatarComposer.mapSlot("blazer") == .outerwear)
        #expect(BodyAvatarComposer.mapSlot("jacket") == .outerwear)
        #expect(BodyAvatarComposer.mapSlot("bomber") == .outerwear)
        #expect(BodyAvatarComposer.mapSlot("windbreaker") == .outerwear)
        #expect(BodyAvatarComposer.mapSlot("jeans") == .bottom)
        #expect(BodyAvatarComposer.mapSlot("trousers") == .bottom)
        #expect(BodyAvatarComposer.mapSlot("leggings") == .bottom)
        #expect(BodyAvatarComposer.mapSlot("sneakers") == .shoes)
        #expect(BodyAvatarComposer.mapSlot("chelsea") == .shoes)
        #expect(BodyAvatarComposer.mapSlot("tee") == .top)
        #expect(BodyAvatarComposer.mapSlot("sweater") == .top)
        #expect(BodyAvatarComposer.mapSlot("polo") == .top)
        #expect(BodyAvatarComposer.mapSlot("hoodie") == .top)
    }

    @Test func displaySlotCorrectsDirtyTopLabels() {
        // 西装误标 top → 外套，才能与 tee 同屏
        #expect(
            BodyAvatarComposer.displaySlot(slotRaw: "top", itemName: "Navy Blazer")
                == .outerwear)
        #expect(
            BodyAvatarComposer.displaySlot(slotRaw: "top", itemName: "Denim jacket")
                == .outerwear)
        #expect(
            BodyAvatarComposer.displaySlot(slotRaw: "top", itemName: "Camel coat")
                == .outerwear)
        #expect(
            BodyAvatarComposer.displaySlot(slotRaw: "top", itemName: "Black bomber")
                == .outerwear)
        #expect(
            BodyAvatarComposer.displaySlot(slotRaw: "top", itemName: "Olive windbreaker")
                == .outerwear)
        #expect(
            BodyAvatarComposer.displaySlot(slotRaw: "top", itemName: "White tee")
                == .top)
        #expect(
            BodyAvatarComposer.displaySlot(slotRaw: "top", itemName: "Summer dress")
                == .dress)
        #expect(
            BodyAvatarComposer.displaySlot(slotRaw: "top", itemName: "Blue jeans")
                == .bottom)
        #expect(
            BodyAvatarComposer.displaySlot(slotRaw: "top", itemName: "Black leggings")
                == .bottom)
        #expect(
            BodyAvatarComposer.displaySlot(slotRaw: "top", itemName: "Wool cardigan")
                == .outerwear)
        #expect(
            BodyAvatarComposer.displaySlot(slotRaw: "top", itemName: "Chelsea boots")
                == .shoes)
        #expect(
            BodyAvatarComposer.displaySlot(slotRaw: "top", itemName: "Brown oxfords")
                == .shoes)
        // 牛津纺衬衫 ≠ 牛津鞋（Search 筛 Shoes 不得误命中）
        #expect(
            BodyAvatarComposer.displaySlot(slotRaw: "top", itemName: "Oxford Shirt")
                == .top)
        #expect(
            BodyAvatarComposer.displaySlot(slotRaw: "top", itemName: "Oxford cloth button-down")
                == .top)
        // 已是 outerwear 保持
        #expect(
            BodyAvatarComposer.displaySlot(slotRaw: "outerwear", itemName: "Blazer")
                == .outerwear)
        #expect(
            BodyAvatarComposer.displaySlot(slotRaw: "accessory", itemName: "Belt")
                == nil)
    }

    @Test func displaySlotShoesBottomHintsWinOverDressHint() {
        // 复合名称：dress pants 是裤、dress shoes 是鞋，不应纠偏成 dress
        #expect(
            BodyAvatarComposer.displaySlot(slotRaw: "top", itemName: "Dress pants")
                == .bottom)
        #expect(
            BodyAvatarComposer.displaySlot(slotRaw: "top", itemName: "Black dress shoes")
                == .shoes)
        // 真连衣裙仍纠偏为 dress
        #expect(
            BodyAvatarComposer.displaySlot(slotRaw: "top", itemName: "Wrap dress")
                == .dress)
    }

    @Test func layersStackOuterwearAboveTop() {
        let layers = BodyAvatarComposer.layers(slots: [
            .top: "tee",
            .outerwear: "blazer",
            .bottom: "pants",
            .shoes: "sneakers",
        ])
        #expect(layers.count == 4)
        let bySlot = Dictionary(uniqueKeysWithValues: layers.map { ($0.slot, $0) })
        #expect(bySlot[.shoes]!.zIndex < bySlot[.bottom]!.zIndex)
        #expect(bySlot[.bottom]!.zIndex < bySlot[.top]!.zIndex)
        #expect(bySlot[.top]!.zIndex < bySlot[.outerwear]!.zIndex)
        #expect(layers.map(\.zIndex) == layers.map(\.zIndex).sorted())
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

    @Test func nearestSnapsNonFiniteDegreesToFront() {
        // NaN/±inf 不得 trap：吸附到正面（deg0）。
        #expect(BodyAvatarYaw.nearest(degrees: .nan) == .deg0)
        #expect(BodyAvatarYaw.nearest(degrees: .infinity) == .deg0)
        #expect(BodyAvatarYaw.nearest(degrees: -.infinity) == .deg0)
    }
}
