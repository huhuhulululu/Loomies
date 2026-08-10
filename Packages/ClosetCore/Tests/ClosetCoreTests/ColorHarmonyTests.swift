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

    @Test func nonFiniteHueIsNeutralNotClashing() {
        // NaN/±inf 色相无法判距离 → 中性，不误报「色彩冲突」。
        let nan = GarmentColor(hueDegrees: .nan)
        let inf = GarmentColor(hueDegrees: .infinity)
        #expect(ColorHarmony.relation(nan, red) == .neutral)
        #expect(ColorHarmony.relation(red, nan) == .neutral)
        #expect(ColorHarmony.relation(inf, GarmentColor(hueDegrees: 70)) == .neutral)
        #expect(ColorHarmony.isHarmonious([nan, GarmentColor(hueDegrees: 70)]))
    }

    @Test func nonFiniteHueNotCountedAsNewFamily() {
        // NaN 不应计入 60-30-10 族数（否则脏数据破坏平衡判定）。
        #expect(ColorHarmony.followsSixtyThirtyTen([
            GarmentColor(hueDegrees: .nan),
            GarmentColor(hueDegrees: 0),
            GarmentColor(hueDegrees: 120),
            GarmentColor(hueDegrees: 240)]))
    }
}
