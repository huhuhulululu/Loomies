import Foundation

/// 身体维度采集的**单独同意**（DESIGN §2.2 隐私段）。
/// 与遥测门同构：默认未同意，用户显式授予；可撤回。
/// ⚠️ 门必须在**任何 context.insert 之前**判定——放在 insert 之后返回 false
/// 会留下 pending insert + 关系幻影，污染下一次无关 save（保存原子性铁律）。
public final class BodyDataConsent: @unchecked Sendable {
    public static let defaultsKey = "loomies.bodyData.consent"
    public static let shared = BodyDataConsent()

    private let defaults: UserDefaults
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var isGranted: Bool {
        lock.lock(); defer { lock.unlock() }
        return defaults.bool(forKey: Self.defaultsKey)
    }

    public func setGranted(_ granted: Bool) {
        lock.lock()
        defaults.set(granted, forKey: Self.defaultsKey)
        lock.unlock()
        AppLog.notice("body data consent=\(granted)", .data)
    }

    // MARK: - 客户文案（只说做得到的）

    public static let title = "Body measurements"
    public static let explainer =
        "Measurements power fit marks and body-shape styling. They are stored in a separate "
        + "local store on this device, are never synced to the cloud, and are left out of data "
        + "exports unless you explicitly include them. You can delete them any time."
    public static let grantTitle = "Use my measurements"
    public static let declineTitle = "Not now"
    /// 未同意时试图落库身体维度的诚实提示。
    public static let requiredMessage =
        "Turn on body measurements first — we won't store them without your say-so."
}
