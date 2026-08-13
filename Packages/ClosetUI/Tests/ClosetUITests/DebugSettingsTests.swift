import Testing
import Foundation
@testable import ClosetUI
import ClosetCore

@MainActor
struct DebugSettingsTests {

    /// D154：**自造实例，不碰全局。**
    ///
    /// 此前这条用例在 `DebugSettings.shared` 上把 `forceColdStart` /
    /// `disableAntiRepeat` 拨成 true 再 reset——而生产代码
    ///（`CopilotViewModel.isColdStart`、`refresh`）读的就是 `.shared`：
    /// 并行跑的推荐用例在那几微秒窗口里会看到「强制冷启动」，
    /// 于是 refresh 走早退分支、suggestions 当场为空。
    /// 极少发作，而这正是最贵的那种失败——与代码改动无关、与调度有关、复现不了。
    @Test func flagsRoundTrip() {
        let suite = "loomies.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let d = DebugSettings(defaults: defaults)

        d.forceColdStart = true
        d.disableAntiRepeat = true
        #expect(d.flagsForDiagnostics["forceColdStart"] == "true")
        #expect(d.flagsForDiagnostics["disableAntiRepeat"] == "true")
        d.resetAll()
        #expect(d.forceColdStart == false)
        #expect(d.disableAntiRepeat == false)
    }

    /// 开关真的落到了它自己那个域上（不是只改了内存）。
    @Test func flagsPersistToTheirOwnDomain() {
        let suite = "loomies.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        DebugSettings(defaults: defaults).forceColdStart = true
        // 同一个域上重建一个实例，应当读回刚写的值
        #expect(DebugSettings(defaults: defaults).forceColdStart)
    }
}
