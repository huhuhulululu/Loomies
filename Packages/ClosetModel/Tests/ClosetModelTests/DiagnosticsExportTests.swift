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
        #expect(snap.wardrobes.first?.name == "NYC")
        #expect(snap.wardrobes.first?.availableCount == 1)
        #expect(snap.flags["coldStart"] == "true")
        #expect(snap.recentLogLines.contains(where: { $0.contains("diag-test") }))

        let json = try DiagnosticsExport.jsonString(in: ctx, build: "3")
        #expect(json.contains("NYC"))
        #expect(json.contains("itemCount"))
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
}
