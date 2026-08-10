import Testing
@testable import ClosetCore

struct CandidateFilterTests {
    // 75°F 日间 → 可接受 veryLight...medium
    let ctx = FilterContext(occasion: "work", daytimeTempF: 75, wornWithin7DaysIDs: ["recent"])

    @Test func keepsAvailableMatchingOccasionAndWeather() {
        let item = CandidateItem(id: "a", slot: .top, occasions: ["work"], warmth: .light)
        #expect(CandidateFilter.filter([item], context: ctx).map(\.id) == ["a"])
    }

    @Test func dropsNonAvailableStatus() {
        let item = CandidateItem(id: "a", slot: .top, occasions: ["work"], warmth: .light, status: .inWash)
        #expect(CandidateFilter.filter([item], context: ctx).isEmpty)
    }

    @Test func dropsWrongOccasion() {
        let item = CandidateItem(id: "a", slot: .top, occasions: ["gala"], warmth: .light)
        #expect(CandidateFilter.filter([item], context: ctx).isEmpty)
    }

    @Test func keepsUnknownOccasion() {
        // occasions 空 = 未知，三值语义不硬过滤
        let item = CandidateItem(id: "a", slot: .top, occasions: [], warmth: .light)
        #expect(CandidateFilter.filter([item], context: ctx).map(\.id) == ["a"])
    }

    @Test func dropsTooWarmForWeather() {
        // 75°F 下 veryWarm 超出可接受上限 medium
        let item = CandidateItem(id: "a", slot: .top, occasions: ["work"], warmth: .veryWarm)
        #expect(CandidateFilter.filter([item], context: ctx).isEmpty)
    }

    @Test func keepsUnknownWarmth() {
        let item = CandidateItem(id: "a", slot: .top, occasions: ["work"], warmth: nil)
        #expect(CandidateFilter.filter([item], context: ctx).map(\.id) == ["a"])
    }

    @Test func dropsRecentlyWorn() {
        let item = CandidateItem(id: "recent", slot: .top, occasions: ["work"], warmth: .light)
        #expect(CandidateFilter.filter([item], context: ctx).isEmpty)
    }

    /// C3: 写入端大小写/空白不一致（编辑器保存 "Work"，上下文用 "work"），
    /// 过滤边界归一化后不得静默排除。
    @Test func occasionMatchIsCaseAndWhitespaceInsensitive() {
        let capitalized = CandidateItem(id: "a", slot: .top, occasions: ["Work"], warmth: .light)
        #expect(CandidateFilter.filter([capitalized], context: ctx).map(\.id) == ["a"])
        let padded = CandidateItem(id: "b", slot: .top, occasions: [" work "], warmth: .light)
        #expect(CandidateFilter.filter([padded], context: ctx).map(\.id) == ["b"])
    }

    /// occasion "" / 纯空白 = 未指定场合（非可选 String 的自然 unset 值），
    /// 不得反向硬过滤掉所有已知场合单品（三值语义的对称侧）。
    @Test func emptyOccasionKeepsKnownOccasionItems() {
        let item = CandidateItem(id: "a", slot: .top, occasions: ["work"], warmth: .light)
        let emptyCtx = FilterContext(occasion: "", daytimeTempF: 75)
        #expect(CandidateFilter.filter([item], context: emptyCtx).map(\.id) == ["a"])
        let blankCtx = FilterContext(occasion: "   ", daytimeTempF: 75)
        #expect(CandidateFilter.filter([item], context: blankCtx).map(\.id) == ["a"])
    }

    /// NaN/±inf 温度是垃圾输入：不得落入 default 深冬偏置，应全温区放行。
    @Test func nonFiniteTemperatureKeepsAllWarmthLevels() {
        for t in [Double.nan, .infinity, -.infinity] {
            let band = WeatherFit.acceptableWarmth(daytimeTempF: t)
            #expect(band.lowerBound == .veryLight && band.upperBound == .veryWarm)
        }
        let nanCtx = FilterContext(occasion: "work", daytimeTempF: .nan)
        for w in Warmth.allCases {
            let item = CandidateItem(id: "a", slot: .top, occasions: ["work"], warmth: w)
            #expect(CandidateFilter.filter([item], context: nanCtx).map(\.id) == ["a"])
        }
    }
}
