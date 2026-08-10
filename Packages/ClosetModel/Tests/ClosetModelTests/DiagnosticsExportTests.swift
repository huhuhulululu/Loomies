import Testing
import SwiftData
import Foundation
@testable import ClosetModel
import ClosetCore

@MainActor
struct DiagnosticsExportTests {

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    @Test func snapshotCountsItemsAndWardrobes() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "NYC", locationCity: "New York"); ctx.insert(w)
        let i = Item(name: "tee"); i.slotRaw = "top"; i.wardrobe = w; i.statusRaw = "available"
        ctx.insert(i)
        try ctx.save()

        AppLog.ring.clear()
        AppLog.info("diag-test", .diagnostics)

        let snap = DiagnosticsExport.snapshot(in: ctx, appVersion: "0.1.0", build: "3",
                                              flags: ["coldStart": "true"])
        #expect(snap.wardrobeCount == 1)
        #expect(snap.itemCount == 1)
        #expect(snap.wardrobes.first?.hasCity == true)
        #expect(snap.wardrobes.first?.availableCount == 1)
        #expect(snap.flags["coldStart"] == "true")
        #expect(snap.recentLogLines.contains(where: { $0.contains("diag-test") }))

        let json = try DiagnosticsExport.jsonString(in: ctx, build: "3")
        // 诊断脱敏：衣柜名与城市不得出现在给支持方的包里
        #expect(!json.contains("NYC"))
        #expect(!json.contains("New York"))
        #expect(json.contains("itemCount"))
    }

    /// 端到端隐私锁：经真实服务路径产生的日志（含实体操作）随诊断导出时，
    /// 不得携带单品名/衣柜名/城市/绝对路径——日志源头必须用 AppLog.ref 稳定标识。
    @Test func diagnosticsJSONCarriesNoPIIFromServiceLogs() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Secret Closet", locationCity: "Hidden City"); ctx.insert(w)
        let i = Item(name: "Sézane Silk Blouse"); i.slotRaw = "top"; i.wardrobe = w
        ctx.insert(i)
        try ctx.save()

        AppLog.ring.clear()
        let prevLevel = AppLog.minLevel
        AppLog.setMinLevel(.debug)
        defer { AppLog.setMinLevel(prevLevel) }
        // 真实服务路径打日志（编辑/状态/打卡）
        _ = ItemEditorService.apply(.init(name: "Sézane Silk Blouse"), to: i, in: ctx)
        _ = ItemStatusService.setStatus(i, to: "inWash", in: ctx)
        _ = CheckInService.recordWear(items: [], on: Date(), in: w, in: ctx)

        let json = try DiagnosticsExport.jsonString(in: ctx)
        #expect(!json.contains("Sézane"))
        #expect(!json.contains("Secret Closet"))
        #expect(!json.contains("Hidden City"))
        #expect(!json.contains("/var/"))
        #expect(!json.contains("/Users/"))
    }

    @Test func bodyCompleteFlagWhenProfileFull() throws {
        let ctx = try makeContext()
        let p = PersonBodyProfile(personID: UUID())
        p.bustInches = 36; p.waistInches = 26; p.hipInches = 36; p.highHipInches = 34
        ctx.insert(p)
        try ctx.save()
        let snap = DiagnosticsExport.snapshot(in: ctx)
        #expect(snap.bodyProfileComplete == true)
    }

    /// M3: multi-person — one incomplete profile must drag the flag to false (not profiles.first only).
    @Test func bodyCompleteFlagFalseWhenAnyProfileIncomplete() throws {
        let ctx = try makeContext()
        let full = PersonBodyProfile(personID: UUID())
        full.bustInches = 36; full.waistInches = 26; full.hipInches = 36; full.highHipInches = 34
        ctx.insert(full)
        let partial = PersonBodyProfile(personID: UUID())
        partial.bustInches = 36 // missing waist/hip/highHip → incomplete
        ctx.insert(partial)
        try ctx.save()

        let snap = DiagnosticsExport.snapshot(in: ctx)
        #expect(snap.bodyProfileComplete == false)
    }

    /// M3: no profiles at all → nil (unknown), not false.
    @Test func bodyCompleteFlagNilWhenNoProfiles() throws {
        let ctx = try makeContext()
        let snap = DiagnosticsExport.snapshot(in: ctx)
        #expect(snap.bodyProfileComplete == nil)
    }

    /// Slot histogram uses GarmentSlot.resolved (displaySlot truth), not bare slotRaw.
    @Test func slotHistogramResolvesDirtyBlazerAsOuterwear() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "LA"); ctx.insert(w)
        let dirty = Item(name: "Navy Blazer")
        dirty.slotRaw = "top" // storage dirty; product truth = outerwear
        dirty.wardrobe = w
        dirty.statusRaw = "available"
        ctx.insert(dirty)
        let tee = Item(name: "White tee")
        tee.slotRaw = "top"
        tee.wardrobe = w
        tee.statusRaw = "available"
        ctx.insert(tee)
        try ctx.save()

        let snap = DiagnosticsExport.snapshot(in: ctx)
        let slots = snap.wardrobes.first?.slots ?? [:]
        #expect(slots["outerwear"] == 1)
        #expect(slots["top"] == 1)
        #expect(slots["top"] != 2) // must not lump blazer under raw "top"
    }

    @Test func exportFailedMessageIsCustomerFacing() {
        let msg = DiagnosticsExport.exportFailedMessage
        #expect(msg.localizedCaseInsensitiveContains("couldn't export"))
        #expect(msg.localizedCaseInsensitiveContains("diagnostics"))
        #expect(msg.localizedCaseInsensitiveContains("try again"))
        #expect(!msg.contains("NSError"))
        #expect(!msg.contains("localizedDescription"))
    }

    /// Success chip: no char-count tech detail (parity with DataLifecycle exportReadyMessage).
    @Test func exportReadyMessageIsHonestWithoutCharCount() {
        let msg = DiagnosticsExport.exportReadyMessage
        #expect(msg.localizedCaseInsensitiveContains("diagnostics ready"))
        #expect(msg.localizedCaseInsensitiveContains("share"))
        #expect(!msg.localizedCaseInsensitiveContains("chars"))
        #expect(!msg.localizedCaseInsensitiveContains("bytes"))
        #expect(!msg.contains("NSError"))
    }

    /// Me Export diagnostics button VO — support-only, not full closet dump.
    @Test func exportButtonAccessibilityHintIsSupportScoped() {
        let hint = DiagnosticsExport.exportButtonAccessibilityHint
        #expect(hint.localizedCaseInsensitiveContains("share"))
        #expect(hint.localizedCaseInsensitiveContains("diagnostics"))
        #expect(hint.localizedCaseInsensitiveContains("not your full"))
        #expect(!hint.localizedCaseInsensitiveContains("try-on"))
        #expect(!hint.contains("NSError"))
    }
}
