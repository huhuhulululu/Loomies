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

/// D119：**激活阶梯在 8 件处消失，而北极星区间正好从 8 开始**——
/// 用户在 8→20 这段完全没人告诉他还差什么。
struct ActivationLadderRangeTests {

    @Test func theLadderStaysUntilTheClosetIsUsable() {
        #expect(ActivationProgress.showsLadder(itemCount: 0))
        #expect(ActivationProgress.showsLadder(itemCount: 8),
                "8 件正是北极星区间的起点，阶梯却在这里消失了")
        #expect(ActivationProgress.showsLadder(itemCount: 19))
    }

    @Test func itStopsOnceTheClosetCanCarryAWeek() {
        #expect(!ActivationProgress.showsLadder(itemCount: 20))
        #expect(!ActivationProgress.showsLadder(itemCount: 60))
    }

    /// 毕业文案得说清「从此以后会怎样」，而不只是恭喜一句。
    @Test func theReadyMomentSaysWhatHappensNext() {
        #expect(!ActivationProgress.readyHeadline.isEmpty)
        let body = ActivationProgress.readyBody(itemCount: 20)
        #expect(body.contains("20"))
        #expect(body.localizedCaseInsensitiveContains("add more"),
                Comment(rawValue: "没说清接下来还能做什么：\(body)"))
    }

    /// 毕业文案不得与进度条文案自相矛盾（同一时刻两处说法必须同向）。
    @Test func theReadyCopyAgreesWithTheProgressCaption() {
        let caption = ActivationProgress.caption(itemCount: 20)
        #expect(caption.localizedCaseInsensitiveContains("ready"))
        #expect(!ActivationProgress.showsLadder(itemCount: 20))
    }
}

/// D140：**每日回访藏在 Me → Daily 的一个开关里，没有任何一处告诉用户它存在。**
///
/// MARKET §8.1 把 copilot 机制的 D30 证伪线整个押在「每天早上用一次」上，
/// 而唯一能挣来那条线的机制，用户得先自己翻进设置页、还得猜到那里有个开关。
/// D118 建好了策略、排程、归因、撤权对账——**全套齐了，就是没人知道它在**。
/// `mayAskForPermission` 零生产调用点正是这件事的化石：那条策略写的就是
/// 「什么时候可以开口要权限」，而这个 App 从来没有主动开过口。
///
/// 邀请的时机不能是「装完第一件」——那时用户还没体验过这个循环。
/// 真正该问的那一刻是**他刚刚打完卡**：今天这一身定下来了，
/// 「明早还要不要我叫你一次」在那一秒才是顺理成章的一句话。
struct DailyRitualInviteTests {

    /// 用户还没走完过一次日常，就不配问他要每天早上的注意力。
    @Test func itDoesNotAskBeforeTheLoopHasEverClosed() {
        #expect(!DailyRitual.shouldInvite(
            alreadyEnabled: false, alreadyAsked: false,
            availableItemCount: 20, confirmedItemCount: 20, settledToday: false))
    }

    /// 刚打完卡、衣柜也够——这就是该问的那一刻。
    @Test func itAsksRightAfterTheDayIsSettled() {
        #expect(DailyRitual.shouldInvite(
            alreadyEnabled: false, alreadyAsked: false,
            availableItemCount: 20, confirmedItemCount: 20, settledToday: true))
    }

    /// 已经开着就别再问（问了显得这 App 不记得自己的状态）。
    @Test func anAlreadyOnNudgeIsNeverPitched() {
        #expect(!DailyRitual.shouldInvite(
            alreadyEnabled: true, alreadyAsked: false,
            availableItemCount: 20, confirmedItemCount: 20, settledToday: true))
    }

    /// **问过一次就不再问。** iOS 的权限弹窗一辈子只有一次机会，
    /// 而反复推销的结果是用户把整个 App 的通知永久关掉。
    @Test func decliningIsFinal() {
        #expect(!DailyRitual.shouldInvite(
            alreadyEnabled: false, alreadyAsked: true,
            availableItemCount: 20, confirmedItemCount: 20, settledToday: true))
    }

    /// 衣柜凑不出一身时不邀请——排程本身就会跳过它（`shouldSchedule`），
    /// 邀请用户开一个不会响的提醒，是当场撒谎。
    @Test func itNeverInvitesIntoANudgeThatWouldNotFire() {
        #expect(!DailyRitual.shouldInvite(
            alreadyEnabled: false, alreadyAsked: false,
            availableItemCount: 7, confirmedItemCount: 7, settledToday: true),
                "邀请开一个衣柜条件根本不满足、永远不会发的提醒")
        #expect(DailyRitual.shouldSchedule(availableItemCount: 7) == false)
    }

    /// 判据必须**真的走** `mayAskForPermission`——这条策略此前零调用点，
    /// 接上它才算这个 App 学会了「先给价值再要权限」。
    @Test func theInviteHonoursThePermissionTimingPolicy() {
        #expect(!DailyRitual.mayAskForPermission(confirmedItemCount: 0))
        #expect(!DailyRitual.shouldInvite(
            alreadyEnabled: false, alreadyAsked: false,
            availableItemCount: 20, confirmedItemCount: 0, settledToday: true),
                "一件都没确认过就开口要通知权限")
    }

    /// 邀请文案不得承诺「我们已经替你选好了明天」——
    /// 排程侧根本没算过明天的推荐（`DailyRitual.body` 同一条理由）。
    @Test func theInviteDoesNotPromiseAPreparedLook() {
        let text = (DailyRitual.inviteHeadline + " " + DailyRitual.permissionRationale)
            .lowercased()
        #expect(!text.contains("picked"), Comment(rawValue: text))
        #expect(!text.contains("ready for you"), Comment(rawValue: text))
    }

    /// 说清「以后能在哪儿改」——否则用户点了「不用」就再也找不到它。
    @Test func theInviteSaysWhereToChangeItLater() {
        #expect(DailyRitual.inviteFootnote.localizedCaseInsensitiveContains("me"))
    }

    /// 时刻标签跟随 **locale**（§10.5：用 `Locale` 实现而非硬编码），
    /// 且只有一处实现——邀请卡上写的时间必须与设置页选的那个逐字一致。
    ///
    /// 注意断言里的 `\u{202f}`：系统格式化在 AM/PM 前用的是**窄不换行空格**，
    /// 不是普通空格。旧实现手拼 `"\(h):00 AM"` 用的是普通空格——
    /// 于是这个 App 印出来的时间与系统其它地方**逐字不同**。
    @Test func theHourReadsAsAmericansReadIt() {
        let l = Locale(identifier: "en_US")
        #expect(DailyRitual.hourLabel(7, locale: l) == "7:00\u{202f}AM")
        #expect(DailyRitual.hourLabel(11, locale: l) == "11:00\u{202f}AM")
        #expect(DailyRitual.hourLabel(5, locale: l) == "5:00\u{202f}AM")
        #expect(DailyRitual.hourLabel(0, locale: l) == "12:00\u{202f}AM", "午夜是 12 AM 不是 0 AM")
        #expect(DailyRitual.hourLabel(12, locale: l) == "12:00\u{202f}PM", "正午是 12 PM")
    }

    /// **用户把 iPhone 设成 24 小时制时，不许还印 AM/PM。**
    ///
    /// 这是 §10.5「用 `MeasurementFormatter` / `Locale` 实现而非硬编码」点名的那类事。
    /// 旧实现写着 `let suffix = h < 12 ? "AM" : "PM"`，注释还拿「en-US 首发市场」
    /// 替自己辩护——可 24 小时制不是别的国家的事，**是同一批美国用户的系统偏好**
    ///（系统时间、通知中心、锁屏全都是 07:00，只有这个 App 印 7:00 AM）。
    @Test func aTwentyFourHourDeviceGetsNoAmPm() {
        for id in ["en_GB", "de_DE", "fr_FR"] {
            let label = DailyRitual.hourLabel(19, locale: Locale(identifier: id))
            #expect(!label.localizedCaseInsensitiveContains("AM"), Comment(rawValue:
                "\(id) 是 24 小时制，却印出了 \(label)"))
            #expect(!label.localizedCaseInsensitiveContains("PM"), Comment(rawValue:
                "\(id) 是 24 小时制，却印出了 \(label)"))
            #expect(label.contains("19"), Comment(rawValue:
                "\(id) 下 19 点该读作 19:xx，实际是 \(label)"))
        }
    }

    /// 默认参数走 `Locale.current` —— 不传 locale 的调用方（生产上全是）
    /// 才会跟着用户的系统设置走。写死一个 `en_US` 默认值等于这条改了个寂寞。
    @Test func theDefaultFollowsTheUsersOwnLocale() {
        #expect(DailyRitual.hourLabel(7) == DailyRitual.hourLabel(7, locale: .current),
                "默认参数没走 Locale.current —— 用户的 24 小时制设置不会生效")
    }
}

/// D142：`nextFireDate` 零生产调用点——排程用的是 `UNCalendarNotificationTrigger`
/// 的 `DateComponents` 匹配，从来没人问过「下一次是什么时候」。
///
/// 而那正是开关旁边最该有的一行：用户拨了开关，凭什么相信它真的会响？
/// **能核对的状态才是诚实的状态**（同 D136 的撤权对账：设置里显示「开」
/// 而系统一条都不会发，是最典型的那类不诚实）。
struct NextNudgeLineTests {

    private let cal = Calendar(identifier: .gregorian)

    private func at(_ h: Int, _ m: Int) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 8; c.day = 13; c.hour = h; c.minute = m
        return cal.date(from: c)!
    }

    /// 还没到点 → 今天。
    @Test func beforeTheHourItIsToday() {
        let line = DailyRitual.nextNudgeLine(
            isEnabled: true, availableItemCount: 20, hour: 7,
            now: at(5, 30), calendar: cal)
        #expect(line?.localizedCaseInsensitiveContains("today") == true,
                Comment(rawValue: line ?? "nil"))
        // 期望值取自 `hourLabel` 本身，不再手抄字面量：
        // 系统格式化用的是窄不换行空格（`\u{202f}`），手抄的普通空格肉眼看不出差别，
        // 而这行断言此前就是这么错的（D211 改实现时当场红出来）。
        #expect(line?.contains(DailyRitual.hourLabel(7)) == true, Comment(rawValue: line ?? "nil"))
    }

    /// 过了点 → 明天（**不补发今天**，与排程口径一致）。
    @Test func afterTheHourItIsTomorrow() {
        let line = DailyRitual.nextNudgeLine(
            isEnabled: true, availableItemCount: 20, hour: 7,
            now: at(9, 0), calendar: cal)
        #expect(line?.localizedCaseInsensitiveContains("tomorrow") == true,
                Comment(rawValue: line ?? "nil"))
    }

    /// **关着就不写时间**——写一个不会到来的时刻正是这条规则要防的事。
    @Test func aDisabledNudgeHasNoNextTime() {
        #expect(DailyRitual.nextNudgeLine(
            isEnabled: false, availableItemCount: 20, hour: 7,
            now: at(5, 0), calendar: cal) == nil)
    }

    /// 衣柜凑不出一身时也不会响（`shouldSchedule` 直接跳过）——
    /// 那就不许显示一个时间。
    @Test func aClosetThatCannotDressYouHasNoNextTime() {
        #expect(DailyRitual.nextNudgeLine(
            isEnabled: true, availableItemCount: 3, hour: 7,
            now: at(5, 0), calendar: cal) == nil,
                "开关开着、衣柜不够，却显示了一个永远不会到来的时刻")
    }
}
