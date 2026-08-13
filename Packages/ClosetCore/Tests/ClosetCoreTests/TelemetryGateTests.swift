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

/// D88：遥测开关不得是**安慰剂控件**。此前 `track()` 在全部生产代码里零调用点——
/// 白名单里定义了 10 个事件，一个都没有产出方；用户在 Privacy 分组拨动的开关
/// 不改变任何行为。文案本身诚实（"Nothing is sent yet"），但控件本身是空的。
struct TelemetryWiringTests {

    static func productionSources() -> [URL] {
        let packages = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let appShell = packages.deletingLastPathComponent()
            .appendingPathComponent("app-shell", isDirectory: true)
        var files: [URL] = []
        let fm = FileManager.default
        for root in [packages, appShell] {
            let en = fm.enumerator(at: root, includingPropertiesForKeys: nil)
            while let url = en?.nextObject() as? URL {
                guard url.pathExtension == "swift",
                      url.path.contains("/Sources/") || url.path.contains("/app-shell/"),
                      !url.path.contains("/Tests/"), !url.path.contains("/.build/")
                else { continue }
                files.append(url)
            }
        }
        return files
    }

    /// 每个白名单事件都必须有生产产出方——否则它只是个没人发的枚举 case。
    @Test func everyDeclaredEventHasAProductionEmitter() throws {
        var body = ""
        for url in Self.productionSources() {
            body += (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }
        #expect(body.contains("TelemetryGate.shared.track("), "全仓零调用点")
        var missing: [String] = []
        for event in TelemetryEvent.allCases {
            // 调用点写作 `.appLaunch` / `.itemConfirmed` 等
            let needle = ".\(String(describing: event))"
            let emitted = body.components(separatedBy: "track(").dropFirst()
                .contains { $0.hasPrefix(needle) }
            if !emitted { missing.append(event.rawValue) }
        }
        #expect(missing.isEmpty, Comment(rawValue: "无产出方的事件：\(missing)"))
    }

    /// 产出方不得夹带红线字段：搜索词、单品名、城市、围度一律不进 payload。
    /// D164：判据从「键名恰好叫 name」改成**看值读了什么**。
    ///
    /// 原来只匹配 `"name":` 这种恰好同名的键——而 `"closet_name": wardrobe.name`
    /// 泄漏的是同一份内容，却一个字都不匹配（实测注入后门照样绿）。
    /// **危险在值，不在键名**：一个叫 `mode` 的键塞进 `item.name` 同样是泄漏。
    /// 键名仍然查（叫 `name` 的键本身就可疑），但主判据是值里读了用户内容没有。
    /// D165：**这张表必须跟着 schema 走。**
    ///
    /// 上一条的 `userContentReads` 是手工枚举的——schema 加一个
    /// `.nickname` 而没人想起来更新它，那道门就会对新字段视而不见，
    /// 而且**没有任何征兆**（本 session 已经在四道门上见过这个形态）。
    ///
    /// 判据：实体里每个用户可输入的 String 字段（排除 `…Raw` 枚举存储、
    /// 路径/键这类机器字段）都必须在表里有对应项，或在下面的豁免表里
    /// 写明理由。加字段的人会被这条门拦下来，而不是被下一次隐私事故拦下来。
    @Test func theUserContentListTracksTheSchema() throws {
        let entities = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ClosetModel/Sources/ClosetModel/Entities.swift")
        let text = try String(contentsOf: entities, encoding: .utf8)

        /// 机器字段：不是用户写进去的内容，泄漏它们不构成隐私问题。
        let notUserContent: Set<String> = [
            "localImageRelativePath",   // 相对路径（uuid 文件名）
            "dayKey",                   // "yyyy-MM-dd"
            "fitFeedback",              // 紧/合/松 三选一，枚举化的
            "subtype",                  // 受控词表（blazer/coat…）
        ]
        var missing: [String] = []
        for line in text.split(separator: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard t.hasPrefix("public var "), t.contains(": String") else { continue }
            let prop = t.dropFirst("public var ".count)
                .prefix { $0 != ":" }
                .trimmingCharacters(in: .whitespaces)
            guard !prop.hasSuffix("Raw"), !notUserContent.contains(prop) else { continue }
            let covered = UserContentFields.reads.contains { $0.contains(prop) }
            if !covered { missing.append(prop) }
        }
        #expect(missing.isEmpty, Comment(rawValue:
            "schema 里这些用户内容字段没进遥测判据表，泄漏时门不会响：\(missing) —— "
            + "把它们加进 `userContentReads`，或在本测试的豁免表里写明为什么不算用户内容"))
    }

    @Test func emittersCarryNoUserContent() throws {
        var violations: [String] = []
        let forbidden = ["text", "name", "city", "query", "bust", "waist", "hip"]
        let userContentReads = UserContentFields.reads
        for url in Self.productionSources() {
            guard let text = try? String(contentsOf: url, encoding: .utf8),
                  text.contains("TelemetryGate.shared.track(") else { continue }
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            for (n, line) in lines.enumerated() {
                // payload 字面量键名（"xxx": ...）
                guard line.contains("\": ") else { continue }
                // 只看 track( 调用之后 6 行内的键
                let start = max(0, n - 6)
                let window = lines[start...n].joined()
                guard window.contains("track(") else { continue }
                for key in forbidden where line.contains("\"\(key)\":") {
                    violations.append("\(url.lastPathComponent):\(n + 1) ~ 键名 \(key)")
                }
                // 值侧：`"任意键": 读到用户内容` —— 只看冒号之后
                let value = line.components(separatedBy: "\": ").dropFirst().joined(separator: "\": ")
                for read in userContentReads where value.contains(read) {
                    violations.append("\(url.lastPathComponent):\(n + 1) ~ 值里读了 \(read)")
                }
            }
        }
        #expect(violations.isEmpty, Comment(rawValue: "\(violations)"))
    }
}
