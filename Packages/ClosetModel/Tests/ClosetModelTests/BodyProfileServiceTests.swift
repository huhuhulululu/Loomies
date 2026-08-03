import Testing
import Foundation
@testable import ClosetModel
import ClosetCore

@MainActor
struct BodyProfileServiceTests {

    @Test func incompleteWhenAnyMissing() {
        let p = PersonBodyProfile(personID: UUID())
        p.bustInches = 36; p.waistInches = 28; p.hipInches = 38
        // highHip missing
        #expect(!BodyProfileService.isComplete(p))
        #expect(BodyProfileService.bodyShape(from: p) == nil)
        #expect(BodyProfileService.measurements(from: p) == nil)
    }

    @Test func completeYieldsShape() {
        let p = PersonBodyProfile(personID: UUID())
        // classic hourglass-ish: bust≈hip, clear waist drop
        p.bustInches = 36; p.waistInches = 26; p.hipInches = 36; p.highHipInches = 34
        #expect(BodyProfileService.isComplete(p))
        let shape = BodyProfileService.bodyShape(from: p)
        #expect(shape != nil)
        let m = BodyProfileService.measurements(from: p)!
        #expect(m.bust == 36)
        #expect(m.waist == 26)
    }
}
