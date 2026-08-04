import Testing
import SwiftData
import Foundation
@testable import ClosetModel

@MainActor
struct DemoSeedServiceTests {

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
        let n1 = DemoSeedService.seedIfEmpty(w, in: ctx)
        #expect(n1 >= 5)
        #expect((w.items ?? []).count == n1)
        let n2 = DemoSeedService.seedIfEmpty(w, in: ctx)
        #expect(n2 == 0)
        #expect((w.items ?? []).count == n1)
    }

    @Test func seedCreatesAllCoreSlots() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Demo"); ctx.insert(w)
        _ = DemoSeedService.seed(w, in: ctx)
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
}
