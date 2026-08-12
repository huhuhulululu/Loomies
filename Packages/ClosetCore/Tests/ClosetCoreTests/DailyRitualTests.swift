import Testing
import Foundation
@testable import ClosetCore

/// D118：**这个 App 永远不会主动出现在用户面前**。
/// 全仓 0 处 `UNUserNotificationCenter` / `WidgetKit`——三个独立视角同时点名。
///
/// 而 MARKET §8.1 把「D30 全体 ≥8%、激活层 ≥30%」定为 copilot 机制的证伪线：
/// 一个每天早上要用一次的产品，没有任何回访面，那条线根本无从谈起。
///
/// 排期策略（决定这一波做什么、不做什么）：
/// - **一条**每日本地通知。不做 Widget（MVP-PLAN §5 已砍）、不做后台再生成。
/// - 文案**刻意不点名任何单品**——点名就需要后台任务重算今日推荐，
///   还会把衣柜内容漏到锁屏上。结论式措辞，价值在「该定今天穿什么了」。
/// - 触发策略是纯函数放 Core，`swift test` 覆盖；
///   `UNUserNotificationCenter` 那层是 `#if os(iOS)`，只能靠 `xcodebuild` 验（D92）。
struct DailyRitualTests {

    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        utc.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    /// 当天还没到点 → 今天。
    @Test func beforeTheHourItFiresToday() {
        let now = date(2026, 8, 12, 5, 30)
        let next = DailyRitual.nextFireDate(after: now, hour: 7, minute: 0, calendar: utc)
        #expect(next == date(2026, 8, 12, 7, 0))
    }

    /// 已经过点 → 明天（不是「今天补一发」，那是骚扰）。
    @Test func afterTheHourItFiresTomorrow() {
        let now = date(2026, 8, 12, 9, 15)
        let next = DailyRitual.nextFireDate(after: now, hour: 7, minute: 0, calendar: utc)
        #expect(next == date(2026, 8, 13, 7, 0))
    }

    /// 正好到点：算作已过（同一分钟内不重复打扰）。
    @Test func exactlyOnTheHourCountsAsPast() {
        let now = date(2026, 8, 12, 7, 0)
        let next = DailyRitual.nextFireDate(after: now, hour: 7, minute: 0, calendar: utc)
        #expect(next == date(2026, 8, 13, 7, 0))
    }

    /// 跨月边界。
    @Test func itCrossesMonthBoundaries() {
        let now = date(2026, 8, 31, 23, 0)
        let next = DailyRitual.nextFireDate(after: now, hour: 7, minute: 0, calendar: utc)
        #expect(next == date(2026, 9, 1, 7, 0))
    }

    /// 非法时间不排（不静默落到 0 点半夜炸用户）。
    @Test func anInvalidHourSchedulesNothing() {
        let now = date(2026, 8, 12, 5, 0)
        #expect(DailyRitual.nextFireDate(after: now, hour: 24, minute: 0, calendar: utc) == nil)
        #expect(DailyRitual.nextFireDate(after: now, hour: -1, minute: 0, calendar: utc) == nil)
        #expect(DailyRitual.nextFireDate(after: now, hour: 7, minute: 60, calendar: utc) == nil)
    }

    // MARK: - 文案

    /// **不点名任何单品**——点名要后台重算，还会把衣柜内容漏到锁屏上。
    @Test func theCopyNeverNamesAPiece() {
        for weekday in 1...7 {
            let title = DailyRitual.title(weekday: weekday, calendar: utc)
            #expect(!title.isEmpty)
            // 不含引号/插值痕迹（点名单品的典型形态）
            #expect(!title.contains("\""))
            #expect(!title.contains("·"))
        }
        #expect(!DailyRitual.body.contains("\""))
    }

    /// 星期名跟着当天走——「Tuesday's look」比「今天的搭配」更像有人记得你。
    @Test func theTitleNamesTheDay() {
        // 2026-08-12 是星期三
        let weekday = utc.component(.weekday, from: date(2026, 8, 12, 7, 0))
        #expect(DailyRitual.title(weekday: weekday, calendar: utc)
            .localizedCaseInsensitiveContains("wednesday"))
    }

    /// 正文不得承诺一件产品此刻兑现不了的事（本地通知没算过今天的推荐）。
    @Test func theBodyPromisesNothingItCannotKeep() {
        let body = DailyRitual.body.lowercased()
        for claim in ["ready", "we picked", "your look is", "chosen for you"] {
            #expect(!body.contains(claim),
                    Comment(rawValue: "通知承诺了一件本地排程兑现不了的事：\(DailyRitual.body)"))
        }
    }

    // MARK: - 什么时候才配打扰用户

    /// 衣柜还凑不出一身时不排——推到锁屏上却打开是空的，比不推更糟。
    @Test func anEmptyClosetEarnsNoNotification() {
        #expect(!DailyRitual.shouldSchedule(availableItemCount: 0))
        #expect(!DailyRitual.shouldSchedule(availableItemCount: 3))
    }

    @Test func aWorkingClosetEarnsOne() {
        #expect(DailyRitual.shouldSchedule(availableItemCount: 8))
        #expect(DailyRitual.shouldSchedule(availableItemCount: 40))
    }

    /// 权限**不在第一屏要**：先给价值再要权限（DESIGN §485）。
    /// 判据是「用户已经确认过第一件衣服」。
    @Test func permissionIsAskedOnlyAfterTheFirstPieceLands() {
        #expect(!DailyRitual.mayAskForPermission(confirmedItemCount: 0))
        #expect(DailyRitual.mayAskForPermission(confirmedItemCount: 1))
    }

    /// 默认时间是早上 7 点——起床后、出门前。
    @Test func theDefaultHourIsMorning() {
        #expect(DailyRitual.defaultHour == 7)
        #expect(DailyRitual.defaultMinute == 0)
    }

    /// 用户选的时间要落在合理范围（选择器不给出半夜档）。
    @Test func theSelectableHoursAreCivil() {
        #expect(DailyRitual.selectableHours.first == 5)
        #expect(DailyRitual.selectableHours.last == 11)
        #expect(DailyRitual.selectableHours.contains(DailyRitual.defaultHour))
    }
}

/// D118：星期名与触发日必须一一对应。
/// 「一条每日重复 + 排程当刻算出的星期名」会让周三排的标题周四照发——
/// 那一刻标题就是假话。
struct DailyRitualWeeklyPlanTests {

    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    @Test func thePlanCoversEveryDayExactlyOnce() {
        let plan = DailyRitual.weeklyPlan(calendar: utc)
        #expect(plan.count == 7)
        #expect(Set(plan.map(\.weekday)) == Set(1...7))
    }

    @Test func eachEntryNamesItsOwnDay() {
        let names = ["sunday", "monday", "tuesday", "wednesday",
                     "thursday", "friday", "saturday"]
        for entry in DailyRitual.weeklyPlan(calendar: utc) {
            #expect(entry.title.localizedCaseInsensitiveContains(names[entry.weekday - 1]),
                    Comment(rawValue: "weekday \(entry.weekday) 的标题是「\(entry.title)」"))
        }
    }

    /// 标题各不相同（否则七条排程等于一条，星期名白算）。
    @Test func theTitlesAreAllDistinct() {
        let titles = DailyRitual.weeklyPlan(calendar: utc).map(\.title)
        #expect(Set(titles).count == 7)
    }
}
