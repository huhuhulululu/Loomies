import Testing
import Foundation
import SwiftData
@testable import ClosetUI
import ClosetModel
import ClosetCore

/// D192：Today 上两处口径漂移。
@MainActor
struct TodayCopyDriftTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    private func warmWardrobe(_ ctx: ModelContext) throws -> Wardrobe {
        let w = Wardrobe(name: "Home"); ctx.insert(w)
        let slots = ["top", "bottom", "shoes", "outerwear"]
        for i in 0..<16 {
            let item = Item(name: "piece-\(i)")
            item.wardrobe = w
            item.slotRaw = slots[i % slots.count]
            item.statusRaw = "available"
            item.warmthRaw = Warmth.medium.rawValue
            item.occasionsRaw = ["casual"]
            ctx.insert(item)
        }
        try ctx.save()
        return w
    }

    // MARK: - #10 「Look 1 of N」翻页后不更新

    /// 翻到第 3 套时，那行字得跟着走。
    ///
    /// `statusMessage` 只在刷新落地那一处写「Look 1 of N」（且刚把 index 置 0），
    /// 而 `selectSuggestion` / next / previous 一个都不写它——恒为「Look 1 of N」。
    /// 同屏的 hero 却印着 `\(index + 1)/\(lookCount)`：翻到最后一套时
    /// 屏幕上并排显示「3/3」和「Look 1 of 3」。
    ///
    /// 这里不给生产加测试专用钩子（建议列表来自引擎，构造它要跑整条推荐链）：
    /// 计数文案抽成纯函数直接测，**翻页有没有去写它**用结构门钉。
    @Test func theCounterSentenceHasOneSource() {
        #expect(CopilotViewModel.lookCounter(index: 0, total: 3) == "Look 1 of 3")
        #expect(CopilotViewModel.lookCounter(index: 2, total: 3) == "Look 3 of 3")
        #expect(CopilotViewModel.lookCounter(index: 0, total: 0) == "",
                "没有建议时不该印计数（那行字要留给空态理由）")
        #expect(CopilotViewModel.lookCounter(index: 9, total: 3) == "Look 3 of 3",
                "越界索引要收敛，不许印「Look 10 of 3」")
    }

    /// 结构门：**翻页必须改写那行字。**
    @Test func selectingASuggestionRewritesTheStatusLine() throws {
        let text = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Sources/ClosetUI/CopilotViewModel.swift"),
            encoding: .utf8)
        let r = try #require(text.range(of: "public func selectSuggestion(at index: Int)"))
        let rest = text[r.lowerBound...]
        let end = rest.range(of: "\n    public func selectNextLook")?.lowerBound ?? rest.endIndex
        let body = String(rest[rest.startIndex..<end])
        #expect(body.contains("lookCounter"), Comment(rawValue:
            "翻页没有改写计数行 —— hero 印 3/3，这行还写着 Look 1 of 3：\(body)"))
    }

    // MARK: - #11 Today 的场合清单是第二张手抄表

    /// Today 的场合选项要走 `OccasionMix`，不许自己抄一张。
    ///
    /// `OccasionMix` 自称与 `CandidateFilter` 同源、明写「不得另开一套」，
    /// 而 Today 的 picker 是 `["work", "date", "gala", "casual"]` + `.capitalized`——
    /// 于是详情页把它叫「Events」、Today 叫「Gala」，同一个东西两个名字。
    /// 值集合当前恰好一致，所以还没筛空；手抄表不跟随 `choices` 才是真风险面。
    @Test func todayUsesTheSharedOccasionList() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Sources/ClosetUI/CopilotView.swift"),
            encoding: .utf8)
        let handRolled = source.split(separator: "\n").filter { line in
            let t = line.trimmingCharacters(in: .whitespaces)
            return t.contains("\"gala\"") && !t.hasPrefix("//") && !t.hasPrefix("///")
        }
        #expect(handRolled.isEmpty, Comment(rawValue:
            "Today 自己抄了一张场合表：\(handRolled) —— 用 OccasionMix.choices"))
        #expect(source.contains("OccasionMix.choices"), "没走共享清单")
    }

    /// 显示名走 `displayTitle`，不是 `.capitalized`（后者出「Gala」，那边叫「Events」）。
    @Test func theOccasionLabelsMatchTheRestOfTheApp() {
        #expect(OccasionMix.displayTitle("gala") == "Events")
        let source = try? String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Sources/ClosetUI/CopilotView.swift"),
            encoding: .utf8)
        #expect((source ?? "").contains("OccasionMix.displayTitle"))
    }
}
