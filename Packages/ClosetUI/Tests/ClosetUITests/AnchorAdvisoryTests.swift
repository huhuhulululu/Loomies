import Testing
import Foundation
import SwiftData
@testable import ClosetUI
import ClosetModel
import ClosetCore

/// D131：**锚定件绕过全部四条门，而用户不会知道**。
///
/// 锚定的那件直接进结果、不过场合/温区过滤——这本身**是对的**：
/// 用户说「我今天就要穿这件」，产品不该反过来教育他（同 D126 的判断）。
///
/// 错的是**不吭声**：85°F 的日子锚了一件厚大衣，App 照常端出几套带大衣的搭配，
/// 一句「今天这个温度它偏厚」都没有。用户要么以为 App 觉得这样合适，
/// 要么以为温区过滤坏了。
///
/// 所以不是筛掉它，是**说出来**。
@MainActor
struct AnchorAdvisoryTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    private func setup() throws -> (ModelContext, Wardrobe) {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        try ctx.save()
        return (ctx, w)
    }

    private func item(
        _ ctx: ModelContext, _ w: Wardrobe, _ name: String, _ slot: String,
        warmth: Warmth? = .light, occasions: [String] = ["work"]
    ) -> Item {
        let i = Item(name: name)
        i.slotRaw = slot; i.statusRaw = "available"; i.wardrobe = w
        i.warmthRaw = warmth?.rawValue
        i.occasionsRaw = occasions
        ctx.insert(i)
        return i
    }

    /// 锚了一件今天太厚的 → 如实提示（但**照样用**）。
    @Test func anOutOfBandAnchorIsCalledOut() throws {
        let (ctx, w) = try setup()
        let coat = item(ctx, w, "Wool coat", "outerwear", warmth: .veryWarm)
        try ctx.save()

        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 85)
        vm.toggleAnchor(coat)
        vm.refresh()
        let note = try #require(vm.anchorAdvisory)
        #expect(note.contains("Wool coat"), Comment(rawValue: note))
        #expect(note.localizedCaseInsensitiveContains("warm")
                || note.localizedCaseInsensitiveContains("today"),
                Comment(rawValue: note))
    }

    /// 锚了一件与今天场合不符的 → 同样如实提示。
    @Test func anOffOccasionAnchorIsCalledOut() throws {
        let (ctx, w) = try setup()
        let gown = item(ctx, w, "Gala gown", "dress", occasions: ["gala"])
        try ctx.save()

        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 70)
        vm.toggleAnchor(gown)
        vm.refresh()
        let note = try #require(vm.anchorAdvisory)
        #expect(note.contains("Gala gown"))
    }

    /// 合适的锚定不提示（别造噪声）。
    @Test func aSuitableAnchorSaysNothing() throws {
        let (ctx, w) = try setup()
        let tee = item(ctx, w, "Work tee", "top", warmth: .light, occasions: ["work"])
        try ctx.save()

        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 70)
        vm.toggleAnchor(tee)
        vm.refresh()
        #expect(vm.anchorAdvisory == nil)
    }

    /// **温度未知时不提示**——不知道冷暖就没资格说「今天偏厚」（D130 的纪律）。
    @Test func anUnknownTemperatureMakesNoWeatherClaim() throws {
        let (ctx, w) = try setup()
        let coat = item(ctx, w, "Wool coat", "outerwear", warmth: .veryWarm)
        try ctx.save()

        let vm = CopilotViewModel(wardrobe: w, occasion: "work")   // 温度未知
        vm.toggleAnchor(coat)
        vm.refresh()
        #expect(vm.anchorAdvisory == nil,
                "天气都不知道，却断言这件今天偏厚")
    }

    /// 未标温区/场合的件不提示（三值语义：未知不是「不合适」）。
    @Test func unknownAttributesAreNotCalledOut() throws {
        let (ctx, w) = try setup()
        let mystery = item(ctx, w, "Mystery piece", "top", warmth: nil, occasions: [])
        try ctx.save()

        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 85)
        vm.toggleAnchor(mystery)
        vm.refresh()
        #expect(vm.anchorAdvisory == nil)
    }

    /// 取消锚定后提示消失。
    @Test func theAdvisoryClearsWhenTheAnchorGoes() throws {
        let (ctx, w) = try setup()
        let coat = item(ctx, w, "Wool coat", "outerwear", warmth: .veryWarm)
        try ctx.save()

        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 85)
        vm.toggleAnchor(coat)
        vm.refresh()
        #expect(vm.anchorAdvisory != nil)
        vm.toggleAnchor(coat)
        vm.refresh()
        #expect(vm.anchorAdvisory == nil)
    }

    /// 锚定件**仍然出现在结果里**——提示不是变相的过滤。
    @Test func theAnchorIsStillHonoured() throws {
        let (ctx, w) = try setup()
        let coat = item(ctx, w, "Wool coat", "outerwear", warmth: .veryWarm)
        _ = item(ctx, w, "Tee", "top")
        _ = item(ctx, w, "Jeans", "bottom")
        _ = item(ctx, w, "Boots", "shoes")
        try ctx.save()

        let vm = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 85)
        vm.toggleAnchor(coat)
        vm.refresh()
        #expect(vm.suggestions.allSatisfy {
            $0.outfit.itemIDs.contains(coat.id.uuidString)
        }, "提示变成了过滤 —— 用户说要穿的那件被拿掉了")
    }
}
