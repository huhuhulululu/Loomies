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
    @Test func aStaleRunDoesNotOverwriteANewerOne() async throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        for name in ["Navy tee", "Red tee"] {
            let i = Item(name: name); i.slotRaw = "top"; i.statusRaw = "available"
            i.wardrobe = w; ctx.insert(i)
        }
        try ctx.save()

        let vm = SearchViewModel()
        vm.homeWardrobeID = w.id

        // D146：过去这里用 `beginRun()` + `applyIfCurrent(generation:)` 演示
        // 「慢的那次回来覆盖了新的一次」——而 `applyIfCurrent` **生产零调用点**，
        // 那条路根本不存在：`run(in:)` 每次都现读 `vm.text` 现查，
        // 一个迟到的防抖任务醒来只会照着**当前**输入再查一遍，
        // 结果与用户此刻看到的一致。演出来的风险不是风险。
        //
        // 真正该守的用户保证只有一条：无论中间发生过什么，
        // 屏幕上的结果对得上输入框里的字。
        vm.text = "navy"
        let inFlight = Task { await vm.runDebounced(in: ctx) }
        await Task.yield()              // 让它领到代号并进入 sleep
        vm.text = "red"
        vm.run(in: ctx)
        #expect(vm.results.map(\.name) == ["Red tee"])
        await inFlight.value             // 迟到的那次醒来
        #expect(vm.results.map(\.name) == ["Red tee"],
                "迟到的那次防抖把结果搅乱了")
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

/// D134：新加的筛必须进 `clear()`，否则「清除」清不干净——
/// 用户点了清除仍卡在「没有匹配」，而屏幕上看不出还有哪个筛在生效。
@MainActor
struct SearchClearCompletenessTests {

    /// 清除要把**每一个**筛项归零。
    @Test func clearResetsEveryFacet() {
        let vm = SearchViewModel()
        vm.text = "navy"
        vm.slotRaw = "top"
        vm.occasion = "work"
        vm.statusRaw = "available"
        vm.colorPaletteID = "navy"
        vm.clear()
        #expect(!vm.isFiltering, "清除之后仍有筛项在生效")
        #expect(vm.colorPaletteID == nil, "颜色筛没被清掉 —— 用户会卡在「没有匹配」")
    }

    /// 结构门：`isFiltering` 认得的每个筛项，`clear()` 都得清。
    /// （下一个人加筛项时，漏改 `clear` 会红。）
    @Test func clearCoversEverythingIsFilteringKnowsAbout() throws {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/ClosetUI/SearchViewModel.swift")
        let text = try String(contentsOf: file, encoding: .utf8)
        func body(after marker: String) -> String {
            guard let r = text.range(of: marker) else { return "" }
            return String(text[r.upperBound...].prefix(400))
        }
        let filtering = body(after: "public var isFiltering: Bool {")
        let clearing = body(after: "public func clear() {")
        for facet in ["text", "slotRaw", "occasion", "statusRaw", "colorPaletteID"]
        where filtering.contains(facet) {
            #expect(clearing.contains(facet),
                    Comment(rawValue: "`clear()` 漏了 \(facet)"))
        }
    }
}
