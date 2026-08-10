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
        let m = BodyMorphParams(chest: 1.08, waist: 1.0, hip: 1.0, shoulder: 1.08, height: 1)
        let face = m.horizontalScale(normalizedY: 0.08)
        #expect(abs(face - 1.0) < 0.001)  // 脸完全锁 1
        let chest = m.horizontalScale(normalizedY: 0.34)
        #expect(chest > 1.01)  // pastie 带有阻尼但仍变宽
        #expect(chest < m.chest)  // 阻尼 < 满 chest
    }

    @Test func pastieBandIsFlatAcrossFullMeasuredRange() {
        // 实测 croquis 乳贴 y≈0.22–0.45；带内必须完全平坦
        let m = BodyMorphParams(chest: 1.08, waist: 0.94, hip: 1.06, shoulder: 1.04, height: 1)
        let samples = [0.24, 0.30, 0.36, 0.42, 0.44].map { m.horizontalScale(normalizedY: $0) }
        let ref = samples[0]
        for s in samples {
            #expect(abs(s - ref) < 0.002)
        }
    }

    @Test func thongBandIsFlatAgainstShear() {
        let m = BodyMorphParams(chest: 1.05, waist: 0.94, hip: 1.08, shoulder: 1.02, height: 1)
        let a = m.horizontalScale(normalizedY: 0.48)
        let b = m.horizontalScale(normalizedY: 0.54)
        let c = m.horizontalScale(normalizedY: 0.60)
        #expect(abs(a - b) < 0.002)
        #expect(abs(b - c) < 0.002)
    }

    @Test func isVisuallyNeutralDetectsIdentity() {
        #expect(BodyMorphParams.neutral.isVisuallyNeutral)
        #expect(!BodyMorphParams(chest: 1.05, waist: 1, hip: 1, shoulder: 1, height: 1).isVisuallyNeutral)
    }

    @Test func waistPinchVisibleForHourglassPreset() {
        let m = BodyMorphParams.preset(for: .hourglass)
        #expect(m.waist < 0.98)
        #expect(m.hip > m.waist)
        // 乳贴带平坦；出带后向腰/臀过渡
        let pastie = m.horizontalScale(normalizedY: 0.34)
        let mid = m.horizontalScale(normalizedY: 0.47)
        let hip = m.horizontalScale(normalizedY: 0.55)
        #expect(abs(m.horizontalScale(normalizedY: 0.28) - pastie) < 0.002)
        #expect(mid != pastie || hip != pastie)  // 剖面有变化
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

    /// C2: 无效围度（0 / 负 / 非有限）视为缺失 → 中性，而非钳到 scaleLo 极瘦。
    @Test func invalidMeasurementsFallBackToNeutralNotScaleLo() {
        let zero = BodyMeasurements(bust: 0, waist: 0, hip: 0, highHip: 0)
        #expect(BodyMorphParams.from(measurements: zero) == .neutral)
        let junk = BodyMeasurements(bust: .nan, waist: -5, hip: .infinity, highHip: 0)
        #expect(BodyMorphParams.from(measurements: junk) == .neutral)
        // 部分缺失：仅该字段回中性，其余仍按测量驱动
        let partial = BodyMeasurements(bust: 40, waist: 0, hip: 40, highHip: 34)
        let m = BodyMorphParams.from(measurements: partial)
        #expect(m.waist == 1)
        #expect(m.chest > 1)
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
        #expect(legacy.widthScale >= BodyMorphParams.scaleLo - 0.01
                && legacy.widthScale <= BodyMorphParams.scaleHi + 0.01)
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
