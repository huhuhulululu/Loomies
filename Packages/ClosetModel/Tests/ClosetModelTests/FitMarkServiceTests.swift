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

    @Test func outerwearCanonicalAndDirtyTopGetChestMark() {
        // demo seed / intake 写 outerwear（旧 switch 只认 "outer" 会漏）
        let blazer = Item(name: "Navy blazer")
        blazer.slotRaw = "outerwear"
        blazer.chestFlatWidthInches = 18
        let profile = PersonBodyProfile(personID: UUID()); profile.bustInches = 34
        #expect(FitMarkService.mark(item: blazer, profile: profile) == .fitted)

        // 脏数据 blazer-as-top → resolved outerwear，仍按胸围
        let dirty = Item(name: "Camel coat")
        dirty.slotRaw = "top"
        dirty.chestFlatWidthInches = 18
        #expect(FitMarkService.mark(item: dirty, profile: profile) == .fitted)

        // 别名 raw
        let alias = Item(name: "Piece")
        alias.slotRaw = "outer"
        alias.chestFlatWidthInches = 18
        #expect(FitMarkService.mark(item: alias, profile: profile) == .fitted)
    }

    /// Closet grid FitMark must follow live profile edits (Me → Body), not a stale snapshot.
    @Test func markTracksLiveProfileMeasureEdits() {
        let item = Item(name: "tee"); item.slotRaw = "top"; item.chestFlatWidthInches = 18
        let profile = PersonBodyProfile(personID: UUID()); profile.bustInches = 34
        #expect(FitMarkService.mark(item: item, profile: profile) == .fitted)
        // Larger body → same flat width feels tighter
        profile.bustInches = 40
        #expect(FitMarkService.mark(item: item, profile: profile) == .tight)
        // Smaller body again → roomier / fitted depending on ease band
        profile.bustInches = 34
        #expect(FitMarkService.mark(item: item, profile: profile) == .fitted)
        #expect(FitMarkCopy.label(.fitted) != FitMarkCopy.label(.tight))
    }

    /// Field API powers detail live preview (unsaved widths / dirty name→outerwear).
    @Test func markFromFieldsMatchesItemAndResolvesDirtyName() {
        let profile = PersonBodyProfile(personID: UUID()); profile.bustInches = 34
        let fromFields = FitMarkService.mark(
            slotRaw: "top",
            name: "Camel coat",
            chestFlatWidthInches: 18,
            waistFlatWidthInches: nil,
            profile: profile)
        #expect(fromFields == .fitted)

        let item = Item(name: "Camel coat")
        item.slotRaw = "top"
        item.chestFlatWidthInches = 18
        #expect(FitMarkService.mark(item: item, profile: profile) == fromFields)

        #expect(FitMarkService.mark(
            slotRaw: "bottom",
            name: "Trousers",
            chestFlatWidthInches: 99,
            waistFlatWidthInches: 14,
            profile: {
                let p = PersonBodyProfile(personID: UUID())
                p.waistInches = 28
                return p
            }()) == .tight)
    }
}
