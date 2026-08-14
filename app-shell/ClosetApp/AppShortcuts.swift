import AppIntents

/// 把「Today's look / 今日搭配」注册进 Siri / Action Button / Spotlight（A7, HANDOFF §6.6）。
///
/// `AppShortcutsProvider` 由系统在构建期从 App Intents 元数据里**自动发现**，
/// 无需在 `ClosetApp.swift` 里手动注册——这一波 `ClosetApp.swift` 无人拥有，正好不碰它。
struct LoomiesAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TodayLookIntent(),
            // 每条短语都**必须**含 `\(.applicationName)`（系统硬性要求，缺了不注册）；
            // 它解析成 App 显示名 "Loomies"。首发美国区，英文短语为主，
            // 但 §6.6 点名了「今日搭配」，一并注册中文触发语。
            phrases: [
                "Today's look in \(.applicationName)",
                "What should I wear in \(.applicationName)",
                "Show my \(.applicationName) outfit",
                "\(.applicationName) 今日搭配",
            ],
            shortTitle: "Today's look",
            systemImageName: "tshirt"
        )
    }
}
