import Testing
import Foundation
import SwiftData
@testable import ClosetUI
import ClosetModel
import ClosetCore

/// D117：**合身结论从来没出现在做决定的那一刻**。
///
/// MARKET §2 三处独立断言「合身是唯一无人占据的纵深」——竞品（Whering/Acloset/
/// Alta/Google Photos）都停在目录层。而本仓已经把它算出来了：`FitMarkService`
/// 有实现、有测试、有网格徽章……**Today 的建议行与试衣间零引用**。
/// 试衣间尤其讽刺：那里的字面问题就是「这件穿在我身上怎么样」。
///
/// 这一波不新增服务、不改排序（守 D85「不改推荐」），只把已有结论
/// 端到用户面前：整套里**最紧**的那条——因为决定「今天穿不穿这套」的
/// 是最勒的那一件，不是平均值。
@MainActor
struct OutfitFitMarkTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    /// 胸围 36 / 腰 28 的档案。
    private func profile(_ ctx: ModelContext) throws -> PersonBodyProfile {
        let p = PersonBodyProfile(personID: UUID())
        p.bustInches = 36
        p.waistInches = 28
        p.hipInches = 38
        ctx.insert(p)
        try ctx.save()
        return p
    }

    private func item(
        _ ctx: ModelContext, _ name: String, _ slot: String,
        chest: Double? = nil, waist: Double? = nil
    ) -> Item {
        let i = Item(name: name)
        i.slotRaw = slot
        i.statusRaw = "available"
        i.chestFlatWidthInches = chest
        i.waistFlatWidthInches = waist
        ctx.insert(i)
        return i
    }

    /// 一套里没有任何一件有实测 → nil（不编，也不显示空行）。
    @Test func noMeasurementsMeansNoVerdict() throws {
        let ctx = try makeContext()
        let p = try profile(ctx)
        let items = [item(ctx, "Tee", "top"), item(ctx, "Jeans", "bottom")]
        #expect(OutfitFitMark.tightest(items: items, profile: p) == nil)
    }

    /// 没有身体档案 → nil（合身判定的前提是用户给过维度）。
    @Test func noProfileMeansNoVerdict() throws {
        let ctx = try makeContext()
        let items = [item(ctx, "Tee", "top", chest: 18)]
        #expect(OutfitFitMark.tightest(items: items, profile: nil) == nil)
    }

    /// 单件：直接给该件的结论。
    @Test func aSinglePieceReportsItsOwnVerdict() throws {
        let ctx = try makeContext()
        let p = try profile(ctx)
        // 胸 36，平铺 18 → ease = 0 → 偏紧
        let tight = [item(ctx, "Tee", "top", chest: 18)]
        #expect(OutfitFitMark.tightest(items: tight, profile: p)?.verdict == .tight)
        // 平铺 20 → ease = 4 → 合身
        let ok = [item(ctx, "Shirt", "top", chest: 20)]
        #expect(OutfitFitMark.tightest(items: ok, profile: p)?.verdict == .fitted)
    }

    /// **最紧的那件说了算**——决定今天穿不穿这套的是最勒的那一件。
    @Test func theTightestPieceWins() throws {
        let ctx = try makeContext()
        let p = try profile(ctx)
        let items = [
            item(ctx, "Loose shirt", "top", chest: 23),     // 松
            item(ctx, "Snug trousers", "bottom", waist: 14), // 腰 28，ease 0 → 紧
        ]
        let mark = try #require(OutfitFitMark.tightest(items: items, profile: p))
        #expect(mark.verdict == .tight)
        #expect(mark.pieceName == "Snug trousers", "点名的不是最紧那件")
    }

    /// 部分件没实测时，用有实测的那些下结论，并**如实**说还有几件不知道——
    /// 否则用户会以为这条结论覆盖了整套。
    @Test func itSaysHowManyPiecesAreUnknown() throws {
        let ctx = try makeContext()
        let p = try profile(ctx)
        let items = [
            item(ctx, "Shirt", "top", chest: 20),
            item(ctx, "Jeans", "bottom"),
            item(ctx, "Boots", "shoes"),
        ]
        let mark = try #require(OutfitFitMark.tightest(items: items, profile: p))
        #expect(mark.unmeasuredCount == 2)
        #expect(mark.summary.contains("2"), Comment(rawValue: "没说清还有几件不知道：\(mark.summary)"))
    }

    /// 全部有实测时不提「还有几件不知道」（别造噪声）。
    @Test func aFullyMeasuredLookSaysNothingExtra() throws {
        let ctx = try makeContext()
        let p = try profile(ctx)
        let items = [item(ctx, "Shirt", "top", chest: 20)]
        let mark = try #require(OutfitFitMark.tightest(items: items, profile: p))
        #expect(mark.unmeasuredCount == 0)
        #expect(!mark.summary.localizedCaseInsensitiveContains("unknown"))
    }

    /// 文案守 §10.4 红线：只评价衣服，不评价身体。
    @Test func theSummaryNeverEvaluatesTheBody() throws {
        let ctx = try makeContext()
        let p = try profile(ctx)
        for chest in [16.0, 18.0, 20.0, 26.0] {
            let items = [item(ctx, "Top \(chest)", "top", chest: chest)]
            guard let mark = OutfitFitMark.tightest(items: items, profile: p) else { continue }
            let lower = mark.summary.lowercased()
            for word in ["flatter", "slimming", "hide your", "problem area"] {
                #expect(!lower.contains(word), Comment(rawValue: "踩红线：\(mark.summary)"))
            }
        }
    }

    /// 一件实测都没有时，给的是**入口**而不是空白——
    /// 否则走快速添加建库的用户永远看不到这条差异化能力存在。
    @Test func theInviteAppearsWhenNothingIsMeasured() {
        #expect(!OutfitFitMark.measureInvite.isEmpty)
        #expect(OutfitFitMark.measureInvite.localizedCaseInsensitiveContains("measure"))
    }

    /// 结构门：两个决策现场都必须真的用上它（本仓复发病是「算出来了没人调」）。
    @Test func bothDecisionSurfacesUseIt() throws {
        let dir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Sources/ClosetUI")
        for file in ["CopilotView.swift", "FittingRoomView.swift"] {
            let text = try String(
                contentsOf: dir.appendingPathComponent(file), encoding: .utf8)
            #expect(text.contains("OutfitFitMark"),
                    Comment(rawValue: "\(file) 里没有合身结论 —— 决定就发生在这个屏幕上"))
        }
    }
}

/// D117：头像是这个产品的门面，而第一屏那个模特对新用户来说是**陌生人**——
/// 从 Today 没有任何路径把它变成「像我」，用户得自己翻到 Me → Body 才发现能改。
/// BODY-AVATAR-USER-FLOW §5.3 本来就规定「一步到 Me → Body」。
@MainActor
struct AvatarEntryPointTests {

    private var sourcesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Sources/ClosetUI")
    }

    @Test func theHeroAvatarLeadsToTheBodyScreen() throws {
        let text = try String(
            contentsOf: sourcesDir.appendingPathComponent("CopilotView.swift"), encoding: .utf8)
        #expect(text.contains("BodyProfileView(personID:"),
                "Today 上没有通往身体设置的入口 —— 头像永远是个陌生人")
    }

    /// 入口必须是**小可点区域**而不是整块可点：整块会跟已有的 orbit 手势打架
    /// （转身也会被当成点击）。
    @Test func theEntryPointDoesNotSwallowTheOrbitGesture() throws {
        let text = try String(
            contentsOf: sourcesDir.appendingPathComponent("CopilotView.swift"), encoding: .utf8)
        #expect(text.contains("editBodyAffordance"))
        // 叠加（overlay）才是正确写法；把 BodyAvatarView 包进 NavigationLink 的
        // label 里就是吞手势——判据是「NavigationLink 之后紧跟着 BodyAvatarView」。
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var swallows = false
        for (i, line) in lines.enumerated() where line.contains("NavigationLink") {
            let window = lines[i..<min(lines.count, i + 4)].joined(separator: "\n")
            if window.contains("BodyAvatarView(") { swallows = true }
        }
        #expect(!swallows, "整块头像被包进 NavigationLink，orbit 手势会被吞掉")
        #expect(text.contains("overlay(alignment: .topLeading) { editBodyAffordance }"),
                "入口不是叠加上去的")
    }
}

/// D118 接线门：每日回访这条能力必须真的**被接上**——
/// 本仓的复发病正是「实现了 + 测试写了 + 零调用点」。
@MainActor
struct DailyRitualWiringTests {

    private var sourcesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Sources/ClosetUI")
    }

    /// 用户能开关它。
    @Test func thereIsAUserFacingSwitch() throws {
        let text = try String(
            contentsOf: sourcesDir.appendingPathComponent("AppRootView.swift"), encoding: .utf8)
        #expect(text.contains("DailyRitualScheduler"),
                "设置里没有每日回访的开关 —— 能力等于不存在")
        #expect(text.contains("DailyRitual.selectableHours"), "用户选不了时间")
    }

    /// 每次进 Today 都按衣柜当下的状态重排——
    /// 「配不配打扰用户」取决于衣柜此刻的样子，不是用户上次拨开关那一刻的样子。
    @Test func itIsRescheduledFromTheDailySurface() throws {
        let text = try String(
            contentsOf: sourcesDir.appendingPathComponent("CopilotView.swift"), encoding: .utf8)
        #expect(text.contains("DailyRitualScheduler.reschedule"))
    }

    /// 授权被拒必须把开关拨回去（显示「开」却一条不发是最典型的不诚实）。
    @Test func aDeniedPermissionTurnsTheSwitchBack() throws {
        let text = try String(
            contentsOf: sourcesDir.appendingPathComponent("AppRootView.swift"), encoding: .utf8)
        #expect(text.contains("dailyRitualOn = false"),
                "授权被拒后开关还显示着「开」")
    }
}
