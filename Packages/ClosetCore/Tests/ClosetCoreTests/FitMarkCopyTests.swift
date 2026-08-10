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

    /// Detail must not overclaim try-on / “fit as intended”; measurement ease only.
    @Test func detailIsProportionGuideNotTryOn() {
        for v in [FitVerdict.tight, .fitted, .loose] {
            let d = FitMarkCopy.detail(v)
            #expect(d.localizedCaseInsensitiveContains("proportion guide"))
            #expect(d.localizedCaseInsensitiveContains("flat widths")
                || d.localizedCaseInsensitiveContains("measures"))
            #expect(!d.localizedCaseInsensitiveContains("try-on"))
            #expect(!d.localizedCaseInsensitiveContains("as intended"))
            #expect(!d.localizedCaseInsensitiveContains("on your body"))
        }
    }
}
