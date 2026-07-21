import Testing
@testable import ClosetCore

struct OutfitGrammarTests {
    let shoes = CandidateItem(id: "sh", slot: .shoes)

    @Test func topBottomShoesIsValid() {
        let items = [CandidateItem(id: "t", slot: .top), CandidateItem(id: "b", slot: .bottom), shoes]
        #expect(OutfitGrammar.violations(items).isEmpty)
    }

    @Test func dressShoesIsValid() {
        #expect(OutfitGrammar.violations([CandidateItem(id: "d", slot: .dress), shoes]).isEmpty)
    }

    @Test func missingBottom() {
        let v = OutfitGrammar.violations([CandidateItem(id: "t", slot: .top), shoes])
        #expect(v.contains(.missingBottom))
    }

    @Test func missingShoes() {
        let v = OutfitGrammar.violations([CandidateItem(id: "t", slot: .top), CandidateItem(id: "b", slot: .bottom)])
        #expect(v.contains(.missingShoes))
    }

    @Test func dressWithSeparatesConflicts() {
        let v = OutfitGrammar.violations([CandidateItem(id: "d", slot: .dress), CandidateItem(id: "t", slot: .top), shoes])
        #expect(v.contains(.dressWithSeparates))
    }

    @Test func doubleBottomIsDuplicate() {
        let v = OutfitGrammar.violations([
            CandidateItem(id: "t", slot: .top),
            CandidateItem(id: "b1", slot: .bottom),
            CandidateItem(id: "b2", slot: .bottom), shoes])
        #expect(v.contains(.duplicate(.bottom)))
    }

    @Test func doubleBlazerIsDuplicateSubtype() {
        let v = OutfitGrammar.violations([
            CandidateItem(id: "t", slot: .top),
            CandidateItem(id: "b", slot: .bottom), shoes,
            CandidateItem(id: "o1", slot: .outerwear, subtype: "blazer"),
            CandidateItem(id: "o2", slot: .outerwear, subtype: "blazer")])
        #expect(v.contains(.duplicateSubtype("blazer")))
    }
}
