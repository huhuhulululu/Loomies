import Testing
import ClosetCore

struct NudeBodyBaseSpecTests {
    @Test func invariantRequiresRealHumanPhotoCatalogBasewear() {
        let i = NudeBodyBaseSpec.invariant.lowercased()
        #expect(i.contains("photograph") || i.contains("photo") || i.contains("human"))
        #expect(i.contains("mesh") || i.contains("capsule") || i.contains("simulation"))
        #expect(i.contains("thong"))
        #expect(i.contains("pastie") || i.contains("basewear"))
        #expect(i.contains("not brief") || i.contains("both wear thong"))
        #expect(NudeBodyBaseSpec.allowsAnyCovering == false)
        #expect(NudeBodyBaseSpec.allowsMinimalCatalogBasewear == true)
        #expect(NudeBodyBaseSpec.requiresFullNude == false)
        #expect(NudeBodyBaseSpec.requiresPhotorealRealHuman)
        #expect(NudeBodyBaseSpec.allowsMeshOrSimulationAsFinalVisual == false)
        #expect(NudeBodyBaseSpec.allowsProceduralCapsuleAsFinalVisual == false)
        #expect(NudeBodyBaseSpec.primaryRenderMode == .realHumanPhoto)
        #expect(NudeBodyBaseSpec.coveringPolicy == "minimal_basewear")
        #expect(NudeBodyBaseSpec.photorealFrontAssetsCertifiedCatalogBasewear == true)
        #expect(NudeBodyBaseSpec.isHardRequirementMet == true)
        #expect(NudeBodyBaseSpec.certificationGaps.isEmpty)
    }

    @Test func basewearDescriptionsAreCatalogMinimalThongBothSexes() {
        let f = NudeBodyBaseSpec.femaleBasewearDescription.lowercased()
        let m = NudeBodyBaseSpec.maleBasewearDescription.lowercased()
        #expect(f.contains("pastie") || f.contains("thong"))
        #expect(f.contains("thong"))
        #expect(m.contains("thong"))
        #expect(!m.contains("brief") || m.contains("not brief"))
        #expect(NudeBodyBaseSpec.basewearDescription(for: .female).lowercased().contains("thong"))
        #expect(NudeBodyBaseSpec.basewearDescription(for: .male).lowercased().contains("thong"))
    }

    @Test func forbidsFullClothingTokensButAllowsPhotorealNames() {
        #expect(NudeBodyBaseSpec.isForbiddenAssetName("bra_set"))
        #expect(NudeBodyBaseSpec.isForbiddenAssetName("clothed_dummy"))
        #expect(NudeBodyBaseSpec.isForbiddenAssetName("lingerie_front"))
        #expect(NudeBodyBaseSpec.isForbiddenAssetName("swimsuit_model"))
        #expect(!NudeBodyBaseSpec.isForbiddenAssetName("photoreal_female_front"))
        #expect(!NudeBodyBaseSpec.isForbiddenAssetName("photoreal_male_front"))
        #expect(!NudeBodyBaseSpec.isForbiddenAssetName("nude_body_male_african"))
    }

    @Test func multiPhenotypeSkinRGBDiffer() {
        let light = AvatarBodyPhenotype.european.skinRGB
        let deep = AvatarBodyPhenotype.african.skinRGB
        #expect(light.r > deep.r)
        #expect(AvatarBodyPhenotype.allCases.count >= 6)
        #expect(AvatarBodyPhenotype.european.skinLuminance > AvatarBodyPhenotype.african.skinLuminance)
    }

    @Test func photorealFrontGateOpenWhenCatalogCertified() {
        #expect(NudeBodyBaseSpec.photorealFrontAssetsCertifiedCatalogBasewear == true)
        #expect(NudeBodyBaseSpec.photorealFrontAssetsCertifiedFullNude == false)
        #expect(NudeBodyBaseSpec.mayUsePhotorealFrontAsset(named: "photoreal_female_front"))
        #expect(NudeBodyBaseSpec.mayUsePhotorealFrontAsset(named: "photoreal_male_front"))
        #expect(NudeBodyBaseSpec.mayUsePhotorealFrontAsset(
            named: NudeBodyBaseSpec.photorealFrontName(sex: .female, phenotype: .african)))
        #expect(NudeBodyBaseSpec.isHardRequirementMet == true)
    }

    @Test func phenotypePhotorealNames() {
        let n = NudeBodyBaseSpec.photorealFrontName(sex: .female, phenotype: .african)
        #expect(n == "photoreal_female_african_front")
        #expect(NudeBodyBaseSpec.isAllowedPhotorealFrontName(n))
        #expect(NudeBodyBaseSpec.mayUsePhotorealFrontAsset(named: n))
    }

    @Test func meshCatalogNamesAreNudePrefixed() {
        #expect(MannequinMeshCatalog.usdzResourceName(for: .female).hasPrefix("nude_"))
        #expect(MannequinMeshCatalog.usdzResourceName(for: .male).hasPrefix("nude_"))
    }

    @Test func multiPhenotypeAssetNameInventoriesAreComplete() {
        let fronts = NudeBodyBaseSpec.allPhenotypePhotorealFrontNames
        let meshes = NudeBodyBaseSpec.allPhenotypeNudeMeshNames
        #expect(fronts.count == AvatarBodySex.allCases.count * AvatarBodyPhenotype.allCases.count)
        #expect(meshes.count == fronts.count)
        #expect(Set(fronts).count == fronts.count)
        #expect(fronts.contains("photoreal_male_middleEastern_front"))
        #expect(fronts.allSatisfy { NudeBodyBaseSpec.isAllowedPhotorealFrontName($0) })
        let frames = BodyAvatarAsset.allPhotorealFrameNames
        #expect(
            frames.count
                == AvatarBodySex.allCases.count
                * AvatarBodyPhenotype.allCases.count
                * BodyAvatarYaw.allCases.count)
        #expect(NudeBodyBaseSpec.isAllowedPhotorealFrontName("photoreal_female_yaw180"))
    }

    @Test func skinTintMultiplierSupportsMultiPhenotypeGenericPhotoreal() {
        let id = AvatarBodyPhenotype.eastAsian.skinTintMultiplier(relativeTo: .eastAsian)
        #expect(abs(id.r - 1) < 0.02 && abs(id.g - 1) < 0.02)
        #expect(AvatarBodyPhenotype.isGenericPhotorealFrontName("photoreal_female_front"))
        #expect(!AvatarBodyPhenotype.isGenericPhotorealFrontName("photoreal_female_african_front"))
    }

    @Test func d59CatalogBasewearSatisfiesProductHardRequirement() {
        // User chose scheme 2 + D64: catalog pastie/thong (♀) and thong (♂).
        #expect(NudeBodyBaseSpec.photorealFrontAssetsCertifiedCatalogBasewear == true)
        #expect(NudeBodyBaseSpec.requiresFullNude == false)
        #expect(NudeBodyBaseSpec.isHardRequirementMet == true)
        #expect(NudeBodyBaseSpec.coveringPolicy == "minimal_basewear")
        #expect(NudeBodyBaseSpec.photorealFrontAssetsCertifiedFullNude == false)
    }
}
