import Testing
import Foundation
import SwiftData
@testable import ClosetUI
import ClosetModel
import ClosetCore

/// D125：**每敲一个字母就全表扫一遍**。
///
/// `onChange(of: text)` 直接调 `run(in:)`，而 `run` 会
/// fetch 全部 `Item` → 逐件 Unicode 折叠 → 排序。D120 我又在后面加了
/// 整柜穿着统计的批量取——等于把这条本来就重的路径**又加重了一层**，
/// 而它每敲一个字母跑一次。「navy」四个字母 = 四遍全表。
///
/// 防抖判据放在纯逻辑里才测得到（SwiftUI 的 task/timer 在 `swift test` 里观察不到）。
@MainActor
struct SearchDebounceTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    /// 文本输入要防抖——连打不该每个字母跑一遍。
    @Test func typingIsDebounced() {
        #expect(SearchViewModel.textDebounce > 0.1)
        #expect(SearchViewModel.textDebounce <= 0.4,
                "防抖太久会让搜索显得迟钝")
    }

    /// **筛选 chip 不防抖**：点一下就该立刻出结果，
    /// 那是一次明确的动作，不是连续输入。
    @Test func facetChangesRunImmediately() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let i = Item(name: "Navy tee"); i.slotRaw = "top"; i.statusRaw = "available"
        i.wardrobe = w; ctx.insert(i)
        try ctx.save()

        let vm = SearchViewModel()
        vm.homeWardrobeID = w.id
        vm.slotRaw = "top"
        vm.run(in: ctx)                    // 同步路径仍然可用
        #expect(vm.results.count == 1)
    }

    /// 代际：慢的那次回来时若已被新输入取代，结果必须被丢弃——
    /// 否则用户会看到上一个搜索词的结果。
    @Test func aStaleRunDoesNotOverwriteANewerOne() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        for name in ["Navy tee", "Red tee"] {
            let i = Item(name: name); i.slotRaw = "top"; i.statusRaw = "available"
            i.wardrobe = w; ctx.insert(i)
        }
        try ctx.save()

        let vm = SearchViewModel()
        vm.homeWardrobeID = w.id
        vm.text = "navy"
        let stale = vm.beginRun()          // 取一个代号
        vm.text = "red"
        vm.run(in: ctx)                    // 新的一次跑完
        let namesAfterFresh = vm.results.map(\.name)
        #expect(namesAfterFresh == ["Red tee"], Comment(rawValue: "\(namesAfterFresh)"))

        vm.applyIfCurrent(generation: stale, results: [], in: ctx)
        #expect(vm.results.map(\.name) == ["Red tee"],
                "过期的那次结果覆盖了更新的一次")
    }

    /// 当前代的结果正常落地。
    @Test func theCurrentRunApplies() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        try ctx.save()
        let vm = SearchViewModel()
        vm.homeWardrobeID = w.id
        let gen = vm.beginRun()
        vm.applyIfCurrent(generation: gen, results: [], in: ctx)
        #expect(vm.results.isEmpty)
    }

    /// 结构门：文本输入必须走防抖路径，不得直接 `run`。
    @Test func theTextFieldUsesTheDebouncedPath() throws {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/ClosetUI/AppRootView.swift")
        let text = try String(contentsOf: file, encoding: .utf8)
        #expect(text.contains("runDebounced"),
                "文本输入还在每个字母直接跑一遍全表扫描")
    }
}
