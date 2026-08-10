import Testing
@testable import ClosetCore

struct TextNormalizeTests {
    @Test func blankToNilTrimsAndCollapses() {
        #expect(TextNormalize.blankToNil(nil) == nil)
        #expect(TextNormalize.blankToNil("") == nil)
        #expect(TextNormalize.blankToNil("   ") == nil)
        #expect(TextNormalize.blankToNil("\n\t ") == nil)
        #expect(TextNormalize.blankToNil("Sézane") == "Sézane")
        #expect(TextNormalize.blankToNil("  Acne Studios  ") == "Acne Studios")
    }

    @Test func isBlankMatchesBlankToNil() {
        #expect(TextNormalize.isBlank(nil))
        #expect(TextNormalize.isBlank(" "))
        #expect(!TextNormalize.isBlank(" M "))
    }
}
