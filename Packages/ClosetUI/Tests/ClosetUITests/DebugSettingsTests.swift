import Testing
@testable import ClosetUI
import ClosetCore

@MainActor
struct DebugSettingsTests {
    @Test func flagsRoundTrip() {
        let d = DebugSettings.shared
        d.forceColdStart = true
        d.disableAntiRepeat = true
        #expect(d.flagsForDiagnostics["forceColdStart"] == "true")
        #expect(d.flagsForDiagnostics["disableAntiRepeat"] == "true")
        d.resetAll()
        #expect(d.forceColdStart == false)
        #expect(d.disableAntiRepeat == false)
    }
}
