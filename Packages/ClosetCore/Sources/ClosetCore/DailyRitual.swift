import Foundation

/// 每日回访（D118）。
///
/// 此前这个 App **永远不会主动出现在用户面前**：全仓 0 处
/// `UNUserNotificationCenter` / `WidgetKit`。而 MARKET §8.1 把
/// 「D30 全体 ≥8%、激活层 ≥30%」定为 copilot 机制的证伪线——
/// 一个每天早上要用一次的产品没有任何回访面，那条线根本无从谈起。
///
/// 这里只放**策略**（何时发、发什么、什么情况下不配发），纯 Foundation 可测；
/// `UNUserNotificationCenter` 那层是 `#if os(iOS)`，只能靠 `xcodebuild` 验（D92）。
public enum DailyRitual {

    public static let defaultHour = 7      // 起床后、出门前
    public static let defaultMinute = 0

    /// 时间选择器给出的档位。不给半夜档——那不是提醒，是骚扰。
    public static let selectableHours = Array(5...11)

    /// 下一次触发时刻。已过点就排明天，**不补发今天**。
    /// 非法时间返回 nil（不静默落到半夜）。
    public static func nextFireDate(
        after now: Date, hour: Int, minute: Int, calendar: Calendar = .current
    ) -> Date? {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0
        guard let todaysSlot = calendar.date(from: components) else { return nil }
        // 正好到点算已过：同一分钟内不重复打扰
        if todaysSlot > now { return todaysSlot }
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: todaysSlot)
        else { return nil }
        return tomorrow
    }

    /// 通知标题。点名**星期**而不是单品——
    /// 点名单品要后台重算今日推荐，还会把衣柜内容漏到锁屏上。
    public static func title(weekday: Int, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US")
        let symbols = formatter.weekdaySymbols ?? []
        let index = max(1, min(7, weekday)) - 1
        let name = index < symbols.count ? symbols[index] : "Today"
        return "\(name)'s look"
    }

    /// 正文。**不承诺**「已经为你选好了」——本地排程根本没算过今天的推荐，
    /// 说了就是一句到点必然兑现不了的话。
    public static let body = "Settle what you're wearing before you head out."

    /// 衣柜凑不出一身时不排：推到锁屏、点开却是空的，比不推更糟。
    public static func shouldSchedule(availableItemCount: Int) -> Bool {
        availableItemCount >= minimumItemsToEarnANotification
    }

    /// 与冷启动阈值同源（低于它连一套完整搭配都拼不出）。
    public static let minimumItemsToEarnANotification = 8

    /// 权限**不在第一屏要**：先给价值再要权限（DESIGN §485）。
    /// 判据是用户已经真的确认过第一件衣服——那一刻他才知道这 App 是干什么的。
    public static func mayAskForPermission(confirmedItemCount: Int) -> Bool {
        confirmedItemCount >= 1
    }

    /// 请求权限时给用户的理由（系统弹窗前的自有说明）。
    public static let permissionRationale =
        "One nudge each morning, at a time you pick. No other notifications."

    /// 一周七条**按周重复**的排程（每天一条）。
    ///
    /// 不能用「一条每日重复 + 排程当刻算出的星期名」——周三排的
    /// 「Wednesday's look」周四照样会发，标题当场变成假话。
    /// 七条各自带 weekday 分量，每条每周命中一次，星期名永远对得上。
    public static func weeklyPlan(calendar: Calendar = .current) -> [(weekday: Int, title: String)] {
        (1...7).map { (weekday: $0, title: title(weekday: $0, calendar: calendar)) }
    }

    /// 设置项存储键。
    public static let enabledDefaultsKey = "loomies.dailyRitual.enabled"
    public static let hourDefaultsKey = "loomies.dailyRitual.hour"
}
