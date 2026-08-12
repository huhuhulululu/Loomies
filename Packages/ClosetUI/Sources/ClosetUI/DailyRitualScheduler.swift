import Foundation
import ClosetCore
#if canImport(UserNotifications)
import UserNotifications
#endif

/// 每日回访的平台侧（D118）。策略在 `ClosetCore.DailyRitual`（纯函数、可测），
/// 这里只负责跟 `UNUserNotificationCenter` 打交道。
///
/// ⚠️ 本文件主体是 `#if canImport(UserNotifications)`——macOS 的 `swift test`
/// **根本编不到它**（D92 实证：并发/Sendable 错误只有 `xcodebuild` 报）。
/// 改完必须真机编译验证。
@MainActor
public enum DailyRitualScheduler {

    /// 通知标识前缀。一周七条（每条按周重复），重排即整批覆盖，
    /// 不会堆出一串重复提醒。
    public static let requestIdentifierPrefix = "loomies.dailyRitual."

    static var allIdentifiers: [String] {
        (1...7).map { "\(requestIdentifierPrefix)\($0)" }
    }

    public static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: DailyRitual.enabledDefaultsKey) }
        set { UserDefaults.standard.set(newValue, forKey: DailyRitual.enabledDefaultsKey) }
    }

    /// 用户选的时刻。未设过 → 默认 7 点。
    public static var hour: Int {
        get {
            let stored = UserDefaults.standard.object(forKey: DailyRitual.hourDefaultsKey) as? Int
            guard let stored, DailyRitual.selectableHours.contains(stored) else {
                return DailyRitual.defaultHour
            }
            return stored
        }
        set { UserDefaults.standard.set(newValue, forKey: DailyRitual.hourDefaultsKey) }
    }

    /// 请求权限。返回是否拿到——**拿不到就把开关关回去**，
    /// 否则设置里显示「开」而系统层面一条都不会发（UI 诚实铁律）。
    public static func requestAuthorization() async -> Bool {
        #if canImport(UserNotifications)
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            AppLog.notice("dailyRitual authorization granted=\(granted)", .app)
            return granted
        } catch {
            AppLog.error("dailyRitual authorization failed: \(AppLog.errRef(error))", .app)
            return false
        }
        #else
        return false
        #endif
    }

    /// 排程（或按当前状态取消）。
    ///
    /// `availableItemCount` 决定这个 App 此刻**配不配**打扰用户：
    /// 衣柜凑不出一身时推到锁屏、点开却是空的，比不推更糟。
    public static func reschedule(availableItemCount: Int, now: Date = Date()) async {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: allIdentifiers)
        guard isEnabled, DailyRitual.shouldSchedule(availableItemCount: availableItemCount) else {
            AppLog.debug("dailyRitual not scheduled (enabled=\(isEnabled) items=\(availableItemCount))", .app)
            return
        }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else {
            AppLog.notice("dailyRitual skipped: not authorized", .app)
            return
        }
        // 七条按周重复，每条自带正确的星期名。
        // 「一条每日重复 + 排程当刻算出的星期名」会让周三排的标题周四照发——
        // 到那一刻标题就是假话（`DailyRitual.weeklyPlan` 的注释里有同一条理由）。
        let calendar = Calendar.current
        _ = now   // 触发用 DateComponents 匹配，不需要具体起点
        for entry in DailyRitual.weeklyPlan(calendar: calendar) {
            var components = DateComponents()
            components.hour = hour
            components.minute = DailyRitual.defaultMinute
            components.weekday = entry.weekday

            let content = UNMutableNotificationContent()
            content.title = entry.title
            content.body = DailyRitual.body
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            do {
                try await center.add(UNNotificationRequest(
                    identifier: "\(requestIdentifierPrefix)\(entry.weekday)",
                    content: content, trigger: trigger))
            } catch {
                AppLog.error("dailyRitual schedule failed: \(AppLog.errRef(error))", .app)
            }
        }
        AppLog.notice("dailyRitual scheduled hour=\(hour) days=7", .app)
        #endif
    }

    /// 关掉：既清开关也清挂起的请求（只清一个会留下幽灵提醒）。
    public static func disable() {
        isEnabled = false
        #if canImport(UserNotifications)
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: allIdentifiers)
        #endif
    }
}
