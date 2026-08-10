import Testing
import Foundation
import ClosetCore
@testable import ClosetUI

struct PhotorealCoveringQATests {
    @Test func bundlePhotorealFailsZeroCoveringHeuristicWhileCoveredButCatalogGateOpen() {
        for name in NudeBodyBaseSpec.minimumCertFrontNames {
            let report = PhotorealCoveringQA.analyzeBundlePhotoreal(named: name)
            #expect(report != nil, "missing bundle photoreal \(name)")
            guard let report else { continue }
            // Catalog assets intentionally keep pastie/thong → zero-covering fails.
            #expect(
                !report.passesZeroCoveringHeuristic,
                "\(name) should fail covering QA while fabric remains: \(report.notes)")
            #expect(report.combinedEdgeScore > 0)
            // D59: catalog cert opens display gate even with minimal basewear.
            #expect(
                NudeBodyBaseSpec.mayUsePhotorealFrontAsset(named: name),
                "catalog basewear gate must allow photoreal display under D59")
        }
        #expect(NudeBodyBaseSpec.photorealFrontAssetsCertifiedFullNude == false)
        #expect(NudeBodyBaseSpec.photorealFrontAssetsCertifiedCatalogBasewear == true)
        #expect(NudeBodyBaseSpec.isHardRequirementMet == true)
    }

    @Test func mayRecommendCertificationRequiresHumanAndHeuristic() {
        let fail = PhotorealCoveringQA.Report(
            width: 100, height: 150,
            chestEdgeScore: 0.2, pelvisEdgeScore: 0.2, combinedEdgeScore: 0.2,
            passesZeroCoveringHeuristic: false,
            notes: ["fabric"])
        #expect(!PhotorealCoveringQA.mayRecommendCertification(
            automated: fail, humanZeroCoveringConfirmed: true))

        let passAuto = PhotorealCoveringQA.Report(
            width: 100, height: 150,
            chestEdgeScore: 0.02, pelvisEdgeScore: 0.02, combinedEdgeScore: 0.02,
            passesZeroCoveringHeuristic: true,
            notes: ["clear"])
        #expect(!PhotorealCoveringQA.mayRecommendCertification(
            automated: passAuto, humanZeroCoveringConfirmed: false))
        #expect(PhotorealCoveringQA.mayRecommendCertification(
            automated: passAuto, humanZeroCoveringConfirmed: true))
    }

    @Test func certFlipPrerequisitesDocumentCatalogBasewearPath() {
        let joined = NudeBodyBaseSpec.certFlipPrerequisites.joined(separator: " ").lowercased()
        #expect(joined.contains("photograph") || joined.contains("photo") || joined.contains("human"))
        #expect(joined.contains("thong"))
        #expect(joined.contains("pastie") || joined.contains("basewear"))
        #expect(joined.contains("yaw") || joined.contains("multi-angle") || joined.contains("angle"))
        #expect(NudeBodyBaseSpec.minimumCertFrontNames.count == 2)
        #expect(NudeBodyBaseSpec.primaryRenderMode == .realHumanPhoto)
        #expect(NudeBodyBaseSpec.coveringPolicy == "minimal_basewear")
        #expect(NudeBodyBaseSpec.requiresFullNude == false)
    }

    @Test func fullNudeRasterIsNotCertifiablePhotorealPhoto() {
        // Procedural raster must never flip full-nude cert; catalog bar is separate.
        #expect(NudeBodyBaseSpec.photorealFrontAssetsCertifiedFullNude == false)
        guard FullNudeBodyRaster.makeCGImage(
            sex: .female, phenotype: .eastAsian, width: 256, height: 384) != nil
        else {
            #expect(Bool(false), "raster should produce image")
            return
        }
        #expect(NudeBodyBaseSpec.photorealFrontAssetsCertifiedFullNude == false)
        #expect(NudeBodyBaseSpec.requiresPhotorealRealHuman)
        #expect(!NudeBodyBaseSpec.allowsMeshOrSimulationAsFinalVisual)
        #expect(NudeBodyBaseSpec.photorealFrontAssetsCertifiedCatalogBasewear == true)
    }
}
