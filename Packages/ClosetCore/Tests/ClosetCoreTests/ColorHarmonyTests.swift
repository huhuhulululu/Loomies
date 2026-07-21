import Testing
@testable import ClosetCore

struct ColorHarmonyTests {
    let red = GarmentColor(hueDegrees: 0)
    let navy = GarmentColor(hueDegrees: 220, isNeutral: true)

    @Test func neutralPairsWithAnything() {
        #expect(ColorHarmony.relation(navy, red) == .neutral)
        #expect(ColorHarmony.relation(red, navy) == .neutral)
    }

    @Test func analogousWithin30() {
        #expect(ColorHarmony.relation(GarmentColor(hueDegrees: 20), GarmentColor(hueDegrees: 40)) == .analogous)
    }

    @Test func complementaryNear180() {
        #expect(ColorHarmony.relation(GarmentColor(hueDegrees: 0), GarmentColor(hueDegrees: 180)) == .complementary)
    }

    @Test func triadicNear120() {
        #expect(ColorHarmony.relation(GarmentColor(hueDegrees: 0), GarmentColor(hueDegrees: 120)) == .triadic)
    }

    @Test func clashingOtherwise() {
        #expect(ColorHarmony.relation(GarmentColor(hueDegrees: 0), GarmentColor(hueDegrees: 70)) == .clashing)
    }

    @Test func harmoniousWithNeutralAndComplementary() {
        #expect(ColorHarmony.isHarmonious([navy, red, GarmentColor(hueDegrees: 180)]))
    }

    @Test func clashingPaletteNotHarmonious() {
        #expect(!ColorHarmony.isHarmonious([GarmentColor(hueDegrees: 0), GarmentColor(hueDegrees: 70)]))
    }

    @Test func sixtyThirtyTenBalanced() {
        #expect(ColorHarmony.followsSixtyThirtyTen([navy, red, GarmentColor(hueDegrees: 240)]))
    }

    @Test func tooManyHuesNotBalanced() {
        let busy = [GarmentColor(hueDegrees: 0), GarmentColor(hueDegrees: 60),
                    GarmentColor(hueDegrees: 120), GarmentColor(hueDegrees: 240)]
        #expect(!ColorHarmony.followsSixtyThirtyTen(busy))
    }
}
