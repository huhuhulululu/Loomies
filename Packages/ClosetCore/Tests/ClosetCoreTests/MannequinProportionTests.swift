import Testing
import ClosetCore

struct MannequinProportionTests {
    @Test func maleBaseWiderShouldersNarrowerHipsThanFemale() {
        let f = MannequinSegmentScales.base(for: .female)
        let m = MannequinSegmentScales.base(for: .male)
        #expect(m.shoulderWidth > f.shoulderWidth)
        #expect(m.hipWidth < f.hipWidth)
        #expect(m.height >= f.height)
    }

    @Test func morphWidensChestAndHip() {
        let neutral = MannequinSegmentScales.resolve(
            sex: .female,
            morph: .neutral,
            shape: .rectangle)
        let wide = MannequinSegmentScales.resolve(
            sex: .female,
            morph: BodyMorphParams(chest: 1.08, waist: 1, hip: 1.08, shoulder: 1.05, height: 1),
            shape: .rectangle)
        #expect(wide.chestWidth > neutral.chestWidth)
        #expect(wide.hipWidth > neutral.hipWidth)
        #expect(wide.shoulderWidth > neutral.shoulderWidth)
    }

    @Test func pearBiasIncreasesHip() {
        let rect = MannequinSegmentScales.resolve(sex: .female, morph: .neutral, shape: .rectangle)
        let pear = MannequinSegmentScales.resolve(sex: .female, morph: .neutral, shape: .pear)
        #expect(pear.hipWidth > rect.hipWidth)
    }

    @Test func invertedTriangleBiasIncreasesShoulder() {
        let rect = MannequinSegmentScales.resolve(sex: .female, morph: .neutral, shape: .rectangle)
        let inv = MannequinSegmentScales.resolve(
            sex: .female, morph: .neutral, shape: .invertedTriangle)
        #expect(inv.shoulderWidth > rect.shoulderWidth)
    }

    @Test func multiPhenotypeSegmentBiasIsReadableAndSubtle() {
        let ea = MannequinSegmentScales.resolve(
            sex: .female, morph: .neutral, shape: .rectangle, phenotype: .eastAsian)
        let af = MannequinSegmentScales.resolve(
            sex: .female, morph: .neutral, shape: .rectangle, phenotype: .african)
        let eu = MannequinSegmentScales.resolve(
            sex: .female, morph: .neutral, shape: .rectangle, phenotype: .european)
        // African / European read broader than eastAsian baseline; stay within ±~5% of each other.
        #expect(af.shoulderWidth > ea.shoulderWidth)
        #expect(af.limbThickness > ea.limbThickness)
        #expect(eu.height > ea.height)
        #expect(af.shoulderWidth / ea.shoulderWidth < 1.08)
        #expect(AvatarBodyPhenotype.african.segmentBias.limbThickness
            > AvatarBodyPhenotype.eastAsian.segmentBias.limbThickness)
    }

    @Test func garmentOpacityFrontFullSideHidden() {
        #expect(MannequinGarmentVisibility.opacity(yawDegrees: 0) == 1)
        #expect(MannequinGarmentVisibility.opacity(yawDegrees: 10) > 0.8)
        #expect(MannequinGarmentVisibility.opacity(yawDegrees: 90) == 0)
        #expect(MannequinGarmentVisibility.opacity(yawDegrees: 350) > 0.5)
        #expect(MannequinGarmentVisibility.opacity(yawDegrees: -20) > 0.5)
    }

    @Test func hybridBlendKeepsFullNudeMannequinWhenPhotorealUncertified() {
        // Gate closed path: front must not ghost the procedural multi-phenotype nude.
        let front = MannequinHybridBlend.opacities(
            yawDegrees: 0, hasCertifiedPhotorealFront: false)
        #expect(front.photoreal == 0)
        #expect(front.mannequin == 1)

        let side = MannequinHybridBlend.opacities(
            yawDegrees: 90, hasCertifiedPhotorealFront: false)
        #expect(side.photoreal == 0)
        #expect(side.mannequin == 1)
    }

    @Test func hybridBlendFadesMannequinOnlyWhenCertifiedPhotorealPresent() {
        let front = MannequinHybridBlend.opacities(
            yawDegrees: 0, hasCertifiedPhotorealFront: true)
        #expect(front.photoreal == 1)
        #expect(abs(front.mannequin - 0.08) < 0.0001) // residual 3D rim under photoreal
        #expect(front.mannequin < 0.15)

        let side = MannequinHybridBlend.opacities(
            yawDegrees: 90, hasCertifiedPhotorealFront: true)
        #expect(side.photoreal == 0)
        #expect(side.mannequin == 1)
    }

    @Test func sexRawRoundTrip() {
        #expect(AvatarBodySex(rawValue: "male") == .male)
        #expect(AvatarBodySex(rawValue: "female") == .female)
        #expect(AvatarBodySex(rawValue: "other") == nil)
    }

    // MARK: - USDZ mesh catalog (lock-in path)

    @Test func usdzResourceNamesDifferBySexAndAreNudePrefixed() {
        let f = MannequinMeshCatalog.usdzResourceName(for: .female)
        let m = MannequinMeshCatalog.usdzResourceName(for: .male)
        #expect(f == "nude_body_female")
        #expect(m == "nude_body_male")
        #expect(f != m)
        #expect(MannequinMeshCatalog.usdzFileName(for: .female) == "nude_body_female.usdz")
        #expect(MannequinMeshCatalog.usdzFileName(for: .male) == "nude_body_male.usdz")
        #expect(MannequinMeshCatalog.legacyUsdzResourceName(for: .female) == "mannequin_body_female")
    }

    @Test func meshSourceFallsBackToProceduralWithoutAssets() {
        #expect(
            MannequinMeshCatalog.resolveSource(sex: .female, availableResourceNames: [])
                == .procedural)
        #expect(
            MannequinMeshCatalog.resolveSource(
                sex: .male, availableResourceNames: ["croquis_hourglass"])
                == .procedural)
    }

    @Test func meshSourcePrefersUSDZWhenPresent() {
        #expect(
            MannequinMeshCatalog.resolveSource(
                sex: .female,
                availableResourceNames: ["mannequin_body_female"])
                == .usdz)
        #expect(
            MannequinMeshCatalog.resolveSource(
                sex: .male,
                availableResourceNames: ["mannequin_body_male.usdz"])
                == .usdz)
        // Wrong sex asset must not unlock the other sex.
        #expect(
            MannequinMeshCatalog.resolveSource(
                sex: .male,
                availableResourceNames: ["mannequin_body_female"])
                == .procedural)
    }

    @Test func meshSourcePrefersPhenotypeStemThenSexThenLegacy() {
        let stems = MannequinMeshCatalog.usdzCandidateStems(sex: .male, phenotype: .african)
        #expect(stems.first == "nude_body_male_african")
        #expect(stems.contains("nude_body_male"))
        #expect(stems.contains("mannequin_body_male"))
        #expect(
            MannequinMeshCatalog.resolveUsdzStem(
                sex: .male,
                phenotype: .african,
                availableResourceNames: ["nude_body_male", "nude_body_male_african"])
                == "nude_body_male_african")
        #expect(
            MannequinMeshCatalog.resolveUsdzStem(
                sex: .female,
                phenotype: .european,
                availableResourceNames: ["nude_body_female"])
                == "nude_body_female")
    }

    @Test func segmentNodeNamesCoverMorphTargetsWithoutBasewear() {
        let n = MannequinMeshCatalog.segmentNodeNames
        #expect(n.contains("chest"))
        #expect(n.contains("waist"))
        #expect(n.contains("hip"))
        #expect(n.contains("pelvis"))
        #expect(!n.contains("pastieL"))
        #expect(!n.contains("thong"))
        #expect(n.contains("hair"))
        #expect(n.contains(MannequinMeshCatalog.bodyRootNodeName) == false)
    }

    @Test func garmentVisibilityOpacityNonFiniteYawDefaultsToFront() {
        // NaN/±inf yaw 不得产生 NaN opacity：默认正面全显。
        #expect(MannequinGarmentVisibility.opacity(yawDegrees: .nan) == 1)
        #expect(MannequinGarmentVisibility.opacity(yawDegrees: .infinity) == 1)
        #expect(MannequinGarmentVisibility.opacity(yawDegrees: -.infinity) == 1)
    }
}
