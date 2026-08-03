import Testing
@testable import ClosetCore

struct TelemetryEventsTests {

    @Test func sanitizeKeepsAllowedKeysAndSchema() {
        let out = TelemetryPayload.sanitize(.copilotRefresh, payload: [
            "mode": "copilot",
            "occasion": "work",
            "suggestion_count": "3",
            "extra": "drop_me"
        ])
        #expect(out != nil)
        #expect(out?["schema_version"] == TelemetryPayload.schemaVersion)
        #expect(out?["mode"] == "copilot")
        #expect(out?["extra"] == nil)
    }

    @Test func sanitizeRejectsBodyKeys() {
        let out = TelemetryPayload.sanitize(.fitMarkShown, payload: [
            "verdict": "fitted",
            "bust": "36"   // 红线
        ])
        #expect(out == nil)
    }

    @Test func sanitizeRejectsImageKeys() {
        let out = TelemetryPayload.sanitize(.itemConfirmed, payload: [
            "slot": "top",
            "image": "base64..."
        ])
        #expect(out == nil)
    }

    @Test func allEventsHaveNonEmptyAllowedKeys() {
        for e in TelemetryEvent.allCases {
            #expect(e.allowedKeys.contains("schema_version"))
        }
    }
}
