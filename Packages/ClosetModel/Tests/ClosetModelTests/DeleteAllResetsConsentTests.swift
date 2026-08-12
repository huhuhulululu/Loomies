import Testing
import SwiftData
import Foundation
@testable import ClosetModel
import ClosetCore

/// D88：「行使删除权」必须把**同意状态**一并清掉。此前删光了全部实体与本地图片，
/// 却留下 `loomies.bodyData.consent` 与 `loomies.telemetry.enabled` 两个 UserDefaults 位：
/// 用户执行「删除全部数据」后回到 onboarding，身体数据同意仍是已授予——下次采集不再问，
/// 遥测开关也保持开启。对一个把「删除权」写进 UI 文案的功能，这是实打实的合规残渣。
@MainActor
struct DeleteAllResetsConsentTests {

    func makeContext() throws -> ModelContext {
        try ModelContext(ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    @Test func deleteAllClearsBodyConsentAndTelemetryOptIn() throws {
        let suite = UserDefaults(suiteName: "delete-all-\(UUID().uuidString)")!
        defer { suite.removePersistentDomain(forName: suite.description) }
        let consent = BodyDataConsent(defaults: suite)
        let telemetry = TelemetryGate(sink: nil, defaults: suite)
        consent.setGranted(true)
        telemetry.setEnabled(true)

        let ctx = try makeContext()
        let p = Person(name: "Ada"); ctx.insert(p)
        let body = PersonBodyProfile(personID: p.id); body.bustInches = 34
        ctx.insert(body)
        try ctx.save()

        let receipt = try DataLifecycleService.deleteAllUserData(
            in: ctx, wipeItemImages: false,
            bodyDataConsent: consent, telemetryGate: telemetry)
        #expect(receipt.deletedBodyProfiles == 1)
        // 同意位归零——下一次身体维度采集必须重新征求
        #expect(!consent.isGranted)
        #expect(!telemetry.isEnabled)
        #expect(receipt.resetConsent)
    }

    /// 删除失败时不得先把同意位清掉（数据还在、同意没了 = 更糟的不一致）。
    @Test func failedDeleteLeavesConsentUntouched() throws {
        let suite = UserDefaults(suiteName: "delete-all-fail-\(UUID().uuidString)")!
        defer { suite.removePersistentDomain(forName: suite.description) }
        let consent = BodyDataConsent(defaults: suite)
        consent.setGranted(true)

        let ctx = try makeContext()
        let p = Person(name: "Ada"); ctx.insert(p)
        try ctx.save()
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }

        #expect(throws: (any Error).self) {
            try DataLifecycleService.deleteAllUserData(
                in: ctx, wipeItemImages: false, bodyDataConsent: consent)
        }
        #expect(consent.isGranted)
    }
}
