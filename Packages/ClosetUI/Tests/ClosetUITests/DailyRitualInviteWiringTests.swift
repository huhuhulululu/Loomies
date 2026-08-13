import Testing
import Foundation
@testable import ClosetUI
import ClosetCore

/// D140 接线门：**邀请必须真的出现在 Today 上**。
///
/// 本仓的复发病是「能力实现了 + 测试写了 + 零调用点」——`mayAskForPermission`
/// 就是最好的标本：策略写着「什么时候可以开口要通知权限」，而这个 App
/// 从来没有主动开过口，整个每日回访藏在 Me → Daily 的一个开关后面。
/// 策略层的绿灯不能算数，得有人调它。
@MainActor
struct DailyRitualInviteWiringTests {

    private var uiDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Sources/ClosetUI")
    }

    private func source(_ name: String) throws -> String {
        try String(contentsOf: uiDir.appendingPathComponent(name), encoding: .utf8)
    }

    /// Today 上真的问了这一句。
    @Test func todayActuallyPitchesTheNudge() throws {
        let text = try source("CopilotView.swift")
        #expect(text.contains("DailyRitual.shouldInvite"),
                "邀请策略零调用点 —— 每日回访仍然只有翻进设置页的人才知道")
        #expect(text.contains(DailyRitual.inviteHeadline)
                || text.contains("DailyRitual.inviteHeadline"))
    }

    /// **开启只有一条路径。** 邀请卡若自己再写一遍
    /// 「requestAuthorization → isEnabled = true → reschedule」，
    /// 两份迟早会走岔（少排一次、漏关一次开关），而那正是 D118 反复修的那类 bug。
    @Test func bothEntryPointsShareOneEnablePath() throws {
        let copilot = try source("CopilotView.swift")
        let root = try source("AppRootView.swift")
        #expect(copilot.contains("DailyRitualScheduler.enable("),
                "邀请卡自己拼了一条开启路径")
        #expect(root.contains("DailyRitualScheduler.enable("),
                "设置开关没走共用路径")
        // 视图层不得再直接摸权限/开关——那是 scheduler 的活
        #expect(!copilot.contains("DailyRitualScheduler.isEnabled = true"))
        #expect(!root.contains("DailyRitualScheduler.isEnabled = true"))
    }

    /// 拒绝要落盘：不落的话下次冷启动照样问，
    /// 而 iOS 的权限弹窗一辈子只有一次机会。
    @Test func decliningIsRemembered() throws {
        let text = try source("CopilotView.swift")
        // 跨启动记住 → 必须落 UserDefaults（@State 活不过一次冷启动）。
        // 键走符号而不是字面量：策略与存储的键对不上时，
        // 「问过了」会写进一个没人读的地方。
        #expect(text.contains("@AppStorage(DailyRitual.inviteAskedDefaultsKey)"),
                "点了「不用」之后没有任何东西跨启动记住，下次还问")
        #expect(text.contains("nudgeInviteAsked = true"))
    }

    /// 时刻标签只有一处实现——邀请卡写的时间与设置页选的必须逐字一致。
    @Test func theHourLabelHasASingleImplementation() throws {
        let root = try source("AppRootView.swift")
        #expect(root.contains("DailyRitual.hourLabel"))
        #expect(!root.contains("\"AM\" : \"PM\""),
                "设置页仍自己拼 12 小时制 —— 两份格式化迟早写出两个时间")
    }

    /// D142：开关旁边要写出下一次几点响——`nextFireDate` 此前零调用点，
    /// 而那正是让这个开关**可核对**的唯一一行。
    @Test func theSwitchShowsWhenItWillNextFire() throws {
        let text = try source("AppRootView.swift")
        #expect(text.contains("DailyRitual.nextNudgeLine"),
                "开关拨开了，用户没有任何办法确认它到底会不会响")
    }

    /// 邀请卡不得挂在 `else` 链上（D134 的错位在同一个文件里发生过：
    /// 一张卡片插进 if/else 中间，`else` 改挂到了它头上，
    /// 正常屏也跟着渲染出一张「没有匹配」）。
    @Test func theInviteStandsOnItsOwnCondition() throws {
        let text = try source("CopilotView.swift")
        guard let r = text.range(of: "if showsNudgeInvite") else {
            Issue.record("找不到邀请卡的条件"); return
        }
        let before = text[..<r.lowerBound].suffix(200)
        #expect(!before.contains("} else"),
                "邀请卡被挂进了 else 链 —— D134 同款错位")
    }
}
