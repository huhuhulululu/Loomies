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
        // D139：这里原先钉的是「wear history is kept」。记录行确实留着，
        // 但唯一能读它的界面按 `wardrobeSnapshotID == wardrobe.id` 过滤，
        // 而那个柜已经没了——技术上为真、实际为假。断言跟着文案一起改，
        // 否则这条测试会把那句不诚实焊回去（今天已经栽过两次）。
        #expect(!warning.localizedCaseInsensitiveContains("wear history"),
                Comment(rawValue: "又在承诺一份没有任何界面读得到的历史：\(warning)"))

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

/// D88：删柜确认面的**判空与文案**。此前判空只看 `itemCount`，而 DeleteService 的
/// 阻断判据同样只看 items——于是「0 件单品但有 N 套 look / M 条日历计划」的衣柜
/// 会一路 force=false 删除成功，级联抹掉全部 look 与计划，而用户看到的确认文案是
/// 「This closet is empty.」。可达路径：逐件删光单品或全部 Transfer 走，look 留在原柜。
@MainActor
struct WardrobeDeleteConfirmCopyTests {

    func snap(items: Int, looks: Int, plans: Int) -> WardrobeDeleteConfirm.Counts {
        WardrobeDeleteConfirm.Counts(itemCount: items, lookCount: looks, planCount: plans)
    }

    @Test func emptyOnlyWhenNothingCascades() {
        #expect(WardrobeDeleteConfirm.isEffectivelyEmpty(snap(items: 0, looks: 0, plans: 0)))
        // 有 look / 有计划 → 不是空柜，哪怕一件衣服都没有
        #expect(!WardrobeDeleteConfirm.isEffectivelyEmpty(snap(items: 0, looks: 1, plans: 0)))
        #expect(!WardrobeDeleteConfirm.isEffectivelyEmpty(snap(items: 0, looks: 0, plans: 1)))
        #expect(!WardrobeDeleteConfirm.isEffectivelyEmpty(snap(items: 3, looks: 0, plans: 0)))
    }

    /// 零单品但有 look/计划：不得说「empty」，且必须点名将被删的 look 与计划。
    @Test func zeroItemsWithLooksIsNotCalledEmpty() {
        let msg = WardrobeDeleteConfirm.message(snap(items: 0, looks: 2, plans: 1))
        #expect(!msg.localizedCaseInsensitiveContains("empty"))
        #expect(msg.localizedCaseInsensitiveContains("look"))
        #expect(msg.localizedCaseInsensitiveContains("plan"))
        // 「0 pieces」是噪音——一件都没有就别提件数
        #expect(!msg.contains("0 pieces"))
    }

    @Test func trulyEmptyClosetSaysSo() {
        let msg = WardrobeDeleteConfirm.message(snap(items: 0, looks: 0, plans: 0))
        #expect(msg.localizedCaseInsensitiveContains("empty"))
    }

    /// 单次确认即完成：非空柜按钮措辞升级为 "Delete anyway"，且直接 force 删除——
    /// 此前叠两层 .confirmationDialog 并在同一 runloop 内切换，第二层会被 SwiftUI 吞掉，
    /// 表现为「点了删除什么也没发生」，而第二层文案与第一层逐字相同、无新增披露。
    @Test func nonEmptyClosetConfirmsOnceWithEscalatedButton() {
        let empty = snap(items: 0, looks: 0, plans: 0)
        let full = snap(items: 2, looks: 1, plans: 0)
        #expect(WardrobeDeleteConfirm.confirmTitle(empty) == "Delete")
        #expect(WardrobeDeleteConfirm.confirmTitle(full)
            .localizedCaseInsensitiveContains("anyway"))
        #expect(WardrobeDeleteConfirm.needsForce(empty) == false)
        #expect(WardrobeDeleteConfirm.needsForce(full) == true)
    }

    /// 计数快照必须来自真实关系（0 件 + 1 look 的柜子确实存在于数据层）。
    @Test func countsSnapshotSeesLooksWithoutItems() throws {
        let ctx = try ModelContext(ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let o = Outfit(name: "look"); o.wardrobe = w; ctx.insert(o)
        let plan = CalendarPlan(date: Date()); plan.outfit = o; ctx.insert(plan)
        try ctx.save()
        let pending = PendingWardrobeDelete(wardrobe: w, in: ctx)
        #expect(pending.itemCount == 0)
        #expect(pending.lookCount == 1)
        #expect(pending.planCount == 1)
        #expect(!WardrobeDeleteConfirm.isEffectivelyEmpty(pending.counts))
    }
}

/// D139：**删柜对话框说的事和实际发生的不一致**。
///
/// 两处：
/// 1. 「Wear history is kept」——记录行确实留着，但唯一能读它的界面
///    （`WearHistoryView`）按 `wardrobeSnapshotID == wardrobe.id` 过滤，
///    而那个柜已经没了：**技术上为真、实际为假**。
///    对用户来说，一句读不到的「保留」比不提更糟——它让人以为还能找回来。
/// 2. 删柜会把**别的柜里**用到这些件的搭配标为永久缺件（D103 修的是行为），
///    而对话框只字不提——用户在别的柜里发现搭配坏了，无从知道是自己刚才那一下。
@MainActor
struct WardrobeDeleteCopyHonestyTests {

    private func counts(items: Int = 3, looks: Int = 2, plans: Int = 1, foreign: Int = 0)
        -> WardrobeDeleteConfirm.Counts {
        .init(itemCount: items, lookCount: looks, planCount: plans,
              foreignLookCount: foreign)
    }

    /// 不得再宣称「穿着历史保留」——那句话用户验证不了，也用不上。
    @Test func itNoLongerClaimsHistoryIsBrowsable() {
        let text = WardrobeDeleteConfirm.message(counts())
        #expect(!text.localizedCaseInsensitiveContains("wear history is kept"),
                Comment(rawValue: "承诺了一份读不到的历史：\(text)"))
    }

    /// **别柜受影响时必须说**——那是用户最想不到的后果。
    @Test func itNamesTheDamageToOtherClosets() {
        let text = WardrobeDeleteConfirm.message(counts(foreign: 2))
        #expect(text.localizedCaseInsensitiveContains("other closet"),
                Comment(rawValue: "没说会影响别的柜：\(text)"))
        #expect(text.contains("2"))
    }

    /// 不影响别柜时不提（0 是噪音，且会让人以为有事发生）。
    @Test func itStaysQuietWhenNoOtherClosetIsAffected() {
        let text = WardrobeDeleteConfirm.message(counts(foreign: 0))
        #expect(!text.localizedCaseInsensitiveContains("other closet"))
    }

    /// 既有的级联面照旧说清（这次改动不得把已有的诚实说法弄丢）。
    @Test func theExistingCascadeIsStillStated() {
        let text = WardrobeDeleteConfirm.message(counts())
        #expect(text.contains("3 pieces"))
        #expect(text.contains("2 looks"))
        #expect(text.contains("1 calendar plans"))
        #expect(text.localizedCaseInsensitiveContains("photos"))
    }

    /// 空柜仍走空态文案。
    @Test func anEmptyClosetKeepsItsOwnMessage() {
        let text = WardrobeDeleteConfirm.message(counts(items: 0, looks: 0, plans: 0))
        #expect(text == WardrobeDeleteConfirm.emptyMessage)
    }
}
