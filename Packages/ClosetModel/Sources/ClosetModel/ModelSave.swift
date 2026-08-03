import Foundation
import SwiftData
import ClosetCore

/// 统一 save：记录错误，DEBUG 可抛；避免静默 `try? context.save()` 丢失败。
public enum ModelSave {
    public enum Mode: Sendable { case soft, strict }

    @discardableResult
    public static func save(_ context: ModelContext, mode: Mode = .soft,
                            label: String = "save") -> Bool {
        do {
            try context.save()
            AppLog.debug("ModelSave.\(label) ok", .data)
            return true
        } catch {
            AppLog.error("ModelSave.\(label) failed: \(error)", .data)
            #if DEBUG
            if mode == .strict { assertionFailure("ModelSave.\(label): \(error)") }
            #endif
            return false
        }
    }
}
