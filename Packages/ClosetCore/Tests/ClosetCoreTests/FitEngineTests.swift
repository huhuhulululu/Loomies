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

    @Test func nonFiniteEaseYieldsNoVerdict() {
        // NaN/±inf（来自缺失/脏测值）→ nil：不展示标记，而非误报「合身」。
        let band = EaseBand(minEase: 1, maxEase: 5)
        #expect(FitEngine.verdict(ease: .nan, band: band) == nil)
        #expect(FitEngine.verdict(ease: .infinity, band: band) == nil)
        #expect(FitEngine.verdict(ease: -.infinity, band: band) == nil)
    }

    @Test func nonPositiveInputsYieldNoEase() {
        // 0/负数为缺失/脏测值 → nil：ease(0,0)=0 不得落进阈值带误报「合身」，
        // 负围度不得把 ease 抬高误报「偏松」。
        #expect(FitEngine.ease(garmentFlatWidth: 0, bodyCircumference: 0) == nil)
        #expect(FitEngine.ease(garmentFlatWidth: 18, bodyCircumference: 0) == nil)
        #expect(FitEngine.ease(garmentFlatWidth: 0, bodyCircumference: 34) == nil)
        #expect(FitEngine.ease(garmentFlatWidth: -5, bodyCircumference: 34) == nil)
        #expect(FitEngine.ease(garmentFlatWidth: 18, bodyCircumference: -34) == nil)
        #expect(FitEngine.ease(garmentFlatWidth: 18, bodyCircumference: .nan) == nil)
        // 干净输入不受影响
        #expect(FitEngine.ease(garmentFlatWidth: 18, bodyCircumference: 34) == 2)
    }

    @Test func nilEaseYieldsNoVerdict() {
        let band = EaseBand(minEase: 1, maxEase: 5)
        #expect(FitEngine.verdict(ease: nil, band: band) == nil)
        // 端到端：脏输入经 ease → verdict 全程无判定
        #expect(FitEngine.verdict(ease: FitEngine.ease(garmentFlatWidth: 0, bodyCircumference: 0), band: band) == nil)
    }
}
