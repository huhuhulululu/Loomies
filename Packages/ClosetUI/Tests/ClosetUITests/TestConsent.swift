import Foundation
import ClosetCore

/// 测试用身体数据同意：每例独立 suite，互不串味（`UserDefaults.standard`
/// 在并行测试里会被别的用例翻转，曾造成 TelemetryGate 的间歇失败）。
enum TestConsent {
    static func granted() -> BodyDataConsent {
        let c = BodyDataConsent(defaults: UserDefaults(suiteName: "test-consent-\(UUID().uuidString)")!)
        c.setGranted(true)
        return c
    }
}
