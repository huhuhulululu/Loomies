import Testing
import SwiftData
import Foundation
@testable import ClosetModel
import ClosetCore

/// Model-lane gap fixes: transfer 位置清理、整柜删除级联计划、打卡同柜守卫、收藏单次提交。
@MainActor
struct ModelLaneGapFixesTests {

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    /// CM-1: 转移必须清空位置——源柜 StorageLocation 不得跟随单品进目标柜。
    @Test func transferClearsLocation() throws {
        let ctx = try makeContext()
        let a = Wardrobe(name: "A"); ctx.insert(a)
        let b = Wardrobe(name: "B"); ctx.insert(b)
        let loc = StorageLocationService.create(name: "Rod", in: a, context: ctx)
        let i = Item(name: "tee"); i.wardrobe = a; ctx.insert(i)
        #expect(StorageLocationService.assign(i, to: loc, in: ctx))
        #expect(TransferService.transfer(i, to: b, in: ctx))
        #expect(i.wardrobe?.id == b.id)
        #expect(i.location == nil)   // 同柜不变量：位置不跨柜
    }

    /// CM-1: transfer save 失败须还原位置 + rollback——脏标记不得滞留。
    @Test(.serialized) func transferSaveFailureRestoresLocationAndRollsBack() throws {
        let ctx = try makeContext()
        let a = Wardrobe(name: "A"); ctx.insert(a)
        let b = Wardrobe(name: "B"); ctx.insert(b)
        let loc = StorageLocationService.create(name: "Rod", in: a, context: ctx)
        let i = Item(name: "tee"); i.wardrobe = a; ctx.insert(i)
        #expect(StorageLocationService.assign(i, to: loc, in: ctx))
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        #expect(!TransferService.transfer(i, to: b, in: ctx))
        #expect(i.wardrobe?.id == a.id)      // 内存值已还原
        #expect(i.location?.id == loc?.id)   // 位置一并还原
        #expect(!ctx.hasChanges)             // 失败变更不再滞留
    }

    /// CM-2: force 整柜删除须级联删除绑定本柜搭配的 CalendarPlan——不留孤儿计划。
    @Test func forceDeleteWardrobeDeletesBoundCalendarPlans() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let other = Wardrobe(name: "B"); ctx.insert(other)
        let i = Item(name: "tee"); i.wardrobe = w; ctx.insert(i)
        let j = Item(name: "shoe"); j.wardrobe = other; ctx.insert(j)
        let bound = try OutfitDraftService.create(name: "look", items: [i], in: w, context: ctx)
        let unbound = try OutfitDraftService.create(name: "other look", items: [j], in: other, context: ctx)
        let boundPlan = CalendarPlanService.plan(outfit: bound, on: Date(timeIntervalSince1970: 1_700_000_000), in: ctx)
        let unboundPlan = CalendarPlanService.plan(outfit: unbound, on: Date(timeIntervalSince1970: 1_700_086_400), in: ctx)
        #expect(boundPlan != nil && unboundPlan != nil)

        try DeleteService.deleteWardrobe(w, force: true, in: ctx)
        let plans = try ctx.fetch(FetchDescriptor<CalendarPlan>())
        #expect(plans.count == 1)                          // 绑定计划已删，他柜计划保留
        #expect(plans.first?.outfit?.id == unbound.id)
        #expect(CalendarPlanService.attentionPlans(in: ctx).isEmpty)
    }

    /// CM-3: 打卡只记本柜单品——外柜件不得计入本柜快照。
    @Test func recordWearExcludesForeignItems() throws {
        let ctx = try makeContext()
        let a = Wardrobe(name: "A"); ctx.insert(a)
        let b = Wardrobe(name: "B"); ctx.insert(b)
        let local = Item(name: "tee"); local.wardrobe = a; ctx.insert(local)
        let foreign = Item(name: "coat"); foreign.wardrobe = b; ctx.insert(foreign)
        try ctx.save()

        let rec = CheckInService.recordWear(
            items: [local, foreign], on: Date(timeIntervalSince1970: 1_700_000_000), in: a, in: ctx)
        #expect(rec != nil)
        #expect(rec!.wornItemIDs == [local.id.uuidString])   // 外柜件被过滤
        #expect(rec!.wardrobeSnapshotID == a.id)

        // 全部外柜 → 走空选择守卫，不落零件记录。
        let rec2 = CheckInService.recordWear(
            items: [foreign], on: Date(timeIntervalSince1970: 1_700_086_400), in: a, in: ctx)
        #expect(rec2 == nil)
        #expect(try ctx.fetch(FetchDescriptor<WearRecord>()).count == 1)
    }

    /// CM-4: 收藏落库单次提交——save 失败不得残留非收藏 outfit。
    @Test(.serialized) func saveFavoriteSaveFailurePersistsNoOutfit() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let t = Item(name: "t"); t.wardrobe = w; ctx.insert(t)
        try ctx.save()
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        #expect(throws: OutfitDraftError.saveFailed) {
            try OutfitFavoriteService.saveFavorite(
                name: "look", itemIDs: [t.id.uuidString], occasion: "work", in: w, context: ctx)
        }
        #expect(try ctx.fetch(FetchDescriptor<ClosetModel.Outfit>()).isEmpty)   // 失败即零残留
        #expect(!ctx.hasChanges)                  // 脏标记不滞留
        #expect((t.outfits ?? []).isEmpty)        // 锚点单品无幻影搭配
    }

    /// CM-R1: 跨柜拒绝路径（含 WardrobeInvariant 守卫契约）——拒绝后不得滞留
    /// 脏标记，锚点单品的内存 outfits 不得残留幻影搭配。
    @Test(.serialized) func crossWardrobeRejectLeavesNoDirtyMarkerOrPhantom() throws {
        let ctx = try makeContext()
        let a = Wardrobe(name: "A"); ctx.insert(a)
        let b = Wardrobe(name: "B"); ctx.insert(b)
        let anchor = Item(name: "tee"); anchor.wardrobe = a; ctx.insert(anchor)
        let foreign = Item(name: "foreign"); foreign.wardrobe = b; ctx.insert(foreign)
        try ctx.save()
        #expect(throws: OutfitDraftError.self) {
            try OutfitDraftService.create(name: "look", items: [anchor, foreign], in: a, context: ctx)
        }
        #expect(try ctx.fetch(FetchDescriptor<ClosetModel.Outfit>()).isEmpty)   // 拒绝即零落库
        #expect(!ctx.hasChanges)                       // 脏标记不滞留
        #expect((anchor.outfits ?? []).isEmpty)        // 锚点单品无幻影搭配
        #expect((a.outfits ?? []).isEmpty)             // 目标柜无幻影搭配
    }

    /// CM-A: deleteItem 中途不得 save——forceFailure 下失败的 deleteItem 不得
    /// 残留 permanentlyMissing / 脏标记；单品仍在。
    @Test(.serialized) func deleteItemSaveFailureCommitsNoIntermediateState() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "tee"); i.wardrobe = w; ctx.insert(i)
        let o = Outfit(name: "look"); o.wardrobe = w; o.items = [i]; ctx.insert(o)
        try ctx.save()
        let plan = CalendarPlanService.plan(outfit: o, on: Date(timeIntervalSince1970: 1_700_000_000), in: ctx)
        #expect(plan != nil)
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        #expect(!DeleteService.deleteItem(i, in: ctx))
        #expect(o.permanentlyMissing == false)   // 未提前提交
        #expect(plan?.needsAttention == false)
        #expect(!ctx.hasChanges)                 // 无滞留脏标记
        #expect(try ctx.fetch(FetchDescriptor<Item>()).count == 1)
    }

    /// CM-A: 成功路径仍单次提交 attention——绑定计划 needsAttention 随删件落库。
    @Test func deleteItemFlagsBoundPlanAttention() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "tee"); i.wardrobe = w; ctx.insert(i)
        let o = Outfit(name: "look"); o.wardrobe = w; o.items = [i]; ctx.insert(o)
        try ctx.save()
        let plan = CalendarPlanService.plan(outfit: o, on: Date(timeIntervalSince1970: 1_700_000_000), in: ctx)
        #expect(plan != nil && plan?.needsAttention == false)
        #expect(DeleteService.deleteItem(i, in: ctx))
        #expect(plan?.needsAttention == true)
        #expect(o.permanentlyMissing == true)
    }

    /// CM-B: 删人须同 save 删除其 PersonBodyProfile——最敏感数据不得残留。
    @Test func deletePersonDeletesBodyProfile() throws {
        let ctx = try makeContext()
        let p = Person(name: "me"); ctx.insert(p)
        let profile = PersonBodyProfile(personID: p.id); ctx.insert(profile)
        try ctx.save()
        try DeleteService.deletePerson(p, in: ctx)
        #expect(try ctx.fetch(FetchDescriptor<Person>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<PersonBodyProfile>()).isEmpty)
    }

    /// CM-B: deletePerson save 失败 → profile 与人一并回滚，无滞留。
    @Test(.serialized) func deletePersonSaveFailureKeepsBodyProfile() throws {
        let ctx = try makeContext()
        let p = Person(name: "me"); ctx.insert(p)
        let profile = PersonBodyProfile(personID: p.id); ctx.insert(profile)
        try ctx.save()
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        #expect(throws: DeleteError.saveFailed) {
            try DeleteService.deletePerson(p, in: ctx)
        }
        #expect(!ctx.hasChanges)
        #expect(try ctx.fetch(FetchDescriptor<Person>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<PersonBodyProfile>()).count == 1)
    }

    /// CM-C: force 整柜删除须清理单品本地图文件——不留孤儿照片。
    @Test(.serialized) func forceDeleteWardrobeDeletesItemImageFiles() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "tee"); i.wardrobe = w; ctx.insert(i)
        let rel = ItemImageStore.save(data: Data([1, 2, 3, 4]), for: i.id)
        #expect(rel != nil)
        i.localImageRelativePath = rel
        try ctx.save()
        let url = ItemImageStore.absoluteURL(relativePath: rel)
        #expect(url != nil)
        #expect(FileManager.default.fileExists(atPath: url!.path))
        defer { ItemImageStore.delete(relativePath: rel) }   // 兜底清理
        try DeleteService.deleteWardrobe(w, force: true, in: ctx)
        #expect(!FileManager.default.fileExists(atPath: url!.path))   // 文件已删
    }

    /// CM-D: setFavorite save 失败 → 内存还原 + context rollback，脏标记不滞留。
    @Test(.serialized) func setFavoriteSaveFailureRollsBackContext() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let t = Item(name: "t"); t.wardrobe = w; ctx.insert(t)
        let o = try OutfitDraftService.create(name: "look", items: [t], in: w, context: ctx)
        #expect(!o.isFavorite)
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        #expect(!OutfitFavoriteService.setFavorite(o, true, in: ctx))
        #expect(!o.isFavorite)      // 内存值已还原
        #expect(!ctx.hasChanges)    // 脏标记不滞留
    }

    /// CM-D: calendarPlan save 失败（新建 + 覆盖两路）→ context rollback。
    @Test(.serialized) func calendarPlanSaveFailureRollsBackContext() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let t = Item(name: "t"); t.wardrobe = w; ctx.insert(t)
        let o = try OutfitDraftService.create(name: "look", items: [t], in: w, context: ctx)
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        // 新建路径
        #expect(CalendarPlanService.plan(outfit: o, on: day, in: ctx) == nil)
        #expect(!ctx.hasChanges)
        #expect(try ctx.fetch(FetchDescriptor<CalendarPlan>()).isEmpty)   // pending insert 已丢弃
        ModelSave.clearForcedFailure(on: ctx)
        let existing = CalendarPlanService.plan(outfit: o, on: day, in: ctx)
        #expect(existing != nil)
        let o2 = try OutfitDraftService.create(name: "look2", items: [t], in: w, context: ctx)
        ModelSave.forceFailure(on: ctx)
        // 覆盖路径：outfit 还原 + rollback
        #expect(CalendarPlanService.plan(outfit: o2, on: day, in: ctx) == nil)
        #expect(existing?.outfit?.id == o.id)
        #expect(!ctx.hasChanges)
    }

    /// CM-E: create 拒绝跨柜父节点（与 assign 同守卫）。
    @Test func createLocationRejectsCrossWardrobeParent() throws {
        let ctx = try makeContext()
        let a = Wardrobe(name: "A"); ctx.insert(a)
        let b = Wardrobe(name: "B"); ctx.insert(b)
        let parent = StorageLocationService.create(name: "Rod", in: a, context: ctx)
        #expect(parent != nil)
        let child = StorageLocationService.create(name: "Drawer", in: b, parent: parent, context: ctx)
        #expect(child == nil)   // 跨柜父节点被拒
        #expect(try ctx.fetch(FetchDescriptor<StorageLocation>()).count == 1)
        // 同柜父节点仍放行
        let ok = StorageLocationService.create(name: "Drawer", in: a, parent: parent, context: ctx)
        #expect(ok != nil)
        #expect(ok?.parent?.id == parent?.id)
    }

    /// CM-F: 垃圾测值（0 宽 / 0 围）不得出自信判定——'缺任一测值 → nil' 契约覆盖非正值。
    @Test func fitMarkNilOnZeroMeasures() {
        let profile = PersonBodyProfile(personID: UUID())
        profile.bustInches = 34; profile.waistInches = 28

        // 平铺宽 0 → nil（而非 ease=−body 的 .tight）
        let zeroFlatTop = Item(name: "tee"); zeroFlatTop.slotRaw = "top"; zeroFlatTop.chestFlatWidthInches = 0
        #expect(FitMarkService.mark(item: zeroFlatTop, profile: profile) == nil)
        let zeroFlatBottom = Item(name: "pants"); zeroFlatBottom.slotRaw = "bottom"; zeroFlatBottom.waistFlatWidthInches = 0
        #expect(FitMarkService.mark(item: zeroFlatBottom, profile: profile) == nil)

        // 身体围 0 → nil（而非巨大 ease 的 .loose）
        let zeroBust = PersonBodyProfile(personID: UUID()); zeroBust.bustInches = 0
        let tee = Item(name: "tee"); tee.slotRaw = "top"; tee.chestFlatWidthInches = 18
        #expect(FitMarkService.mark(item: tee, profile: zeroBust) == nil)
        let zeroWaist = PersonBodyProfile(personID: UUID()); zeroWaist.waistInches = 0
        let pants = Item(name: "pants"); pants.slotRaw = "bottom"; pants.waistFlatWidthInches = 14
        #expect(FitMarkService.mark(item: pants, profile: zeroWaist) == nil)

        // 正常值仍出判定（守卫不误伤）
        #expect(FitMarkService.mark(item: tee, profile: profile) == .fitted)
    }

    /// CM-G: 三围 + 推断上臀 + 手选覆盖 → provisional 优先于 mixed（上臀只是估计）。
    @Test func resolveSourceProvisionalWinsOverMixed() {
        let p = PersonBodyProfile(personID: UUID())
        p.bustInches = 34; p.waistInches = 28; p.hipInches = 38
        p.highHipInches = BodyProfileService.inferHighHip(waist: 28, hip: 38)
        p.highHipInferred = true
        p.popularShapeOverrideRaw = PopularShape.hourglass.rawValue
        #expect(BodyProfileService.resolveSource(p) == .provisional)
        #expect(BodyProfileService.confidence(for: p) == .provisional)
        #expect(BodyProfileService.styleWeightFactor(for: p) == 0.85)
        // 上臀实测 + 覆盖 → 仍 mixed
        p.highHipInferred = false
        #expect(BodyProfileService.resolveSource(p) == .mixed)
        // 无覆盖 + 推断上臀 → provisional（原行为不变）
        p.highHipInferred = true
        p.popularShapeOverrideRaw = nil
        #expect(BodyProfileService.resolveSource(p) == .provisional)
    }

    /// CM-H: 非法 warmthRaw 须整体拒绝——不改任何字段，不落库，脏标记不滞留。
    @Test func applyRejectsInvalidWarmthRaw() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "coat"); i.wardrobe = w; i.warmthRaw = 4; ctx.insert(i)
        try ctx.save()
        let rev = i.revision
        #expect(!ItemEditorService.apply(.init(name: "renamed", warmthRaw: 0), to: i, in: ctx))
        #expect(i.warmthRaw == 4)          // 未改
        #expect(i.name == "coat")          // 无部分 mutation
        #expect(i.revision == rev)
        #expect(!ctx.hasChanges)
        #expect(!ItemEditorService.apply(.init(warmthRaw: 99), to: i, in: ctx))
        #expect(i.warmthRaw == 4)
        // 合法值仍放行
        #expect(ItemEditorService.apply(.init(warmthRaw: 2), to: i, in: ctx))
        #expect(i.warmthRaw == 2)
    }

    /// CM-I: 同名 DTO 按 id 决胜——导出快照可复现，与抓取顺序无关。
    @Test func exportSortsSameNameItemsByID() throws {
        let ctx = try makeContext()
        let a = Item(name: "tee"); ctx.insert(a)
        let b = Item(name: "tee"); ctx.insert(b)
        let c = Item(name: "coat"); ctx.insert(c)
        try ctx.save()
        let snap = try DataLifecycleService.exportSnapshot(in: ctx)
        let teeIDs = snap.items.filter { $0.name == "tee" }.map(\.id)
        #expect(teeIDs == [a.id.uuidString, b.id.uuidString].sorted())
        // 全列表有序：(name, id) 单调
        let keys = snap.items.map { "\($0.name)|\($0.id)" }
        #expect(keys == keys.sorted())
    }

    /// CM-P1: 打卡 save 失败 → 返回 nil、不落 WearRecord、脏标记不滞留。
    @Test(.serialized) func recordWearSaveFailureLeavesNoResidue() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let i = Item(name: "tee"); i.wardrobe = w; ctx.insert(i)
        try ctx.save()
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        #expect(CheckInService.recordWear(
            items: [i], on: Date(timeIntervalSince1970: 1_700_000_000), in: w, in: ctx) == nil)
        #expect(try ctx.fetch(FetchDescriptor<WearRecord>()).isEmpty)   // 失败即零残留
        #expect(!ctx.hasChanges)                                        // 脏标记不滞留
    }

    /// CM-P2: demoSeed save 失败 → .saveFailed、零残留单品、脏标记不滞留，
    /// 且失败前已写盘的剪影 PNG 必须从 ItemImageStore 删除——不留孤儿文件。
    @Test(.serialized) func seedSaveFailureDeletesSilhouetteFilesAndLeavesNoResidue() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        try ctx.save()
        let fm = FileManager.default
        let root = ItemImageStore.rootDirectory
        let before = Set((try? fm.contentsOfDirectory(atPath: root.path)) ?? [])
            .filter { $0.hasSuffix(".png") }
        defer {
            // 兜底清理：失败路径应已删图；若源码泄漏则在此移除，不污染共享目录
            let now = Set((try? fm.contentsOfDirectory(atPath: root.path)) ?? [])
            for name in now.subtracting(before) where name.hasSuffix(".png") {
                try? fm.removeItem(at: root.appendingPathComponent(name))
            }
        }
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        #expect(DemoSeedService.seed(w, in: ctx) == .saveFailed)
        #expect(try ctx.fetch(FetchDescriptor<Item>()).isEmpty)   // 失败即零残留
        #expect(!ctx.hasChanges)                                  // 脏标记不滞留
        let after = Set((try? fm.contentsOfDirectory(atPath: root.path)) ?? [])
            .filter { $0.hasSuffix(".png") }
        #expect(after.subtracting(before).isEmpty)   // 写盘剪影已随失败删除
    }

    /// CM-P2b: 剪影写盘失败（ItemImageStore.forceFailure）不得阻断 seed——
    /// 单品仍入库、仅无本地图。首个 exercise 此 hook 的测试。
    @Test(.serialized) func seedSucceedsWhenImageStoreFails() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        try ctx.save()
        ItemImageStore.forceFailure(true)
        defer { ItemImageStore.forceFailure(false) }
        #expect(DemoSeedService.seed(w, in: ctx) == .added(9))
        #expect(try ctx.fetch(FetchDescriptor<Item>()).count == 9)
        #expect((w.items ?? []).allSatisfy { $0.localImageRelativePath == nil })
    }

    /// CM-P3: location create save 失败 → 返回 nil、不落 StorageLocation、脏标记不滞留。
    @Test(.serialized) func createLocationSaveFailureLeavesNoResidue() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        try ctx.save()
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        #expect(StorageLocationService.create(name: "Rod", in: w, context: ctx) == nil)
        #expect(try ctx.fetch(FetchDescriptor<StorageLocation>()).isEmpty)
        #expect(!ctx.hasChanges)
    }

    /// CM-P4: calendarRemove save 失败 → 返回 false、计划仍在、脏标记不滞留。
    @Test(.serialized) func removePlanSaveFailureKeepsPlanAndRollsBack() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let t = Item(name: "t"); t.wardrobe = w; ctx.insert(t)
        let o = try OutfitDraftService.create(name: "look", items: [t], in: w, context: ctx)
        let plan = CalendarPlanService.plan(
            outfit: o, on: Date(timeIntervalSince1970: 1_700_000_000), in: ctx)
        #expect(plan != nil)
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        #expect(!CalendarPlanService.remove(plan!, in: ctx))
        #expect(try ctx.fetch(FetchDescriptor<CalendarPlan>()).count == 1)   // 计划仍在
        #expect(!ctx.hasChanges)                                             // 脏标记不滞留
    }

    /// CM-deleteLocation: deleteLocation save 失败 → 返回 false、内存指针还原
    ///（item/child 仍指向被删位置）、脏标记不滞留，后续无关 save 不得提交失败删除。
    @Test(.serialized) func deleteLocationSaveFailureRestoresPointersAndRollsBack() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "A"); ctx.insert(w)
        let parent = StorageLocationService.create(name: "Closet", in: w, context: ctx)
        let loc = StorageLocationService.create(name: "Shelf", in: w, parent: parent, context: ctx)
        let child = StorageLocationService.create(name: "Box", in: w, parent: loc, context: ctx)
        #expect(parent != nil && loc != nil && child != nil)
        let i = Item(name: "tee"); i.wardrobe = w; ctx.insert(i)
        #expect(StorageLocationService.assign(i, to: loc, in: ctx))

        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        #expect(!DeleteService.deleteLocation(loc!, in: ctx))
        #expect(i.location?.id == loc?.id)       // 内存指针已还原（未滞留提升至父）
        #expect(child?.parent?.id == loc?.id)    // 子位置一并还原
        #expect(!ctx.hasChanges)                 // 脏标记不滞留

        // 后续无关 save 不得提交失败的删除/提升
        ModelSave.clearForcedFailure(on: ctx)
        i.revision += 1
        #expect(ModelSave.save(ctx, label: "unrelatedAfterFailedDeleteLocation"))
        #expect(try ctx.fetch(FetchDescriptor<StorageLocation>()).count == 3)   // 位置仍在
        #expect(i.location?.id == loc?.id)
        #expect(child?.parent?.id == loc?.id)
    }

    /// CM-N2: 同刻 WearRecord / CalendarPlan 按 id 决胜——
    /// sorted 非稳定排序，仅按日期串比较时相对顺序未定义。
    @Test func exportSortsSameTimestampRecordsByID() throws {
        let ctx = try makeContext()
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let w1 = WearRecord(date: day); ctx.insert(w1)
        let w2 = WearRecord(date: day); ctx.insert(w2)
        let p1 = CalendarPlan(date: day); ctx.insert(p1)
        let p2 = CalendarPlan(date: day); ctx.insert(p2)
        try ctx.save()
        let snap = try DataLifecycleService.exportSnapshot(in: ctx)
        #expect(snap.wearRecords.map(\.id) == [w1.id.uuidString, w2.id.uuidString].sorted())
        #expect(snap.plans.map(\.id) == [p1.id.uuidString, p2.id.uuidString].sorted())
        // 全列表有序：(date, id) 单调
        let wearKeys = snap.wearRecords.map { "\($0.date)|\($0.id)" }
        #expect(wearKeys == wearKeys.sorted())
        let planKeys = snap.plans.map { "\($0.date)|\($0.id)" }
        #expect(planKeys == planKeys.sorted())
    }
}
