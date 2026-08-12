import Testing
import SwiftData
import Foundation
@testable import ClosetModel
import ClosetCore

/// D88：位置树在同一波里被打开成多层，但删除与遍历的安全网没跟上。
/// - 删父节点会把子位置与衣物**静默**提到祖父级：删「Closet 1」→「Rail A」「Box 1」
///   悄悄变成顶层，无任何告知；
/// - 这次提升还能撞出两个同名兄弟——正是同一波新加的 `siblingNameConflicts` 要防的歧义
///   （根层已有「Attic」+ 子层「Closet 1/Attic」→ 删掉 Closet 1 → 两行都叫 Attic，选不清）；
/// - 建子节点无深度上限，`listWithDepth` 的递归对成环数据会栈溢出崩溃。
@MainActor
struct StorageTreeSafetyTests {

    func makeContext() throws -> ModelContext {
        try ModelContext(ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    /// 删除前必须能说清后果（几件衣服、几个子位置会被提到哪一级）。
    @Test func deleteWarningNamesReparentedChildrenAndItems() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let closet = try #require(StorageLocationService.create(name: "Closet 1", in: w, context: ctx))
        _ = try #require(StorageLocationService.create(name: "Rail A", in: w, parent: closet, context: ctx))
        let item = Item(name: "tee"); item.slotRaw = "top"; item.wardrobe = w
        item.location = closet; ctx.insert(item)
        try ctx.save()

        let plan = StorageLocationService.deletePlan(for: closet)
        #expect(plan.childCount == 1)
        #expect(plan.itemCount == 1)
        #expect(plan.destinationName == StorageLocationService.topLevelName)
        let warning = StorageLocationService.deleteWarning(plan)
        #expect(warning.localizedCaseInsensitiveContains("top level"))
        #expect(warning.contains("1"))
        // 空叶子无需吓唬用户
        let leaf = try #require(StorageLocationService.create(name: "Empty", in: w, context: ctx))
        #expect(!StorageLocationService.deletePlan(for: leaf).needsConfirmation)
    }

    /// 提升后不得出现两个同名兄弟——那正是位置 Picker 里分辨不出的歧义。
    @Test func reparentingDoesNotCreateDuplicateSiblings() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        _ = try #require(StorageLocationService.create(name: "Attic", in: w, context: ctx))
        let closet = try #require(StorageLocationService.create(name: "Closet 1", in: w, context: ctx))
        let nested = try #require(StorageLocationService.create(
            name: "Attic", in: w, parent: closet, context: ctx))
        try ctx.save()

        #expect(DeleteService.deleteLocation(closet, in: ctx))
        let roots = StorageLocationService.listWithDepth(in: w).filter { $0.depth == 0 }
        let names = roots.map(\.location.name)
        #expect(names.count == Set(names).count,
                Comment(rawValue: "提升后出现同名兄弟：\(names)"))
        // 被提升的那个改了名，不是被删掉（用户的数据不能凭空消失）
        #expect(roots.contains { $0.location.id == nested.id })
    }

    /// 深度上限：rail / drawer / bin 三层足够，无限嵌套会把缩进推出屏幕。
    @Test func depthIsCapped() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        var parent: StorageLocation? = nil
        for level in 0..<StorageLocationService.maxDepth {
            parent = try #require(StorageLocationService.create(
                name: "L\(level)", in: w, parent: parent, context: ctx),
                "第 \(level) 层就建不出来了")
        }
        // 再深一层必须被拒（返回 nil），且有可展示的诚实文案
        #expect(StorageLocationService.create(
            name: "TooDeep", in: w, parent: parent, context: ctx) == nil)
        #expect(StorageLocationService.depthLimitReached(parent: parent))
        #expect(StorageLocationService.depthLimitMessage
            .localizedCaseInsensitiveContains("level"))
    }

    /// 成环数据（导入/外部写入）不得让遍历栈溢出。
    @Test func cyclicParentDoesNotHangTheWalk() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let a = try #require(StorageLocationService.create(name: "A", in: w, context: ctx))
        let b = try #require(StorageLocationService.create(name: "B", in: w, parent: a, context: ctx))
        // 绕过 create 的守卫直接造环（模拟导入的坏数据）
        a.parent = b
        try? ctx.save()
        let nodes = StorageLocationService.listWithDepth(in: w)
        #expect(nodes.count <= 2)   // 不重复展开，不无限递归
    }
}
