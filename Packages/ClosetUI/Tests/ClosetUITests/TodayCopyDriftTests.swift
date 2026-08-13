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

/// D198：**装文字的 chip 不许写死高度。**
///
/// 属性 / 场合 / 颜色三种 chip 都是 `Text(...).frame(height: 32)`——
/// 而无障碍大字号下 `.caption` 能长到 40pt 以上，32pt 的框会把字**裁掉**。
/// 用户看得见，且这是同一条规则的**四份手抄**（本仓最熟的那个病）。
///
/// 收成 `DS.chipMinHeight` 并改 `minHeight`：视觉高度不变，字长了能撑开。
///
/// 判据只看**装了文字的**固定高度——头像图那类固定尺寸是正当的
///（`FullNudeBodyImageView(...).frame(height: 88)` 画的是图，不是字）。
@MainActor
struct DynamicTypeSafetyTests {

    @Test func theChipHeightTokenExists() {
        #expect(DS.chipMinHeight > 0)
    }

    /// 结构门：源码里不许再出现「固定高度包着 Text」。
    @Test func noTextSitsInAFixedHeightBox() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/ClosetUI")
        var offenders: [String] = []
        var scanned = 0
        for case let url as URL in FileManager.default
            .enumerator(at: root, includingPropertiesForKeys: nil)!
        where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init)
            for (i, line) in lines.enumerated() {
                let t = line.trimmingCharacters(in: .whitespaces)
                guard !t.hasPrefix("//"), !t.hasPrefix("///") else { continue }
                guard t.contains(".frame(height:") else { continue }
                scanned += 1
                // 认**构造**：从这行往上找第一个不是修饰符的行——那才是被框住的视图。
                //
                // 第一版拿 8 行窗口找 `Text(` 再排除含 `View(` 的，当场假绿：
                // `ScrollView(` 也含 `View(`，把整条排除掉了。判据在**排除侧**
                // 太宽与在断言侧太松是同一个病（D175/D183 记过两次，这是第三次）。
                var framed: String?
                var j = i - 1
                while j >= 0 {
                    let candidate = lines[j].trimmingCharacters(in: .whitespaces)
                    if !candidate.isEmpty, !candidate.hasPrefix("."),
                       !candidate.hasPrefix("//") {
                        framed = candidate
                        break
                    }
                    j -= 1
                }
                if let framed, framed.hasPrefix("Text(") {
                    offenders.append("\(url.lastPathComponent):\(i + 1) ~ \(framed.prefix(40))")
                }
            }
        }
        #expect(scanned >= 4, Comment(rawValue: "只扫到 \(scanned) 处 frame(height:)：口径坏了"))
        #expect(offenders.isEmpty, Comment(rawValue:
            "这些地方用固定高度框住了文字，大字号会裁掉：\(offenders) —— 用 minHeight"))
    }
}
