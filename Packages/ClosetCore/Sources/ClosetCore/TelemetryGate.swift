import Foundation

/// 遥测发送出口（D86）。生产默认**无 sink**——当前 build 未接任何分析服务，
/// 合规文案也如实这么说。真机接 SDK 时实现本协议即可。
public protocol TelemetrySink: Sendable {
    /// 只接收**已净化**载荷（白名单过滤后）；拿不到原始 payload。
    func send(_ event: TelemetryEvent, payload: [String: String])
}

/// 遥测同意门 + 唯一发送出口（D86）。
///
/// 此前 `TelemetryEvents.sanitize` 是零调用点死代码：没有出口、没有同意门，
/// 而 About 已向用户承诺 opt-in 控件存在（不实陈述）。本类型补上：
/// - **opt-in**：默认关闭，用户显式打开才可能发送
/// - **唯一出口**：`sanitize` 是 `track` 的内部步骤，sink 协议不暴露原始 payload，
///   「绕过白名单发事件」在类型层就做不到
public final class TelemetryGate: @unchecked Sendable {
    public static let defaultsKey = "loomies.telemetry.enabled"

    /// App 侧唯一实例。生产无 sink——真机接 SDK 时在此注入。
    public static let shared = TelemetryGate()

    private let sink: (any TelemetrySink)?
    private let defaults: UserDefaults
    private let lock = NSLock()

    public init(sink: (any TelemetrySink)? = nil, defaults: UserDefaults = .standard) {
        self.sink = sink
        self.defaults = defaults
    }

    /// 是否已连接分析服务（文案据此说「Nothing is sent yet」）。
    public var hasSink: Bool { sink != nil }

    /// opt-in：默认关闭。
    public var isEnabled: Bool {
        lock.lock(); defer { lock.unlock() }
        return defaults.bool(forKey: Self.defaultsKey)
    }

    public func setEnabled(_ enabled: Bool) {
        lock.lock()
        defaults.set(enabled, forKey: Self.defaultsKey)
        lock.unlock()
        AppLog.notice("telemetry consent=\(enabled)", .telemetry)
    }

    /// 唯一发送入口。未同意 / 载荷含红线键 / 无 sink → 什么都不发。
    public func track(_ event: TelemetryEvent, payload: [String: String] = [:]) {
        guard isEnabled, let sink else { return }
        guard let clean = TelemetryPayload.sanitize(event, payload: payload) else {
            AppLog.notice("telemetry event dropped (forbidden key) \(event.rawValue)", .telemetry)
            return
        }
        sink.send(event, payload: clean)
    }
}
