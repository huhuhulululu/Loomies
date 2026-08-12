import Testing
import Foundation
import SwiftData
@testable import ClosetUI
import ClosetModel
import ClosetCore

/// D114：**入库两条路径与详情页的场合控件不一致**。
///
/// D108 把详情页从「逗号分隔自由文本」改成多选，理由是场合是 `CandidateFilter`
/// 的硬过滤输入。但两条**入库**路径还是单选 `Picker`：
/// - 一件衣服从入库那一刻起最多只能带**一个**场合，而现实里一条黑裤子
///   既能上班也能约会；
/// - 更隐蔽的是空集时 `get` 返回 `"casual"`——控件**显示成已选 Casual**，
///   用户以为设过了，实际库里是空集（未知）。两种状态在界面上无法区分。
///
/// 后果：用拍照批量建起来的衣柜，每件只带一个场合，换个场合就被硬门筛成零；
/// 而用户看不到任何异样——正是 D108 要消灭的那类缺陷，只是换了个入口。
@MainActor
struct IntakeOccasionParityTests {

    private var sourcesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/ClosetUI")
    }

    /// 结构门：入库不得再用单选 Picker 收场合。
    @Test func intakePathsUseTheSameMultiSelectAsDetail() throws {
        let text = try String(
            contentsOf: sourcesDir.appendingPathComponent("PhotoCaptureViews.swift"),
            encoding: .utf8)
        #expect(!text.contains("Picker(\"Occasion\""),
                "入库还在用单选 Picker 收场合 —— 一件衣服只能带一个场合")
        #expect(text.contains("OccasionChips"),
                "入库没有复用详情页那个多选控件（D108）")
    }

    /// 手动新增的草稿必须能带多个场合。
    @Test func manualDraftCarriesMultipleOccasions() throws {
        let ctx = try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        try ctx.save()

        var draft = QuickAddDraft()
        draft.name = "Black trousers"
        draft.slotRaw = "bottom"
        draft.occasions = ["work", "date"]
        let item = try #require(draft.commit(into: w, context: ctx))
        #expect(Set(item.occasionsRaw) == ["work", "date"])
    }

    /// 一件都不选 = 未知（三值语义），**不得**被偷偷写成 casual。
    @Test func selectingNoneMeansUnknownNotCasual() throws {
        let ctx = try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        try ctx.save()

        var draft = QuickAddDraft()
        draft.name = "Anything tee"
        draft.slotRaw = "top"
        draft.occasions = []
        let item = try #require(draft.commit(into: w, context: ctx))
        #expect(item.occasionsRaw.isEmpty, "空集被偷偷写成了某个场合")

        // 三值语义兑现：未知不被任何场合的硬门筛掉
        for occasion in OccasionMix.choices {
            let kept = CandidateFilter.filter(
                [item.toCandidateItem()],
                context: FilterContext(occasion: occasion, daytimeTempF: 70))
            #expect(kept.count == 1,
                    Comment(rawValue: "未标场合的件在 \(occasion) 被筛掉了"))
        }
    }

    /// 多场合的件在**每个**所选场合下都被留下（这正是改多选的理由）。
    @Test func aMultiOccasionPieceSurvivesEachOfThem() throws {
        let ctx = try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        try ctx.save()

        var draft = QuickAddDraft()
        draft.name = "Black trousers"
        draft.slotRaw = "bottom"
        draft.occasions = ["work", "date"]
        let item = try #require(draft.commit(into: w, context: ctx))

        for occasion in ["work", "date"] {
            let kept = CandidateFilter.filter(
                [item.toCandidateItem()],
                context: FilterContext(occasion: occasion, daytimeTempF: 70))
            #expect(kept.count == 1, Comment(rawValue: "\(occasion) 下被筛掉了"))
        }
        let gala = CandidateFilter.filter(
            [item.toCandidateItem()],
            context: FilterContext(occasion: "gala", daytimeTempF: 70))
        #expect(gala.isEmpty, "没选的场合也被留下 —— 硬门形同虚设")
    }
}
