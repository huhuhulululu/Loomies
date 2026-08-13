import Foundation
import SwiftData
import ClosetCore

/// 统一 save：记录错误，DEBUG 可抛；避免静默 `try? context.save()` 丢失败。
public enum ModelSave {
    public enum Mode: Sendable { case soft, strict }

    /// Test hook: contexts registered here always fail save (tests force failure paths).
    ///
    /// D143：键是 `ObjectIdentifier`——**也就是堆地址**。注册过的 context 释放而
    /// 没人清，这条记录就留着；之后新分配的某个 `ModelContext` 正好落在同一地址时，
    /// 会凭空继承「所有 save 都失败」。那种污染与代码改动无关、与测试顺序有关、
    /// 复现不了——最贵的那一类。
    ///
    /// 所以额外持**弱引用**：查表时要求那个对象仍活着且是同一个，
    /// 死掉的条目当场清掉。地址被回收也就没得继承了。
    private static let forceFailureLock = NSLock()
    private final class WeakContext {
        weak var context: ModelContext?
        init(_ c: ModelContext) { context = c }
    }
    nonisolated(unsafe) private static var forceFailureIDs: [ObjectIdentifier: WeakContext] = [:]

    /// Test hook: force all ModelSave calls on this context to fail.
    static func forceFailure(on context: ModelContext) {
        forceFailureLock.lock()
        forceFailureIDs[ObjectIdentifier(context)] = WeakContext(context)
        forceFailureLock.unlock()
    }

    /// Test hook: clear a forced failure registered with `forceFailure(on:)`.
    static func clearForcedFailure(on context: ModelContext) {
        forceFailureLock.lock()
        forceFailureIDs.removeValue(forKey: ObjectIdentifier(context))
        forceFailureLock.unlock()
    }

    /// Test hook: 当前还挂着几条（用来断言死条目真的被清掉了）。
    static var forcedFailureCount: Int {
        forceFailureLock.lock()
        defer { forceFailureLock.unlock() }
        purgeDeadEntriesLocked()
        return forceFailureIDs.count
    }

    /// 调用方必须已持锁。
    private static func purgeDeadEntriesLocked() {
        forceFailureIDs = forceFailureIDs.filter { $0.value.context != nil }
    }

    @discardableResult
    public static func save(_ context: ModelContext, mode: Mode = .soft,
                            label: String = "save") -> Bool {
        forceFailureLock.lock()
        purgeDeadEntriesLocked()
        // 弱引用还指着**同一个**对象才算数——只比地址会认错人
        let forced = forceFailureIDs[ObjectIdentifier(context)]?.context === context
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
