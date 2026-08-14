import Testing
import Foundation
import SwiftData
@testable import ClosetUI
import ClosetModel
import ClosetCore

/// D147：**D105 修的那个崩溃，在第二处还原样留着。**
///
/// D105 认定 `Dictionary(uniqueKeysWithValues:)` 按实体 id 建表是一条崩溃路径：
/// schema **没有**把 id 声明为 unique，重复 key 直接 `fatalError`。
/// 当时改掉的是 `TransferHistory.closetNames`（按衣柜 id）——
/// 而 `WearHistoryViewModel.load` 按**单品 id** 做同一件事，一个字没动。
///
/// 单品比衣柜多两个数量级，这一处的暴露面严格更大。
/// 代价与场景依旧完全不成比例：它只是给历史行取几个显示名，
/// 却能把「穿着历史」整页变成一次进程终止。
///
/// 同一条修复要走遍它该走的每一处——这正是 D105 当时漏掉的那半步。
@MainActor
struct WearHistoryDuplicateIDTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    /// 重复 id 不得让取名字的路径崩掉。
    @Test func duplicateItemIDsDoNotCrashTheHistory() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let shared = UUID()
        let a = Item(name: "Alpha"); a.id = shared; a.wardrobe = w; ctx.insert(a)
        let b = Item(name: "Beta"); b.id = shared; b.wardrobe = w; ctx.insert(b)
        let rec = WearRecord(date: Date())
        rec.wornItemIDs = [shared.uuidString]
        rec.wardrobeSnapshotID = w.id
        ctx.insert(rec)
        try ctx.save()

        let vm = WearHistoryViewModel(wardrobe: w)
        vm.load(in: ctx)     // 修之前：fatalError，整个测试进程一起死
        #expect(vm.entries.count == 1)
    }

    /// 撞了也要取**确定的**胜者——同一个库跑两次结果一致
    /// （不确定的话，用户每次进这一页看到的名字都可能不一样）。
    @Test func theWinnerIsDeterministic() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let shared = UUID()
        for name in ["Zulu", "Alpha", "Mike"] {
            let i = Item(name: name); i.id = shared; i.wardrobe = w; ctx.insert(i)
        }
        let rec = WearRecord(date: Date())
        rec.wornItemIDs = [shared.uuidString]
        rec.wardrobeSnapshotID = w.id
        ctx.insert(rec)
        try ctx.save()

        let first = WearHistoryViewModel(wardrobe: w)
        first.load(in: ctx)
        let second = WearHistoryViewModel(wardrobe: w)
        second.load(in: ctx)
        #expect(first.entries.first?.pieceNames == second.entries.first?.pieceNames,
                "同一个库两次读出不同的名字")
        #expect(first.entries.first?.pieceNames == ["Alpha"],
                Comment(rawValue: "胜者不确定：\(first.entries.first?.pieceNames ?? [])"))
    }

    /// 没有重复时行为一个字不变。
    @Test func normalHistoryIsUnaffected() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let tee = Item(name: "Tee"); tee.wardrobe = w; ctx.insert(tee)
        let jeans = Item(name: "Jeans"); jeans.wardrobe = w; ctx.insert(jeans)
        let rec = WearRecord(date: Date())
        rec.wornItemIDs = [tee.id.uuidString, jeans.id.uuidString]
        rec.wardrobeSnapshotID = w.id
        ctx.insert(rec)
        try ctx.save()

        let vm = WearHistoryViewModel(wardrobe: w)
        vm.load(in: ctx)
        #expect(vm.entries.first?.pieceNames == ["Jeans", "Tee"])
        #expect(vm.entries.first?.missingCount == 0)
    }

    /// 结构门：**按实体 id 建表的地方，一处都不许再用会崩的那个构造器。**
    /// D105 只修了两处中的一处，靠的是人眼；这条让下一处在合入时就红。
    @Test func noProductionCodeBuildsIDMapsThatCanTrap() throws {
        let packages = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        // D209：遍历型门必须自证「扫到过东西」——判据见 D208。
        var scannedFileCount = 0
        var offenders: [String] = []
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: packages, includingPropertiesForKeys: nil)
        else { Issue.record("遍历器建不起来 —— 静默 return 等于这道门根本没跑"); return }
        for case let url as URL in walker where url.pathExtension == "swift" {
            let path = url.path
            guard path.contains("/Sources/") else { continue }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            scannedFileCount += 1
            // 只看**代码行**——解释「为什么不用它」的注释不算犯规
            //（第一版就是这么误报的：两处修好的地方各有一段说明踩进来）
            let offends = text.split(separator: "\n").contains { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return trimmed.contains("uniqueKeysWithValues")
                    && !trimmed.hasPrefix("//") && !trimmed.hasPrefix("///")
                    && !trimmed.hasPrefix("*")
            }
            if offends { offenders.append(url.lastPathComponent) }
        }
        #expect(scannedFileCount >= 80, Comment(rawValue:
            "只扫到 \(scannedFileCount) 个源文件 —— 遍历坏了，这道门在空转"))
        #expect(offenders.isEmpty, Comment(rawValue:
            "这些地方用 `Dictionary(uniqueKeysWithValues:)`，重复 key 会直接终止进程："
            + "\(offenders) —— 用带决胜的 `Dictionary(_:uniquingKeysWith:)`"))
    }
}

/// D156：详情页只取一次穿着记录表。
///
/// 洗涤说明与穿着统计此前各自取全表——实测单次约 72ms（两年每日打卡 730 条），
/// 打开一件衣服白花一倍。两条口径本来就来自同一张表，取一次即可。
@MainActor
struct DetailLoadsWearRecordsOnceTests {

    @Test func loadHistoryFetchesTheTableOnce() throws {
        let text = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Sources/ClosetUI/ItemDetailViewModel.swift"),
            encoding: .utf8)
        guard let r = text.range(of: "public func loadHistory(in context: ModelContext)") else {
            Issue.record("找不到 loadHistory"); return
        }
        // D162：窗口式判据看不见窗口外的第二次取表（假绿方向）——改按结构边界
        let rest = text[r.lowerBound...]
        let stop = rest.range(of: "\n    /// Me Storage location")?.lowerBound
            ?? rest.endIndex
        let body = String(rest[rest.startIndex..<stop])
        // 只数**代码行**——解释「为什么只取一次」的注释里也会出现这个词。
        // D147 的第一版就是这么误报的，同一个坑不该踩第二次：判据认构造，不认词。
        let fetches = body.split(separator: "\n").filter { line in
            let t = line.trimmingCharacters(in: .whitespaces)
            return t.contains("FetchDescriptor<WearRecord>")
                && !t.hasPrefix("//") && !t.hasPrefix("///")
        }.count
        #expect(fetches == 1, Comment(rawValue:
            "loadHistory 取了 \(fetches) 次穿着记录全表 —— 每次约 72ms"))
        // 两处都必须吃那一次的结果，不许自己再去取
        #expect(body.contains("records: records"))
    }
}

/// D169：穿着历史**全表取回再在内存里按柜过滤**。
///
/// 实测（文件库、两年 730 条、一半属本柜）：现状 62ms，把过滤下推到谓词后 27ms。
/// 排序仍留在内存——`SortDescriptor` 表达不了「同日按 id 决胜」，
/// 而那条决定了同一天多次打卡的显示顺序（不稳定的话用户每次进来看到的次序都可能不同）。
/// 内存排序用摊平法（D157/D168 同款）。
///
/// 两处改动都不改结果：谓词与原过滤条件逐字相同，排序键逐字相同。
@MainActor
struct WearHistoryFetchTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    /// 只显示本柜的记录（别柜的一条都不许进来）。
    @Test func onlyThisClosetsRecordsAppear() throws {
        let ctx = try makeContext()
        let mine = Wardrobe(name: "Mine"); ctx.insert(mine)
        let other = Wardrobe(name: "Other"); ctx.insert(other)
        let tee = Item(name: "Tee"); tee.wardrobe = mine; ctx.insert(tee)
        try ctx.save()
        for (i, w) in [mine, other, mine].enumerated() {
            let r = WearRecord(date: Date().addingTimeInterval(-86_400 * Double(i)))
            r.wornItemIDs = [tee.id.uuidString]
            r.wardrobeSnapshotID = w.id
            ctx.insert(r)
        }
        try ctx.save()

        let vm = WearHistoryViewModel(wardrobe: mine)
        vm.load(in: ctx)
        #expect(vm.entries.count == 2)
    }

    /// 顺序与旧写法**逐条一致**（最近在前；同日按 id 决胜）。
    @Test func theOrderMatchesTheOldComparator() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let tee = Item(name: "Tee"); tee.wardrobe = w; ctx.insert(tee)
        try ctx.save()
        let sameDay = Date()
        for i in 0..<6 {
            let r = WearRecord(date: i < 3 ? sameDay
                               : Date().addingTimeInterval(-86_400 * Double(i)))
            r.wornItemIDs = [tee.id.uuidString]
            r.wardrobeSnapshotID = w.id
            ctx.insert(r)
        }
        try ctx.save()

        let legacy = (try ctx.fetch(FetchDescriptor<WearRecord>()))
            .filter { $0.wardrobeSnapshotID == w.id }
            .sorted { ($0.date, $0.id.uuidString) > ($1.date, $1.id.uuidString) }
        let vm = WearHistoryViewModel(wardrobe: w)
        vm.load(in: ctx)
        #expect(vm.entries.map(\.id) == legacy.map(\.id),
                "新旧顺序不同 —— 同一天多次打卡的次序会变")
    }

    /// 空历史不炸。
    @Test func anEmptyHistoryIsFine() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        try ctx.save()
        let vm = WearHistoryViewModel(wardrobe: w)
        vm.load(in: ctx)
        #expect(vm.entries.isEmpty)
    }
}
