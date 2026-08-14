import Testing
import Foundation
@testable import ClosetUI
import ClosetCore

/// D154：**一个测试把全局调试开关拨成 true，另一个测试正在读它。**
///
/// `DebugSettingsTests.flagsRoundTrip` 在 `DebugSettings.shared` 上把
/// `forceColdStart` / `disableAntiRepeat` 置为 true 再 reset。而生产代码
/// （`CopilotViewModel.isColdStart`、`refresh`、`CopilotView`）读的就是 `.shared`——
/// 并行跑的推荐类用例在那个窗口里会看到「强制冷启动」，
/// 于是 `refresh` 走早退分支、`suggestions` 当场为空，断言崩掉。
///
/// 窗口只有几微秒，所以它极少发作——而这正是最贵的那种失败：
/// 与代码改动无关、与调度有关、复现不了（D143 的地址复用是同一类）。
///
/// 处置：**需要拨开关的测试自己造一个实例**（`init(defaults:)` 本来就是 public，
/// 配一个独立的 UserDefaults suite），不碰全局。这条用门守住。
@MainActor
struct DebugSettingsIsolationTests {

    /// 自造实例是好使的（否则下面那条门只是把能力挡掉）。
    @Test func anIsolatedInstanceWorks() {
        let suite = "loomies.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let d = DebugSettings(defaults: defaults)
        d.forceColdStart = true
        #expect(d.forceColdStart)
        #expect(!DebugSettings.shared.forceColdStart,
                "自造实例的写入串到了全局上 —— 隔离没有发生")
    }

    /// **没有任何测试把全局开关拨成 true。**
    ///
    /// 拨 false 是防污染的基线（无害）；拨 true 才会让并行的推荐用例
    /// 走进它没预期的分支。
    @Test func noTestFlipsAGlobalFlagOn() throws {
        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        // D209：遍历型门必须自证「扫到过东西」——判据见 D208。
        var scannedFileCount = 0
        var offenders: [String] = []
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: testsDir, includingPropertiesForKeys: nil)
        else { Issue.record("遍历器建不起来 —— 静默 return 等于这道门根本没跑"); return }
        for case let url as URL in walker where url.pathExtension == "swift" {
            guard url.lastPathComponent != "DebugSettingsIsolationTests.swift" else { continue }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            scannedFileCount += 1
            // 只看真正操作全局单例的行：`DebugSettings.shared` 或
            // `let d = DebugSettings.shared` 之后对 d 的赋值都算
            let aliasesShared = text.contains("= DebugSettings.shared")
            for line in text.split(separator: "\n") {
                let t = line.trimmingCharacters(in: .whitespaces)
                guard !t.hasPrefix("//"), !t.hasPrefix("///") else { continue }
                let flipsOn = t.hasSuffix("= true")
                guard flipsOn else { continue }
                if t.contains("DebugSettings.shared")
                    || (aliasesShared && (t.hasPrefix("d.") || t.hasPrefix("debug."))) {
                    offenders.append("\(url.lastPathComponent): \(t)")
                }
            }
        }
        let census = try TraversalCensus.check(
            live: scannedFileCount,
            key: TraversalCensus.closetUITests,
            testFile: #filePath)
        #expect(census == nil, Comment(rawValue: census ?? ""))
        #expect(offenders.isEmpty, Comment(rawValue:
            "这些测试把全局调试开关拨成了 true，并行跑的推荐用例会读到："
            + "\(offenders) —— 改用 DebugSettings(defaults: UserDefaults(suiteName:))"))
    }

    /// 全局实例在测试期间保持出厂状态（没人留下脏开关）。
    @Test func theGlobalStaysAtItsDefaults() {
        #expect(!DebugSettings.shared.forceColdStart)
        #expect(!DebugSettings.shared.disableAntiRepeat)
    }
}
