import Testing
import Foundation
import SwiftData
@testable import ClosetUI
import ClosetModel
import ClosetCore

/// D126：**锚定可以选出一个永远拼不出的组合**。
///
/// 两条下装、连衣裙 + 上装、两双鞋——`OutfitGrammar` 早就把这些定为非法，
/// 而锚定选择器一条都不查：用户选完，候选区一片空白，
/// 没有任何一句话告诉他是自己选的组合本身不成立。
///
/// copilot 的核心机制就是「用户挑几件、App 补齐」（D19）——
/// 挑的那一步给出一个死局，等于机制在最关键的地方失灵。
///
/// 处置**不是禁止点击**：用户的意图（「我今天就想穿这条裙子」）比规则重要。
/// 取「后选的替换先选的同类」——那正是用户真实的意思，
/// 并把发生了什么如实说出来。
@MainActor
struct AnchorConflictTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    private func item(_ ctx: ModelContext, _ w: Wardrobe, _ name: String, _ slot: String) -> Item {
        let i = Item(name: name)
        i.slotRaw = slot; i.statusRaw = "available"; i.wardrobe = w
        ctx.insert(i)
        return i
    }

    private func setup() throws -> (ModelContext, Wardrobe, CopilotViewModel) {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        try ctx.save()
        return (ctx, w, CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 70))
    }

    /// 选第二条下装 → 替换第一条（用户想穿的是后选的那条）。
    @Test func asecondBottomReplacesTheFirst() throws {
        let (ctx, w, vm) = try setup()
        let jeans = item(ctx, w, "Jeans", "bottom")
        let chinos = item(ctx, w, "Chinos", "bottom")
        try ctx.save()

        vm.toggleAnchor(jeans)
        vm.toggleAnchor(chinos)
        #expect(vm.isAnchored(chinos))
        #expect(!vm.isAnchored(jeans), "两条下装同时锚定 —— 永远拼不出任何一套")
    }

    /// 连衣裙与上下装互斥：选裙子会把上装/下装挤掉。
    @Test func aDressReplacesSeparates() throws {
        let (ctx, w, vm) = try setup()
        let tee = item(ctx, w, "Tee", "top")
        let jeans = item(ctx, w, "Jeans", "bottom")
        let dress = item(ctx, w, "Dress", "dress")
        try ctx.save()

        vm.toggleAnchor(tee)
        vm.toggleAnchor(jeans)
        vm.toggleAnchor(dress)
        #expect(vm.isAnchored(dress))
        #expect(!vm.isAnchored(tee))
        #expect(!vm.isAnchored(jeans))
    }

    /// 反过来也一样：已锚定裙子时选上装，裙子让位。
    @Test func separatesReplaceADress() throws {
        let (ctx, w, vm) = try setup()
        let dress = item(ctx, w, "Dress", "dress")
        let tee = item(ctx, w, "Tee", "top")
        try ctx.save()

        vm.toggleAnchor(dress)
        vm.toggleAnchor(tee)
        #expect(vm.isAnchored(tee))
        #expect(!vm.isAnchored(dress))
    }

    /// 不冲突的照常叠加（上装 + 下装 + 鞋是一身，不是冲突）。
    @Test func compatibleSlotsStack() throws {
        let (ctx, w, vm) = try setup()
        let tee = item(ctx, w, "Tee", "top")
        let jeans = item(ctx, w, "Jeans", "bottom")
        let boots = item(ctx, w, "Boots", "shoes")
        try ctx.save()

        vm.toggleAnchor(tee)
        vm.toggleAnchor(jeans)
        vm.toggleAnchor(boots)
        #expect(vm.anchorIDs.count == 3)
    }

    /// 取消锚定不受影响（再点一次就是取消，不是替换自己）。
    @Test func tappingTheSamePieceUnanchorsIt() throws {
        let (ctx, w, vm) = try setup()
        let tee = item(ctx, w, "Tee", "top")
        try ctx.save()
        vm.toggleAnchor(tee)
        vm.toggleAnchor(tee)
        #expect(vm.anchorIDs.isEmpty)
    }

    /// **发生了替换要说出来**——静默替换会让用户以为自己点漏了。
    @Test func aReplacementIsAnnounced() throws {
        let (ctx, w, vm) = try setup()
        let jeans = item(ctx, w, "Jeans", "bottom")
        let chinos = item(ctx, w, "Chinos", "bottom")
        try ctx.save()

        vm.toggleAnchor(jeans)
        vm.toggleAnchor(chinos)
        let note = try #require(vm.anchorNote)
        #expect(note.contains("Jeans"), Comment(rawValue: "没说清换掉了哪件：\(note)"))
    }

    /// 没有替换时不留旧提示（提示要跟着最后一次动作走）。
    @Test func theNoteClearsWhenNothingWasReplaced() throws {
        let (ctx, w, vm) = try setup()
        let jeans = item(ctx, w, "Jeans", "bottom")
        let chinos = item(ctx, w, "Chinos", "bottom")
        let tee = item(ctx, w, "Tee", "top")
        try ctx.save()

        vm.toggleAnchor(jeans)
        vm.toggleAnchor(chinos)          // 产生提示
        vm.toggleAnchor(tee)             // 不冲突
        #expect(vm.anchorNote == nil, "上一次替换的提示留在了屏幕上")
    }

    /// 锚定集合任何时候都必须是**语法上可能成立**的（这条是总闸）。
    @Test func theAnchorSetIsAlwaysBuildable() throws {
        let (ctx, w, vm) = try setup()
        let pieces = [
            item(ctx, w, "Tee", "top"), item(ctx, w, "Shirt", "top"),
            item(ctx, w, "Jeans", "bottom"), item(ctx, w, "Chinos", "bottom"),
            item(ctx, w, "Dress", "dress"),
            item(ctx, w, "Boots", "shoes"), item(ctx, w, "Sneakers", "shoes"),
        ]
        try ctx.save()
        for piece in pieces { vm.toggleAnchor(piece) }

        let anchored = pieces.filter { vm.isAnchored($0) }.map { $0.toCandidateItem() }
        // 锚定集合本身可以还缺件（补全器会补），但不得含**互斥**冲突
        let violations = OutfitGrammar.violations(anchored)
        let exclusive = violations.filter {
            $0 != .missingTop && $0 != .missingBottom && $0 != .missingShoes
        }
        #expect(exclusive.isEmpty, Comment(rawValue: "锚定集合本身就非法：\(exclusive)"))
    }
}

/// D126 接线门：替换提示必须真的渲染出来。
@MainActor
struct AnchorNoteWiringTests {
    @Test func theReplacementNoteIsShown() throws {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/ClosetUI/CopilotView.swift")
        let text = try String(contentsOf: file, encoding: .utf8)
        #expect(text.contains("vm.anchorNote"),
                "替换悄悄发生了 —— 用户会以为自己点漏了")
    }
}
