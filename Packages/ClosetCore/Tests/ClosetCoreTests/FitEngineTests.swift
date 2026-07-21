import Testing
@testable import ClosetCore

struct FitEngineTests {

    @Test func easeIsGarmentMinusBody() {
        // 平铺宽 18in → 服装周长 36in；身体胸围 34in → ease = 2
        #expect(FitEngine.ease(garmentFlatWidth: 18, bodyCircumference: 34) == 2)
    }

    @Test func easeCanBeNegative() {
        // 平铺宽 16in → 周长 32in；身体 34in → ease = -2（服装比身体小）
        #expect(FitEngine.ease(garmentFlatWidth: 16, bodyCircumference: 34) == -2)
    }

    @Test func tightWhenBelowBand() {
        let band = EaseBand(minEase: 1, maxEase: 5)
        #expect(FitEngine.verdict(ease: 0, band: band) == .tight)
    }

    @Test func fittedWithinBand() {
        let band = EaseBand(minEase: 1, maxEase: 5)
        #expect(FitEngine.verdict(ease: 3, band: band) == .fitted)
    }

    @Test func looseWhenAboveBand() {
        let band = EaseBand(minEase: 1, maxEase: 5)
        #expect(FitEngine.verdict(ease: 7, band: band) == .loose)
    }

    @Test func boundaryIsFitted() {
        // 边界值归入合身（闭区间）
        let band = EaseBand(minEase: 1, maxEase: 5)
        #expect(FitEngine.verdict(ease: 1, band: band) == .fitted)
        #expect(FitEngine.verdict(ease: 5, band: band) == .fitted)
    }
}
