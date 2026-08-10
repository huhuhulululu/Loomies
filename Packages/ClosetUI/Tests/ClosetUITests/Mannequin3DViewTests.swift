import Testing
import Foundation
import ClosetCore
@testable import ClosetUI

struct Mannequin3DViewTests {
    @MainActor
    @Test func coordinatorDefaultsToProceduralWithoutUSDZ() {
        let coord = MannequinSceneCoordinator()
        #expect(coord.activeMeshSource == .procedural)
        coord.apply(scales: .neutralMale, sex: .male, phenotype: .african, yawDegrees: 45)
        #expect(coord.activeMeshSource == .procedural)
    }

    @MainActor
    @Test func catalogAndSpecAreD59MinimalBasewearMultiPhenotype() {
        #expect(MannequinMeshCatalog.usdzResourceName(for: .female) == "nude_body_female")
        #expect(NudeBodyBaseSpec.allowsAnyCovering == false)
        #expect(NudeBodyBaseSpec.allowsMinimalCatalogBasewear == true)
        #expect(NudeBodyBaseSpec.requiresFullNude == false)
        #expect(AvatarBodyPhenotype.allCases.count >= 6)
        #expect(NudeBodyBaseSpec.photorealFrontAssetsCertifiedFullNude == false)
        #expect(NudeBodyBaseSpec.photorealFrontAssetsCertifiedCatalogBasewear == true)
        #expect(NudeBodyBaseSpec.isHardRequirementMet == true)
        #expect(NudeBodyBaseSpec.primaryRenderMode == .realHumanPhoto)
        #expect(NudeBodyBaseSpec.coveringPolicy == "minimal_basewear")
    }

    @Test func photorealFrontResourcesExistAndCatalogGateAllowsDisplay() {
        for name in [
            BodyAvatarAsset.photorealFrontName(sex: .female),
            BodyAvatarAsset.photorealFrontName(sex: .male)
        ] {
            let url = Bundle.module.url(forResource: name, withExtension: "png")
                ?? Bundle.module.url(forResource: name, withExtension: nil)
            #expect(url != nil, "missing photoreal resource \(name).png")
            #expect(
                NudeBodyBaseSpec.mayUsePhotorealFrontAsset(named: name),
                "D59 catalog cert must allow photoreal display")
        }
    }

    @Test func catalogFullOrbitEightYawFramesExistForBothSexes() {
        // D67: full 8×45° catalog orbit, both sexes, thong basewear
        for sex in ["female", "male"] {
            for yaw in ["000", "045", "090", "135", "180", "225", "270", "315"] {
                let name = yaw == "000"
                    ? "photoreal_\(sex)_front"
                    : "photoreal_\(sex)_yaw\(yaw)"
                let alt = "photoreal_\(sex)_yaw\(yaw)"
                let url = Bundle.module.url(forResource: name, withExtension: "png")
                    ?? Bundle.module.url(forResource: alt, withExtension: "png")
                    ?? Bundle.module.url(forResource: name, withExtension: nil)
                #expect(url != nil, "missing \(name)/\(alt).png")
                #expect(NudeBodyBaseSpec.mayUsePhotorealFrontAsset(named: alt))
                #expect(NudeBodyBaseSpec.isAllowedPhotorealFrontName(alt))
            }
        }
    }

    @Test func catalogPhenotypeFrontsExistForAllSexPhenotypePairs() {
        // D68: multi-ethnicity catalog fronts (Me phenotype picker)
        for sex in AvatarBodySex.allCases {
            for p in AvatarBodyPhenotype.allCases {
                let name = NudeBodyBaseSpec.photorealFrontName(sex: sex, phenotype: p)
                let url = Bundle.module.url(forResource: name, withExtension: "png")
                    ?? Bundle.module.url(forResource: name, withExtension: nil)
                #expect(url != nil, "missing phenotype front \(name).png")
                #expect(NudeBodyBaseSpec.mayUsePhotorealFrontAsset(named: name))
                #expect(NudeBodyBaseSpec.isAllowedPhotorealFrontName(name))
            }
        }
        #expect(AvatarBodyPhenotype.allCases.count == 8)
    }

    @Test func catalogPhenotypeQuarterFramesExistForKeyPairs() {
        // Non-eastAsian phenotype×yaw045 (identity guard: no generic sex yaw fallback).
        // eastAsian uses generic orbit (D69). Expanded via interval gen (no TF).
        let phenotypes = [
            "african", "european", "latinx", "southAsian",
            "southeastAsian", "middleEastern", "indigenous",
        ]
        for sex in ["female", "male"] {
            for p in phenotypes {
                let name = "photoreal_\(sex)_\(p)_yaw045"
                let url = Bundle.module.url(forResource: name, withExtension: "png")
                    ?? Bundle.module.url(forResource: name, withExtension: nil)
                #expect(url != nil, "missing \(name).png")
                #expect(NudeBodyBaseSpec.mayUsePhotorealFrontAsset(named: name))
            }
        }
    }

    @Test func catalogPhenotypeMirrorQuarterFramesExistForStarterSet() {
        // Non-eastAsian phenotype×yaw315 (¾ left). eastAsian uses generic orbit (D69).
        let phenotypes = [
            "african", "european", "latinx", "southAsian",
            "southeastAsian", "middleEastern", "indigenous",
        ]
        for sex in ["female", "male"] {
            for p in phenotypes {
                let name = "photoreal_\(sex)_\(p)_yaw315"
                let url = Bundle.module.url(forResource: name, withExtension: "png")
                    ?? Bundle.module.url(forResource: name, withExtension: nil)
                #expect(url != nil, "missing \(name).png")
                #expect(NudeBodyBaseSpec.mayUsePhotorealFrontAsset(named: name))
            }
        }
    }

    @Test func catalogPhenotypeProfileFramesExistForStarterSet() {
        // Non-eastAsian phenotype×yaw090 (true profile). eastAsian uses generic orbit (D69).
        // female_european_yaw090 unblocked via interval gen (no TF).
        let phenotypes = [
            "african", "european", "latinx", "southAsian",
            "southeastAsian", "middleEastern", "indigenous",
        ]
        for sex in ["female", "male"] {
            for p in phenotypes {
                let name = "photoreal_\(sex)_\(p)_yaw090"
                let url = Bundle.module.url(forResource: name, withExtension: "png")
                    ?? Bundle.module.url(forResource: name, withExtension: nil)
                #expect(url != nil, "missing \(name).png")
                #expect(NudeBodyBaseSpec.mayUsePhotorealFrontAsset(named: name))
            }
        }
    }

    @Test func catalogPhenotypeLeftProfileFramesExistForStarterSet() {
        // Non-eastAsian phenotype×yaw270 (left profile) — full 14/14 lock, no TF.
        let phenotypes = [
            "african", "european", "latinx", "southAsian",
            "southeastAsian", "middleEastern", "indigenous",
        ]
        for sex in ["female", "male"] {
            for p in phenotypes {
                let name = "photoreal_\(sex)_\(p)_yaw270"
                let url = Bundle.module.url(forResource: name, withExtension: "png")
                    ?? Bundle.module.url(forResource: name, withExtension: nil)
                #expect(url != nil, "missing \(name).png")
                #expect(NudeBodyBaseSpec.mayUsePhotorealFrontAsset(named: name))
            }
        }
    }

    @Test func catalogMaleBackFramesExist() {
        // D70/D72: generic + phenotype backs (both sexes non-EA)
        for name in [
            "photoreal_male_yaw180",
            "photoreal_male_eastAsian_yaw180",
            "photoreal_female_yaw180",
        ] {
            let url = Bundle.module.url(forResource: name, withExtension: "png")
                ?? Bundle.module.url(forResource: name, withExtension: nil)
            #expect(url != nil, "missing \(name).png")
            #expect(NudeBodyBaseSpec.mayUsePhotorealFrontAsset(named: name))
            #expect(NudeBodyBaseSpec.isAllowedPhotorealFrontName(name))
        }
    }

    @Test func catalogPhenotypeThreeQuarterAndBackFramesExistFullMatrix() {
        // D72 close: non-eastAsian 7×2 × yaw135/180/225 = 42 frames (no TF)
        let phenotypes = [
            "african", "european", "latinx", "southAsian",
            "southeastAsian", "middleEastern", "indigenous",
        ]
        for sex in ["female", "male"] {
            for p in phenotypes {
                for yaw in ["135", "180", "225"] {
                    let name = "photoreal_\(sex)_\(p)_yaw\(yaw)"
                    let url = Bundle.module.url(forResource: name, withExtension: "png")
                        ?? Bundle.module.url(forResource: name, withExtension: nil)
                    #expect(url != nil, "missing \(name).png")
                    #expect(NudeBodyBaseSpec.mayUsePhotorealFrontAsset(named: name))
                    #expect(NudeBodyBaseSpec.isAllowedPhotorealFrontName(name))
                }
            }
        }
    }

    @MainActor
    @Test func multiPhenotypeRebuildStaysProceduralWhenNoUSDZ() {
        let coord = MannequinSceneCoordinator()
        for p in AvatarBodyPhenotype.allCases {
            coord.apply(scales: .neutralFemale, sex: .female, phenotype: p, yawDegrees: 0)
            #expect(coord.activeMeshSource == .procedural)
        }
    }

    @MainActor
    @Test func hybridBlendUncertifiedKeepsFullMannequinOpacity() {
        let o = MannequinHybridBlend.opacities(
            yawDegrees: 0, hasCertifiedPhotorealFront: false)
        #expect(o.mannequin == 1)
        #expect(o.photoreal == 0)
    }

    @Test func multiPhenotypeFacePlatesExistForAllSexPhenotypePairs() {
        let names = BodyAvatarAsset.allFacePlateNames
        #expect(names.count == AvatarBodySex.allCases.count * AvatarBodyPhenotype.allCases.count)
        for name in names {
            let url = Bundle.module.url(
                forResource: name, withExtension: "png", subdirectory: "BodyAvatar/Face")
                ?? Bundle.module.url(forResource: name, withExtension: "png")
            #expect(url != nil, "missing face plate \(name).png")
        }
    }

    @Test func multiToneSkinTilesExistInBundle() {
        for name in [
            "skin_light_fair", "skin_medium_warm", "skin_olive_warm",
            "skin_deep_brown", "skin_bump",
            "skin_limb_female", "skin_limb_male",
            "skin_thigh_female", "skin_thigh_male",
            "skin_torso_side", "skin_photoreal_macro", "skin_photoreal_macro_deep",
            "skin_normal", "skin_normal_deep",
            "skin_torso_front_female", "skin_torso_front_male"
        ] {
            let url = Bundle.module.url(
                forResource: name, withExtension: "png", subdirectory: "BodyAvatar/Skin")
                ?? Bundle.module.url(forResource: name, withExtension: "png")
            #expect(url != nil, "missing skin tile \(name).png")
        }
    }

    @Test func hardRequirementMetViaCatalogBasewearNotFullNude() {
        #expect(NudeBodyBaseSpec.allowsMeshOrSimulationAsFinalVisual == false)
        #expect(NudeBodyBaseSpec.photoreal3DMeshCertifiedFullNude == false)
        #expect(NudeBodyBaseSpec.photorealFrontAssetsCertifiedFullNude == false)
        #expect(NudeBodyBaseSpec.photorealFrontAssetsCertifiedCatalogBasewear == true)
        #expect(NudeBodyBaseSpec.isHardRequirementMet == true)
        #expect(NudeBodyBaseSpec.primaryRenderMode == .realHumanPhoto)
    }
}
