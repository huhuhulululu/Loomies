import Testing
import SwiftData
import Foundation
@testable import ClosetUI
import ClosetModel
import ClosetCore

@MainActor
struct CopilotViewModelTests {
    init() {
        ItemImageTestRoot.install()   // 触盘套件：根目录按进程隔离，勿写真机目录
        // 避免 DebugSettings 单例污染用例
        DebugSettings.shared.forceColdStart = false
        DebugSettings.shared.disableAntiRepeat = false
        AppLog.setMinLevel(.debug)
    }

    func setup() throws -> (ModelContext, Wardrobe, Item) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        let ctx = ModelContext(container)
        let w = Wardrobe(name: "A"); ctx.insert(w)
        func mk(_ name: String, _ slot: String, status: String = "available") -> Item {
            let i = Item(name: name); i.slotRaw = slot; i.wardrobe = w
            i.occasionsRaw = ["work"]; i.warmthRaw = Warmth.light.rawValue
            i.colorHue = 0; i.colorIsNeutral = true; i.statusRaw = status
            ctx.insert(i); return i
        }
        let top = mk("top", "top"); _ = mk("bottom", "bottom"); _ = mk("shoes", "shoes")
        _ = mk("dirtyBottom", "bottom", status: "inWash")
        try ctx.save()
        return (ctx, w, top)
    }

    @Test func copilotRefreshProducesSuggestions() throws {
        let (_, w, top) = try setup()
        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 75)
        vm.toggleAnchor(top)
        #expect(vm.isAnchored(top))
        vm.refresh()
        #expect(!vm.suggestions.isEmpty)
        #expect(vm.suggestions[0].outfit.itemIDs.contains(top.id.uuidString))
    }

    @Test func fullAutoProducesSuggestions() throws {
        let (_, w, _) = try setup()
        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 75)
        // setup 仅 3 件会触发冷启动；本用例测 full-auto 本身，压低阈值
        vm.coldStartThreshold = 1
        vm.fullAuto = true
        vm.refresh()
        #expect(!vm.suggestions.isEmpty)
    }

    @Test func availableItemsExcludesInWash() throws {
        let (_, w, _) = try setup()
        let vm = CopilotViewModel(wardrobe: w)
        #expect(vm.availableItems.allSatisfy { $0.statusRaw == "available" })
        #expect(vm.availableItems.count == 3)   // 4 件中 1 件在洗
    }

    @Test func toggleAnchorAddsAndRemoves() throws {
        let (_, w, top) = try setup()
        let vm = CopilotViewModel(wardrobe: w)
        vm.toggleAnchor(top); #expect(vm.isAnchored(top))
        vm.toggleAnchor(top); #expect(!vm.isAnchored(top))
    }

    @Test func refreshAcceptsBodyShapeAndWornIDs() throws {
        let (_, w, top) = try setup()
        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 75)
        vm.bodyShape = .hourglass
        vm.wornWithin7DaysIDs = ["some-other-id"]
        vm.toggleAnchor(top)
        vm.refresh()
        #expect(!vm.suggestions.isEmpty)
    }

    /// Me → Body must re-sync scorer bodyShape (not bootstrap-only snapshot).
    @Test func applyBodyProfileTracksMeBodyEdits() throws {
        let (ctx, w, _) = try setup()
        let person = Person(name: "Ada")
        ctx.insert(person)
        w.owner = person
        let profile = PersonBodyProfile(personID: person.id)
        profile.popularShapeOverrideRaw = PopularShape.hourglass.rawValue
        ctx.insert(profile)
        try ctx.save()

        let vm = CopilotViewModel(wardrobe: w)
        #expect(vm.bodyShape == nil)
        #expect(vm.applyBodyProfile(profile) == true)
        #expect(vm.bodyShape != nil)
        #expect(vm.bodyShape?.popularCategory == .hourglass)
        #expect(vm.applyBodyProfile(profile) == false) // no change

        profile.popularShapeOverrideRaw = PopularShape.pear.rawValue
        #expect(vm.applyBodyProfile(profile) == true)
        #expect(vm.bodyShape?.popularCategory == .pear)

        #expect(vm.loadBodyShape(in: ctx) == false) // already pear
        profile.popularShapeOverrideRaw = PopularShape.apple.rawValue
        try ctx.save()
        #expect(vm.loadBodyShape(in: ctx) == true)
        #expect(vm.bodyShape?.popularCategory == .apple)
    }

    @Test func coldStartBlocksFullAutoWithoutAnchor() throws {
        let (_, w, top) = try setup()
        // setup 有 3 available < default threshold 8 → cold start
        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 75)
        #expect(vm.isColdStart)
        vm.fullAuto = true
        vm.refresh()
        #expect(vm.suggestions.isEmpty)  // 无锚定 → 空

        vm.toggleAnchor(top)
        vm.refresh()
        #expect(!vm.suggestions.isEmpty) // 有锚定 → 可补全
    }

    @Test func coldStartWithoutAnchorSetsStatusMessage() throws {
        let (_, w, _) = try setup()
        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 75)
        vm.refresh()
        #expect(vm.suggestions.isEmpty)
        #expect(vm.statusMessage.contains("Cold start") || vm.statusMessage.contains("anchor"))
        #expect(vm.lastRefreshMS >= 0)
    }

    /// U1: anchor moved to inWash must not anchor suggestions — falls back to
    /// the cold-start/no-anchor path.
    @Test func anchorMovedToInWashDropsAnchor() throws {
        let (ctx, w, top) = try setup()
        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 75)
        vm.toggleAnchor(top)
        vm.refresh()
        #expect(!vm.suggestions.isEmpty)  // available anchor completes looks

        top.statusRaw = "inWash"
        try ctx.save()
        vm.refresh()
        #expect(vm.suggestions.isEmpty)
        #expect(vm.statusMessage.contains("Cold start") || vm.statusMessage.contains("anchor"))
        // Still anchored in the set (user intent kept), just filtered out.
        #expect(vm.isAnchored(top))
    }

    /// U2: wear records from a SECOND wardrobe must not trigger this closet's
    /// "All pieces worn in last 7 days" empty-reason.
    @Test func otherWardrobeWearRecordsDoNotTriggerAllWornMessage() throws {
        let (ctx, w, _) = try setup()
        // Second wardrobe with its own pieces, all "worn" recently.
        let w2 = Wardrobe(name: "B"); ctx.insert(w2)
        var otherWorn: Set<String> = []
        for name in ["b-top", "b-bottom", "b-shoes"] {
            let i = Item(name: name); i.slotRaw = "top"; i.wardrobe = w2
            i.statusRaw = "available"; ctx.insert(i)
            otherWorn.insert(i.id.uuidString)
        }
        try ctx.save()

        let vm = CopilotViewModel(wardrobe: w, occasion: "evening", daytimeTempF: 75)
        vm.coldStartThreshold = 1
        vm.fullAuto = true
        // No "evening" pieces in w → suggestions empty; worn IDs all belong to w2.
        vm.wornWithin7DaysIDs = otherWorn
        vm.refresh()
        #expect(vm.suggestions.isEmpty)
        #expect(!vm.statusMessage.contains("All pieces worn"))
        #expect(vm.statusMessage.contains("No outfits matched"))
    }

    @Test func largeClosetAllowsFullAuto() throws {
        let (ctx, w, _) = try setup()
        DebugSettings.shared.forceColdStart = false
        // 再塞够件数越过阈值
        for i in 0..<10 {
            let item = Item(name: "extra\(i)")
            item.slotRaw = i % 2 == 0 ? "top" : "bottom"
            item.wardrobe = w
            item.occasionsRaw = ["work"]
            item.warmthRaw = Warmth.light.rawValue
            item.colorIsNeutral = true
            item.statusRaw = "available"
            ctx.insert(item)
        }
        // 再补鞋若干
        for i in 0..<3 {
            let s = Item(name: "shoes\(i)"); s.slotRaw = "shoes"; s.wardrobe = w
            s.occasionsRaw = ["work"]; s.warmthRaw = Warmth.light.rawValue
            s.colorIsNeutral = true; s.statusRaw = "available"; ctx.insert(s)
        }
        try ctx.save()
        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 75)
        #expect(!vm.isColdStart)
        vm.fullAuto = true
        vm.refresh()
        #expect(!vm.suggestions.isEmpty)
    }

    @Test func selectSuggestionUpdatesHeroIndex() throws {
        let (ctx, w, _) = try setup()
        DebugSettings.shared.forceColdStart = false
        for i in 0..<12 {
            let item = Item(name: "x\(i)")
            item.slotRaw = ["top", "bottom", "shoes"][i % 3]
            item.wardrobe = w
            item.occasionsRaw = ["work"]
            item.warmthRaw = Warmth.light.rawValue
            item.colorIsNeutral = true
            item.statusRaw = "available"
            ctx.insert(item)
        }
        try ctx.save()
        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 75)
        vm.coldStartThreshold = 1
        vm.fullAuto = true
        vm.refresh()
        #expect(!vm.suggestions.isEmpty)
        #expect(vm.selectedSuggestionIndex == 0)
        #expect(vm.selectedSuggestion != nil)
        if vm.suggestions.count > 1 {
            vm.selectSuggestion(at: 1)
            #expect(vm.selectedSuggestionIndex == 1)
        }
        vm.refresh()
        #expect(vm.selectedSuggestionIndex == 0)  // refresh 重置到首条
    }

    @Test func nextPreviousLookCycles() throws {
        let (ctx, w, _) = try setup()
        for i in 0..<14 {
            let item = Item(name: "n\(i)")
            item.slotRaw = ["top", "bottom", "shoes"][i % 3]
            item.wardrobe = w
            item.occasionsRaw = ["work"]
            item.warmthRaw = Warmth.light.rawValue
            item.colorIsNeutral = true
            item.statusRaw = "available"
            ctx.insert(item)
        }
        try ctx.save()
        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 75)
        vm.coldStartThreshold = 1
        vm.fullAuto = true
        vm.refresh()
        guard vm.lookCount > 1 else { return }
        let first = vm.selectedSuggestionIndex
        vm.selectNextLook()
        #expect(vm.selectedSuggestionIndex != first || vm.lookCount == 1)
        vm.selectPreviousLook()
        #expect(vm.selectedSuggestionIndex == first)
    }

    @Test func emptyDressOverlayMessageIsVoiceOverAudibleCopy() {
        // Capsule + accessibilityLabel share this string (must not be empty/hidden).
        let cold = CopilotEmptyDressOverlay.message(isColdStart: true)
        let dressedGate = CopilotEmptyDressOverlay.message(isColdStart: false)
        #expect(!cold.isEmpty)
        #expect(!dressedGate.isEmpty)
        #expect(cold.contains("Model ready"))
        #expect(dressedGate.contains("Undressed"))
        #expect(dressedGate.contains("layer clothes"))
        #expect(cold != dressedGate)
    }

    @Test func heroTitleDoesNotClaimPieceCountWhenWardrobeIDsUnresolved() throws {
        // Gap: selectedSuggestion with stale itemIDs → empty heroLayers + undressed
        // capsule while title used to say "N-piece look" from Core outfit.count.
        let unresolved = CopilotHeroTitle.text(
            resolvedItemNames: [],
            hasSelectedSuggestion: true,
            hasAnchors: false,
            isColdStart: false)
        #expect(unresolved == CopilotHeroTitle.unavailablePhrase)
        #expect(!unresolved.localizedCaseInsensitiveContains("piece"))
        #expect(!unresolved.contains("-piece"))

        // Empty-string names only → still unavailable (no claimable pieces).
        let blanks = CopilotHeroTitle.text(
            resolvedItemNames: ["", ""],
            hasSelectedSuggestion: true,
            hasAnchors: false,
            isColdStart: false)
        #expect(blanks == CopilotHeroTitle.unavailablePhrase)

        let named = CopilotHeroTitle.text(
            resolvedItemNames: ["Silk top", "Trousers", "Loafers"],
            hasSelectedSuggestion: true,
            hasAnchors: false,
            isColdStart: false)
        #expect(named == "Silk top · Trousers · Loafers")
        #expect(!named.contains("piece"))

        // Integration: wardrobe resolve empty layers when IDs missing; title must match.
        let orphanIDs = [UUID().uuidString, UUID().uuidString, UUID().uuidString]
        let (_, w, _) = try setup()
        let layers = OutfitAvatarComposer.layers(itemIDs: orphanIDs, in: w)
        #expect(layers.isEmpty)
        let ids = Set(orphanIDs)
        let names = (w.items ?? [])
            .filter { ids.contains($0.id.uuidString) }
            .map(\.name)
        #expect(names.isEmpty)
        let title = CopilotHeroTitle.text(
            resolvedItemNames: names,
            hasSelectedSuggestion: true,
            hasAnchors: false,
            isColdStart: false)
        #expect(title == CopilotHeroTitle.unavailablePhrase)
        // Old bug would have been "3-piece look" despite undressed hero.
        #expect(title != "\(orphanIDs.count)-piece look")
    }

    @Test func selectedEmptyHeroCopyIsConsistentAcrossTitleCapsuleAndCaption() {
        // Gap selected-empty-copy-divergence: three surfaces must share recovery phrase
        // when selectedSuggestion resolves to empty heroLayers (not Undressed vs
        // Look items unavailable vs bare Proportion guide).
        let phrase = CopilotHeroTitle.unavailablePhrase
        let title = CopilotHeroTitle.text(
            resolvedItemNames: [],
            hasSelectedSuggestion: true,
            hasAnchors: false,
            isColdStart: false)
        let capsule = CopilotEmptyDressOverlay.message(
            isColdStart: false, lookItemsUnavailable: true)
        let caption = CopilotHeroFitCaption.text(
            layers: [],
            hasSelectedSuggestion: true,
            hasAnchors: false,
            isColdStart: false)

        #expect(title == phrase)
        #expect(capsule.contains(phrase))
        #expect(caption.contains(phrase))
        // Capsule may still say undressed as secondary cue; must not be the old generic.
        #expect(capsule != "Undressed · complete a look to layer clothes")
        // Caption must not be the old generic proportion-only line.
        #expect(caption != "Proportion guide · not a photo try-on")
        #expect(caption.localizedCaseInsensitiveContains("not a photo try-on")
            || caption.localizedCaseInsensitiveContains("not photo try-on"))

        // Non-selected empty still uses the generic undressed capsule (no false unavailable).
        let genericCapsule = CopilotEmptyDressOverlay.message(
            isColdStart: false, lookItemsUnavailable: false)
        #expect(genericCapsule.contains("Undressed"))
        #expect(!genericCapsule.contains(phrase))

        // Path-only layers under a selected look: caption keeps "add item photos",
        // capsule must not claim "Look items unavailable" (items resolved, just no decode).
        let pathOnly = BodyAvatarComposer.layers(slots: [.top: "tee"])
        #expect(!pathOnly.isEmpty)
        let pathCaption = CopilotHeroFitCaption.text(
            layers: pathOnly,
            hasSelectedSuggestion: true,
            hasAnchors: false,
            isColdStart: false)
        #expect(pathCaption.contains("add item photos")
            || pathCaption.contains("proportion guide"))
        #expect(!pathCaption.contains(phrase))
        let pathCapsule = CopilotEmptyDressOverlay.message(
            isColdStart: false, lookItemsUnavailable: false)
        #expect(!pathCapsule.contains(phrase))
    }

    @Test func emptyDressOverlayPinsToCanvasOnlyNotFullStackBottom() {
        // Regression: capsule must not use ZStack Spacer-bottom over the full
        // BodyAvatarView (canvas+orbit+caption) — that covers fitCaption/orbit.
        #expect(CopilotEmptyDressOverlay.placement == .canvasOnly)
        #expect(CopilotEmptyDressOverlay.canvasAspectRatio == 2.0 / 3.0)
        #expect(CopilotEmptyDressOverlay.canvasBottomPadding == 28)

        let width: CGFloat = 320
        let canvasH = CopilotEmptyDressOverlay.canvasBandHeight(forWidth: width)
        #expect(abs(canvasH - 480) < 0.01) // 320 / (2/3) = 480

        // Short hero with orbit + caption chrome below the canvas band.
        let stackWithChrome = CGSize(width: width, height: canvasH + 80)
        #expect(
            CopilotEmptyDressOverlay.fullStackBottomWouldCoverChrome(
                stackSize: stackWithChrome))
        // Canvas-only host is shorter than the full stack → chrome stays clear.
        #expect(canvasH < stackWithChrome.height)

        #expect(CopilotEmptyDressOverlay.canvasBandHeight(forWidth: 0) == 0)
        #expect(CopilotEmptyDressOverlay.canvasBandHeight(forWidth: -10) == 0)
    }

    @Test func heroFitCaptionCarriesWearSummaryOntoBodyAvatarCaption() throws {
        // fitCaption 文案：可解码图 → proportion guide；仅 path/bundle 名 → add photos
        let namedOnly = BodyAvatarComposer.layers(slots: [
            .top: "tee",
            .bottom: "pants",
            .shoes: "sneakers"
        ])
        #expect(OutfitAvatarComposer.hasVisibleGarments(namedOnly))
        // Bundle names without decodeable assets are not on-canvas
        let namedOnlyCaption = CopilotHeroFitCaption.text(
            layers: namedOnly,
            hasSelectedSuggestion: true,
            hasAnchors: false,
            isColdStart: false)
        #expect(namedOnlyCaption.contains("top"))
        #expect(namedOnlyCaption.contains("add item photos")
            || namedOnlyCaption.contains("proportion guide"))

        // Real local PNG → hasRenderableVisual → proportion guide
        let id = UUID()
        let png = Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")!
        let rel = try #require(ItemImageStore.save(data: png, for: id, ext: "png"))
        defer { ItemImageStore.delete(relativePath: rel) }
        let withPNG = BodyAvatarComposer.layers(slotImages: [
            .top: BodyAvatarSlotImage(id: id.uuidString, localRelativePath: rel),
            .bottom: BodyAvatarSlotImage(id: "b", localRelativePath: rel),
        ])
        #expect(BodyAvatarView.hasRenderableVisual(withPNG[0]))
        let dressed = CopilotHeroFitCaption.text(
            layers: withPNG,
            hasSelectedSuggestion: true,
            hasAnchors: false,
            isColdStart: false)
        #expect(dressed.contains("proportion guide"))
        #expect(dressed.contains("not photo try-on"))

        let noVisual = BodyAvatarComposer.layers(slotImages: [
            .top: BodyAvatarSlotImage(id: "t1", bundleName: nil, localRelativePath: nil)
        ])
        #expect(!OutfitAvatarComposer.hasVisibleGarments(noVisual))
        let needsPhotos = CopilotHeroFitCaption.text(
            layers: noVisual,
            hasSelectedSuggestion: true,
            hasAnchors: false,
            isColdStart: false)
        #expect(needsPhotos.contains("add item photos"))

        let anchorHint = CopilotHeroFitCaption.text(
            layers: namedOnly,
            hasSelectedSuggestion: false,
            hasAnchors: true,
            isColdStart: false)
        #expect(anchorHint.contains("Complete"))

        let cold = CopilotHeroFitCaption.text(
            layers: [],
            hasSelectedSuggestion: false,
            hasAnchors: false,
            isColdStart: true)
        #expect(cold.contains("load samples") || cold.contains("Add pieces"))
    }

    /// A11Y-4: look-pager chevrons keep a small visual but must meet the
    /// 44pt HIG minimum hit target.
    @Test func lookPagerChevronHitAreaMeetsHIGMinimum() {
        #expect(CopilotView.lookPagerChevronHitArea >= 44)
        #expect(CopilotView.lookPagerChevronVisualSize == 28)
        // Hit area grows symmetric padding around the visual (regression guard).
        #expect(CopilotView.lookPagerChevronHitArea > CopilotView.lookPagerChevronVisualSize)
        #expect((CopilotView.lookPagerChevronHitArea - CopilotView.lookPagerChevronVisualSize)
            .truncatingRemainder(dividingBy: 2) == 0)
    }
}
