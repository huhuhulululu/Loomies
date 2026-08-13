import Testing
import Foundation
import SwiftData
@testable import ClosetUI
import ClosetModel
import ClosetCore

/// D152：**推荐计算同步跑在主线程上，冷天实测 1959ms（改前 3013ms）。**
///
/// 两秒的计算换个线程不会变快——但界面不再冻。用户在冬天打开 Today 时
/// 至少能滚动、能点，而不是对着一个卡死的屏幕怀疑 App 挂了。
///
/// 切分点很干净：`RecommendationService.detailed` 只是把 SwiftData 的
/// `Wardrobe` 映射成 `[CandidateItem]` 再交给纯 Core。所以
/// **主线程快照成纯值 → 后台算 → 回主线程落地**，三段各司其职。
///
/// 危险在第三段：慢的那次回来时可能已经被新的一次取代（切了柜、换了场合、
/// 改了锚定）。落地必须带**代际**——这条纪律 D125（搜索）与 D116（天气）
/// 各栽过一次，不能再栽第三次。
@MainActor
struct RefreshOffMainTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    @discardableResult
    private func seed(_ ctx: ModelContext, count: Int = 4) throws -> Wardrobe {
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        for slot in ["top", "bottom", "shoes"] {
            for i in 0..<count {
                let it = Item(name: "\(slot)-\(i)")
                it.slotRaw = slot; it.statusRaw = "available"; it.wardrobe = w
                it.occasionsRaw = ["work"]; it.warmthRaw = Warmth.light.rawValue
                it.colorHue = Double(i * 40); it.colorIsNeutral = false
                ctx.insert(it)
            }
        }
        try ctx.save()
        return w
    }

    /// 异步路径给出的结果与同步路径**逐个一致**——否则「挪到后台」
    /// 就变成了偷偷换一套推荐。
    @Test func theAsyncPathAgreesWithTheSyncOne() throws {
        let ctx = try makeContext()
        let w = try seed(ctx)

        let syncVM = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 70)
        syncVM.fullAuto = true
        syncVM.refresh()

        let asyncVM = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 70)
        asyncVM.fullAuto = true
        let request = try #require(asyncVM.makeRefreshRequest())
        asyncVM.applyRefresh(CopilotViewModel.computeRefresh(request), for: request)

        #expect(asyncVM.suggestions.map(\.outfit.itemIDs)
                == syncVM.suggestions.map(\.outfit.itemIDs))
        #expect(!syncVM.suggestions.isEmpty)
    }

    /// **过期的那次不许落地。** 慢的一次回来时状态已经变了，
    /// 把旧结果盖上去等于给用户看一个他刚刚离开的世界。
    @Test func aStaleResultIsDropped() throws {
        let ctx = try makeContext()
        let w = try seed(ctx)
        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 70)
        vm.fullAuto = true

        let stale = try #require(vm.makeRefreshRequest())   // 领了代号
        let staleResult = CopilotViewModel.computeRefresh(stale)
        _ = vm.makeRefreshRequest()                          // 新的一次作废了它
        vm.applyRefresh(staleResult, for: stale)

        #expect(vm.suggestions.isEmpty, "过期的那次结果落地了")
    }

    /// 当前代照常落地。
    @Test func theCurrentResultLands() throws {
        let ctx = try makeContext()
        let w = try seed(ctx)
        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 70)
        vm.fullAuto = true
        let req = try #require(vm.makeRefreshRequest())
        vm.applyRefresh(CopilotViewModel.computeRefresh(req), for: req)
        #expect(!vm.suggestions.isEmpty)
    }

    /// 冷启动的早退分支（没锚定、件数不够）仍在**主线程当场**处理——
    /// 那条路不需要算任何东西，扔进后台只会让空态晚一帧出现。
    @Test func theColdStartShortcutNeedsNoBackgroundWork() throws {
        let ctx = try makeContext()
        let w = try seed(ctx, count: 1)      // 3 件，低于冷启动阈值
        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 70)
        #expect(vm.isColdStart)
        #expect(vm.makeRefreshRequest() == nil, "冷启动空态不该派一次后台计算")
        #expect(!vm.statusMessage.isEmpty, "早退分支没有就地给出空态文案")
    }

    /// **加载指示必须真的看得见。**
    ///
    /// spinner 在 hero 与 CTA 两处早就写好了，而同步路径下它**从来渲染不出来**：
    /// `isRefreshing = true` → 两秒同步计算 → `= false`，全发生在一次调用里，
    /// SwiftUI 根本没机会观察到 true。界面冻着，转圈也转不起来。
    ///
    /// 挪到后台之后它才第一次有意义——所以这条契约要钉住：
    /// 快照之后、落地之前，状态必须是「正在刷新」。
    @Test func theSpinnerIsObservableWhileComputing() throws {
        let ctx = try makeContext()
        let w = try seed(ctx)
        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 70)
        vm.fullAuto = true

        #expect(!vm.isRefreshing)
        let req = try #require(vm.makeRefreshRequest())
        #expect(vm.isRefreshing, "快照之后没有进入「正在刷新」—— 转圈永远不出现")
        vm.applyRefresh(CopilotViewModel.computeRefresh(req), for: req)
        #expect(!vm.isRefreshing, "算完了还挂着「正在刷新」—— CTA 会一直是禁用的")
    }

    /// 冷启动早退也要把状态收干净（那条路不派计算，但不能留着转圈）。
    @Test func theShortcutLeavesNoSpinnerBehind() throws {
        let ctx = try makeContext()
        let w = try seed(ctx, count: 1)
        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 70)
        #expect(vm.makeRefreshRequest() == nil)
        #expect(!vm.isRefreshing, "空态早退留下了一个永远转下去的圈")
    }

    /// 接线门：Today 必须真的走异步路径——否则这一波等于没做。
    @Test func todayActuallyUsesTheAsyncPath() throws {
        let text = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Sources/ClosetUI/CopilotView.swift"),
            encoding: .utf8)
        #expect(text.contains("refreshOffMain"),
                "Today 仍在主线程同步算推荐 —— 冬天那两秒照冻")
    }
}
