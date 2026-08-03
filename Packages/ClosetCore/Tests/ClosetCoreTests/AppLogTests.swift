import Testing
import Foundation
@testable import ClosetCore

@Suite(.serialized)  // 共享 minLevel / ring，禁止并行
struct AppLogTests {

    @Test func ringKeepsRecentEntries() {
        AppLog.ring.clear()
        AppLog.setMinLevel(.debug)
        for i in 0..<5 {
            AppLog.info("msg-\(i)", .diagnostics)
        }
        let snap = AppLog.ring.snapshot()
        #expect(snap.count >= 5)
        #expect(snap.last?.message == "msg-4")
        #expect(snap.last?.category == .diagnostics)
    }

    @Test func minLevelFiltersDebug() {
        AppLog.ring.clear()
        AppLog.setMinLevel(.error)
        AppLog.debug("should-drop", .app)
        AppLog.error("should-keep", .app)
        let msgs = AppLog.ring.snapshot().map(\.message)
        #expect(!msgs.contains("should-drop"))
        #expect(msgs.contains("should-keep"))
        AppLog.setMinLevel(.debug)  // restore for other tests
    }

    @Test func timedRecordsDurationMessage() {
        AppLog.ring.clear()
        AppLog.setMinLevel(.debug)
        let v = AppLog.timed("unit-work", .copilot) { 42 }
        #expect(v == 42)
        let hit = AppLog.ring.snapshot().contains { $0.message.contains("unit-work done") }
        #expect(hit)
    }

    @Test func logEntryLineTextNonEmpty() {
        let e = LogEntry(date: Date(), level: .info, category: .data,
                         message: "hello", file: "x", line: 1)
        #expect(e.lineText.contains("hello"))
        #expect(e.lineText.contains("info"))
    }
}
