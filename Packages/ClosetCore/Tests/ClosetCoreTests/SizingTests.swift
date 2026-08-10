import Testing
@testable import ClosetCore

struct SizingTests {

    @Test func topSchemaFields() {
        let f = MeasurementSchema.fields(for: .top)
        #expect(f.contains(.chestFlat) && f.contains(.garmentLength) && f.contains(.shoulder) && f.contains(.sleeve))
    }

    @Test func bottomSchemaFields() {
        let f = MeasurementSchema.fields(for: .bottom)
        #expect(f.contains(.waistFlat) && f.contains(.hipFlat) && f.contains(.inseam))
        #expect(!f.contains(.sleeve))
    }

    @Test func skirtSchemaFields() {
        let f = MeasurementSchema.fields(for: .skirt)
        #expect(f.contains(.waistFlat) && f.contains(.skirtLength))
    }

    @Test func circumferenceDoublesFlatWidth() {
        let m = FlatMeasurements(values: [.chestFlat: 19])
        #expect(m.circumference(.chestFlat) == 38)
    }

    @Test func circumferenceNilWhenUnset() {
        #expect(FlatMeasurements(values: [:]).circumference(.chestFlat) == nil)
    }

    @Test func completenessFraction() {
        // top 需 4 字段，填 2 → 0.5
        let m = FlatMeasurements(values: [.chestFlat: 19, .garmentLength: 26])
        #expect(m.completeness(for: .top) == 0.5)
    }

    @Test func completenessFullWhenAllFilled() {
        let m = FlatMeasurements(values: [.waistFlat: 15, .hipFlat: 20, .inseam: 30, .riseFront: 10])
        #expect(m.completeness(for: .bottom) == 1.0)
    }

    @Test func nominalSizeNeverAssumesCrossBrandEquality() {
        // 同标签 "M" 不同体系 → 不相等（尺码不可跨体系/品牌等同，vanity sizing 铁律）
        let a = NominalSize(system: .us, rawLabel: "M")
        let b = NominalSize(system: .eu, rawLabel: "M")
        #expect(a != b)
    }

    @Test func nominalSizePreservesRawLabel() {
        // 原始标签保真（如中国号型 160/84A 不被规约）
        #expect(NominalSize(system: .cnGBT, rawLabel: "160/84A").rawLabel == "160/84A")
    }

    @Test func fitFromMeasurementsIntegratesEaseEngine() {
        // 尺码归一化的落点：合身走 measurements 而非尺码标签
        let garment = FlatMeasurements(values: [.chestFlat: 19]) // 周长 38
        let bodyBust = 34.0
        let ease = FitEngine.ease(garmentFlatWidth: garment.circumference(.chestFlat)! / 2, bodyCircumference: bodyBust)
        #expect(ease == 4)
        #expect(FitEngine.verdict(ease: ease, band: EaseBand(minEase: 2, maxEase: 6)) == .fitted)
    }

    @Test func circumferenceNilForNonPositiveOrNonFiniteFlat() {
        // 0/负/NaN 平铺宽为脏填值 → 视同未填
        #expect(FlatMeasurements(values: [.chestFlat: 0]).circumference(.chestFlat) == nil)
        #expect(FlatMeasurements(values: [.chestFlat: -3]).circumference(.chestFlat) == nil)
        #expect(FlatMeasurements(values: [.chestFlat: .nan]).circumference(.chestFlat) == nil)
    }

    @Test func completenessIgnoresNonPositiveDirtyValues() {
        // top 4 字段：1 个有效 + 3 个脏值（0/负/NaN）→ 0.25，而非把脏填值当已测得 1.0
        let m = FlatMeasurements(values: [.chestFlat: 19, .garmentLength: 0, .shoulder: -2, .sleeve: .nan])
        #expect(m.completeness(for: .top) == 0.25)
    }
}
