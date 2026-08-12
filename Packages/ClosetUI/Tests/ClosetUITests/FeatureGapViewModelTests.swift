import Testing
import SwiftData
import Foundation
@testable import ClosetUI
import ClosetModel
import ClosetCore
import ClosetIntake

@MainActor
struct FeatureGapViewModelTests {

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    @Test func itemDetailSavesEdits() throws {
        let ctx = try makeContext()
        let i = Item(name: "tee"); i.slotRaw = "top"; ctx.insert(i)
        try ctx.save()
        let vm = ItemDetailViewModel(item: i)
        vm.name = "White tee"
        vm.brand = "Uniqlo"
        vm.statusRaw = "inWash"
        vm.save(in: ctx)
        #expect(i.name == "White tee")
        #expect(i.brand == "Uniqlo")
        #expect(i.statusRaw == "inWash")
        #expect(vm.message == "Saved.")
        #expect(!vm.message.localizedCaseInsensitiveContains("couldn't"))
    }

    /// Detail Save can assign / clear Me Storage location (parity StorageLocationService).
    @Test func itemDetailSavesStorageLocation() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let rod = try #require(StorageLocationService.create(name: "Rod", in: w, context: ctx))
        let drawer = try #require(
            StorageLocationService.create(name: "Drawer", in: w, parent: rod, context: ctx))
        let i = Item(name: "tee"); i.slotRaw = "top"; i.wardrobe = w; ctx.insert(i)
        try ctx.save()

        let vm = ItemDetailViewModel(item: i)
        #expect(vm.locationID == nil)
        #expect(vm.storageLocations.map(\.name) == ["Rod", "Drawer"])
        #expect(ItemDetailViewModel.noStorageLocationsCaption
            .localizedCaseInsensitiveContains("Me"))
        #expect(ItemDetailViewModel.noStorageLocationsCaption
            .localizedCaseInsensitiveContains("Storage"))

        vm.locationID = drawer.id
        vm.save(in: ctx)
        #expect(i.location?.id == drawer.id)
        #expect(vm.locationID == drawer.id)
        #expect(vm.message == "Saved.")

        // Clear → None.
        vm.locationID = nil
        vm.save(in: ctx)
        #expect(i.location == nil)
        #expect(vm.locationID == nil)
        #expect(vm.message == "Saved.")

        // Stale picker id after location deleted — honest fail, not silent OK.
        vm.locationID = drawer.id
        #expect(DeleteService.deleteLocation(drawer, in: ctx))
        vm.save(in: ctx)
        #expect(vm.message == StorageLocationService.assignSaveFailedMessage
            || vm.message == ItemDetailViewModel.saveFailedMessage)
        #expect(CustomerFlashStyle.isFailure(vm.message)
            || vm.message.localizedCaseInsensitiveContains("couldn't"))
    }

    /// Me → Storage empty list VO — short empty title; no try-on / fake inventory.
    @Test func storageEmptyCopyIsHonestForVoiceOver() {
        #expect(StorageEmptyCopy.title.localizedCaseInsensitiveContains("no locations"))
        #expect(!StorageEmptyCopy.title.localizedCaseInsensitiveContains("try-on"))
        #expect(!StorageEmptyCopy.title.localizedCaseInsensitiveContains("sync"))
        #expect(StorageEmptyCopy.rowSwipeAccessibilityHint.localizedCaseInsensitiveContains("swipe"))
        // Fail flashes stay customer-facing (list must not silently drop rows).
        #expect(CustomerFlashStyle.isFailure(StorageLocationService.createSaveFailedMessage))
        #expect(CustomerFlashStyle.isFailure(StorageLocationService.removeSaveFailedMessage))
        #expect(StorageLocationService.removeSaveFailedMessage
            .localizedCaseInsensitiveContains("couldn't remove"))
    }

    /// Save success/failure copy constants — fail path must not masquerade as “Saved.”
    @Test func itemDetailSaveFailedMessageIsHonest() {
        #expect(ItemDetailViewModel.saveFailedMessage.localizedCaseInsensitiveContains("couldn't save"))
        #expect(ItemDetailViewModel.saveFailedMessage.localizedCaseInsensitiveContains("try again"))
        #expect(ItemDetailViewModel.saveFailedMessage != "Saved.")
        // Delete fail shares DeleteError.saveFailed (period + voice); not “Deleted.”
        #expect(ItemDetailViewModel.deleteFailedMessage
            == DeleteError.saveFailed.errorDescription)
        #expect(ItemDetailViewModel.deleteFailedMessage
            .localizedCaseInsensitiveContains("couldn't delete"))
        #expect(ItemDetailViewModel.deleteFailedMessage
            .localizedCaseInsensitiveContains("try again"))
        #expect(ItemDetailViewModel.deleteFailedMessage != "Deleted.")
        #expect(CustomerFlashStyle.isFailure(ItemDetailViewModel.deleteFailedMessage))
        #expect(!CustomerFlashStyle.isFailure("Deleted."))
    }

    /// Detail Save rewrites form Type when name implies outerwear (stack/filter truth).
    @Test func itemDetailSaveResolvesDirtyBlazerAndSyncsForm() throws {
        let ctx = try makeContext()
        let i = Item(name: "Piece"); i.slotRaw = "top"; ctx.insert(i)
        try ctx.save()
        let vm = ItemDetailViewModel(item: i)
        vm.name = "Navy Blazer"
        vm.slotRaw = "top"
        vm.save(in: ctx)
        #expect(i.slotRaw == "outerwear")
        #expect(vm.slotRaw == "outerwear")
        #expect(vm.name == "Navy Blazer")
    }

    /// Open detail: Type picker shows resolved product slot (not bare dirty slotRaw).
    @Test func itemDetailInitResolvesDirtyBlazerSlotForTypePicker() {
        let i = Item(name: "Navy Blazer")
        i.slotRaw = "top" // storage dirty; Closet/Search show Outerwear
        let vm = ItemDetailViewModel(item: i)
        #expect(vm.slotRaw == "outerwear")
        #expect(vm.slotRaw != "top")
        // Alias raw still maps into GarmentSlot.allCases for the picker.
        let alias = Item(name: "Coat")
        alias.slotRaw = "outer"
        #expect(ItemDetailViewModel(item: alias).slotRaw == "outerwear")
    }

    /// Clearing flat width fields then Save must wipe entity measures (not leave stale FitMark).
    @Test func itemDetailSaveClearsEmptyFlatWidths() throws {
        let ctx = try makeContext()
        let i = Item(name: "tee"); i.slotRaw = "top"
        i.chestFlatWidthInches = 18
        ctx.insert(i)
        try ctx.save()
        let vm = ItemDetailViewModel(item: i)
        #expect(vm.chestFlat == "18.0" || vm.chestFlat == "18")
        vm.chestFlat = ""
        vm.waistFlat = ""
        vm.save(in: ctx)
        #expect(i.chestFlatWidthInches == nil)
        #expect(i.waistFlatWidthInches == nil)
        #expect(vm.chestFlat.isEmpty)
        #expect(vm.waistFlat.isEmpty)
    }

    /// Fit mark shows label + measurement-ease detail (proportion guide, not try-on).
    @Test func itemDetailRefreshFitSurfacesProportionDetail() throws {
        let ctx = try makeContext()
        let i = Item(name: "tee"); i.slotRaw = "top"
        i.chestFlatWidthInches = 18
        ctx.insert(i)
        let p = PersonBodyProfile(personID: UUID())
        p.bustInches = 36; p.waistInches = 28; p.hipInches = 38; p.highHipInches = 34
        ctx.insert(p)
        try ctx.save()
        let vm = ItemDetailViewModel(item: i)
        vm.refreshFit(profile: p)
        #expect(vm.fitLabel != nil)
        let detail = try #require(vm.fitDetail)
        #expect(detail.localizedCaseInsensitiveContains("proportion guide"))
        #expect(!detail.localizedCaseInsensitiveContains("try-on"))
        #expect(!detail.localizedCaseInsensitiveContains("as intended"))
        vm.refreshFit(profile: nil)
        #expect(vm.fitLabel == nil)
        #expect(vm.fitDetail == nil)
    }

    /// Detail form: typing flat width previews FitMark before Save (entity stays nil).
    @Test func itemDetailFitPreviewUsesUnsavedFormFields() throws {
        let ctx = try makeContext()
        let i = Item(name: "tee"); i.slotRaw = "top"
        // No flat width on entity yet — customer is still typing.
        ctx.insert(i)
        let p = PersonBodyProfile(personID: UUID())
        p.bustInches = 34
        ctx.insert(p)
        try ctx.save()
        let vm = ItemDetailViewModel(item: i)
        #expect(i.chestFlatWidthInches == nil)
        vm.refreshFit(profile: p)
        #expect(vm.fitLabel == nil)

        vm.chestFlat = "18"
        vm.refreshFit(profile: p)
        #expect(vm.fitLabel == FitMarkCopy.label(.fitted))
        #expect(i.chestFlatWidthInches == nil) // unsaved

        vm.chestFlat = "16"
        vm.refreshFit(profile: p)
        #expect(vm.fitLabel == FitMarkCopy.label(.tight))

        // Dirty name + top raw → outerwear still uses chest flat for mark.
        vm.name = "Navy Blazer"
        vm.slotRaw = "top"
        vm.chestFlat = "18"
        vm.refreshFit(profile: p)
        #expect(vm.fitLabel == FitMarkCopy.label(.fitted))
    }

    @Test func itemDetailDeleteRemovesItemAndMarksOutfitMissing() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Home"); ctx.insert(w)
        let i = Item(name: "old tee"); i.slotRaw = "top"; i.wardrobe = w; ctx.insert(i)
        let o = Outfit(name: "look"); o.isFavorite = true; o.wardrobe = w
        o.items = [i]; ctx.insert(o)
        try ctx.save()
        let id = i.id
        let vm = ItemDetailViewModel(item: i)
        #expect(!vm.didDelete)
        vm.delete(in: ctx)
        #expect(vm.didDelete)
        #expect(vm.message == "Deleted.")
        #expect(!vm.message.localizedCaseInsensitiveContains("couldn't"))
        let left = try ctx.fetch(FetchDescriptor<Item>()).filter { $0.id == id }
        #expect(left.isEmpty)
        #expect(o.permanentlyMissing == true)
    }

    @Test func transferMovesItem() throws {
        let ctx = try makeContext()
        let a = Wardrobe(name: "NYC"); ctx.insert(a)
        let b = Wardrobe(name: "BKK"); ctx.insert(b)
        let i = Item(name: "x"); i.wardrobe = a; ctx.insert(i)
        try ctx.save()
        let vm = TransferViewModel(item: i)
        vm.loadDestinations(in: ctx)
        #expect(vm.destinations.count == 1)
        vm.selectedDestinationID = b.id
        let ok = vm.transfer(in: ctx)
        #expect(ok)
        #expect(vm.didTransfer)
        #expect(i.wardrobe?.id == b.id)
        #expect(vm.message.localizedCaseInsensitiveContains("Moved"))
    }

    /// No destination selected → false + honest message (sheet must not dismiss).
    @Test func transferWithoutDestinationDoesNotCommit() throws {
        let ctx = try makeContext()
        let a = Wardrobe(name: "Home"); ctx.insert(a)
        let b = Wardrobe(name: "Trip"); ctx.insert(b)
        let i = Item(name: "coat"); i.wardrobe = a; ctx.insert(i)
        try ctx.save()
        let vm = TransferViewModel(item: i)
        vm.loadDestinations(in: ctx)
        vm.selectedDestinationID = nil
        let ok = vm.transfer(in: ctx)
        #expect(!ok)
        #expect(!vm.didTransfer)
        #expect(vm.message == TransferViewModel.pickDestinationMessage)
        #expect(i.wardrobe?.id == a.id)
    }

    /// ModelSave fail toast must not look like success (sheet stays open).
    @Test func transferSaveFailedMessageIsHonest() {
        #expect(TransferViewModel.saveFailedMessage.localizedCaseInsensitiveContains("couldn't move"))
        #expect(TransferViewModel.saveFailedMessage.localizedCaseInsensitiveContains("try again"))
        #expect(!TransferViewModel.saveFailedMessage.localizedCaseInsensitiveContains("moved to"))
        #expect(TransferService.saveFailedMessage == TransferViewModel.saveFailedMessage)
        // 空目的地 VO——指路 Me；词汇统一为 closet（Me 里已无 "Wardrobes" 这个标签）
        #expect(TransferViewModel.noOtherWardrobesMessage
            .localizedCaseInsensitiveContains("Me"))
        #expect(TransferViewModel.noOtherWardrobesMessage
            .localizedCaseInsensitiveContains("closet"))
        #expect(!TransferViewModel.noOtherWardrobesMessage
            .localizedCaseInsensitiveContains("try-on"))
        #expect(!CustomerFlashStyle.isFailure(TransferViewModel.noOtherWardrobesMessage))
    }

    /// Sole closet → no destinations; Move stays disabled via empty list (honest empty copy).
    @Test func transferSoleClosetHasNoDestinations() throws {
        let ctx = try makeContext()
        let a = Wardrobe(name: "Only"); ctx.insert(a)
        let i = Item(name: "tee"); i.wardrobe = a; ctx.insert(i)
        try ctx.save()
        let vm = TransferViewModel(item: i)
        vm.loadDestinations(in: ctx)
        #expect(vm.destinations.isEmpty)
        #expect(vm.selectedDestinationID == nil)
        #expect(!vm.transfer(in: ctx))
        #expect(vm.message == TransferViewModel.pickDestinationMessage)
        #expect(i.wardrobe?.id == a.id)
    }

    @Test func bodyProfileCompletesFFIT() throws {
        let ctx = try makeContext()
        let pid = UUID()
        let vm = BodyProfileViewModel(personID: pid, bodyDataConsent: TestConsent.granted())
        vm.bustInches = 36
        vm.waistInches = 26
        vm.hipInches = 36
        vm.highHipInches = 34
        vm.save(in: ctx)
        #expect(vm.isComplete)
        #expect(vm.shapeLabel != nil)
        #expect(vm.liveMeasurements != nil)
        #expect(vm.popularShape == .hourglass)
        #expect(vm.confidence == .measured)
        #expect(vm.message.localizedCaseInsensitiveContains("Saved"))
        #expect(!vm.message.localizedCaseInsensitiveContains("couldn't"))
    }

    /// Fail toast must not masquerade as Saved (ModelSave guard).
    @Test func bodyProfileSaveFailedMessageIsHonest() {
        #expect(BodyProfileViewModel.saveFailedMessage
            .localizedCaseInsensitiveContains("couldn't save"))
        #expect(BodyProfileViewModel.saveFailedMessage
            .localizedCaseInsensitiveContains("try again"))
        #expect(!BodyProfileViewModel.saveFailedMessage
            .localizedCaseInsensitiveContains("measurements ready"))
        // Measure steppers (icon-only −/+) name the field for VoiceOver.
        #expect(BodyProfileView.measureStepAccessibilityLabel(
            title: "Bust", direction: .decrease) == "Decrease Bust")
        #expect(BodyProfileView.measureStepAccessibilityLabel(
            title: "Waist", direction: .increase) == "Increase Waist")
        #expect(!BodyProfileView.measureStepAccessibilityLabel(
            title: "Hip", direction: .increase)
            .localizedCaseInsensitiveContains("try-on"))
        // Fine-tune morph sliders — axis name + spoken multiplier (not bare “slider” / ×).
        #expect(BodyProfileView.morphSliderAccessibilityLabel(title: "Chest")
            == "Chest fine-tune")
        #expect(BodyProfileView.morphSliderAccessibilityLabel(title: "Height")
            == "Height fine-tune")
        #expect(BodyProfileView.morphSliderAccessibilityValue(1.05) == "1.05 times")
        #expect(BodyProfileView.morphSliderAccessibilityValue(0.90) == "0.90 times")
        #expect(BodyProfileView.morphSliderAccessibilityHint
            .localizedCaseInsensitiveContains("0.90"))
        #expect(BodyProfileView.morphSliderAccessibilityHint
            .localizedCaseInsensitiveContains("1.10"))
        #expect(!BodyProfileView.morphSliderAccessibilityLabel(title: "Waist")
            .localizedCaseInsensitiveContains("try-on"))
        #expect(!BodyProfileView.morphSliderAccessibilityHint
            .localizedCaseInsensitiveContains("try-on"))
    }

    @Test func bodyProfileLivePreviewWithoutSave() {
        let vm = BodyProfileViewModel(personID: UUID(), bodyDataConsent: TestConsent.granted())
        vm.bustInches = 34
        vm.waistInches = 30
        vm.hipInches = 42
        vm.highHipInches = 38
        vm.refreshPreview()
        #expect(vm.isComplete)
        #expect(vm.popularShape == .pear)
        #expect(vm.liveMeasurements?.hip == 42)
    }

    @Test func bodyProfileQuickPickWithoutMeasures() throws {
        let ctx = try makeContext()
        let pid = UUID()
        let vm = BodyProfileViewModel(personID: pid, bodyDataConsent: TestConsent.granted())
        vm.selectPopularShape(.apple, in: ctx)
        #expect(vm.selectedPopular == .apple)
        #expect(vm.popularShape == .apple)
        #expect(vm.confidence == .visualOnly)
        #expect(!vm.isComplete)
        #expect(vm.profile?.popularShapeOverrideRaw == PopularShape.apple.rawValue)
        #expect(vm.message.localizedCaseInsensitiveContains("Saved"))
        #expect(!vm.message.localizedCaseInsensitiveContains("couldn't"))
    }

    @Test func bodyProfileInferHighHip() {
        let vm = BodyProfileViewModel(personID: UUID(), bodyDataConsent: TestConsent.granted())
        vm.waistInches = 28
        vm.hipInches = 40
        vm.applyInferredHighHip()
        #expect(vm.highHipInferred)
        #expect(vm.highHipInches != nil)
        #expect(vm.highHipInches! > 28 && vm.highHipInches! < 40)
    }

    @Test func bodyProfileMetricDisplay() {
        let vm = BodyProfileViewModel(personID: UUID(), bodyDataConsent: TestConsent.granted())
        vm.bustInches = 36
        vm.usesMetric = true
        let s = vm.displayValue(inches: 36)
        #expect(s == "91" || s.hasPrefix("91"))
    }

    @Test func bodyMorphUpdatesWithFineTune() {
        let vm = BodyProfileViewModel(personID: UUID(), bodyDataConsent: TestConsent.granted())
        vm.selectedPopular = .hourglass
        vm.refreshPreview()
        let baseWaist = vm.morph.waist
        vm.fineWaist = 0.92
        vm.refreshPreview()
        #expect(vm.morph.waist < baseWaist)
        vm.resetFineTune()
        #expect(abs(vm.fineWaist - 1) < 0.001)
    }

    @Test func bodyMorphFromMeasurements() {
        let vm = BodyProfileViewModel(personID: UUID(), bodyDataConsent: TestConsent.granted())
        vm.bustInches = 40
        vm.waistInches = 26
        vm.hipInches = 40
        vm.highHipInches = 34
        vm.refreshPreview()
        #expect(vm.morph.chest > 1.0)
        #expect(vm.morph.waist < 1.0)
    }

    @Test func bodyFineTunePersistsAcrossLoad() throws {
        let ctx = try makeContext()
        let pid = UUID()
        let vm = BodyProfileViewModel(personID: pid, bodyDataConsent: TestConsent.granted())
        vm.selectedPopular = .pear
        vm.fineChest = 1.05
        vm.fineWaist = 0.94
        vm.fineHip = 1.08
        vm.fineHeight = 1.02
        vm.save(in: ctx)
        let vm2 = BodyProfileViewModel(personID: pid, bodyDataConsent: TestConsent.granted())
        vm2.load(in: ctx)
        #expect(abs(vm2.fineChest - 1.05) < 0.001)
        #expect(abs(vm2.fineWaist - 0.94) < 0.001)
        #expect(abs(vm2.fineHip - 1.08) < 0.001)
        #expect(abs(vm2.fineHeight - 1.02) < 0.001)
        #expect(vm2.morph.hip > 1.0)
    }

    @Test func outfitActionsSaveAndPlan() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        func mk(_ n: String, _ s: String) -> Item {
            let i = Item(name: n); i.slotRaw = s; i.wardrobe = w
            i.occasionsRaw = ["work"]; i.warmthRaw = Warmth.light.rawValue
            i.colorIsNeutral = true; i.statusRaw = "available"; ctx.insert(i); return i
        }
        let t = mk("t", "top"); let _ = mk("b", "bottom"); let _ = mk("s", "shoes")
        try ctx.save()
        let scored = RecommendationService.suggestions(
            for: w, anchors: [t], occasion: "work", daytimeTempF: 75).first
        #expect(scored != nil)
        let actions = OutfitActionsViewModel()
        actions.saveFavorite(scored: scored!, occasion: "work", in: w, context: ctx)
        #expect(OutfitFavoriteService.favorites(in: w).count == 1)
        #expect(actions.message == OutfitActionsViewModel.savedToFavoritesMessage)
        #expect(actions.message.localizedCaseInsensitiveContains("toolbar"))
        actions.planToday(scored: scored!, occasion: "work", in: w, context: ctx)
        let plans = try ctx.fetch(FetchDescriptor<CalendarPlan>())
        #expect(!plans.isEmpty)
        #expect(actions.message == "Added to calendar.")
    }

    /// Orphan look IDs: Save/Plan flash human copy (not raw OutfitDraftError dump).
    @Test func outfitActionsSavePlanOrphanIDsHonestMessage() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        try ctx.save()
        let ghostA = CandidateItem(id: UUID().uuidString, slot: .top)
        let ghostB = CandidateItem(id: UUID().uuidString, slot: .bottom)
        // ClosetCore.Outfit value type (not SwiftData ClosetModel.Outfit).
        let orphan = ScoredOutfit(
            outfit: ClosetCore.Outfit(items: [ghostA, ghostB]),
            score: OutfitScore(value: 1, reasons: []))
        let actions = OutfitActionsViewModel()
        actions.saveFavorite(scored: orphan, occasion: "work", in: w, context: ctx)
        #expect(actions.message.localizedCaseInsensitiveContains("couldn't save"))
        #expect(actions.message.localizedCaseInsensitiveContains("closet"))
        #expect(!actions.message.contains("OutfitDraftError"))
        #expect(!actions.message.contains("error 0"))
        #expect(OutfitFavoriteService.favorites(in: w).isEmpty)

        actions.planToday(scored: orphan, occasion: "work", in: w, context: ctx)
        #expect(actions.message.localizedCaseInsensitiveContains("couldn't plan"))
        #expect(actions.message.localizedCaseInsensitiveContains("closet"))
        #expect(!actions.message.contains("OutfitDraftError"))

        let mapped = OutfitActionsViewModel.failureMessage(
            prefix: "Couldn't save", error: OutfitDraftError.emptySelection)
        #expect(mapped == "Couldn't save — No pieces from this look are in your closet.")
        let saveFailFlash = OutfitActionsViewModel.failureMessage(
            prefix: "Couldn't save", error: OutfitDraftError.saveFailed)
        #expect(saveFailFlash.localizedCaseInsensitiveContains("couldn't save"))
        #expect(saveFailFlash.localizedCaseInsensitiveContains("try again"))
        #expect(!saveFailFlash.contains("OutfitDraftError"))
    }

    /// Favorites list: plan an already-saved look without re-drafting pieces.
    @Test func planFavoriteSchedulesExistingLook() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        func mk(_ n: String, _ s: String) -> Item {
            let i = Item(name: n); i.slotRaw = s; i.wardrobe = w
            i.occasionsRaw = ["casual"]; i.warmthRaw = Warmth.light.rawValue
            i.colorIsNeutral = true; i.statusRaw = "available"; ctx.insert(i); return i
        }
        let t = mk("tee", "top"); let b = mk("jeans", "bottom"); let s = mk("sneakers", "shoes")
        try ctx.save()
        let outfit = try OutfitFavoriteService.saveFavorite(
            name: "Weekend",
            itemIDs: [t, b, s].map { $0.id.uuidString },
            occasion: "casual",
            in: w,
            context: ctx)
        #expect(outfit.isFavorite)

        let actions = OutfitActionsViewModel()
        // Favorites swipe Plan today — same titled flash as Calendar plan picker.
        let favTitle = FavoritesView.lookDisplayTitle(outfit)
        #expect(favTitle == "Weekend")
        let plan = actions.planFavorite(outfit, in: ctx, lookTitle: favTitle)
        #expect(plan != nil)
        #expect(plan!.outfit?.id == outfit.id)
        #expect(plan!.needsAttention == false)
        #expect(actions.message == "Planned Weekend.")
        #expect(CalendarPlanService.plans(for: w, in: ctx).count == 1)

        // Empty / whitespace name → customer “Favorite look” (Favorites list + Calendar plan picker).
        outfit.name = "  "
        #expect(FavoritesView.lookDisplayTitle(outfit) == "Favorite look")
        #expect(OutfitActionsViewModel.planScheduledMessage(
            lookTitle: FavoritesView.lookDisplayTitle(outfit), needsAttention: false)
            == "Planned Favorite look.")
        outfit.name = "Weekend"

        // Meta line: capitalized occasion (not raw `work`); list “—” vs plan picker “Any”.
        #expect(FavoritesView.lookMetaLine(outfit) == "3 pieces · Casual")
        #expect(FavoritesView.lookMetaLine(outfit, emptyOccasion: "Any") == "3 pieces · Casual")
        outfit.occasionRaw = nil
        #expect(FavoritesView.lookMetaLine(outfit) == "3 pieces · —")
        #expect(FavoritesView.lookMetaLine(outfit, emptyOccasion: "Any") == "3 pieces · Any")
        outfit.occasionRaw = "  work  "
        #expect(FavoritesView.lookMetaLine(outfit) == "3 pieces · Work")
        outfit.occasionRaw = "casual"
        #expect(FavoritesEmptyCopy.rowSwipeAccessibilityHint
            .localizedCaseInsensitiveContains("plan today"))
        #expect(FavoritesEmptyCopy.rowSwipeAccessibilityHint
            .localizedCaseInsensitiveContains("remove"))

        // Missing pieces → still schedules, honest attention copy (titled path).
        outfit.missing = true
        let again = actions.planFavorite(
            outfit, on: Date().addingTimeInterval(86_400), in: ctx,
            lookTitle: FavoritesView.lookDisplayTitle(outfit))
        #expect(again?.needsAttention == true)
        #expect(actions.message == "Planned Weekend — look needs attention.")

        // Untitled API still has generic flash (Today Plan uses its own string).
        let untitled = actions.planFavorite(
            outfit, on: Date().addingTimeInterval(172_800), in: ctx)
        #expect(untitled?.needsAttention == true)
        #expect(actions.message == "Added to calendar — look needs attention.")
        #expect(OutfitActionsViewModel.planScheduledMessage(
            lookTitle: "Weekend", needsAttention: false) == "Planned Weekend.")
        #expect(OutfitActionsViewModel.planScheduledMessage(
            needsAttention: true) == "Added to calendar — look needs attention.")

        // ModelSave fail flash must not look like success.
        #expect(CalendarPlanService.saveFailedMessage.localizedCaseInsensitiveContains("couldn't plan"))
        #expect(CalendarPlanService.saveFailedMessage.localizedCaseInsensitiveContains("try again"))
        #expect(!CalendarPlanService.saveFailedMessage.localizedCaseInsensitiveContains("added to calendar"))
    }

    /// Calendar empty VO copy — Attention filter vs bare list; no fake sync/try-on.
    @Test func calendarEmptyCopyIsHonestForVoiceOver() {
        #expect(CalendarEmptyCopy.title(attentionOnly: false) == "No plans yet")
        #expect(CalendarEmptyCopy.title(attentionOnly: true) == "No items need attention")
        #expect(CalendarEmptyCopy.description.localizedCaseInsensitiveContains("Today"))
        #expect(CalendarEmptyCopy.description.localizedCaseInsensitiveContains("favorite"))
        #expect(!CalendarEmptyCopy.description.localizedCaseInsensitiveContains("try-on"))
        #expect(!CalendarEmptyCopy.description.localizedCaseInsensitiveContains("sync"))
        // Chrome: + toolbar + plan-row swipe; flash strings stay customer-facing for overlay VO.
        #expect(CalendarEmptyCopy.addPlanAccessibilityLabel == "Plan a favorite")
        #expect(CalendarEmptyCopy.planRowAccessibilityHint.localizedCaseInsensitiveContains("swipe"))
        #expect(CalendarPlanService.removeSaveFailedMessage
            .localizedCaseInsensitiveContains("couldn't remove"))
        #expect(!CalendarPlanService.removeSaveFailedMessage
            .localizedCaseInsensitiveContains("try-on"))
        // Plan-day sheet empty favorites — VO + recovery; no sync/try-on.
        #expect(CalendarEmptyCopy.noFavoritesYet.localizedCaseInsensitiveContains("Today"))
        #expect(CalendarEmptyCopy.noFavoritesYet.localizedCaseInsensitiveContains("favorite"))
        #expect(!CalendarEmptyCopy.noFavoritesYet.localizedCaseInsensitiveContains("try-on"))
        #expect(!CalendarEmptyCopy.noFavoritesYet.localizedCaseInsensitiveContains("sync"))
    }

    /// Intake empty VO — title + honest pipeline; error/processing fold into one label.
    @Test func intakeEmptyCopyIsHonestForVoiceOver() {
        #expect(IntakeEmptyCopy.title == "Add a photo")
        #expect(IntakeEmptyCopy.description == IntakeServiceFactory.photoPipelineCaption)
        #expect(IntakeEmptyCopy.processingDescription
            == IntakeServiceFactory.photoProcessingCaption)
        #expect(IntakeEmptyCopy.description.localizedCaseInsensitiveContains("Vision"))
        #expect(IntakeEmptyCopy.description.localizedCaseInsensitiveContains("starter"))
        #expect(!IntakeEmptyCopy.description.localizedCaseInsensitiveContains("try-on"))
        #expect(!IntakeEmptyCopy.description.localizedCaseInsensitiveContains("pre-fill"))

        let idle = IntakeEmptyCopy.accessibilityLabel(isProcessing: false)
        #expect(idle.hasPrefix("Add a photo."))
        #expect(idle.localizedCaseInsensitiveContains("starter"))

        let withErr = IntakeEmptyCopy.accessibilityLabel(
            isProcessing: false, error: "Cutout failed")
        #expect(withErr.localizedCaseInsensitiveContains("Cutout failed"))

        let processing = IntakeEmptyCopy.accessibilityLabel(isProcessing: true)
        #expect(processing.localizedCaseInsensitiveContains("Cutting out"))
        #expect(!processing.localizedCaseInsensitiveContains("pre-fill"))
    }

    /// A11Y-1: capture Button must stay a separate, activatable VO target —
    /// `.combine` on the whole empty state would merge it into an inert element.
    @Test func intakeCaptureButtonKeepsSeparateVoiceOverLabel() {
        #expect(IntakeEmptyCopy.captureButtonAccessibilityLabel == "Add a photo")
        // Same wording as the visible CTA title (VO appends the "button" trait).
        #expect(IntakeEmptyCopy.captureButtonAccessibilityLabel == IntakeEmptyCopy.title)
        // The combined text-column label must not claim the button is inside it.
        let combined = IntakeEmptyCopy.accessibilityLabel(isProcessing: false)
        #expect(combined.hasPrefix("\(IntakeEmptyCopy.captureButtonAccessibilityLabel)."))
    }

    /// AddPieceSheet choose caption VO — sheet title + pipeline; keeps CTAs as separate targets.
    @Test func addPieceChooseCopyIsHonestForVoiceOver() {
        #expect(IntakeEmptyCopy.chooseTitle == "Add piece")
        let bare = IntakeEmptyCopy.chooseAccessibilityLabel()
        #expect(bare.hasPrefix("Add piece."))
        #expect(bare.localizedCaseInsensitiveContains("Vision"))
        #expect(bare.localizedCaseInsensitiveContains("starter"))
        #expect(!bare.localizedCaseInsensitiveContains("try-on"))
        #expect(!bare.localizedCaseInsensitiveContains("pre-fill"))
        #expect(!bare.localizedCaseInsensitiveContains("scan with camera"))

        let withMsg = IntakeEmptyCopy.chooseAccessibilityLabel(message: "Photo too small")
        #expect(withMsg.localizedCaseInsensitiveContains("Photo too small"))
    }
}
