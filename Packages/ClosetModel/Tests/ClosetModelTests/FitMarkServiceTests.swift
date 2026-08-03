import Testing
import Foundation
@testable import ClosetModel
import ClosetCore

@MainActor
struct FitMarkServiceTests {

    @Test func nilWhenMissingFlatWidth() {
        let item = Item(name: "tee"); item.slotRaw = "top"
        let profile = PersonBodyProfile(personID: UUID()); profile.bustInches = 34
        #expect(FitMarkService.mark(item: item, profile: profile) == nil)
    }

    @Test func nilWhenMissingBody() {
        let item = Item(name: "tee"); item.slotRaw = "top"; item.chestFlatWidthInches = 18
        let profile = PersonBodyProfile(personID: UUID())
        #expect(FitMarkService.mark(item: item, profile: profile) == nil)
    }

    @Test func topFittedWhenEaseInBand() {
        // flat 18 → circ 36; body 34 → ease 2 ∈ [1,5]
        let item = Item(name: "tee"); item.slotRaw = "top"; item.chestFlatWidthInches = 18
        let profile = PersonBodyProfile(personID: UUID()); profile.bustInches = 34
        #expect(FitMarkService.mark(item: item, profile: profile) == .fitted)
    }

    @Test func topTightWhenEaseBelowBand() {
        // flat 16 → circ 32; body 34 → ease -2 < 1
        let item = Item(name: "tee"); item.slotRaw = "top"; item.chestFlatWidthInches = 16
        let profile = PersonBodyProfile(personID: UUID()); profile.bustInches = 34
        #expect(FitMarkService.mark(item: item, profile: profile) == .tight)
    }

    @Test func bottomUsesWaist() {
        // flat 14 → circ 28; body 28 → ease 0 < 0.5 → tight
        let item = Item(name: "pants"); item.slotRaw = "bottom"; item.waistFlatWidthInches = 14
        let profile = PersonBodyProfile(personID: UUID()); profile.waistInches = 28
        #expect(FitMarkService.mark(item: item, profile: profile) == .tight)
    }

    @Test func shoesNoMark() {
        let item = Item(name: "sneakers"); item.slotRaw = "shoes"; item.chestFlatWidthInches = 10
        let profile = PersonBodyProfile(personID: UUID()); profile.bustInches = 34
        #expect(FitMarkService.mark(item: item, profile: profile) == nil)
    }
}
