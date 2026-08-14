import Testing
import Foundation
@testable import ClosetCore

/// D211：`DESIGN §10.5` 的一条——「用 `MeasurementFormatter` / `Locale` 实现**而非硬编码**」。
///
/// ### 哪种硬编码是 bug，哪种不是
///
/// 本波修 `hourLabel` 时先分清了这个，否则下一个人会把对的那些也一起「修」了：
///
/// | 场景 | 硬编码 locale | 判断 |
/// |---|---|---|
/// | 几点整（`7:00 AM` / `19:00`） | ❌ | **12h/24h 是系统级用户偏好，与语言无关**——美国用户也会开 24 小时制 |
/// | 上次穿着日期（`Aug 11`） | ✅ 对的 | 月份名与**语言**绑定；App 文案是英文（"3 days ago"），日期跟着 en_US 才一致 |
///
/// 区别在于：**这个格式跟的是「用户的偏好」还是「界面的语言」**。
/// 前者必须跟随系统，后者必须跟随文案。
struct LocaleFormattingLintTests {

    private var sourcesRoots: [URL] {
        let packages = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // ClosetCoreTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // ClosetCore
            .deletingLastPathComponent()   // Packages
        return ["ClosetCore", "ClosetModel", "ClosetUI", "ClosetIntake"].map {
            packages.appendingPathComponent("\($0)/Sources")
        }
    }

    /// 判据：一行里同时出现 `"AM"` 与 `"PM"` 两个字面量 —— 那就是在手拼 12 小时制。
    /// 认**构造**不认单词：`.dateTime.hour()` 的输出里当然有 AM，那是系统给的。
    static func handRollsAmPm(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard !t.hasPrefix("//"), !t.hasPrefix("///"), !t.hasPrefix("*") else { return false }
        return t.contains("\"AM\"") && t.contains("\"PM\"")
    }

    /// 自测：喂一个已知违规，判据抓得到吗（防过滤逻辑写坏后整体空转）。
    @Test func theCheckWouldCatchTheOldImplementation() {
        #expect(Self.handRollsAmPm(#"        let suffix = h < 12 ? "AM" : "PM""#),
                "判据抓不到旧实现那一行 —— 它在空转")
        #expect(!Self.handRollsAmPm(#"        /// 12 小时制标签："AM" / "PM""#),
                "注释被当成违规")
        #expect(!Self.handRollsAmPm(#"        return date.formatted(.dateTime.hour())"#),
                "系统格式化被当成违规")
    }

    /// **没有人再手拼 AM/PM**。
    @Test func nobodyHandRollsTwelveHourTime() throws {
        let fm = FileManager.default
        var scannedFileCount = 0
        var offenders: [String] = []
        for root in sourcesRoots {
            guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: nil)
            else { Issue.record("遍历器建不起来：\(root.lastPathComponent)"); continue }
            for case let url as URL in walker where url.pathExtension == "swift" {
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                scannedFileCount += 1
                for (n, line) in text.split(
                    separator: "\n", omittingEmptySubsequences: false).enumerated()
                where Self.handRollsAmPm(String(line)) {
                    offenders.append("\(url.lastPathComponent):\(n + 1)")
                }
            }
        }
        // D216：宽扫下界跟账本，不再手填 ≥80
        let census = try TraversalCensus.check(
            live: scannedFileCount,
            key: TraversalCensus.allPackageSources,
            testFile: #filePath)
        #expect(census == nil, Comment(rawValue: census ?? ""))
        #expect(offenders.isEmpty, Comment(rawValue:
            "这些地方手拼 12 小时制：\(offenders) —— "
            + "用户开了系统的「24-Hour Time」之后，只有这个 App 还在印 AM/PM。"
            + "用 `DailyRitual.hourLabel` 或 `.formatted(.dateTime.hour().minute())`"))
    }

    /// **温度单位仍是写死的 °F**——这一条是**记录现状，不是批准它**。
    ///
    /// DESIGN §10.5 承诺「英制…可切公制」，而实现没有公制路径：
    /// 引擎的温区表、`OuterwearCue` 的 60°F/50% 阈值全按华氏工作，
    /// 切公制要换算数值而不只是换个符号。首发美国区这样是站得住的，
    /// 但**文档说的是「可切」**——所以 DESIGN 那条已标注延期（D211）。
    ///
    /// 这条测试的作用：哪天真做了公制，它会红，提醒把 DESIGN 的延期标记划掉。
    @Test func temperatureIsStillImperialOnly() {
        let line = TodayWidgetCopy.weatherLine(
            TodayWidgetSnapshot(dayKey: "2026-08-13", lookTitle: nil, pieces: [],
                                daytimeTempF: 72, weatherSourceLabel: nil, isSettled: false))
        #expect(line == "72°F", Comment(rawValue:
            "温度显示变了（\(line ?? "nil")）—— 如果是做了公制切换，"
            + "去把 DESIGN §10.5 的延期标记划掉，并把这条改成两种单位都验"))
    }
}
