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
}
