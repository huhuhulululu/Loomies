import Testing
import Foundation
@testable import ClosetCore

/// D86 遥测门：白名单 `sanitize` 此前是**零调用点死代码**——没有发送出口、没有同意门，
/// 而 About 文案已向用户承诺「opt-in when enabled」。本波补上出口与门，
/// 并让「绕过白名单发事件」在结构上不可能（sanitize 是 track 的内部步骤，非可选前置）。
struct TelemetryGateTests {

    /// 记录 sink（测试替身）——生产默认无 sink，什么都不发。
    final class RecordingSink: TelemetrySink, @unchecked Sendable {
        private let lock = NSLock()
        private var events: [(TelemetryEvent, [String: String])] = []
        func send(_ event: TelemetryEvent, payload: [String: String]) {
            lock.lock(); events.append((event, payload)); lock.unlock()
        }
        var recorded: [(TelemetryEvent, [String: String])] {
            lock.lock(); defer { lock.unlock() }; return events
        }
    }

    /// 每个用例独立 UserDefaults suite——共享 .standard 会让并行用例互相翻转同意位。
    func makeGate(enabled: Bool, sink: RecordingSink?) -> (TelemetryGate, UserDefaults, String) {
        let suite = "telemetry-gate-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let gate = TelemetryGate(sink: sink, defaults: defaults)
        gate.setEnabled(enabled)
        return (gate, defaults, suite)
    }

    @Test func disabledGateSendsNothing() {
        let sink = RecordingSink()
        let (gate, defaults, suite) = makeGate(enabled: false, sink: sink)
        defer { defaults.removePersistentDomain(forName: suite) }
        gate.track(.appLaunch, payload: [:])
        gate.track(.copilotRefresh, payload: ["mode": "auto"])
        #expect(sink.recorded.isEmpty)
        #expect(!gate.isEnabled)
    }

    @Test func enabledGateSendsSanitizedPayloadOnly() {
        let sink = RecordingSink()
        let (gate, defaults, suite) = makeGate(enabled: true, sink: sink)
        defer { defaults.removePersistentDomain(forName: suite) }
        gate.track(.copilotRefresh, payload: [
            "mode": "auto",
            "occasion": "work",
            "bust_inches": "34",       // 白名单外 + 身体维度
            "item_name": "Blue Shirt", // 白名单外
        ])
        let recorded = sink.recorded
        #expect(recorded.count == 1)
        let payload = recorded[0].1
        #expect(payload["mode"] == "auto")
        #expect(payload["occasion"] == "work")
        #expect(payload["schema_version"] != nil)
        #expect(payload["item_name"] == nil)
        #expect(payload["bust_inches"] == nil)
    }

    /// 身体/图像红线键出现即整包丢弃（不是只丢那个键）——沿用 sanitize 语义。
    @Test func forbiddenKeysDropTheWholeEvent() {
        let sink = RecordingSink()
        let (gate, defaults, suite) = makeGate(enabled: true, sink: sink)
        defer { defaults.removePersistentDomain(forName: suite) }
        gate.track(.onboardingCompleted, payload: ["bust": "34"])
        #expect(sink.recorded.isEmpty)
    }

    /// 默认（生产）无 sink：即使开启也不会发——当前 build 没接任何分析服务，
    /// 文案也如实这么说。
    @Test func defaultGateHasNoSinkSoNothingEscapes() {
        let (gate, defaults, suite) = makeGate(enabled: true, sink: nil)
        defer { defaults.removePersistentDomain(forName: suite) }
        gate.track(.appLaunch, payload: [:])   // 不崩、不发
        #expect(gate.isEnabled)
        #expect(!gate.hasSink)
    }

    /// opt-in 状态可持久化（UserDefaults 注入），默认关闭。
    @Test func consentDefaultsOffAndPersists() {
        let suite = "telemetry-gate-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let gate = TelemetryGate(defaults: defaults)
        #expect(!gate.isEnabled)   // 默认关闭（opt-in，不是 opt-out）
        gate.setEnabled(true)
        #expect(TelemetryGate(defaults: defaults).isEnabled)
        gate.setEnabled(false)
        #expect(!TelemetryGate(defaults: defaults).isEnabled)
    }

    /// 结构性保证：sanitize 是 track 的内部步骤，sink 只能收到已净化载荷。
    /// （sink 协议不暴露原始 payload，绕过白名单发事件在类型层就做不到。）
    @Test func sinkNeverSeesRawPayload() {
        let sink = RecordingSink()
        let (gate, defaults, suite) = makeGate(enabled: true, sink: sink)
        defer { defaults.removePersistentDomain(forName: suite) }
        gate.track(.itemConfirmed, payload: ["slot": "top", "photo_path": "/var/x.jpg"])
        #expect(sink.recorded.count == 1)
        #expect(sink.recorded[0].1["photo_path"] == nil)
        #expect(sink.recorded[0].1["slot"] == "top")
    }
}
