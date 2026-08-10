import Testing
import SwiftData
import Foundation
@testable import ClosetModel
import ClosetCore

@MainActor
struct FeatureGapServicesTests {

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    @Test func itemStatusRejectsInvalid() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "tee"); i.wardrobe = w; ctx.insert(i)
        #expect(!ItemStatusService.setStatus(i, to: "bogus", in: ctx))
        #expect(i.statusRaw == "available")
        #expect(ItemStatusService.setStatus(i, to: "inWash", in: ctx))
        #expect(i.statusRaw == "inWash")
    }

    @Test func storageLocationTreeAndAssign() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let rod = StorageLocationService.create(name: "Rod", in: w, context: ctx)
        let drawer = StorageLocationService.create(name: "Drawer", in: w, parent: rod, context: ctx)
        #expect(rod != nil && drawer != nil)
        let list = StorageLocationService.list(in: w)
        #expect(list.map(\.name) == ["Rod", "Drawer"])
        let i = Item(name: "tee"); i.wardrobe = w; ctx.insert(i)
        #expect(StorageLocationService.assign(i, to: drawer, in: ctx))
        #expect(i.location?.id == drawer!.id)
    }

    /// Create/assign/remove save-fail toast must not look like success.
    @Test func storageLocationSaveFailedMessagesAreHonest() {
        #expect(StorageLocationService.createSaveFailedMessage
            .localizedCaseInsensitiveContains("couldn't add"))
        #expect(StorageLocationService.createSaveFailedMessage
            .localizedCaseInsensitiveContains("try again"))
        #expect(!StorageLocationService.createSaveFailedMessage
            .localizedCaseInsensitiveContains("added"))
        #expect(StorageLocationService.assignSaveFailedMessage
            .localizedCaseInsensitiveContains("couldn't update"))
        #expect(StorageLocationService.assignSaveFailedMessage
            .localizedCaseInsensitiveContains("try again"))
        // Me Storage swipe-delete — same honesty bar as calendar/favorites remove.
        #expect(StorageLocationService.removeSaveFailedMessage
            .localizedCaseInsensitiveContains("couldn't remove"))
        #expect(StorageLocationService.removeSaveFailedMessage
            .localizedCaseInsensitiveContains("try again"))
        #expect(!StorageLocationService.removeSaveFailedMessage
            .localizedCaseInsensitiveContains("removed"))
    }

    @Test func itemEditorPatchesFields() throws {
        let ctx = try makeContext()
        let i = Item(name: "old"); ctx.insert(i)
        ItemEditorService.apply(.init(name: "new", slotRaw: "bottom", brand: "Everlane"), to: i, in: ctx)
        #expect(i.name == "new")
        #expect(i.brand == "Everlane")
        #expect(i.slotRaw == "bottom")
    }

    /// Detail rename: top + blazer name persists outerwear (intake persistSlot parity).
    @Test func itemEditorResolvesDirtyBlazerNameToOuterwear() throws {
        let ctx = try makeContext()
        let i = Item(name: "Piece"); i.slotRaw = "top"; ctx.insert(i)
        ItemEditorService.apply(.init(name: "Navy Blazer", slotRaw: "top"), to: i, in: ctx)
        #expect(i.name == "Navy Blazer")
        #expect(i.slotRaw == "outerwear")

        // Name-only patch still re-resolves existing slot against new name.
        let tee = Item(name: "Coat-ish"); tee.slotRaw = "top"; ctx.insert(tee)
        ItemEditorService.apply(.init(name: "White Tee"), to: tee, in: ctx)
        #expect(tee.slotRaw == "top")
    }

    /// Detail form empty flat fields must clear stored measures (FitMark source).
    @Test func itemEditorReplaceFlatWidthsClearsWhenNil() throws {
        let ctx = try makeContext()
        let i = Item(name: "tee"); i.slotRaw = "top"
        i.chestFlatWidthInches = 18
        i.waistFlatWidthInches = 14
        ctx.insert(i)
        // Partial patch without replace flag leaves measures.
        ItemEditorService.apply(.init(name: "tee"), to: i, in: ctx)
        #expect(i.chestFlatWidthInches == 18)
        // replaceFlatWidths + nil clears (user wiped fields).
        ItemEditorService.apply(
            .init(chestFlatWidthInches: nil, waistFlatWidthInches: nil, replaceFlatWidths: true),
            to: i, in: ctx)
        #expect(i.chestFlatWidthInches == nil)
        #expect(i.waistFlatWidthInches == nil)
        ItemEditorService.apply(
            .init(chestFlatWidthInches: 19, waistFlatWidthInches: nil, replaceFlatWidths: true),
            to: i, in: ctx)
        #expect(i.chestFlatWidthInches == 19)
        #expect(i.waistFlatWidthInches == nil)
    }

    @Test func saveFavoriteFromIDsAndPlan() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let t = Item(name: "t"); t.slotRaw = "top"; t.wardrobe = w; ctx.insert(t)
        let b = Item(name: "b"); b.slotRaw = "bottom"; b.wardrobe = w; ctx.insert(b)
        try ctx.save()
        let o = try OutfitFavoriteService.saveFavorite(
            name: "Work look", itemIDs: [t.id.uuidString, b.id.uuidString],
            occasion: "work", in: w, context: ctx)
        #expect(o.isFavorite)
        #expect(o.occasionRaw == "work")
        #expect(OutfitFavoriteService.favorites(in: w).count == 1)

        #expect(OutfitFavoriteService.setFavorite(o, false, in: ctx))
        #expect(o.isFavorite == false)
        #expect(OutfitFavoriteService.favorites(in: w).isEmpty)

        #expect(OutfitFavoriteService.setFavorite(o, true, in: ctx))
        #expect(OutfitFavoriteService.favorites(in: w).count == 1)

        let plan = CalendarPlanService.plan(outfit: o, on: Date(), in: ctx)
        #expect(plan != nil)
        #expect(plan!.outfit?.id == o.id)
        #expect(plan!.needsAttention == false)
    }

    /// Toggle save-fail toast must not look like success (row must stay in favorites).
    @Test func setFavoriteSaveFailedMessageIsHonest() {
        #expect(OutfitFavoriteService.toggleSaveFailedMessage
            .localizedCaseInsensitiveContains("couldn't update"))
        #expect(OutfitFavoriteService.toggleSaveFailedMessage
            .localizedCaseInsensitiveContains("try again"))
        #expect(!OutfitFavoriteService.toggleSaveFailedMessage
            .localizedCaseInsensitiveContains("removed"))
        #expect(!OutfitFavoriteService.toggleSaveFailedMessage
            .localizedCaseInsensitiveContains("saved to favorites"))
    }

    @Test func crossWardrobeLocationAssignBlocked() throws {
        let ctx = try makeContext()
        let a = Wardrobe(name: "A"); ctx.insert(a)
        let b = Wardrobe(name: "B"); ctx.insert(b)
        let loc = StorageLocationService.create(name: "Rod", in: a, context: ctx)
        #expect(loc != nil)
        let i = Item(name: "x"); i.wardrobe = b; ctx.insert(i)
        #expect(!StorageLocationService.assign(i, to: loc, in: ctx))
        #expect(i.location == nil)
    }

    /// M2: save 失败必须 rollback——变更不得滞留污染下一次无关 save。
    @Test(.serialized) func statusSaveFailureRollsBackContext() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "tee"); i.wardrobe = w; ctx.insert(i)
        try ctx.save()
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        #expect(!ItemStatusService.setStatus(i, to: "inWash", in: ctx))
        #expect(i.statusRaw == "available")   // rollback 恢复原值
        #expect(!ctx.hasChanges)              // 失败变更不再滞留
    }

    /// CM-1: itemEdit save 失败须还原内存字段值 + rollback——UI 不得显示未入库的新值。
    @Test(.serialized) func itemEditorSaveFailureRestoresValuesAndRollsBack() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "old tee"); i.slotRaw = "top"; i.brand = "Uniqlo"
        i.occasionsRaw = ["casual"]; i.wardrobe = w; ctx.insert(i)
        try ctx.save()
        let oldRevision = i.revision
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        #expect(!ItemEditorService.apply(
            .init(name: "new tee", slotRaw: "bottom", occasionsRaw: ["work"], brand: "Everlane"),
            to: i, in: ctx))
        #expect(i.name == "old tee")
        #expect(i.slotRaw == "top")
        #expect(i.occasionsRaw == ["casual"])
        #expect(i.brand == "Uniqlo")
        #expect(i.revision == oldRevision)
        #expect(!ctx.hasChanges)              // 失败变更不再滞留
    }

    /// CM-2: transfer save 失败须 rollback——还原字段值之外脏标记也不得滞留。
    @Test(.serialized) func transferSaveFailureRollsBackContext() throws {
        let ctx = try makeContext()
        let a = Wardrobe(name: "A"); ctx.insert(a)
        let b = Wardrobe(name: "B"); ctx.insert(b)
        let i = Item(name: "tee"); i.wardrobe = a; ctx.insert(i)
        try ctx.save()
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        #expect(!TransferService.transfer(i, to: b, in: ctx))
        #expect(i.wardrobe?.id == a.id)       // 内存值已还原
        #expect(!ctx.hasChanges)              // 失败变更不再滞留
    }

    /// CM-2: locationAssign save 失败须 rollback——与 transfer 同款。
    @Test(.serialized) func locationAssignSaveFailureRollsBackContext() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let loc = StorageLocationService.create(name: "Rod", in: w, context: ctx)
        let i = Item(name: "tee"); i.wardrobe = w; ctx.insert(i)
        try ctx.save()
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        #expect(!StorageLocationService.assign(i, to: loc, in: ctx))
        #expect(i.location == nil)            // 内存值已还原
        #expect(!ctx.hasChanges)              // 失败变更不再滞留
    }

    /// M4: 位置或单品任一侧无衣柜归属（nil）也须阻断，不得静默放行。
    @Test func orphanLocationAssignBlocked() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let orphan = StorageLocation(name: "orphan"); ctx.insert(orphan)   // 无衣柜归属
        let i = Item(name: "x"); i.wardrobe = w; ctx.insert(i)
        try ctx.save()
        #expect(!StorageLocationService.assign(i, to: orphan, in: ctx))
        #expect(i.location == nil)
        // 同柜正常 assign 与解绑（nil 目标 = 清除位置）不受影响
        let loc = StorageLocationService.create(name: "Rod", in: w, context: ctx)
        #expect(StorageLocationService.assign(i, to: loc, in: ctx))
        #expect(StorageLocationService.assign(i, to: nil, in: ctx))
        #expect(i.location == nil)
    }
}
