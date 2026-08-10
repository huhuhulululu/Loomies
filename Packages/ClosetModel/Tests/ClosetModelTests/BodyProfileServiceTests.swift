import Testing
import Foundation
@testable import ClosetModel
import ClosetCore

@MainActor
struct BodyProfileServiceTests {

    @Test func incompleteWhenAnyMissing() {
        let p = PersonBodyProfile(personID: UUID())
        p.bustInches = 36; p.waistInches = 28; p.hipInches = 38
        #expect(!BodyProfileService.isComplete(p))
        #expect(BodyProfileService.bodyShape(from: p) == nil)
        #expect(BodyProfileService.measurements(from: p) == nil)
        #expect(BodyProfileService.resolveSource(p) == .none)
    }

    @Test func completeYieldsShape() {
        let p = PersonBodyProfile(personID: UUID())
        p.bustInches = 36; p.waistInches = 26; p.hipInches = 36; p.highHipInches = 34
        #expect(BodyProfileService.isComplete(p))
        #expect(BodyProfileService.isFullyMeasured(p))
        let shape = BodyProfileService.bodyShape(from: p)
        #expect(shape != nil)
        let m = BodyProfileService.measurements(from: p)!
        #expect(m.bust == 36)
        #expect(m.waist == 26)
        #expect(BodyProfileService.resolveSource(p) == .measured)
        #expect(BodyProfileService.confidence(for: p) == .measured)
        #expect(BodyProfileService.styleWeightFactor(for: p) == 1.0)
    }

    @Test func visualPickWithoutMeasures() {
        let p = PersonBodyProfile(personID: UUID())
        p.popularShapeOverrideRaw = PopularShape.pear.rawValue
        BodyProfileService.refreshSource(on: p)
        #expect(!BodyProfileService.isComplete(p))
        #expect(BodyProfileService.displayPopularShape(from: p) == .pear)
        #expect(BodyProfileService.bodyShape(from: p) == .triangle)
        #expect(BodyProfileService.resolveSource(p) == .visualPick)
        #expect(BodyProfileService.confidence(for: p) == .visualOnly)
        #expect(BodyProfileService.styleWeightFactor(for: p) == 0.5)
        #expect(p.shapeSourceRaw == "visualPick")
    }

    /// isComplete 与 recompute 的 >0 判定同标准：0/负/非有限不算「齐」，
    /// 否则 UI 宣称 Measured 满权重，底层 FFIT 却静默兜底假体型。
    @Test func incompleteWhenAnyNonPositiveOrNonFinite() {
        for bad in [0.0, -3, Double.nan, .infinity] {
            let p = PersonBodyProfile(personID: UUID())
            p.bustInches = 36; p.waistInches = 28; p.hipInches = 38; p.highHipInches = bad
            #expect(!BodyProfileService.isComplete(p))
        }
    }

    @Test func inferHighHipBetweenWaistAndHip() {
        let hh = BodyProfileService.inferHighHip(waist: 28, hip: 40)
        #expect(hh > 28 && hh < 40)
        #expect(abs(hh - 34) < 0.01)
    }

    @Test func provisionalWhenHighHipInferred() {
        let p = PersonBodyProfile(personID: UUID())
        p.bustInches = 36; p.waistInches = 28; p.hipInches = 40
        p.highHipInches = BodyProfileService.inferHighHip(waist: 28, hip: 40)
        p.highHipInferred = true
        #expect(BodyProfileService.isComplete(p))
        #expect(!BodyProfileService.isFullyMeasured(p))
        #expect(BodyProfileService.resolveSource(p) == .provisional)
        #expect(BodyProfileService.styleWeightFactor(for: p) == 0.85)
    }

    @Test func mixedWhenMeasuredAndOverride() {
        let p = PersonBodyProfile(personID: UUID())
        p.bustInches = 36; p.waistInches = 26; p.hipInches = 36; p.highHipInches = 34
        p.popularShapeOverrideRaw = PopularShape.apple.rawValue
        #expect(BodyProfileService.resolveSource(p) == .mixed)
        // display prefers override for croquis
        #expect(BodyProfileService.displayPopularShape(from: p) == .apple)
        // FFIT still from measures
        #expect(BodyProfileService.popularShape(from: p) == .hourglass
            || BodyProfileService.bodyShape(from: p)?.popularCategory == .hourglass)
    }

    @Test func unitConversionRoundTrip() {
        let cm = 91.44
        let inches = BodyProfileService.inches(fromCm: cm)
        #expect(abs(inches - 36) < 0.01)
        #expect(abs(BodyProfileService.cm(fromInches: 36) - cm) < 0.01)
    }

    @Test func measurementsHelperInfers() {
        let r = BodyProfileService.measurements(bust: 36, waist: 28, hip: 40, highHip: nil, inferIfNeeded: true)
        #expect(r != nil)
        #expect(r!.highHipInferred)
        #expect(r!.0.highHip > 28)
    }

    @Test func presentationPhenotypeAndSexRoundTrip() {
        #expect(BodyProfileService.presentationPhenotype(from: nil) == .eastAsian)
        #expect(BodyProfileService.presentationSex(from: nil) == .female)
        let p = PersonBodyProfile(personID: UUID())
        p.presentationPhenotypeRaw = AvatarBodyPhenotype.african.rawValue
        p.presentationSexRaw = AvatarBodySex.male.rawValue
        #expect(BodyProfileService.presentationPhenotype(from: p) == .african)
        #expect(BodyProfileService.presentationSex(from: p) == .male)
        p.presentationPhenotypeRaw = "not-a-phenotype"
        #expect(BodyProfileService.presentationPhenotype(from: p) == .eastAsian)
    }
}
