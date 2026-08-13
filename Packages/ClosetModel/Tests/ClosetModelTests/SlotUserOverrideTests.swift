import Testing
import Foundation
import SwiftData
@testable import ClosetModel
import ClosetCore

/// D194：**用户明确选的 Type 压不过名字推断**（第四轮 #01 的后半，D178 留的账）。
///
/// `GarmentSlot.resolved(slotRaw, name:)` 会用名字纠偏「西装写在 top」这类脏数据，
/// 而它在**八个读取点**各跑一遍——于是用户在详情页把 Type 改回 Top、保存，
/// 下次打开还是被名字改回去。D178 只关掉了最常见的那个词（dress shirt），
/// 一般情况要一个「这是用户明确设的」标记位才做得到。
///
/// 加法式 schema 变更（默认 false 兼容存量行），按 D84 重录 golden 并审 diff。
@MainActor
struct SlotUserOverrideTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    private func makeItem(_ ctx: ModelContext, name: String, slot: String) throws -> Item {
        let w = Wardrobe(name: "Home"); ctx.insert(w)
        let item = Item(name: name); item.slotRaw = slot; item.wardrobe = w
        ctx.insert(item); try ctx.save()
        return item
    }

    /// 存量行（没设过）照旧纠偏——脏数据是纠偏存在的理由。
    @Test func legacyRowsStillGetNameCorrection() throws {
        let ctx = try makeContext()
        let item = try makeItem(ctx, name: "Navy Blazer", slot: "top")
        #expect(item.slotUserSet == false, "默认必须是 false，否则存量行会被当成用户设过")
        #expect(item.resolvedSlot == .outerwear)
    }

    /// **本波的核心**：用户在详情页改了 Type，就该一直是那个。
    @Test func anExplicitTypeChangeSticks() throws {
        let ctx = try makeContext()
        let item = try makeItem(ctx, name: "Navy Blazer", slot: "top")
        #expect(item.resolvedSlot == .outerwear)   // 改之前：名字纠偏

        #expect(ItemEditorService.apply(
            ItemEditorService.Patch(slotRaw: GarmentSlot.top.rawValue),
            to: item, in: ctx))
        #expect(item.slotUserSet, "用户改了 Type，却没记下这是他设的")
        #expect(item.resolvedSlot == .top, Comment(rawValue:
            "保存之后又被名字改回 \\(item.resolvedSlot) —— 用户改不回来"))
    }

    /// 改完之后**再保存一次**（只改名字）不许把它顶回去。
    @Test func aLaterRenameDoesNotUndoTheChoice() throws {
        let ctx = try makeContext()
        let item = try makeItem(ctx, name: "Navy Blazer", slot: "top")
        #expect(ItemEditorService.apply(
            ItemEditorService.Patch(slotRaw: GarmentSlot.top.rawValue), to: item, in: ctx))
        #expect(ItemEditorService.apply(
            ItemEditorService.Patch(name: "Navy Blazer II"), to: item, in: ctx))
        #expect(item.resolvedSlot == .top, "改个名字就把用户的选择顶回去了")
    }

    /// **只改名字**（Type 一下没碰）仍按名字纠偏——不得被误判成「用户设过」。
    ///
    /// 这条正是实现时最容易写错的地方：判据若在改名**之后**才比，
    /// 「Tee → Navy Blazer」会让 `resolvedSlot` 自己从 top 变 outerwear，
    /// 于是送上来的 top 被当成用户的明确选择。
    @Test func renamingAloneIsNotAnExplicitChoice() throws {
        let ctx = try makeContext()
        let item = try makeItem(ctx, name: "Tee", slot: "top")
        #expect(ItemEditorService.apply(
            ItemEditorService.Patch(name: "Navy Blazer", slotRaw: GarmentSlot.top.rawValue),
            to: item, in: ctx))
        #expect(item.slotUserSet == false, Comment(rawValue:
            "只改了名字却被记成「用户设了 Type」—— 名字纠偏从此对它失效"))
        #expect(item.resolvedSlot == .outerwear)
    }

    /// 保存失败要把这一位一起还原（回滚纪律）。
    @Test func aFailedSaveRestoresTheFlag() throws {
        let ctx = try makeContext()
        let item = try makeItem(ctx, name: "Navy Blazer", slot: "top")
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }   // 注册表是进程级的，用完就清
        _ = ItemEditorService.apply(
            ItemEditorService.Patch(slotRaw: GarmentSlot.top.rawValue), to: item, in: ctx)
        #expect(item.slotUserSet == false, "保存失败了，标记位却留下了")
    }

    /// 结构门：**读取点只准走 `resolvedSlot`。**
    ///
    /// 八个读取点各自调 `GarmentSlot.resolved(item.slotRaw, name:)` 正是本条的成因：
    /// 加了标记位而漏掉任何一个，那一处就仍然会把用户的选择改回去。
    @Test func noReadSiteBypassesTheOverride() throws {
        let packages = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        var offenders: [String] = []
        for case let url as URL in FileManager.default
            .enumerator(at: packages, includingPropertiesForKeys: nil)!
        where url.pathExtension == "swift" {
            guard url.path.contains("/Sources/") else { continue }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for (n, line) in text.split(separator: "\n").enumerated() {
                let t = line.trimmingCharacters(in: .whitespaces)
                guard !t.hasPrefix("//"), !t.hasPrefix("///") else { continue }
                // 拿**实体的**两个字段去调纠偏 = 绕过了标记位
                if t.contains("GarmentSlot.resolved(") && t.contains(".slotRaw")
                    && t.contains(".name") {
                    offenders.append("\(url.lastPathComponent):\(n + 1)")
                }
            }
        }
        #expect(offenders.isEmpty, Comment(rawValue:
            "这些地方绕过了用户的明确选择：\(offenders) —— 用 `item.resolvedSlot`"))
    }
}
