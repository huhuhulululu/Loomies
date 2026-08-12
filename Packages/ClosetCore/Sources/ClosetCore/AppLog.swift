import Foundation
#if canImport(OSLog)
import OSLog
#endif

/// 结构化日志（DESIGN §11 / 调试优先）。
/// 纯 Foundation 兼容；Apple 平台走 OSLog，其它退化为 print。
/// DEBUG 默认 info+；Release 默认 error+（可用 setMinLevel 调）。
public enum AppLog {
    public enum Level: Int, Comparable, Sendable {
        case debug = 0, info = 1, notice = 2, error = 3, fault = 4
        public static func < (l: Level, r: Level) -> Bool { l.rawValue < r.rawValue }
    }

    public enum Category: String, Sendable {
        case app, copilot, intake, data, sync, weather, telemetry, diagnostics
    }

    /// 内存环形缓冲（最近 N 条），供诊断导出 / Me 调试台，不落盘。
    public static let ring = LogRing(capacity: 200)

    /// Swift 6：可变全局态收进 @unchecked Sendable 盒。
    private final class LevelBox: @unchecked Sendable {
        let lock = NSLock()
        var value: Level = {
            #if DEBUG
            .debug
            #else
            .error
            #endif
        }()
    }
    private static let levelBox = LevelBox()

    public static var minLevel: Level {
        get { levelBox.lock.lock(); defer { levelBox.lock.unlock() }; return levelBox.value }
        set { levelBox.lock.lock(); levelBox.value = newValue; levelBox.lock.unlock() }
    }

    public static func setMinLevel(_ level: Level) { minLevel = level }

    // MARK: - 日志安全标识（PII 不入日志）

    /// 用户内容（名称/城市/条码原文）不入日志——用 id 前 8 位稳定标识替代，
    /// 可跨日志行关联同一实体，但不可逆推用户输入。
    public static func ref(_ id: UUID) -> String { String(id.uuidString.prefix(8)) }

    /// 错误摘要：domain#code。禁止 `\(error)` 全量插值——Cocoa 错误的 userInfo
    /// 携带 NSFilePath/NSURL（容器 UUID 绝对路径，准设备标识符），会随诊断导出外流。
    public static func errRef(_ err: any Error) -> String {
        let ns = err as NSError
        return "\(ns.domain)#\(ns.code)"
    }

    public static func debug(_ message: @autoclosure () -> String, _ cat: Category = .app,
                             file: String = #fileID, line: Int = #line) {
        log(.debug, message(), cat, file: file, line: line)
    }
    public static func info(_ message: @autoclosure () -> String, _ cat: Category = .app,
                            file: String = #fileID, line: Int = #line) {
        log(.info, message(), cat, file: file, line: line)
    }
    public static func notice(_ message: @autoclosure () -> String, _ cat: Category = .app,
                              file: String = #fileID, line: Int = #line) {
        log(.notice, message(), cat, file: file, line: line)
    }
    public static func error(_ message: @autoclosure () -> String, _ cat: Category = .app,
                             file: String = #fileID, line: Int = #line) {
        log(.error, message(), cat, file: file, line: line)
    }
    public static func fault(_ message: @autoclosure () -> String, _ cat: Category = .app,
                             file: String = #fileID, line: Int = #line) {
        log(.fault, message(), cat, file: file, line: line)
    }

    /// 计时块：结束打 notice + 返回结果。
    @discardableResult
    public static func timed<T>(
        _ label: String, _ cat: Category = .app,
        _ work: () throws -> T
    ) rethrows -> T {
        let t0 = CFAbsoluteTimeGetCurrent()
        do {
            let value = try work()
            let ms = (CFAbsoluteTimeGetCurrent() - t0) * 1000
            notice(String(format: "%@ done in %.1fms", label, ms), cat)
            return value
        } catch {
            let ms = (CFAbsoluteTimeGetCurrent() - t0) * 1000
            // 违反的正是本文件 40 行前自己声明的规则：`String(describing: error)`
            // 会把 Cocoa 错误的 userInfo（NSFilePath/NSURL = 容器 UUID 绝对路径，
            // 准设备标识符）整包写进日志，再随诊断导出外流（D101）。
            Self.error(String(format: "%@ failed in %.1fms: %@", label, ms, Self.errRef(error)), cat)
            throw error
        }
    }

    private static func log(_ level: Level, _ message: String, _ cat: Category,
                            file: String, line: Int) {
        guard level >= minLevel else { return }
        let entry = LogEntry(date: Date(), level: level, category: cat,
                             message: message, file: file, line: line)
        ring.append(entry)
        #if canImport(OSLog)
        // .private：unified log（sysdiagnose/Console/MDM 采集）是出设备通道，
        // 动态消息一律走系统兜底脱敏；调试期用 log profile / Xcode 仍可见明文。
        let logger = Logger(subsystem: "com.pinglin.closet", category: cat.rawValue)
        switch level {
        case .debug:  logger.debug("\(message, privacy: .private)")
        case .info:   logger.info("\(message, privacy: .private)")
        case .notice: logger.notice("\(message, privacy: .private)")
        case .error:  logger.error("\(message, privacy: .private)")
        case .fault:  logger.fault("\(message, privacy: .private)")
        }
        #else
        print("[\(level)][\(cat.rawValue)] \(message)")
        #endif
    }
}

public struct LogEntry: Sendable, Equatable {
    public let date: Date
    public let level: AppLog.Level
    public let category: AppLog.Category
    public let message: String
    public let file: String
    public let line: Int

    public var lineText: String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return "\(f.string(from: date)) [\(level)][\(category.rawValue)] \(message)"
    }
}

/// 线程安全环形缓冲。
public final class LogRing: @unchecked Sendable {
    private let capacity: Int
    private var buf: [LogEntry] = []
    private let lock = NSLock()

    public init(capacity: Int) { self.capacity = max(1, capacity) }

    /// 单条消息截断上限：超长 error dump（SwiftData/AVFoundation userInfo 可达数 KB）
    /// 会把 200 条环撑到数 MB 并挤满诊断包 80 行配额。
    public static let maxMessageLength = 512

    public func append(_ e: LogEntry) {
        lock.lock(); defer { lock.unlock() }
        let entry: LogEntry
        if e.message.count > Self.maxMessageLength {
            entry = LogEntry(
                date: e.date, level: e.level, category: e.category,
                message: String(e.message.prefix(Self.maxMessageLength)) + "…",
                file: e.file, line: e.line)
        } else {
            entry = e
        }
        buf.append(entry)
        if buf.count > capacity { buf.removeFirst(buf.count - capacity) }
    }

    public func snapshot() -> [LogEntry] {
        lock.lock(); defer { lock.unlock() }
        return buf
    }

    public func clear() {
        lock.lock(); defer { lock.unlock() }
        buf.removeAll()
    }

    public var count: Int {
        lock.lock(); defer { lock.unlock() }
        return buf.count
    }
}
