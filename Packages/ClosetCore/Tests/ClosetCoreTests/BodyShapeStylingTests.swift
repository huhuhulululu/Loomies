import Testing
@testable import ClosetCore

struct BodyShapeStylingTests {

    @Test func flatteringWeightIsPositive() {
        #expect(BodyShapeStyling.weight(.hourglass, .wrap) > 0)      // 沙漏强调腰线
        #expect(BodyShapeStyling.weight(.invertedTriangle, .wideLeg) > 0)
    }

    @Test func avoidWeightIsNegative() {
        #expect(BodyShapeStyling.weight(.apple, .belt) < 0)         // 苹果避腰部堆积
        #expect(BodyShapeStyling.weight(.invertedTriangle, .paddedShoulder) < 0)
    }

    @Test func unlistedIsNeutralZero() {
        #expect(BodyShapeStyling.weight(.rectangle, .vNeck) == 0)
    }

    @Test func sameAttributeDiffersAcrossShapes() {
        // belt 对沙漏正、对苹果负——体型化确有区分
        #expect(BodyShapeStyling.weight(.hourglass, .belt) > 0)
        #expect(BodyShapeStyling.weight(.apple, .belt) < 0)
    }

    @Test func affinitySumsAcrossItems() {
        let items = [
            CandidateItem(id: "t", slot: .top, attributes: [.wrap]),      // 沙漏 +1
            CandidateItem(id: "b", slot: .bottom, attributes: [.highWaist]) // 沙漏 +1
        ]
        #expect(BodyShapeStyling.affinity(items: items, shape: .hourglass) == 2)
    }

    @Test func affinityNegativeForAvoid() {
        let items = [CandidateItem(id: "b", slot: .bottom, attributes: [.straightNoWaist])]
        #expect(BodyShapeStyling.affinity(items: items, shape: .hourglass) < 0)
    }
}
