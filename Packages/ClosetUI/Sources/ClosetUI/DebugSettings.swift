import Foundation
import Observation
import ClosetCore

/// 运行时调试开关（Me 调试台 + launch args）。
/// 持久化 UserDefaults，TestFlight 内测也可开（非仅 DEBUG）。
@MainActor
@Observable
public final class DebugSettings {
    public static let shared = DebugSettings()

    private let defaults: UserDefaults
    private enum Key {
        static let verbose = "debug.verboseLogging"
        static let forceCold = "debug.forceColdStart"
        static let disableAntiRepeat = "debug.disableAntiRepeat"
        static let showEmptyReason = "debug.showEmptyReason"
        static let panel = "debug.panelEnabled"
    }

    public var verboseLogging: Bool {
        didSet {
            defaults.set(verboseLogging, forKey: Key.verbose)
            AppLog.setMinLevel(verboseLogging ? .debug : defaultMinLevel)
            AppLog.notice("verboseLogging=\(verboseLogging)", .diagnostics)
        }
    }
    /// 强制冷启动门（即使衣橱已够大）。
    public var forceColdStart: Bool {
        didSet { defaults.set(forceColdStart, forKey: Key.forceCold) }
    }
    /// 关闭近 7 天防重复（调试推荐覆盖率）。
    public var disableAntiRepeat: Bool {
        didSet { defaults.set(disableAntiRepeat, forKey: Key.disableAntiRepeat) }
    }
    /// Today 显示 empty reason / 耗时。
    public var showEmptyReason: Bool {
        didSet { defaults.set(showEmptyReason, forKey: Key.showEmptyReason) }
    }
    /// Me 显示完整调试台。
    public var panelEnabled: Bool {
        didSet { defaults.set(panelEnabled, forKey: Key.panel) }
    }

    private var defaultMinLevel: AppLog.Level {
        #if DEBUG
        .debug
        #else
        .error
        #endif
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // launch args 优先
        let args = ProcessInfo.processInfo.arguments
        let env = ProcessInfo.processInfo.environment
        let launchVerbose = args.contains("-debugVerbose") || env["LOOMIES_DEBUG"] == "1"
        let launchPanel = args.contains("-debugPanel") || env["LOOMIES_DEBUG"] == "1"
        #if DEBUG
        let debugDefaultPanel = true
        #else
        let debugDefaultPanel = false
        #endif

        self.verboseLogging = defaults.object(forKey: Key.verbose) as? Bool ?? launchVerbose
        self.forceColdStart = defaults.bool(forKey: Key.forceCold)
        self.disableAntiRepeat = defaults.bool(forKey: Key.disableAntiRepeat)
        self.showEmptyReason = defaults.object(forKey: Key.showEmptyReason) as? Bool ?? true
        self.panelEnabled = defaults.object(forKey: Key.panel) as? Bool
            ?? (launchPanel || debugDefaultPanel)

        AppLog.setMinLevel(verboseLogging ? .debug : defaultMinLevel)
        if launchVerbose || launchPanel {
            AppLog.notice("DebugSettings from launch args/env", .diagnostics)
        }
    }

    public var flagsForDiagnostics: [String: String] {
        [
            "verbose": "\(verboseLogging)",
            "forceColdStart": "\(forceColdStart)",
            "disableAntiRepeat": "\(disableAntiRepeat)",
            "showEmptyReason": "\(showEmptyReason)",
            "panel": "\(panelEnabled)",
        ]
    }

    public func resetAll() {
        verboseLogging = false
        forceColdStart = false
        disableAntiRepeat = false
        showEmptyReason = true
        #if DEBUG
        panelEnabled = true
        #else
        panelEnabled = false
        #endif
        AppLog.ring.clear()
        AppLog.notice("DebugSettings reset", .diagnostics)
    }
}
