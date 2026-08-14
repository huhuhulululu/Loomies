import Testing
import Foundation
import SwiftData
@testable import ClosetModel

/// D148：**同一条排序规则在仓里手抄了 19 遍，而它每次比较都分配两个 UUID 字符串。**
///
/// `($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString)` —— 元组比较**先算**
/// 两侧的全部分量再比，于是名字明明不同（绝大多数情况）也照样把两个 UUID
/// 格式化成字符串。衣柜网格在每次 `body` 求值里跑三遍全柜排序：
/// 200 件 ≈ 1500 次比较 × 2 次字符串分配 × 3 遍 = 单帧近万次无谓分配。
///
/// 同名才需要决胜——那时再取 `uuidString`。顺带把这条规则收成**一处**：
/// 19 份手抄意味着 19 次写错的机会（其中一处一旦把决胜写反，
/// 同名两行的顺序就会在不同界面之间打架）。
@MainActor
struct NameOrderTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    /// 按名字升序。
    @Test func itSortsByName() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        for n in ["Zulu", "Alpha", "Mike"] {
            let i = Item(name: n); i.wardrobe = w; ctx.insert(i)
        }
        try ctx.save()
        let sorted = (w.items ?? []).sortedByName()
        #expect(sorted.map(\.name) == ["Alpha", "Mike", "Zulu"])
    }

    /// 同名按 id 决胜——**与手抄那版逐个结果一致**（这是替换的前提）。
    @Test func itMatchesTheHandRolledComparatorExactly() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        // 大量同名，逼出决胜路径
        for _ in 0..<40 {
            let i = Item(name: "Tee"); i.wardrobe = w; ctx.insert(i)
        }
        for n in ["Alpha", "Zulu"] {
            let i = Item(name: n); i.wardrobe = w; ctx.insert(i)
        }
        try ctx.save()
        let items = w.items ?? []
        let legacy = items.sorted {
            ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString)
        }
        #expect(items.sortedByName().map(\.id) == legacy.map(\.id),
                "新旧排序结果不同 —— 同名两行的顺序会在不同界面之间打架")
    }

    /// 排序是确定的（同一份数据跑两次一样）。
    @Test func itIsDeterministic() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        for _ in 0..<10 { let i = Item(name: "Tee"); i.wardrobe = w; ctx.insert(i) }
        try ctx.save()
        let items = w.items ?? []
        #expect(items.sortedByName().map(\.id) == items.sortedByName().map(\.id))
    }

    /// 对每种带名字的实体都适用（一条规则，不是五条）。
    @Test func itWorksForEveryNamedEntity() throws {
        let ctx = try makeContext()
        let a = Wardrobe(name: "Beta"); let b = Wardrobe(name: "Alpha")
        ctx.insert(a); ctx.insert(b)
        let p1 = Person(name: "Zoe"); let p2 = Person(name: "Ada")
        ctx.insert(p1); ctx.insert(p2)
        let l1 = StorageLocation(name: "Shelf"); let l2 = StorageLocation(name: "Box")
        ctx.insert(l1); ctx.insert(l2)
        let o1 = Outfit(name: "Night"); let o2 = Outfit(name: "Day")
        ctx.insert(o1); ctx.insert(o2)
        try ctx.save()

        #expect([a, b].sortedByName().map(\.name) == ["Alpha", "Beta"])
        #expect([p1, p2].sortedByName().map(\.name) == ["Ada", "Zoe"])
        #expect([l1, l2].sortedByName().map(\.name) == ["Box", "Shelf"])
        #expect([o1, o2].sortedByName().map(\.name) == ["Day", "Night"])
    }

    /// 空集合不炸。
    @Test func anEmptyCollectionIsFine() {
        #expect([Item]().sortedByName().isEmpty)
    }

    /// 结构门：**不许再手抄这条规则**。19 份手抄是 19 次写错的机会。
    @Test func nobodyHandRollsThisComparatorAnymore() throws {
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
            guard url.path.contains("/Sources/") else { continue }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            scannedFileCount += 1
            for line in text.split(separator: "\n") {
                let t = line.trimmingCharacters(in: .whitespaces)
                guard !t.hasPrefix("//"), !t.hasPrefix("///") else { continue }
                if t.contains("id.uuidString) < (") {
                    offenders.append("\(url.lastPathComponent)")
                    break
                }
            }
        }
        #expect(scannedFileCount >= 80, Comment(rawValue:
            "只扫到 \(scannedFileCount) 个源文件 —— 遍历坏了，这道门在空转"))
        #expect(offenders.isEmpty, Comment(rawValue:
            "这些地方还在手抄「按名字排序、同名按 id 决胜」：\(offenders) —— 用 sortedByName()"))
    }
}
