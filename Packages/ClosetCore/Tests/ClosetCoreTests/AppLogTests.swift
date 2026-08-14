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

    /// 超长消息截断：数 KB 的 error dump 不得把 200 条环撑到数 MB / 挤满诊断配额。
    @Test func ringTruncatesOversizedMessages() {
        let ring = LogRing(capacity: 5)
        let long = String(repeating: "x", count: 5_000)
        ring.append(LogEntry(date: Date(), level: .error, category: .data,
                             message: long, file: "x", line: 1))
        let stored = ring.snapshot().first?.message ?? ""
        #expect(stored.count <= LogRing.maxMessageLength + 1)  // +1 省略号
        #expect(stored.hasSuffix("…"))
        // 正常长度不受影响
        ring.append(LogEntry(date: Date(), level: .info, category: .data,
                             message: "short", file: "x", line: 1))
        #expect(ring.snapshot().last?.message == "short")
    }

    /// 日志安全标识：ref 稳定且不可逆；errRef 不展开 userInfo（防 NSFilePath 外流）。
    @Test func refAndErrRefCarryNoUserContent() {
        let id = UUID()
        #expect(AppLog.ref(id) == String(id.uuidString.prefix(8)))
        let err = NSError(
            domain: "NSCocoaErrorDomain", code: 512,
            userInfo: [NSFilePathErrorKey: "/var/mobile/Containers/secret/path.jpg"])
        let r = AppLog.errRef(err)
        #expect(r == "NSCocoaErrorDomain#512")
        #expect(!r.contains("/var"))
    }

    /// 静态隐私 lint：全仓 Sources 的 AppLog 行禁止插值用户内容
    /// （单品/衣柜/搭配/位置名、城市原文、error 全量 dump）。回归即失败。
    @Test func appLogCallSitesCarryNoPIIPatterns() throws {
        // D208：**遍历型门必须自证「扫到过东西」**。
        // 实证过：把遍历根指向不存在的目录，门照样绿——
        // 「不存在」断言 + 目录遍历 = 看不见的地方等于不存在（假绿，无征兆）。
        var scannedFileCount = 0
        let packagesDir = URL(fileURLWithPath: #filePath)   // …/Packages/ClosetCore/Tests/ClosetCoreTests/AppLogTests.swift
            .deletingLastPathComponent()                    // ClosetCoreTests
            .deletingLastPathComponent()                    // Tests
            .deletingLastPathComponent()                    // ClosetCore
            .deletingLastPathComponent()                    // Packages
        // app-shell 也在扫描范围（曾有 \(error) dump + 衣柜名入日志逃过 lint 的实例）
        let appShellDir = packagesDir.deletingLastPathComponent()
            .appendingPathComponent("app-shell", isDirectory: true)
        let forbidden = [
            #"\(item.name"#, #"\(wardrobe.name"#, #"\(outfit.name"#,
            #"\(location.name"#, #"\(dest.name"#, #"\(w.name"#,
            #"\(error)"#, #"locationCity ??"#,
            // D101：`String(describing: error)` 与 `\(error)` 等价危险，
            // 而旧清单只拦后者——AppLog 自己的 timed() 就从这个洞里漏了出去
            "String(describing: error)",
        ]
        var violations: [String] = []
        let fm = FileManager.default
        var files: [URL] = []
        for root in [packagesDir, appShellDir] {
            let en = fm.enumerator(at: root, includingPropertiesForKeys: nil)
            while let url = en?.nextObject() as? URL {
                guard url.pathExtension == "swift",
                      url.path.contains("/Sources/") || url.path.contains("/app-shell/")
                else { continue }
                files.append(url)
            }
        }
        for url in files {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            scannedFileCount += 1
            // D101：旧写法要求**同一行**里出现 AppLog.——而 `Self.error(...)`
            // 这种同文件内的转发调用不带 AppLog. 前缀，泄漏就从这里漏过去了。
            // 改为：AppLog.swift 全文件扫描，其余文件仍按 AppLog. 行过滤。
            let isLogFile = url.lastPathComponent == "AppLog.swift"
            for (n, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
            where isLogFile || line.contains("AppLog.") {
                // 注释行不算违规——规则文本本身会提到被禁的写法
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//"), !trimmed.hasPrefix("*"),
                      !trimmed.hasPrefix("/*") else { continue }
                for pat in forbidden where line.contains(pat) {
                    violations.append("\(url.lastPathComponent):\(n + 1) ~ \(pat)")
                }
                // D165：插值里读了**用户内容属性**即违规，不问变量叫什么。
                // 与遥测门共用同一份定义（由 schema 同步门守着），
                // 否则两张手工表会各自过期——实测旧表抓得到 `\(item.name`
                // 却抓不到 `\(item.brand` / `\(item.notes`。
                guard line.contains("\\(") else { continue }
                for read in UserContentFields.reads
                where read.hasPrefix(".") && line.contains(read) {
                    violations.append("\(url.lastPathComponent):\(n + 1) ~ 插值读了 \(read)")
                }
            }
        }
        #expect(scannedFileCount >= 3, Comment(rawValue:
            "只扫到 \(scannedFileCount) 个文件 —— 遍历坏了，这道门在空转"))
        #expect(violations.isEmpty, "\(violations)")
    }
}
