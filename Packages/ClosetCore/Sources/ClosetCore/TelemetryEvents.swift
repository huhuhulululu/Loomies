import Foundation

/// 匿名聚合遥测事件 schema（DESIGN §11.8 / D10 / D21 预注册）。
/// 纯类型 + 载荷键；不接 SDK。身体数据/图像永不进事件（红线）。
/// 真机再绑 TelemetryDeck 类 SDK；此处保证事件名与必填键冻结可测。
public enum TelemetryEvent: String, CaseIterable, Sendable {
    case appLaunch = "app_launch"
    case onboardingCompleted = "onboarding_completed"
    case itemConfirmed = "item_confirmed"           // 入库确认
    case copilotRefresh = "copilot_refresh"
    case copilotAccepted = "copilot_accepted"       // 接受某候选（wear-as-is 路径入口）
    case copilotTweaked = "copilot_tweaked"         // 换某件/重配
    case checkInRecorded = "check_in_recorded"
    case searchPerformed = "search_performed"
    case wardrobeSwitched = "wardrobe_switched"
    case fitMarkShown = "fit_mark_shown"           // 展示了合身标记（不计维度值）

    /// 允许的 payload 键（白名单；未知键在 encode 时丢弃）。
    public var allowedKeys: Set<String> {
        switch self {
        case .appLaunch:
            return ["schema_version"]
        case .onboardingCompleted:
            return ["schema_version", "has_body_complete"]
        case .itemConfirmed:
            return ["schema_version", "slot"]
        case .copilotRefresh:
            return ["schema_version", "mode", "occasion", "suggestion_count"]
        case .copilotAccepted:
            // D116：`wear_as_is` 区分「原样穿」与「改过再穿」——
            // MARKET §8.1 判定 copilot 机制成立与否靠的正是这个区分。
            return ["schema_version", "mode", "wear_as_is"]
        case .copilotTweaked:
            return ["schema_version", "mode"]
        case .checkInRecorded:
            return ["schema_version", "item_count", "has_fit_feedback", "wear_as_is"]
        case .searchPerformed:
            return ["schema_version", "has_text", "result_count"]
        case .wardrobeSwitched:
            return ["schema_version"]
        case .fitMarkShown:
            return ["schema_version", "verdict"]   // verdict raw only，无围度
        }
    }
}

/// 校验并净化遥测载荷：只留白名单键；禁止身体/图像类键名。
public enum TelemetryPayload {
    public static let schemaVersion = "1"

    /// 红线键（含即整包拒绝）。
    public static let forbiddenKeys: Set<String> = [
        "bust", "waist", "hip", "high_hip", "body", "image", "photo",
        "person_name", "email", "device_id", "idfa"
    ]

    public static func sanitize(_ event: TelemetryEvent, payload: [String: String]) -> [String: String]? {
        if payload.keys.contains(where: { forbiddenKeys.contains($0.lowercased()) }) {
            return nil
        }
        var out: [String: String] = ["schema_version": schemaVersion]
        for (k, v) in payload where event.allowedKeys.contains(k) && k != "schema_version" {
            out[k] = v
        }
        return out
    }
}
