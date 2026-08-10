import Foundation
import SwiftData
import ClosetCore

/// 统一 save：记录错误，DEBUG 可抛；避免静默 `try? context.save()` 丢失败。
public enum ModelSave {
    public enum Mode: Sendable { case soft, strict }

    /// Test hook: contexts registered here always fail save (tests force failure paths).
    /// Keyed by context so parallel suites using their own contexts are unaffected.
    private static let forceFailureLock = NSLock()
    nonisolated(unsafe) private static var forceFailureIDs = Set<ObjectIdentifier>()

    /// Test hook: force all ModelSave calls on this context to fail.
    static func forceFailure(on context: ModelContext) {
        forceFailureLock.lock()
        forceFailureIDs.insert(ObjectIdentifier(context))
        forceFailureLock.unlock()
    }

    /// Test hook: clear a forced failure registered with `forceFailure(on:)`.
    static func clearForcedFailure(on context: ModelContext) {
        forceFailureLock.lock()
        forceFailureIDs.remove(ObjectIdentifier(context))
        forceFailureLock.unlock()
    }

    @discardableResult
    public static func save(_ context: ModelContext, mode: Mode = .soft,
                            label: String = "save") -> Bool {
        forceFailureLock.lock()
        let forced = forceFailureIDs.contains(ObjectIdentifier(context))
        forceFailureLock.unlock()
        if forced {
            AppLog.error("ModelSave.\(label) forced failure (test hook)", .data)
            return false
        }
        do {
            try context.save()
            AppLog.debug("ModelSave.\(label) ok", .data)
            return true
        } catch {
            AppLog.error("ModelSave.\(label) failed: \(AppLog.errRef(error))", .data)
            #if DEBUG
            if mode == .strict { assertionFailure("ModelSave.\(label): \(error)") }
            #endif
            return false
        }
    }
}
