import Foundation
import Testing
import CoreGraphics
import SwiftData
import AVFoundation
import ClosetCore
@testable import ClosetModel // for ModelSave.forceFailure test hook
@testable import ClosetUI

/// U1 — Me "Export my data": success toast only when the payload was actually
/// handed off (share sheet); otherwise an inline preview (macOS parity with
/// diagnostics, no empty "export ready" claim).
@Suite("DataExportFeedback")
struct DataExportFeedbackTests {
    @Test func handedOffPayloadShowsReadyMessage() {
        let msg = DataExportFeedback.message(
            payloadHandedOff: true, json: "{}", includeBodyDimensions: true)
        #expect(msg == DataLifecycleService.exportReadyMessage(includeBodyDimensions: true))
        let msgNoBody = DataExportFeedback.message(
            payloadHandedOff: true, json: "{}", includeBodyDimensions: false)
        #expect(msgNoBody == DataLifecycleService.exportReadyMessage(includeBodyDimensions: false))
    }

    @Test func noHandoffShowsInlinePreviewNotReadyToast() {
        let json = #"{"items":[]}"#
        let msg = DataExportFeedback.message(
            payloadHandedOff: false, json: json, includeBodyDimensions: true)
        #expect(msg == json)
        #expect(msg != DataLifecycleService.exportReadyMessage(includeBodyDimensions: true))
        #expect(msg != DataLifecycleService.exportReadyMessage(includeBodyDimensions: false))
    }

    @Test func noHandoffPreviewTruncatesWithEllipsis() {
        let json = String(repeating: "x", count: 600)
        let msg = DataExportFeedback.message(
            payloadHandedOff: false, json: json, includeBodyDimensions: false)
        #expect(msg.count == 501)
        #expect(msg.hasSuffix("…"))
    }
}

/// U2 — missing-yaw fallback holds 正面 (deg0) deterministically; Dictionary
/// iteration order is not a policy.
@Suite("AvatarCinematicExporter.resolveBodyFrame")
struct ResolveBodyFrameTests {
    private func frame(yaw: BodyAvatarYaw) -> CGImage {
        FullNudeBodyRaster.makeCGImage(
            sex: .female, phenotype: .eastAsian, morph: .neutral,
            shape: .hourglass, yaw: yaw, width: 32, height: 48)!
    }

    @Test func exactYawWins() {
        let front = frame(yaw: .deg0)
        let side = frame(yaw: .deg90)
        let frames: [BodyAvatarYaw: CGImage] = [.deg0: front, .deg90: side]
        #expect(AvatarCinematicExporter.resolveBodyFrame(yaw: .deg90, frames: frames) === side)
        #expect(AvatarCinematicExporter.resolveBodyFrame(yaw: .deg0, frames: frames) === front)
    }

    @Test func missingYawHoldsFront() {
        let front = frame(yaw: .deg0)
        let side = frame(yaw: .deg90)
        let frames: [BodyAvatarYaw: CGImage] = [.deg0: front, .deg90: side]
        // deg45/deg135/deg180 missing → deterministic front hold, not dict order.
        for yaw: BodyAvatarYaw in [.deg45, .deg135, .deg180] {
            #expect(AvatarCinematicExporter.resolveBodyFrame(yaw: yaw, frames: frames) === front)
        }
    }

    @Test func emptyFramesResolveNil() {
        #expect(AvatarCinematicExporter.resolveBodyFrame(yaw: .deg0, frames: [:]) == nil)
    }
}

/// U3 — film export gate: zero on-canvas garments → no basewear-only video.
@Suite("CopilotCinematicExportCopy.canExport")
struct CinematicExportGateTests {
    init() { ItemImageTestRoot.install() }   // 触盘套件：根目录按进程隔离，勿写真机目录

    @Test func emptyLayersCannotExport() {
        #expect(!CopilotCinematicExportCopy.canExport(layers: []))
    }

    @Test func placeholderOnlyLayersCannotExport() {
        let ghost = BodyAvatarLayer(
            id: "ghost-top",
            slot: .top,
            frame: BodyAvatarAnchors.frame(for: .top),
            zIndex: 2,
            localRelativePath: "ItemImages/missing-\(UUID().uuidString).png")
        #expect(ghost.hasVisual, "path-only layer still claims a visual")
        #expect(!BodyAvatarView.hasRenderableVisual(ghost))
        #expect(!CopilotCinematicExportCopy.canExport(layers: [ghost]))
    }

    @Test func decodableLayerCanExport() throws {
        let id = UUID()
        // Minimal valid 1×1 PNG
        let png = Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")!
        let rel = try #require(ItemImageStore.save(data: png, for: id, ext: "png"))
        defer { ItemImageStore.delete(relativePath: rel) }
        let real = BodyAvatarLayer(
            id: id.uuidString,
            slot: .top,
            frame: BodyAvatarAnchors.frame(for: .top),
            zIndex: 2,
            localRelativePath: rel)
        #expect(BodyAvatarView.hasRenderableVisual(real))
        #expect(CopilotCinematicExportCopy.canExport(layers: [real]))
        #expect(CopilotCinematicExportCopy.nothingToPreviewToast.isEmpty == false)
    }
}

/// U4 — QuickAdd: occasion picker may already be "casual"; occasionsRaw must
/// dedup order-preserving at write.
@Suite("QuickAddDraft.dedupOccasions")
struct QuickAddDedupTests {
    @Test func casualDoesNotDuplicate() {
        #expect(QuickAddDraft.dedupOccasions(["casual", "casual"]) == ["casual"])
    }

    @Test func distinctOccasionsKeepOrder() {
        #expect(QuickAddDraft.dedupOccasions(["work", "casual"]) == ["work", "casual"])
        #expect(QuickAddDraft.dedupOccasions(["gala", "casual"]) == ["gala", "casual"])
    }
}


/// UI-N1 — manual Add piece (AddPieceSheet.manualBody in PhotoCaptureViews)
/// writes occasionsRaw through the same QuickAddDraft.dedupOccasions helper
/// as the manual add path (U4 bug class: picker occasion may be "casual").
@Suite("ManualAddSheet.dedupOccasions")
struct ManualAddDedupTests {
    @Test func casualDoesNotDuplicate() {
        #expect(QuickAddDraft.dedupOccasions(["casual", "casual"]) == ["casual"])
    }

    @Test func distinctOccasionsKeepOrder() {
        #expect(QuickAddDraft.dedupOccasions(["work", "casual"]) == ["work", "casual"])
        #expect(QuickAddDraft.dedupOccasions(["date", "casual"]) == ["date", "casual"])
    }
}

/// UI-N2 — Calendar planSheet favorite button gates dismissal on
/// planFavorite returning non-nil: a ModelSave failure must leave the sheet
/// open (stay-open-on-fail parity) with the honest flash, not silently dismiss.
@Suite("CalendarPlanSheet.dismissGate")
@MainActor
struct CalendarPlanSheetDismissGateTests {
    private func makeFavorite() throws -> (ModelContext, ClosetModel.Outfit) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        let ctx = ModelContext(container)
        let w = Wardrobe(name: "A"); ctx.insert(w)
        func mk(_ n: String, _ s: String) -> Item {
            let i = Item(name: n); i.slotRaw = s; i.wardrobe = w
            i.occasionsRaw = ["casual"]; i.warmthRaw = Warmth.light.rawValue
            i.colorIsNeutral = true; i.statusRaw = "available"; ctx.insert(i); return i
        }
        let ids = [mk("tee", "top"), mk("jeans", "bottom"), mk("sneakers", "shoes")]
            .map { $0.id.uuidString }
        try ctx.save()
        let outfit = try OutfitFavoriteService.saveFavorite(
            name: "Weekend", itemIDs: ids, occasion: "casual", in: w, context: ctx)
        return (ctx, outfit)
    }

    @Test func committedPlanIsNonNilSoSheetDismisses() throws {
        let (ctx, outfit) = try makeFavorite()
        let actions = OutfitActionsViewModel()
        let plan = actions.planFavorite(outfit, in: ctx)
        #expect(plan != nil)
        #expect(actions.message.localizedCaseInsensitiveContains("calendar"))
    }

    @Test func failedSaveReturnsNilAndSetsFlashSoSheetStaysOpen() throws {
        let (ctx, outfit) = try makeFavorite()
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        let actions = OutfitActionsViewModel()
        let plan = actions.planFavorite(outfit, in: ctx)
        // nil → caller keeps the sheet open; flash must not look like success.
        #expect(plan == nil)
        #expect(actions.message == CalendarPlanService.saveFailedMessage)
        #expect(!actions.message.localizedCaseInsensitiveContains("added to calendar"))
    }
}

/// UI-N3 — Me Profile section: Body / Personal-color links only resolve for a
/// wardrobe with a real owner; ownerless wardrobes never fall back to a random
/// UUID (no orphan PersonBodyProfile).
@Suite("MeView.profileOwner")
@MainActor
struct MeProfileOwnerGateTests {
    @Test func ownerlessWardrobeHidesProfileLinks() {
        let wardrobe = Wardrobe(name: "NoOwner")
        #expect(MeView.profileOwner(of: wardrobe) == nil)
    }

    @Test func ownedWardrobeResolvesRealOwnerID() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        let ctx = ModelContext(container)
        let person = Person(name: "Ada"); ctx.insert(person)
        let wardrobe = Wardrobe(name: "NYC"); wardrobe.owner = person; ctx.insert(wardrobe)
        try ctx.save()
        #expect(MeView.profileOwner(of: wardrobe)?.id == person.id)
    }
}

private func makeInMemoryContext() throws -> ModelContext {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
        Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
        configurations: config)
    return ModelContext(container)
}

/// UI-R1 — body profile saves: forced ModelSave failure must roll back the
/// pending insert/mutations (honest toast, no dirty state leaking into the
/// next unrelated save).
@Suite("BodyProfileViewModel.saveRollback")
@MainActor
struct BodyProfileSaveRollbackTests {
    @Test func failedSaveOnNewProfileRollsBackInsert() throws {
        let ctx = try makeInMemoryContext()
        let vm = BodyProfileViewModel(personID: UUID(), bodyDataConsent: TestConsent.granted())
        vm.bustInches = 36; vm.waistInches = 28; vm.hipInches = 38
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        vm.save(in: ctx)
        #expect(vm.message == BodyProfileViewModel.saveFailedMessage)
        #expect(!ctx.hasChanges)
        #expect(vm.profile == nil, "failed insert must drop the reference")
        // Subsequent unrelated save must not persist the failed profile.
        ModelSave.clearForcedFailure(on: ctx)
        ctx.insert(Wardrobe(name: "Unrelated"))
        #expect(ModelSave.save(ctx, label: "unrelated"))
        let profiles = try ctx.fetch(FetchDescriptor<PersonBodyProfile>())
        #expect(profiles.isEmpty)
    }

    @Test func failedSelectBodySexRestoresExistingProfile() throws {
        let ctx = try makeInMemoryContext()
        let vm = BodyProfileViewModel(personID: UUID(), bodyDataConsent: TestConsent.granted())
        vm.save(in: ctx)   // commits a profile
        let p = try #require(vm.profile)
        let oldSexRaw = p.presentationSexRaw
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        vm.selectBodySex(.male, in: ctx)
        #expect(vm.message == BodyProfileViewModel.saveFailedMessage)
        #expect(!ctx.hasChanges)
        #expect(p.presentationSexRaw == oldSexRaw)
    }

    @Test func failedFineTuneRestoresMultipliers() throws {
        let ctx = try makeInMemoryContext()
        let vm = BodyProfileViewModel(personID: UUID(), bodyDataConsent: TestConsent.granted())
        vm.save(in: ctx)
        let p = try #require(vm.profile)
        #expect(p.fineWaist == 1)
        vm.fineWaist = 1.05
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        vm.saveFineTune(in: ctx)
        #expect(vm.message == BodyProfileViewModel.saveFailedMessage)
        #expect(!ctx.hasChanges)
        #expect(p.fineWaist == 1)
    }
}

/// UI-R2 — Me profile helpers: failed ModelSave must restore the old attribute
/// and rollback, not leave a dirty value polluting the next save.
@Suite("ProfileLabels.saveRollback")
@MainActor
struct ProfileLabelsSaveRollbackTests {
    @Test func failedPersonRenameRestoresName() throws {
        let ctx = try makeInMemoryContext()
        let person = Person(name: "Ada"); ctx.insert(person)
        try ctx.save()
        ModelSave.forceFailure(on: ctx)
        #expect(ProfileLabels.applyPersonName("Bea", to: person, in: ctx) == false)
        #expect(person.name == "Ada")
        #expect(!ctx.hasChanges)
        ModelSave.clearForcedFailure(on: ctx)
        ctx.insert(Wardrobe(name: "Unrelated"))
        #expect(ModelSave.save(ctx, label: "unrelated"))
        let people = try ctx.fetch(FetchDescriptor<Person>())
        #expect(people.first?.name == "Ada", "failed rename must not leak into later save")
    }

    @Test func failedWardrobeRenameRestoresName() throws {
        let ctx = try makeInMemoryContext()
        let wardrobe = Wardrobe(name: "Main"); ctx.insert(wardrobe)
        try ctx.save()
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        #expect(ProfileLabels.applyWardrobeName("Beach", to: wardrobe, in: ctx) == false)
        #expect(wardrobe.name == "Main")
        #expect(!ctx.hasChanges)
    }

    @Test func failedCitySaveRestoresCity() throws {
        let ctx = try makeInMemoryContext()
        let wardrobe = Wardrobe(name: "Main", locationCity: "NYC"); ctx.insert(wardrobe)
        try ctx.save()
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        #expect(ProfileLabels.applyCity("Tokyo", to: wardrobe, in: ctx) == false)
        #expect(wardrobe.locationCity == "NYC")
        #expect(!ctx.hasChanges)
    }
}

/// UI-R3 — "Wore it" toast: when anti-repeat is disabled (DebugSettings),
/// pieces are not de-prioritized, so the toast must not claim they are.
@Suite("CopilotWoreIt.flashMessage")
struct CopilotWoreItFlashTests {
    @Test func enabledKeepsDePrioritizedClause() {
        let msg = CopilotWoreIt.flashMessage(.checkedIn(pieceCount: 2), antiRepeatEnabled: true)
        #expect(msg.contains("de-prioritized 7 days"))
    }

    @Test func disabledDropsDePrioritizedClause() {
        let msg = CopilotWoreIt.flashMessage(.checkedIn(pieceCount: 2), antiRepeatEnabled: false)
        #expect(!msg.contains("de-prioritized"))
        #expect(msg.contains("Checked in 2 pieces"))
    }
}


/// UI-G1 — detail Save: when ItemEditorService.apply fails and rolls the item
/// back in memory, the form must NOT re-sync from item (that would silently
/// discard typed name/type/measures/location and let a retry flash "Saved."
/// applying nothing).
@Suite("ItemDetailViewModel.saveFormGate")
@MainActor
struct ItemDetailSaveFormGateTests {
    @Test func failedSaveKeepsTypedFormFields() throws {
        let ctx = try makeInMemoryContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let item = Item(name: "Old")
        item.slotRaw = "top"; item.statusRaw = "available"; item.wardrobe = w
        ctx.insert(item)
        try ctx.save()
        let vm = ItemDetailViewModel(item: item)
        vm.name = "New"
        vm.chestFlat = "22"
        vm.waistFlat = "15"
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        vm.save(in: ctx)
        #expect(vm.message == ItemDetailViewModel.saveFailedMessage)
        #expect(vm.name == "New", "typed name must survive a failed save")
        #expect(vm.slotRaw == "top")
        #expect(vm.chestFlat == "22")
        #expect(vm.waistFlat == "15")
        #expect(vm.locationID == nil)
        #expect(item.name == "Old", "rolled-back item must not leak into the form")
    }

    @Test func successfulSaveStillReSyncsResolvedForm() throws {
        let ctx = try makeInMemoryContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let item = Item(name: "Old")
        item.slotRaw = "top"; item.statusRaw = "available"; item.wardrobe = w
        ctx.insert(item)
        try ctx.save()
        let vm = ItemDetailViewModel(item: item)
        vm.name = "Navy Blazer"
        vm.save(in: ctx)
        #expect(vm.message == "Saved.")
        // top + "Navy Blazer" resolves to outerwear — form follows storage truth.
        #expect(vm.name == "Navy Blazer")
        #expect(vm.slotRaw == GarmentSlot.outerwear.rawValue)
    }
}

/// UI-G2 — WardrobeManageActions.create auto-creates Person("Me") when the
/// closet has no people; a failed save must roll that pending insert back too,
/// else the next unrelated save commits an ownerless "Me" as silent fallback.
@Suite("WardrobeManageActions.createPersonRollback")
struct WardrobeCreatePersonRollbackTests {
    @Test func failedCreateRollsBackAutoCreatedPerson() throws {
        let ctx = try makeInMemoryContext()
        ModelSave.forceFailure(on: ctx)
        let result = WardrobeManageActions.create(
            name: "Beach", city: "", existingPeople: [], in: ctx)
        #expect(result.wardrobe == nil)
        #expect(result.message == WardrobeManageActions.createFailedMessage)
        ModelSave.clearForcedFailure(on: ctx)
        // Unrelated save must not commit the failed wardrobe nor the ownerless "Me".
        ctx.insert(Wardrobe(name: "Unrelated"))
        #expect(ModelSave.save(ctx, label: "unrelated"))
        #expect(try ctx.fetch(FetchDescriptor<Person>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<Wardrobe>()).count == 1)
    }

    @Test func successfulCreateWithNoPeopleCommitsAutoPerson() throws {
        let ctx = try makeInMemoryContext()
        let result = WardrobeManageActions.create(
            name: "Beach", city: "", existingPeople: [], in: ctx)
        #expect(result.wardrobe != nil)
        let people = try ctx.fetch(FetchDescriptor<Person>())
        #expect(people.count == 1)
        #expect(people.first?.name == "Me")
    }

    @Test func failedCreateKeepsExistingPerson() throws {
        let ctx = try makeInMemoryContext()
        let ada = Person(name: "Ada"); ctx.insert(ada)
        try ctx.save()
        ModelSave.forceFailure(on: ctx)
        let result = WardrobeManageActions.create(
            name: "Beach", city: "", existingPeople: [ada], in: ctx)
        #expect(result.wardrobe == nil)
        ModelSave.clearForcedFailure(on: ctx)
        ctx.insert(Wardrobe(name: "Unrelated"))
        #expect(ModelSave.save(ctx, label: "unrelated"))
        let people = try ctx.fetch(FetchDescriptor<Person>())
        #expect(people.count == 1, "pre-existing person must survive the rollback")
        #expect(people.first?.name == "Ada")
    }
}

/// UI-G3 — cinematic export back-pressure loop must stop waiting and throw
/// when the writer dies mid-export, instead of hanging on
/// `isReadyForMoreMediaData == false` forever.
@Suite("AvatarCinematicExporter.writerReadiness")
struct WriterReadinessTests {
    @Test func failedStatusThrows() {
        #expect(throws: AvatarCinematicExporter.ExportError.encodeFailed) {
            try AvatarCinematicExporter.writerReadiness(isReady: false, writerStatus: .failed)
        }
    }

    @Test func cancelledStatusThrows() {
        #expect(throws: AvatarCinematicExporter.ExportError.encodeFailed) {
            try AvatarCinematicExporter.writerReadiness(isReady: false, writerStatus: .cancelled)
        }
    }

    @Test func readyInputStopsWaiting() throws {
        #expect(try AvatarCinematicExporter.writerReadiness(
            isReady: true, writerStatus: .writing) == true)
    }

    @Test func busyInputKeepsWaiting() throws {
        #expect(try AvatarCinematicExporter.writerReadiness(
            isReady: false, writerStatus: .writing) == false)
    }
}

/// UI-N4 — AddPieceSheet confirm dismisses the sheet immediately, so the
/// post-save honesty flashes IntakeViewModel.confirm sets on statusMessage
/// ("Added, but the photo won't appear in try-on" etc.) would never render.
/// postConfirmFlash decides what the parent grid flashes after dismissal:
/// confirm() clears statusMessage at entry, so a non-empty status right after
/// success is exactly a post-save honesty message; nil/empty → no flash.
@Suite("AddPieceSheet.postConfirmFlash")
struct AddPiecePostConfirmFlashTests {
    @Test func nilStatusFlashesNothing() {
        #expect(AddPieceSheet.postConfirmFlash(statusMessage: nil) == nil)
    }

    @Test func emptyStatusFlashesNothing() {
        #expect(AddPieceSheet.postConfirmFlash(statusMessage: "") == nil)
    }

    @Test func postSaveHonestyMessagesPassThrough() {
        for msg in [
            "Added, but the photo won't appear in try-on — re-add the photo later.",
            "Added, but the photo couldn't be aligned for try-on — re-add the photo later.",
            "Added, but the photo couldn't be saved for try-on — re-add the photo later.",
        ] {
            #expect(AddPieceSheet.postConfirmFlash(statusMessage: msg) == msg)
        }
    }
}

/// UI-A2 — measure stepper +/- icon buttons keep the small icon visual but
/// the tap target must meet the 44pt HIG minimum (lookPagerChevron parity).
@Suite("BodyProfileView.measureStepperHitArea")
struct MeasureStepperHitAreaTests {
    @Test func hitAreaMeetsHIGMinimum() {
        #expect(BodyProfileView.measureStepperHitArea >= 44)
        // Icon visual is ~22pt — hit area must grow well past it.
        #expect(BodyProfileView.measureStepperHitArea > 22)
    }
}
