import Testing
import Foundation
import SwiftData
@testable import ClosetUI
import ClosetModel
import ClosetCore

/// D210：Widget 上那几件衣服的**颜色**从哪来。
///
/// 先说一件不好看的：D197 交付 widget 时，`publishWidgetSnapshot`
/// **一条测试都没有**。快照结构、文案、读写、隐私边界全测了，
/// 唯独「App 到底往里写了什么」没人看着——而那正是用户在主屏上看见的东西。
///
/// 这一波要往快照里加颜色，先把这个洞补上。
@MainActor
struct TodayWidgetPublishTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    private func setup() throws -> (ModelContext, Wardrobe, URL) {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        try ctx.save()
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("widget-publish-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (ctx, w, dir)
    }

    @discardableResult
    private func item(
        _ ctx: ModelContext, _ w: Wardrobe, _ name: String, _ slot: String,
        hue: Double? = nil, neutral: Bool = false
    ) -> Item {
        let i = Item(name: name)
        // D194：不设这个标记的话，槽位由**名字**推断——"Navy blazer" 会变成 outerwear，
        // 于是这套永远缺个 top。夹具在这里模拟「用户明确选过 Type」。
        i.slotRaw = slot; i.slotUserSet = true
        i.statusRaw = "available"; i.wardrobe = w
        i.warmthRaw = Warmth.light.rawValue
        i.occasionsRaw = ["work"]
        i.colorHue = hue; i.colorIsNeutral = neutral
        ctx.insert(i)
        return i
    }

    /// 建议里的每件都带着自己的颜色出去。
    @Test func theSuggestedPiecesCarryTheirColours() throws {
        let (ctx, w, dir) = try setup()
        defer { try? FileManager.default.removeItem(at: dir) }
        item(ctx, w, "Navy blazer", "top", hue: 220, neutral: true)
        item(ctx, w, "Chinos", "bottom", hue: 90, neutral: true)
        item(ctx, w, "Loafers", "shoes", hue: 150, neutral: true)
        try ctx.save()

        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 70)
        vm.coldStartThreshold = 0   // 夹具只放三件，别落进冷启动那条不出建议的路
        vm.refresh()
        vm.publishWidgetSnapshot(directory: dir)

        let snap = try #require(TodayWidgetSnapshotStore.read(from: dir))
        #expect(!snap.pieces.isEmpty, "建议有内容，快照却是空的")
        for piece in snap.pieces {
            let id = try #require(piece.colorPaletteID, Comment(rawValue:
                "「\(piece.name)」设过颜色，快照里却没有 —— widget 上会是个空点"))
            #expect(GarmentColorPalette.entry(id: id) != nil, Comment(rawValue:
                "`\(id)` 不在调色板里 —— widget 还原不出来"))
        }
    }

    /// **同名两件不串色**。
    ///
    /// 这条钉的是实现方式：颜色必须跟着 **item 本体**走。
    /// 按名字回查是行得通的写法，直到衣橱里出现两件同名——
    /// 而「两件白 T」恰恰是衣橱里最常见的情形。
    @Test func twoPiecesWithTheSameNameDoNotSwapColours() throws {
        let (ctx, w, dir) = try setup()
        defer { try? FileManager.default.removeItem(at: dir) }
        item(ctx, w, "Tee", "top", hue: 0, neutral: true)        // black
        item(ctx, w, "Tee", "bottom", hue: 212, neutral: false)  // blue
        item(ctx, w, "Loafers", "shoes", hue: 150, neutral: true)
        try ctx.save()

        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 70)
        vm.coldStartThreshold = 0   // 夹具只放三件，别落进冷启动那条不出建议的路
        vm.refresh()
        vm.publishWidgetSnapshot(directory: dir)

        let snap = try #require(TodayWidgetSnapshotStore.read(from: dir))
        let tees = snap.pieces.filter { $0.name == "Tee" }
        // 硬断言，不是 `if tees.count == 2 { … }`：夹具一旦没造出「两件同名同时入选」，
        // 那种写法会静静地跳过检查而报绿（本 session 反复撞见的那个形状）。
        #expect(tees.count == 2, Comment(rawValue:
            "这套里只有 \(tees.count) 件 Tee —— 夹具没造出该测的情形，这条在空转"))
        #expect(Set(tees.compactMap(\.colorPaletteID)).count == 2, Comment(rawValue:
            "两件同名的 Tee 拿到了同一个颜色：\(tees.map { $0.colorPaletteID ?? "nil" }) "
            + "—— 颜色是按名字回查的，而衣橱里最常见的就是两件白 T"))
    }

    /// 没设颜色的件**不猜**——空着传出去，widget 上就是不画点。
    @Test func aPieceWithoutAColourPublishesNil() throws {
        let (ctx, w, dir) = try setup()
        defer { try? FileManager.default.removeItem(at: dir) }
        item(ctx, w, "Mystery top", "top")     // 没设颜色
        item(ctx, w, "Chinos", "bottom", hue: 90, neutral: true)
        item(ctx, w, "Loafers", "shoes", hue: 150, neutral: true)
        try ctx.save()

        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 70)
        vm.coldStartThreshold = 0   // 夹具只放三件，别落进冷启动那条不出建议的路
        vm.refresh()
        vm.publishWidgetSnapshot(directory: dir)

        let snap = try #require(TodayWidgetSnapshotStore.read(from: dir))
        let mystery = try #require(snap.pieces.first { $0.name == "Mystery top" },
                                   "没选中那件没颜色的 —— 这条在空转")
        #expect(mystery.colorPaletteID == nil, "没设颜色的件被猜了一个颜色")
    }

    /// 空衣橱照样写一份**空快照**——不留着昨天那份（D188 在 widget 上的复发面）。
    @Test func anEmptyClosetStillPublishes() throws {
        let (_, w, dir) = try setup()
        defer { try? FileManager.default.removeItem(at: dir) }
        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 70)
        vm.coldStartThreshold = 0   // 夹具只放三件，别落进冷启动那条不出建议的路
        vm.refresh()
        vm.publishWidgetSnapshot(directory: dir)

        let snap = try #require(TodayWidgetSnapshotStore.read(from: dir),
                                "空衣橱时干脆没写 —— widget 会一直显示上一次那身")
        #expect(snap.pieces.isEmpty)
    }
}
