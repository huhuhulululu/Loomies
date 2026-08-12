import Testing
import SwiftData
import Foundation
@testable import ClosetModel

/// D112：`.serialized` 是 **suite / 参数化用例** 的 trait；
/// 挂在非参数化的单个 `@Test` 上**什么都不做**（全仓曾有 25 处这样的写法，
/// 于是「这里安全因为串行」的说法全是假的）。本套用进程级钩子
///（`ItemImageStore.forceFailure` / 共享图片根），必须真的串行。
@Suite(.serialized)
@MainActor
struct DeleteServiceTests {
    init() { ItemImageTestRoot.install() }   // 触盘套件：根目录按进程隔离，勿写真机目录


    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    @Test func deleteWardrobeBlockedWhenHasItems() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "x"); i.wardrobe = w; ctx.insert(i)
        try ctx.save()
        #expect(throws: DeleteError.wardrobeNotEmpty) {
            try DeleteService.deleteWardrobe(w, force: false, in: ctx)
        }
    }

    @Test func deleteWardrobeForceCascadesButKeepsWearRecords() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "x"); i.wardrobe = w; ctx.insert(i)
        let wr = WearRecord(date: Date(timeIntervalSince1970: 1_700_000_000)); ctx.insert(wr)
        try ctx.save()
        try DeleteService.deleteWardrobe(w, force: true, in: ctx)
        #expect(try ctx.fetch(FetchDescriptor<Wardrobe>()).isEmpty)   // 衣柜删
        #expect(try ctx.fetch(FetchDescriptor<Item>()).isEmpty)       // 单品级联删
        #expect(try ctx.fetch(FetchDescriptor<WearRecord>()).count == 1) // WearRecord 保留
    }

    @Test func deletePersonBlockedWhenHasWardrobes() throws {
        let ctx = try makeContext()
        let p = Person(name: "me"); ctx.insert(p)
        let w = Wardrobe(name: "A"); w.owner = p; ctx.insert(w)
        try ctx.save()
        #expect(throws: DeleteError.personHasWardrobes) {
            try DeleteService.deletePerson(p, in: ctx)
        }
    }

    @Test func deletePersonSucceedsWhenNoWardrobes() throws {
        let ctx = try makeContext()
        let p = Person(name: "solo"); ctx.insert(p)
        try ctx.save()
        try DeleteService.deletePerson(p, in: ctx)
        #expect(try ctx.fetch(FetchDescriptor<Person>()).isEmpty)
    }

    /// Delete errors must be customer-facing (no silent success / raw enum).
    @Test func deleteErrorsHaveCustomerFacingCopy() {
        for err in [DeleteError.wardrobeNotEmpty, .personHasWardrobes, .saveFailed] {
            let desc = err.errorDescription ?? ""
            #expect(!desc.isEmpty)
            #expect(!desc.contains("DeleteError"))
            #expect(desc.first?.isUppercase == true)
        }
        #expect(DeleteError.saveFailed.errorDescription?
            .localizedCaseInsensitiveContains("couldn't delete") == true)
        #expect(DeleteError.saveFailed.errorDescription?
            .localizedCaseInsensitiveContains("try again") == true)
        #expect(DeleteError.wardrobeNotEmpty.errorDescription?
            .localizedCaseInsensitiveContains("pieces") == true)
        #expect(DeleteError.personHasWardrobes.errorDescription?
            .localizedCaseInsensitiveContains("closets") == true)
    }

    @Test func deleteItemMarksOutfitPermanentlyMissing() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "x"); i.wardrobe = w; ctx.insert(i)
        let o = Outfit(name: "look"); o.wardrobe = w; o.items = [i]; ctx.insert(o)
        try ctx.save()
        let ok = DeleteService.deleteItem(i, in: ctx)
        #expect(ok) // ModelSave committed (no silent try?)
        #expect(o.permanentlyMissing == true)
        #expect(try ctx.fetch(FetchDescriptor<Item>()).isEmpty)
    }

    @Test func deleteLocationPromotesItemsToParent() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let parent = StorageLocation(name: "closet"); parent.wardrobe = w; ctx.insert(parent)
        let child = StorageLocation(name: "drawer"); child.wardrobe = w; child.parent = parent; ctx.insert(child)
        let i = Item(name: "x"); i.wardrobe = w; i.location = child; ctx.insert(i)
        try ctx.save()
        let ok = DeleteService.deleteLocation(child, in: ctx)
        #expect(ok)
        #expect(i.location?.id == parent.id)   // 位置提升至父节点
    }

    /// M2: save 失败必须 rollback——pending delete 不得滞留污染下一次无关 save。
    /// 整柜级联删（force）同时删成员图；save 失败保留文件（行未删，删图即反向孤儿）。
    /// 此路径此前零测试覆盖——将来接 UI 时的回归高危区。
    @Test func deleteWardrobeForceRemovesMemberImagesKeepsOnFailure() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "tee"); i.slotRaw = "top"; i.wardrobe = w; ctx.insert(i)
        let rel = ItemImageStore.save(data: Data([0x1]), for: i.id, ext: "jpg")
        i.localImageRelativePath = rel
        try ctx.save()

        ModelSave.forceFailure(on: ctx)
        #expect(throws: DeleteError.saveFailed) {
            try DeleteService.deleteWardrobe(w, force: true, in: ctx)
        }
        #expect(ItemImageStore.loadData(relativePath: rel) != nil)
        ModelSave.clearForcedFailure(on: ctx)

        try DeleteService.deleteWardrobe(w, force: true, in: ctx)
        #expect(ItemImageStore.loadData(relativePath: rel) == nil)
        #expect(try ctx.fetch(FetchDescriptor<Item>()).isEmpty)
    }

    /// 删除单品同时删本地图（与 deleteWardrobe 同责任模型）；save 失败保留文件可重试。
    @Test func deleteItemRemovesLocalImageOnCommitKeepsOnFailure() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "tee"); i.slotRaw = "top"; i.wardrobe = w; ctx.insert(i)
        let rel = ItemImageStore.save(data: Data([0xFF, 0xD8, 0xFF]), for: i.id, ext: "jpg")
        i.localImageRelativePath = rel
        try ctx.save()
        #expect(ItemImageStore.loadData(relativePath: rel) != nil)

        // 失败路径：文件保留（DB 行还在，删图会产生反向孤儿）
        ModelSave.forceFailure(on: ctx)
        #expect(!DeleteService.deleteItem(i, in: ctx))
        #expect(ItemImageStore.loadData(relativePath: rel) != nil)
        ModelSave.clearForcedFailure(on: ctx)

        // 成功路径：文件一并删除（不留孤儿）
        #expect(DeleteService.deleteItem(i, in: ctx))
        #expect(ItemImageStore.loadData(relativePath: rel) == nil)
    }

    @Test func deleteItemSaveFailureRollsBackPendingDelete() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "x"); i.wardrobe = w; ctx.insert(i)
        try ctx.save()
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        #expect(!DeleteService.deleteItem(i, in: ctx))
        #expect(!ctx.hasChanges)   // pending delete 已回滚
        #expect(try ctx.fetch(FetchDescriptor<Item>()).count == 1)
        // 后续无关 save 不会再静默提交那次失败的删除
        ModelSave.clearForcedFailure(on: ctx)
        #expect(ModelSave.save(ctx, label: "unrelated"))
        #expect(try ctx.fetch(FetchDescriptor<Item>()).count == 1)
    }
}

/// D103（审计 MEDIUM，实为数据损坏）：删一个衣柜会**静默残害别柜的搭配**。
/// 删柜会级联删掉它的 Item，而**转移进来**的那些 Item 仍然是**原柜**某些 Outfit 的成员
/// （`TransferService.transfer` 只改 `item.wardrobe`，不动 `outfit.items`）。
/// 于是别柜的搭配悄悄少了一件，既没标 `permanentlyMissing`，日历也没重算——
/// 而同文件的 `deleteItem` 早就把这件事做对了。
@MainActor
struct DeleteWardrobeCrossClosetTests {

    func setup() throws -> (ModelContext, Wardrobe, Wardrobe) {
        let ctx = try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
        let home = Wardrobe(name: "Home"); ctx.insert(home)
        let lake = Wardrobe(name: "Lake"); ctx.insert(lake)
        try ctx.save()
        return (ctx, home, lake)
    }

    /// 别柜的搭配引用了被级联删掉的件 → 必须标 permanentlyMissing，不得静默少一件。
    @Test func outfitsInOtherClosetsAreMarkedNotSilentlyThinned() throws {
        let (ctx, home, lake) = try setup()
        // Home 的搭配用了两件 Home 的衣服
        let shirt = Item(name: "Shirt"); shirt.slotRaw = "top"; shirt.wardrobe = home
        let pants = Item(name: "Pants"); pants.slotRaw = "bottom"; pants.wardrobe = home
        ctx.insert(shirt); ctx.insert(pants)
        let homeLook = Outfit(name: "Home look"); homeLook.wardrobe = home
        homeLook.items = [shirt, pants]
        ctx.insert(homeLook)
        try ctx.save()

        // 把 shirt 转到 Lake：它仍是 Home 那套搭配的成员（转移只改归属）
        #expect(TransferService.transfer(shirt, to: lake, in: ctx))
        #expect((homeLook.items ?? []).contains { $0.id == shirt.id })

        // 删掉 Lake → shirt 被级联删除
        try DeleteService.deleteWardrobe(lake, force: true, in: ctx)

        let survivors = try ctx.fetch(FetchDescriptor<Outfit>())
        let look = try #require(survivors.first { $0.id == homeLook.id })
        #expect(look.permanentlyMissing,
                "别柜的搭配被抽走一件却没标记——用户会看到一套悄悄少件的搭配")
    }

    /// 日历上引用该搭配的计划要跟着重算 attention（与 deleteItem 同纪律）。
    @Test func calendarPlansOfAffectedOutfitsAreRecomputed() throws {
        let (ctx, home, lake) = try setup()
        let shirt = Item(name: "Shirt"); shirt.slotRaw = "top"; shirt.wardrobe = home
        ctx.insert(shirt)
        let look = Outfit(name: "Look"); look.wardrobe = home; look.items = [shirt]
        ctx.insert(look)
        let plan = CalendarPlan(date: Date()); plan.outfit = look
        ctx.insert(plan)
        try ctx.save()

        #expect(TransferService.transfer(shirt, to: lake, in: ctx))
        try DeleteService.deleteWardrobe(lake, force: true, in: ctx)

        let plans = try ctx.fetch(FetchDescriptor<CalendarPlan>())
        let p = try #require(plans.first { $0.id == plan.id })
        #expect(p.needsAttention, "计划仍指向一套缺件的搭配，却没标 attention")
    }

    /// 保存失败时标记要还原（不得留下「以为缺件」的假状态）。
    @Test func saveFailureRestoresTheMarks() throws {
        let (ctx, home, lake) = try setup()
        let shirt = Item(name: "Shirt"); shirt.slotRaw = "top"; shirt.wardrobe = home
        ctx.insert(shirt)
        let look = Outfit(name: "Look"); look.wardrobe = home; look.items = [shirt]
        ctx.insert(look)
        try ctx.save()
        #expect(TransferService.transfer(shirt, to: lake, in: ctx))

        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        #expect(throws: (any Error).self) {
            try DeleteService.deleteWardrobe(lake, force: true, in: ctx)
        }
        #expect(!look.permanentlyMissing)
        #expect(!ctx.hasChanges)
    }
}
