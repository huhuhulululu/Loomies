import Testing
import SwiftData
import Foundation
@testable import ClosetModel
import ClosetCore

/// D93：护理与备注的落库纪律（与既有属性同标准）。
@MainActor
struct ItemCareNotesEditorTests {

    func setup() throws -> (ModelContext, Item) {
        let ctx = try ModelContext(ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let i = Item(name: "tee"); i.slotRaw = "top"; i.wardrobe = w; ctx.insert(i)
        try ctx.save()
        return (ctx, i)
    }

    /// 护理写入去重 + 排序确定（导出快照可复现）。
    @Test func careIsDeduplicatedAndSorted() throws {
        let (ctx, item) = try setup()
        #expect(ItemEditorService.apply(
            .init(careRaw: ["noTumbleDry", "handWash", "handWash"]), to: item, in: ctx))
        #expect(item.careRaw == ["handWash", "noTumbleDry"])
    }

    /// 脏护理 raw 整包拒绝——不得部分写入让 UI 与数据各说各话。
    @Test func unknownCareSymbolIsRejectedWholesale() throws {
        let (ctx, item) = try setup()
        #expect(ItemEditorService.apply(.init(careRaw: ["handWash"]), to: item, in: ctx))
        #expect(!ItemEditorService.apply(
            .init(careRaw: ["handWash", "boilInOil"]), to: item, in: ctx))
        #expect(item.careRaw == ["handWash"])   // 原值不动
        #expect(!ctx.hasChanges)
    }

    /// 备注落库前必过 sanitize（超长截断 + 控制字符归一）。
    @Test func notesArePersistedSanitized() throws {
        let (ctx, item) = try setup()
        let dirty = "needs\na belt" + String(repeating: "!", count: ItemNotes.maxLength)
        #expect(ItemEditorService.apply(
            .init(notes: dirty, replaceNotes: true), to: item, in: ctx))
        let stored = try #require(item.notes)
        #expect(stored.count == ItemNotes.maxLength)
        #expect(!stored.contains("\n"))
        #expect(stored.hasPrefix("needs a belt"))
    }

    /// `replaceNotes` 为假时不动备注（与 replaceWarmth/replaceColor 同语义）。
    @Test func notesUntouchedWithoutReplaceFlag() throws {
        let (ctx, item) = try setup()
        #expect(ItemEditorService.apply(
            .init(notes: "keep me", replaceNotes: true), to: item, in: ctx))
        #expect(ItemEditorService.apply(.init(name: "renamed"), to: item, in: ctx))
        #expect(item.notes == "keep me")
        // 显式清空
        #expect(ItemEditorService.apply(
            .init(notes: "   ", replaceNotes: true), to: item, in: ctx))
        #expect(item.notes == nil)
    }

    /// 保存失败还原护理与备注（不得让 UI 显示未入库的新值）。
    @Test func saveFailureRestoresCareAndNotes() throws {
        let (ctx, item) = try setup()
        #expect(ItemEditorService.apply(
            .init(careRaw: ["handWash"], notes: "original", replaceNotes: true),
            to: item, in: ctx))
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        #expect(!ItemEditorService.apply(
            .init(careRaw: ["dryCleanOnly"], notes: "changed", replaceNotes: true),
            to: item, in: ctx))
        #expect(item.careRaw == ["handWash"])
        #expect(item.notes == "original")
        #expect(!ctx.hasChanges)
    }
}
