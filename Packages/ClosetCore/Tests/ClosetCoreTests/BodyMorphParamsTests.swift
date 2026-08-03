import Testing
@testable import ClosetCore

struct BodyMorphParamsTests {

    @Test func neutralProfileNearOneEverywhere() {
        let m = BodyMorphParams.neutral
        for y in stride(from: 0.0, through: 1.0, by: 0.05) {
            let s = m.horizontalScale(normalizedY: y)
            #expect(abs(s - 1.0) < 0.02)
        }
    }

    @Test func faceBandBarelyScalesEvenWhenChestWide() {
        let m = BodyMorphParams(chest: 1.14, waist: 1.0, hip: 1.0, shoulder: 1.14, height: 1)
        let face = m.horizontalScale(normalizedY: 0.08)
        #expect(face < 1.04)
        let chest = m.horizontalScale(normalizedY: 0.34)
        #expect(chest > 1.08)
    }

    @Test func waistPinchVisibleForHourglassPreset() {
        let m = BodyMorphParams.preset(for: .hourglass)
        let waist = m.horizontalScale(normalizedY: 0.44)
        let hip = m.horizontalScale(normalizedY: 0.54)
        #expect(waist < 0.97)
        #expect(hip > waist)
    }

    @Test func pearPresetHipWiderThanChest() {
        let m = BodyMorphParams.preset(for: .pear)
        #expect(m.hip > m.chest)
        #expect(m.horizontalScale(normalizedY: 0.54) > m.horizontalScale(normalizedY: 0.34))
    }

    @Test func measurementsDriveContinuousScales() {
        let slim = BodyMeasurements(bust: 32, waist: 24, hip: 34, highHip: 30)
        let full = BodyMeasurements(bust: 40, waist: 34, hip: 44, highHip: 38)
        let a = BodyMorphParams.from(measurements: slim)
        let b = BodyMorphParams.from(measurements: full)
        #expect(a.chest < b.chest)
        #expect(a.waist < b.waist)
        #expect(a.hip < b.hip)
    }

    @Test func clampsExtremeMeasurements() {
        let huge = BodyMeasurements(bust: 80, waist: 70, hip: 90, highHip: 80)
        let m = BodyMorphParams.from(measurements: huge)
        #expect(m.chest <= BodyMorphParams.scaleHi)
        #expect(m.hip <= BodyMorphParams.scaleHi)
    }

    @Test func fineTuneMultipliesBase() {
        let base = BodyMorphParams.preset(for: .rectangle)
        let tune = BodyMorphParams(chest: 1.05, waist: 0.95, hip: 1.05, shoulder: 1, height: 1)
        let out = base.applying(offsets: tune)
        #expect(out.chest > base.chest)
        #expect(out.waist < base.waist)
    }

    @Test func resolvePrefersMeasurementsOverShape() {
        let m = BodyMeasurements(bust: 40, waist: 28, hip: 40, highHip: 34)
        let r = BodyMorphParams.resolve(measurements: m, shape: .pear)
        let fromM = BodyMorphParams.from(measurements: m)
        #expect(abs(r.chest - fromM.chest) < 0.001)
    }

    @Test func resolveFallsBackToPreset() {
        let r = BodyMorphParams.resolve(measurements: nil, shape: .invertedTriangle)
        #expect(r.shoulder > 1.0)
        #expect(r.hip < 1.0)
    }

    @Test func legacyRoundTripWidthInRange() {
        let m = BodyMorphParams.from(measurements:
            BodyMeasurements(bust: 36, waist: 28, hip: 38, highHip: 34))
        let legacy = m.legacyScale
        #expect(legacy.widthScale >= 0.88 && legacy.widthScale <= 1.14)
    }

    @Test func profileIsSmoothMonotonicSegments() {
        // 相邻采样无跳变爆炸（strip 渲染稳定性）
        let m = BodyMorphParams.preset(for: .hourglass)
        var prev = m.horizontalScale(normalizedY: 0)
        for y in stride(from: 0.02, through: 1.0, by: 0.02) {
            let s = m.horizontalScale(normalizedY: y)
            #expect(abs(s - prev) < 0.08)
            prev = s
        }
    }
}
