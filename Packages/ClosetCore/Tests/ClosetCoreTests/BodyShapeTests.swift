import Testing
@testable import ClosetCore

/// FFIT 9 类各一个手工核算样本（英寸），依据 docs/research/04-body-avatar.md §3.1 plus-size 修正公式逐条构造。
struct BodyShapeTests {

    @Test func hourglass() {
        // bust−hip=-0.5≤1；hip−bust=0.5<3.6；bust−waist=11≥9 → 沙漏
        #expect(FFITClassifier.classify(.init(bust: 38, waist: 27, hip: 38.5, highHip: 33)) == .hourglass)
    }

    @Test func bottomHourglass() {
        // hip−bust=4（≥3.6,<10）；hip−waist=11≥9；highHip/waist=34/29=1.17<1.193 → 下沙漏
        #expect(FFITClassifier.classify(.init(bust: 36, waist: 29, hip: 40, highHip: 34)) == .bottomHourglass)
    }

    @Test func topHourglass() {
        // bust−hip=3（>1,<10）；bust−waist=10≥9 → 上沙漏
        #expect(FFITClassifier.classify(.init(bust: 40, waist: 30, hip: 37, highHip: 33)) == .topHourglass)
    }

    @Test func spoon() {
        // hip−bust=6>2；hip−waist=12≥7；highHip/waist=38/30=1.267≥1.193 → 勺形
        #expect(FFITClassifier.classify(.init(bust: 36, waist: 30, hip: 42, highHip: 38)) == .spoon)
    }

    @Test func triangle() {
        // hip−bust=6≥3.6；0≤hip−waist=7<9 → 三角（梨）
        #expect(FFITClassifier.classify(.init(bust: 34, waist: 33, hip: 40, highHip: 36)) == .triangle)
    }

    @Test func invertedTriangle() {
        // bust−hip=6≥3.6；bust−waist=8<9；hip−waist=2≥0 → 倒三角
        #expect(FFITClassifier.classify(.init(bust: 42, waist: 34, hip: 36, highHip: 35)) == .invertedTriangle)
    }

    @Test func rectangle() {
        // hip−bust=1<3.6 且 bust−hip=-1<3.6；0≤bust−waist=6<9；0≤hip−waist=7<10 → 矩形
        #expect(FFITClassifier.classify(.init(bust: 36, waist: 30, hip: 37, highHip: 33)) == .rectangle)
    }

    @Test func diamond() {
        // hip−waist=-3<0 且 bust−waist=-2<0 → 菱形
        #expect(FFITClassifier.classify(.init(bust: 40, waist: 42, hip: 39, highHip: 41)) == .diamond)
    }

    @Test func oval() {
        // hip−waist=-2<0 且 bust−waist=2≥0 → 椭圆（苹果）
        #expect(FFITClassifier.classify(.init(bust: 44, waist: 42, hip: 40, highHip: 41)) == .oval)
    }

    @Test func popularCategoryMapping() {
        #expect(BodyShape.spoon.popularCategory == .pear)
        #expect(BodyShape.oval.popularCategory == .apple)
        #expect(BodyShape.topHourglass.popularCategory == .hourglass)
    }

    @Test func dirtyInputsYieldNoClassification() {
        // NaN：所有比较为 false，旧实现会漏进兜底被当作真实判定 → 现在 nil
        #expect(FFITClassifier.classifyOrNil(.init(bust: .nan, waist: 27, hip: 38, highHip: 33)) == nil)
        #expect(FFITClassifier.classifyOrNil(.init(bust: 38, waist: 27, hip: 38, highHip: .nan)) == nil)
        // waist==0：旧实现 highHipWaistRatio=.infinity 会把脏输入误导进 .spoon → 现在 nil
        #expect(FFITClassifier.classifyOrNil(.init(bust: 36, waist: 0, hip: 40, highHip: 34)) == nil)
        // 负值 / ±inf 同为脏输入
        #expect(FFITClassifier.classifyOrNil(.init(bust: 36, waist: -27, hip: 38, highHip: 33)) == nil)
        #expect(FFITClassifier.classifyOrNil(.init(bust: 36, waist: .infinity, hip: 38, highHip: 33)) == nil)
    }

    @Test func classifyFallsBackToExplicitRectangleOnDirtyInput() {
        // 非可选 classify 保持签名兼容（ClosetModel 调用方），脏输入显式回退文档化默认 .rectangle。
        #expect(FFITClassifier.classify(.init(bust: .nan, waist: 0, hip: .nan, highHip: 33)) == .rectangle)
        // 干净输入不受影响
        #expect(FFITClassifier.classify(.init(bust: 38, waist: 27, hip: 38.5, highHip: 33)) == .hourglass)
    }
}
