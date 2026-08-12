import Testing
import SwiftData
import Foundation
@testable import ClosetUI
@testable import ClosetModel
import ClosetCore

/// D85 零 UI 入口波 A：删衣柜 / 删人。服务层（DeleteService）早就就绪且带级联测试，
/// 但全仓零 View 调用点——用户根本删不掉衣柜或人。
@MainActor
struct WardrobeDeleteActionsTests {
    init() { ItemImageTestRoot.install() }

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    @Test func emptyClosetDeletesDirectly() throws {
        let ctx = try makeContext()
        let p = Person(name: "Ada"); ctx.insert(p)
        let w = Wardrobe(name: "Spare"); w.owner = p; ctx.insert(w)
        try ctx.save()
        let out = WardrobeManageActions.delete(w, force: false, in: ctx)
        #expect(out.deleted)
        #expect(!out.isFailure)
        #expect(out.blockedReason == nil)
        #expect(try ctx.fetch(FetchDescriptor<Wardrobe>()).isEmpty)
    }

    /// 非空柜阻断必须带**类型化**原因——View 靠它升级到二段确认，
    /// 不得靠 message 字符串相等（润色文案就会静默失效且无测试会红）。
    @Test func nonEmptyClosetBlocksWithTypedReason() throws {
        let ctx = try makeContext()
        let p = Person(name: "Ada"); ctx.insert(p)
        let w = Wardrobe(name: "Main"); w.owner = p; ctx.insert(w)
        let i = Item(name: "tee"); i.slotRaw = "top"; i.wardrobe = w; ctx.insert(i)
        try ctx.save()
        let out = WardrobeManageActions.delete(w, force: false, in: ctx)
        #expect(!out.deleted)
        #expect(out.isFailure)
        #expect(out.blockedReason == .wardrobeNotEmpty)
        #expect(out.message == DeleteError.wardrobeNotEmpty.errorDescription)
        #expect(try ctx.fetch(FetchDescriptor<Wardrobe>()).count == 1)
    }

    /// force 删除会连带删日历计划——警告文案必须告知（不得声称做了没做的事的镜像面：
    /// 也不得隐瞒做了的事）。
    @Test func forceDeleteCascadesPlansAndWarningSaysSo() throws {
        let ctx = try makeContext()
        let p = Person(name: "Ada"); ctx.insert(p)
        let w = Wardrobe(name: "Main"); w.owner = p; ctx.insert(w)
        let i = Item(name: "tee"); i.slotRaw = "top"; i.wardrobe = w; ctx.insert(i)
        let o = Outfit(name: "look"); o.wardrobe = w; o.items = [i]; ctx.insert(o)
        let plan = CalendarPlan(date: Date()); plan.outfit = o; ctx.insert(plan)
        try ctx.save()

        let warning = WardrobeManageActions.forceDeleteWarning(
            itemCount: 1, lookCount: 1, planCount: 1)
        #expect(warning.localizedCaseInsensitiveContains("photo"))
        #expect(warning.localizedCaseInsensitiveContains("calendar")
            || warning.localizedCaseInsensitiveContains("plan"))
        #expect(warning.localizedCaseInsensitiveContains("wear history"))

        let out = WardrobeManageActions.delete(w, force: true, in: ctx)
        #expect(out.deleted)
        #expect(try ctx.fetch(FetchDescriptor<CalendarPlan>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<Item>()).isEmpty)
    }

    /// 当前正在使用的衣柜不可删（避免上层持有已删模型 / 删到零柜回落 Onboarding 造重复 Person）。
    /// 判定与文案走返回值，不依赖 CustomerFlashStyle 的关键词嗅探。
    @Test func currentClosetCannotBeDeleted() throws {
        let ctx = try makeContext()
        let p = Person(name: "Ada"); ctx.insert(p)
        let w = Wardrobe(name: "Main"); w.owner = p; ctx.insert(w)
        try ctx.save()
        #expect(!WardrobeManageActions.canDelete(w, currentWardrobeID: w.id))
        #expect(WardrobeManageActions.canDelete(w, currentWardrobeID: UUID()))
        #expect(!WardrobeManageActions.currentClosetBlockedMessage.isEmpty)
        #expect(!WardrobeManageActions.currentClosetRowAccessibilityHint.isEmpty)
        #expect(!WardrobeManageActions.rowSwipeAccessibilityHint.isEmpty)
    }

    @Test func deleteFailureIsHonestAndLeavesNoDirtyState() throws {
        let ctx = try makeContext()
        let p = Person(name: "Ada"); ctx.insert(p)
        let w = Wardrobe(name: "Spare"); w.owner = p; ctx.insert(w)
        try ctx.save()
        ModelSave.forceFailure(on: ctx)
        let out = WardrobeManageActions.delete(w, force: false, in: ctx)
        #expect(!out.deleted)
        #expect(out.isFailure)
        #expect(out.blockedReason == .saveFailed)
        #expect(!ctx.hasChanges)
        #expect(try ctx.fetch(FetchDescriptor<Wardrobe>()).count == 1)
        ModelSave.clearForcedFailure(on: ctx)
        #expect(WardrobeManageActions.delete(w, force: false, in: ctx).deleted)
    }

    @Test func personDeleteBlockedWhileHoldingClosets() throws {
        let ctx = try makeContext()
        let p = Person(name: "Ada"); ctx.insert(p)
        let w = Wardrobe(name: "Main"); w.owner = p; ctx.insert(w)
        try ctx.save()
        let blocked = WardrobeManageActions.deletePerson(p, in: ctx)
        #expect(!blocked.deleted)
        #expect(blocked.isFailure)
        #expect(blocked.blockedReason == .personHasWardrobes)
        #expect(try ctx.fetch(FetchDescriptor<Person>()).count == 1)
    }

    /// 删人连带删身体维度（最敏感数据）——分区脚注必须明示。
    @Test func personDeleteCascadesBodyProfileAndFooterSaysSo() throws {
        let ctx = try makeContext()
        let p = Person(name: "Solo"); ctx.insert(p)
        let body = PersonBodyProfile(personID: p.id); body.bustInches = 34
        ctx.insert(body)
        try ctx.save()
        #expect(WardrobeManageActions.peopleSectionFooter
            .localizedCaseInsensitiveContains("measurement"))
        let out = WardrobeManageActions.deletePerson(p, in: ctx)
        #expect(out.deleted)
        #expect(!out.isFailure)
        #expect(try ctx.fetch(FetchDescriptor<Person>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<PersonBodyProfile>()).isEmpty)
    }

    /// 确认对话框用值类型快照，不在 @State 里持 @Model（删除后再读属性是未定义行为）。
    @Test func pendingDeleteSnapshotIsValueTypeWithCounts() throws {
        let ctx = try makeContext()
        let p = Person(name: "Ada"); ctx.insert(p)
        let w = Wardrobe(name: "Trip"); w.owner = p; ctx.insert(w)
        let i = Item(name: "tee"); i.slotRaw = "top"; i.wardrobe = w; ctx.insert(i)
        let o = Outfit(name: "look"); o.wardrobe = w; o.items = [i]; ctx.insert(o)
        let plan = CalendarPlan(date: Date()); plan.outfit = o; ctx.insert(plan)
        try ctx.save()
        let snap = PendingWardrobeDelete(wardrobe: w, in: ctx)
        #expect(snap.id == w.id)
        #expect(snap.name == "Trip")
        #expect(snap.itemCount == 1)
        #expect(snap.lookCount == 1)
        #expect(snap.planCount == 1)
        // 快照与模型脱钩：删掉衣柜后快照仍可安全读（对话框消散动画期间会重新求值）
        _ = WardrobeManageActions.delete(w, force: true, in: ctx)
        #expect(snap.name == "Trip")
    }
}
