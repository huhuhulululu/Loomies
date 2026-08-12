import Testing
import SwiftData
import Foundation
@testable import ClosetModel
import ClosetCore

/// D106（缺口清单 LOW，但 DESIGN §219 点名「零成本差异点」）：
/// 「距上次洗涤已穿几次」——MARKET 记录这是 Reddit 用户点名、**竞品无人做**的需求，
/// 而数据基础本就齐备（打卡记录 + 状态机），此前只是没人把它算出来。
///
/// 诚实边界：这是**显性化**，不是建议。不得说「该洗了」——
/// 多久该洗取决于面料、体感、季节，App 没有这些信息。
@MainActor
struct WearsSinceWashTests {

    func setup() throws -> (ModelContext, Wardrobe, Item) {
        let ctx = try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let i = Item(name: "Tee"); i.slotRaw = "top"; i.wardrobe = w
        i.statusRaw = "available"; ctx.insert(i)
        try ctx.save()
        return (ctx, w, i)
    }

    func wear(_ item: Item, in w: Wardrobe, ctx: ModelContext, daysAgo: Int) {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        _ = CheckInService.recordWear(items: [item], on: date, in: w, in: ctx)
    }

    /// 洗完之后从零数起。
    @Test func countsOnlyWearsAfterTheLastWash() throws {
        let (ctx, w, item) = try setup()
        wear(item, in: w, ctx: ctx, daysAgo: 10)
        wear(item, in: w, ctx: ctx, daysAgo: 9)
        // 送洗 → 洗完（回到可用）：这一刻是锚点
        #expect(ItemStatusService.setStatus(item, to: "inWash", in: ctx))
        #expect(ItemStatusService.setStatus(item, to: "available", in: ctx))
        #expect(item.lastWashedAt != nil)

        wear(item, in: w, ctx: ctx, daysAgo: 0)
        #expect(LaundryTracking.wearsSinceWash(item, in: ctx) == 1)
    }

    /// 从没洗过：**不得**谎称「距上次洗涤」——那是另一句话。
    @Test func neverWashedIsADifferentSentence() throws {
        let (ctx, w, item) = try setup()
        wear(item, in: w, ctx: ctx, daysAgo: 3)
        wear(item, in: w, ctx: ctx, daysAgo: 1)
        #expect(item.lastWashedAt == nil)
        #expect(LaundryTracking.wearsSinceWash(item, in: ctx) == 2)
        let caption = try #require(LaundryTracking.caption(item, in: ctx))
        #expect(!caption.localizedCaseInsensitiveContains("since wash"))
        #expect(caption.localizedCaseInsensitiveContains("2"))
    }

    /// 洗完还没再穿 → 不显示（0 次没有信息量，只是噪音）。
    @Test func zeroWearsShowsNothing() throws {
        let (ctx, w, item) = try setup()
        wear(item, in: w, ctx: ctx, daysAgo: 5)
        #expect(ItemStatusService.setStatus(item, to: "inWash", in: ctx))
        #expect(ItemStatusService.setStatus(item, to: "available", in: ctx))
        #expect(LaundryTracking.wearsSinceWash(item, in: ctx) == 0)
        #expect(LaundryTracking.caption(item, in: ctx) == nil)
    }

    /// 干洗同样算「洗过」。
    @Test func dryCleaningAlsoResetsTheCount() throws {
        let (ctx, w, item) = try setup()
        wear(item, in: w, ctx: ctx, daysAgo: 4)
        #expect(ItemStatusService.setStatus(item, to: "dryCleaning", in: ctx))
        #expect(ItemStatusService.setStatus(item, to: "available", in: ctx))
        #expect(LaundryTracking.wearsSinceWash(item, in: ctx) == 0)
    }

    /// 进洗衣状态**本身**不重置——洗完（回到可用）才算（否则送洗当天就清零了）。
    @Test func enteringWashDoesNotYetCount() throws {
        let (ctx, w, item) = try setup()
        wear(item, in: w, ctx: ctx, daysAgo: 2)
        #expect(ItemStatusService.setStatus(item, to: "inWash", in: ctx))
        #expect(item.lastWashedAt == nil, "送洗那一刻还没洗完")
        #expect(LaundryTracking.wearsSinceWash(item, in: ctx) == 1)
    }

    /// 外借/闲置回到可用**不算洗过**（只有洗衣态回来才算）。
    @Test func returningFromLentIsNotAWash() throws {
        let (ctx, w, item) = try setup()
        wear(item, in: w, ctx: ctx, daysAgo: 2)
        #expect(ItemStatusService.setStatus(item, to: "lent", in: ctx))
        #expect(ItemStatusService.setStatus(item, to: "available", in: ctx))
        #expect(item.lastWashedAt == nil)
        #expect(LaundryTracking.wearsSinceWash(item, in: ctx) == 1)
    }

    /// 文案是**显性化**不是建议——不得说「该洗了」。
    @Test func captionNeverPrescribesLaundry() throws {
        let (ctx, w, item) = try setup()
        for d in 0..<6 { wear(item, in: w, ctx: ctx, daysAgo: d) }
        let caption = try #require(LaundryTracking.caption(item, in: ctx))
        for word in ["should", "time to wash", "needs washing", "dirty"] {
            #expect(!caption.localizedCaseInsensitiveContains(word),
                    Comment(rawValue: "越界给了洗衣建议：\(caption)"))
        }
    }

    /// 状态保存失败时不得留下洗涤锚点。
    @Test func saveFailureLeavesNoWashStamp() throws {
        let (ctx, _, item) = try setup()
        #expect(ItemStatusService.setStatus(item, to: "inWash", in: ctx))
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        #expect(!ItemStatusService.setStatus(item, to: "available", in: ctx))
        #expect(item.lastWashedAt == nil)
        #expect(!ctx.hasChanges)
    }
}
