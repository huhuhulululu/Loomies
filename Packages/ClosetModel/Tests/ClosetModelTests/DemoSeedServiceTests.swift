import Testing
import SwiftData
import Foundation
@testable import ClosetModel

// .serialized：共享 ItemImageStore.rootDirectory 真盘目录 + 全局 forceFailure hook，
// 须与其他触盘套件互斥（ModelLaneGapFixesTests 的 seed 失败钉测）。
@MainActor
@Suite(.serialized) struct DemoSeedServiceTests {

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    @Test func seedIfEmptyInsertsOnce() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Demo"); ctx.insert(w)
        let o1 = DemoSeedService.seedIfEmpty(w, in: ctx)
        guard case .added(let n1) = o1 else {
            Issue.record("expected .added, got \(o1)")
            return
        }
        #expect(n1 >= 5)
        #expect((w.items ?? []).count == n1)
        let o2 = DemoSeedService.seedIfEmpty(w, in: ctx)
        #expect(o2 == .alreadyPopulated)
        #expect((w.items ?? []).count == n1)
    }

    @Test func seedCreatesAllCoreSlots() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Demo"); ctx.insert(w)
        let outcome = DemoSeedService.seed(w, in: ctx)
        #expect(outcome.committedCount >= 5)
        let slots = Set((w.items ?? []).map(\.slotRaw))
        #expect(slots.contains("top"))
        #expect(slots.contains("bottom"))
        #expect(slots.contains("shoes"))
    }

    @Test func seedAttachesPaperDollLayerImages() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Demo"); ctx.insert(w)
        _ = DemoSeedService.seed(w, in: ctx)
        let items = w.items ?? []
        #expect(!items.isEmpty)
        let withImage = items.filter { ($0.localImageRelativePath ?? "").isEmpty == false }
        #expect(withImage.count == items.count)
        // 至少一件能解码为 PNG 字节
        let sample = try #require(withImage.first?.localImageRelativePath)
        let data = ItemImageStore.loadData(relativePath: sample)
        #expect(data != nil)
        #expect((data?.count ?? 0) > 200)
        // 叠衣 composer 应标记 hasVisual
        let layers = OutfitAvatarComposer.layers(from: items)
        #expect(!layers.isEmpty)
        let visualCount = layers.filter(\.hasVisual).count
        #expect(visualCount == layers.count)
    }

    /// Seed silhouette slots follow displaySlot (outerwear blazer stacks with top, not as top).
    @Test func seedBlazerSilhouetteUsesOuterwearDisplaySlot() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Demo"); ctx.insert(w)
        _ = DemoSeedService.seed(w, in: ctx)
        let blazer = try #require(
            (w.items ?? []).first { $0.name.localizedCaseInsensitiveContains("blazer") })
        #expect(blazer.slotRaw == "outerwear")
        let layers = OutfitAvatarComposer.layers(from: [blazer])
        #expect(layers.map(\.slot) == [.outerwear])
        #expect(layers.first?.hasVisual == true)
        // Tee + blazer must stack two distinct body slots (displaySlot truth)
        let tee = try #require(
            (w.items ?? []).first { $0.name.localizedCaseInsensitiveContains("tee") })
        let stack = OutfitAvatarComposer.layers(from: [tee, blazer])
        #expect(stack.contains { $0.slot == .top })
        #expect(stack.contains { $0.slot == .outerwear })
    }

    /// Save-fail toast must not look like success (cold-start / Me Demo).
    @Test func seedOutcomeFlashMessagesAreHonest() {
        #expect(DemoSeedService.saveFailedMessage.localizedCaseInsensitiveContains("couldn't load"))
        #expect(DemoSeedService.saveFailedMessage.localizedCaseInsensitiveContains("try again"))
        #expect(!DemoSeedService.saveFailedMessage.localizedCaseInsensitiveContains("added"))
        #expect(DemoSeedService.Outcome.saveFailed.flashMessage == DemoSeedService.saveFailedMessage)
        #expect(DemoSeedService.Outcome.alreadyPopulated.flashMessage
            .localizedCaseInsensitiveContains("already"))
        #expect(DemoSeedService.Outcome.added(9).flashMessage.contains("9"))
        #expect(!DemoSeedService.Outcome.saveFailed.meDemoFlashMessage
            .localizedCaseInsensitiveContains("sample pieces"))
        #expect(DemoSeedService.Outcome.saveFailed.committedCount == 0)
        #expect(DemoSeedService.Outcome.added(9).committedCount == 9)
        // Me Demo button VO — demo-only, not photo import / try-on.
        let hint = DemoSeedService.loadButtonAccessibilityHint
        #expect(hint.localizedCaseInsensitiveContains("demo"))
        #expect(hint.localizedCaseInsensitiveContains("not from your photos"))
        #expect(!hint.localizedCaseInsensitiveContains("try-on"))
        #expect(DemoSeedService.Outcome.added(3).meDemoFlashMessage
            .localizedCaseInsensitiveContains("sample"))
        #expect(DemoSeedService.Outcome.alreadyPopulated.meDemoFlashMessage
            .localizedCaseInsensitiveContains("already"))
    }

    /// M3: 去重序号取最大数字后缀 +1——seed→seed→删第一批→再 seed 不得重名。
    @Test func reseedAfterDeletingFirstBatchNeverDuplicatesNames() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Demo"); ctx.insert(w)
        _ = DemoSeedService.seed(w, in: ctx)          // 批 1：无后缀
        let batch1IDs = Set((w.items ?? []).map(\.id))
        _ = DemoSeedService.seed(w, in: ctx)          // 批 2：后缀 " 1"
        #expect((w.items ?? []).contains { $0.name.hasSuffix(" 1") })
        // 删掉第一批（旧实现 existing/5+1 会重算出已用过的序号 → 重名）
        let survivors = (w.items ?? []).filter { !batch1IDs.contains($0.id) }
        for item in (w.items ?? []) where batch1IDs.contains(item.id) {
            if let path = item.localImageRelativePath {
                ItemImageStore.delete(relativePath: path)
            }
            ctx.delete(item)
        }
        try ctx.save()
        _ = DemoSeedService.seed(w, in: ctx)          // 批 3：后缀必须取 max+1 = " 2"
        let names = (w.items ?? []).map(\.name)
        #expect(Set(names).count == names.count)
        #expect(names.contains { $0.hasSuffix(" 2") })
        #expect(survivors.allSatisfy { $0.name.hasSuffix(" 1") })
    }
}
