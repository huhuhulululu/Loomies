import Testing
import Foundation
import SwiftData
@testable import ClosetUI
import ClosetModel
import ClosetCore

/// D187：**删柜与搬家，两个破坏性动作各漏说一件事。**
///
/// 1. **删柜说「This closet is empty.」，却把整棵存放位置树一起抹了。**
///    判空只数 items / looks / plans 三项，而 `Wardrobe.locations` 是
///    `.cascade`——`context.delete(wardrobe)` 连树一起删，`DeleteService`
///    的注释自己写着这一点。0 件 + 一棵用户一层层建起来的柜格，
///    对话框读作「空」，一按就没了。
///
/// 2. **删柜警告无条件加上「and their local photos」**，即使这个柜一张照片
///    都不会被删（0 件时 `doomedItems` 为空，`ItemImageStore.deleteAll` 一次都不跑）。
///    这条只是多吓唬人，但「诚实文案」不该只在一个方向上诚实。
///
/// 3. **搬家会抹掉存放位置，两个转移面只字不提。** `TransferService` 第 38 行
///    `item.location = nil` 是无条件的，**搬回去也不会恢复**——
///    而批量搬家一次抹掉几十件的位置，摘要只说「Moved 12 pieces.」。
///    （搭配变 Missing 是可逆的，转回即自动重算，那条只需提一句。）
///
/// 三条共同的形状与 D88 同型：**判据是一张手抄的实体清单**，
/// 而 schema 的级联关系是另一张。两张清单从来没有对过账。
@MainActor
struct MoveAndDeleteDisclosureTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    // MARK: - #15 存放位置树

    /// **本波的核心**：有柜格的柜子不是「空」的。
    @Test func aClosetWithStorageSpotsIsNotEmpty() throws {
        let counts = WardrobeDeleteConfirm.Counts(
            itemCount: 0, lookCount: 0, planCount: 0, locationCount: 3)
        #expect(!WardrobeDeleteConfirm.isEffectivelyEmpty(counts), Comment(rawValue:
            "一棵三层的存放位置树被当成「空」——一按就没了，而对话框说什么都不会删"))
        let message = WardrobeDeleteConfirm.message(counts)
        #expect(message != WardrobeDeleteConfirm.emptyMessage)
        #expect(message.localizedCaseInsensitiveContains("storage"), Comment(rawValue:
            "警告没点名存放位置：\(message)"))
    }

    /// 真的什么都没有时仍然说「空」。
    @Test func atrulyEmptyClosetStillReadsEmpty() {
        let counts = WardrobeDeleteConfirm.Counts(
            itemCount: 0, lookCount: 0, planCount: 0, locationCount: 0)
        #expect(WardrobeDeleteConfirm.isEffectivelyEmpty(counts))
        #expect(WardrobeDeleteConfirm.message(counts) == WardrobeDeleteConfirm.emptyMessage)
    }

    /// 快照真的去数了位置树（不是只加了个字段没人填）。
    @Test func theSnapshotCountsTheStorageTree() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Home"); ctx.insert(w); try ctx.save()
        let rail = try #require(StorageLocationService.create(name: "Rail", in: w, context: ctx))
        _ = StorageLocationService.create(name: "Drawer", in: w, parent: rail, context: ctx)

        let pending = PendingWardrobeDelete(wardrobe: w, in: ctx)
        #expect(pending.locationCount == 2, Comment(rawValue:
            "快照数出 \(pending.locationCount) 个存放位置"))
        #expect(!WardrobeDeleteConfirm.isEffectivelyEmpty(pending.counts))
    }

    // MARK: - #18 照片那半句

    /// 一件都没有的柜子不许说「连同它们的本地照片」。
    @Test func aClosetWithNoPiecesDoesNotClaimPhotosGoToo() {
        let text = WardrobeManageActions.forceDeleteWarning(
            itemCount: 0, lookCount: 2, planCount: 1, foreignLookCount: 0)
        #expect(!text.localizedCaseInsensitiveContains("photo"), Comment(rawValue:
            "这个柜一张照片都不会被删，警告却说会：\(text)"))
        #expect(text.localizedCaseInsensitiveContains("look"), "该说的还得说")
    }

    /// 有件时照旧说照片（原行为一个字不变）。
    @Test func aClosetWithPiecesStillNamesPhotos() {
        let text = WardrobeManageActions.forceDeleteWarning(
            itemCount: 3, lookCount: 0, planCount: 0, foreignLookCount: 0)
        #expect(text.localizedCaseInsensitiveContains("photo"))
    }

    // MARK: - #16 搬家抹掉存放位置

    /// 搬家确实会抹掉存放位置，而且**搬回去也不恢复**——先把这条行为钉住。
    @Test func movingAPieceClearsItsStorageSpotForGood() throws {
        let ctx = try makeContext()
        let home = Wardrobe(name: "Home"); ctx.insert(home)
        let lake = Wardrobe(name: "Lake"); ctx.insert(lake); try ctx.save()
        let rail = try #require(StorageLocationService.create(
            name: "Rail", in: home, context: ctx))
        let tee = Item(name: "Tee"); tee.wardrobe = home; ctx.insert(tee); try ctx.save()
        #expect(StorageLocationService.assign(tee, to: rail, in: ctx))

        #expect(TransferService.transfer(tee, to: lake, in: ctx))
        #expect(tee.location == nil)
        #expect(TransferService.transfer(tee, to: home, in: ctx))
        #expect(tee.location == nil, "搬回来也不会恢复位置 —— 所以这条必须事先说")
    }

    /// 两个转移面都得说这件事，而且**说的是同一句**（两处各写各的注定走岔）。
    @Test func bothMoveSheetsDiscloseTheSameConsequences() {
        let single = TransferViewModel.consequenceNotice
        #expect(single.localizedCaseInsensitiveContains("storage")
                || single.localizedCaseInsensitiveContains("spot"),
                Comment(rawValue: "没说存放位置会被清掉：\(single)"))
        #expect(single.localizedCaseInsensitiveContains("missing"), Comment(rawValue:
            "没说原柜的搭配会变成缺件：\(single)"))
        #expect(BatchMoveCopy.consequenceNotice == single,
                "批量与单件说的不是同一句 —— 迟早走岔")
    }

    /// **文案得真的画出来。** 本仓反复栽在「常量写了、零调用点」上
    ///（D182 的 `depthLimitMessage` 就是），所以这条钉的是渲染点。
    @Test func bothMoveSheetsActuallyRenderIt() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Sources/ClosetUI/FeatureViews.swift"),
            encoding: .utf8)
        func renders(_ symbol: String, within marker: String) -> Bool {
            guard let r = source.range(of: marker) else { return false }
            let rest = source[r.lowerBound...]
            let end = rest.range(of: "\n}")?.lowerBound ?? rest.endIndex
            return rest[rest.startIndex..<end].split(separator: "\n").contains { line in
                let t = line.trimmingCharacters(in: .whitespaces)
                return t.contains(symbol) && t.hasPrefix("Text(")
            }
        }
        #expect(renders("TransferViewModel.consequenceNotice", within: "struct TransferSheet"),
                "单件转移面没画出后果")
        #expect(renders("BatchMoveCopy.consequenceNotice", within: "struct BatchMoveSheet"),
                "批量移动面没画出后果")
    }

    /// 结构门：**删柜级联抹掉的每一类，判空清单里都得数到。**
    ///
    /// 这与 D144 给「删除一切」立的门同型——那次是删库的披露，
    /// 这次是删柜的判空。判据认构造：`Wardrobe` 上标了 `.cascade` 的关系，
    /// 必须在 `Counts` 里有对应的计数字段。
    @Test func everyCascadedRelationIsCounted() throws {
        let entities = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ClosetModel/Sources/ClosetModel/Entities.swift")
        let text = try String(contentsOf: entities, encoding: .utf8)
        guard let r = text.range(of: "public final class Wardrobe") else {
            Issue.record("找不到 Wardrobe 实体"); return
        }
        let rest = text[r.upperBound...]
        let end = rest.range(of: "\n}")?.lowerBound ?? rest.endIndex
        let body = String(rest[rest.startIndex..<end])

        // `.cascade` 关系的属性名（`public var locations: [StorageLocation]?` 这一行）
        var cascaded: [String] = []
        let lines = body.split(separator: "\n").map(String.init)
        for (i, line) in lines.enumerated() where line.contains("deleteRule: .cascade") {
            // 属性声明可能在同一行或下一行
            let candidates = [line, i + 1 < lines.count ? lines[i + 1] : ""]
            for c in candidates {
                guard let varRange = c.range(of: "public var ") else { continue }
                let name = String(c[varRange.upperBound...].prefix { $0 != ":" && $0 != " " })
                if !name.isEmpty { cascaded.append(name); break }
            }
        }
        #expect(cascaded.count >= 3, Comment(rawValue:
            "只解析出 \(cascaded)：解析口径坏了"))

        // 每一类都要在判空的计数里露面（items→itemCount、outfits→lookCount…）
        let naming: [String: String] = [
            "items": "itemCount", "outfits": "lookCount", "locations": "locationCount",
        ]
        var uncounted: [String] = []
        for relation in cascaded {
            guard let field = naming[relation] else {
                uncounted.append("\(relation)（没有对应计数字段）")
                continue
            }
            if !WardrobeDeleteConfirm.Counts.countedFields.contains(field) {
                uncounted.append(relation)
            }
        }
        #expect(uncounted.isEmpty, Comment(rawValue:
            "删柜会连带抹掉这些，而判空一个都没数：\(uncounted) —— "
            + "用户会在对话框上读到「empty」"))
    }
}

/// D188 之二：**全自动模式丢掉锚定件，而 chip 与 advisory 还在屏上说反话。**
///
/// `forceAnchor = isColdStart || !fullAuto`，else 分支把 `anchors` 置空却对
/// `anchorAdvisory` 一字未动，`anchorIDs` 也原样留着——视图的 `shouldShowAnchors`
/// 在「fullAuto + anchorIDs 非空」时仍为 true，于是那句
/// 「— keeping it in anyway.」照常渲染，而引擎根本没用它。
///
/// 可达路径不止手动切 toggle：冷启动下锚定一件 → 点「Load samples」会把
/// `fullAuto` 置 true 并刷新，播完 9 件后 `isColdStart` 转 false，锚定即被丢弃。
///
/// D131 加那句 advisory 的理由正是「不吭声会让用户以为过滤坏了」——
/// 这条路把它从「如实说」变成了「主动说反话」。
@MainActor
struct FullAutoDropsAnchorsTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    /// 造一个**过了冷启动**的衣柜（否则 forceAnchor 恒真，走不到那条分支）。
    private func warmWardrobe(_ ctx: ModelContext) throws -> Wardrobe {
        let w = Wardrobe(name: "Home"); ctx.insert(w)
        let slots = ["top", "bottom", "shoes", "outerwear"]
        for i in 0..<12 {
            let item = Item(name: "piece-\(i)")
            item.wardrobe = w
            item.slotRaw = slots[i % slots.count]
            item.statusRaw = "available"
            item.warmthRaw = Warmth.medium.rawValue
            ctx.insert(item)
        }
        try ctx.save()
        return w
    }

    /// **本波的核心**：锚定被丢弃时，屏上不许还留着「仍然照你说的用」。
    @Test func fullAutoDoesNotLeaveAStaleAnchorOnScreen() throws {
        let ctx = try makeContext()
        let w = try warmWardrobe(ctx)
        let vm = CopilotViewModel(wardrobe: w)
        let pinned = try #require((w.items ?? []).first)
        vm.toggleAnchor(pinned)      // 走真正的用户入口，不是直接改内部状态
        vm.fullAuto = false
        _ = vm.makeRefreshRequest()
        #expect(vm.anchorAdvisory != nil || vm.anchorIDs == [pinned.id],
                "前提不成立：非全自动时锚定本该生效")

        vm.fullAuto = true
        _ = vm.makeRefreshRequest()
        #expect(vm.anchorIDs.isEmpty, Comment(rawValue:
            "全自动已经把锚定丢了，chip 却还在：\(vm.anchorIDs)"))
        #expect(vm.anchorAdvisory == nil, Comment(rawValue:
            "引擎没用这件衣服，advisory 还写着「keeping it in anyway」：\(vm.anchorAdvisory ?? "")"))
    }

    /// 冷启动时锚定仍然生效（那条分支不受影响）。
    @Test func aColdStartStillHonoursTheAnchor() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Cold"); ctx.insert(w)
        let tee = Item(name: "Tee"); tee.wardrobe = w; tee.slotRaw = "top"
        tee.statusRaw = "available"; ctx.insert(tee)
        try ctx.save()

        let vm = CopilotViewModel(wardrobe: w)
        vm.fullAuto = true
        vm.toggleAnchor(tee)
        _ = vm.makeRefreshRequest()
        #expect(vm.anchorIDs == [tee.id], "冷启动下锚定被误清了")
    }
}

/// D188 之三：**跨天回到前台，天气与推荐不重算。**
///
/// D136 修好了「今天已定」那条带（回前台重读打卡），但同一个处理器里
/// **只**做了这一件事：`daytimeTempF` / `weatherSourceLabel` /
/// `precipProbabilityPercent` / `suggestions` 全停在上一次刷新，
/// 而 `hasResolvedWeather` 仍为 true——于是昨天那个具体温度会被当成今天的印出来。
///
/// `applyWeather` 的生产调用点只有两个：bootstrap（被 `didBootstrap` 锁死一次）
/// 与换城市。进程只要没被系统回收，早安提醒把用户导向的就是昨天那套 look
/// 和昨天的温度。
///
/// 判据取**跨日历日**而不是「过了多久」：同一天内不重算——
/// 用户切去相册查个东西再回来，建议在他眼皮底下换一批是更糟的体验。
@MainActor
struct NewDayRefreshTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    private func makeVM() throws -> CopilotViewModel {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Home"); ctx.insert(w)
        let tee = Item(name: "Tee"); tee.wardrobe = w; tee.slotRaw = "top"
        tee.statusRaw = "available"; ctx.insert(tee)
        try ctx.save()
        return CopilotViewModel(wardrobe: w)
    }

    /// 还没刷新过 → 不需要「重算」（bootstrap 会做第一次）。
    @Test func beforeTheFirstRefreshThereIsNothingToRedo() throws {
        let vm = try makeVM()
        #expect(vm.needsNewDayRefresh() == false)
    }

    /// **本波的核心**：跨了午夜就要重算。
    @Test func crossingMidnightAsksForARecompute() throws {
        let vm = try makeVM()
        _ = vm.makeRefreshRequest()          // 让 lastRefreshAt 落到「今天」
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        #expect(vm.needsNewDayRefresh(now: tomorrow), Comment(rawValue:
            "跨天回到前台不重算 —— 早安提醒把用户带到的是昨天那套 look 和昨天的温度"))
    }

    /// 同一天内回来不重算（别在用户眼皮底下换一批建议）。
    @Test func comingBackTheSameDayLeavesTheLookAlone() throws {
        let vm = try makeVM()
        _ = vm.makeRefreshRequest()
        let laterToday = Date().addingTimeInterval(3 * 3600)
        let sameDay = Calendar.current.isDate(laterToday, inSameDayAs: Date())
        #expect(vm.needsNewDayRefresh(now: laterToday) == !sameDay,
                "同一天内不该重算（跨过午夜的那几小时除外）")
    }

    /// 接线门：回前台的处理器必须**真的**去问这个判据。
    /// 常量/方法写了没人调，是本仓反复栽的那一类（D182）。
    @Test func theForegroundHandlerActuallyAsks() throws {
        let text = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Sources/ClosetUI/CopilotView.swift"),
            encoding: .utf8)
        guard let r = text.range(of: "onChange(of: scenePhase)") else {
            Issue.record("找不到回前台处理器"); return
        }
        let rest = text[r.lowerBound...]
        let end = rest.range(of: "\n                }")?.lowerBound ?? rest.endIndex
        let body = String(rest[rest.startIndex..<end])
        #expect(body.contains("needsNewDayRefresh"), Comment(rawValue:
            "回前台没问跨天判据 —— 天气与推荐会停在昨天：\(body)"))
    }
}
