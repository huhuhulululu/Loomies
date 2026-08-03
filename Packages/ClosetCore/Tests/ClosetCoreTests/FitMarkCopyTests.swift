import Testing
@testable import ClosetCore

struct FitMarkCopyTests {
    @Test func labelsAreNonEmptyUSEnglish() {
        for v in [FitVerdict.tight, .fitted, .loose] {
            #expect(!FitMarkCopy.label(v).isEmpty)
            #expect(!FitMarkCopy.detail(v).isEmpty)
        }
        #expect(FitMarkCopy.label(.fitted) == "True to size")
        #expect(FitMarkCopy.label(.tight) == "Runs tight")
        #expect(FitMarkCopy.label(.loose) == "Runs loose")
    }
}
