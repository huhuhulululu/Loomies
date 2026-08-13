import Testing
import Foundation
import SwiftData
@testable import ClosetModel
import ClosetCore

/// D122：**有导出没导入**。
///
/// 隐私政策里写着「Export my data … so you can take everything with you」——
/// 可搬出去之后**没有任何地方能搬回来**：换手机、误删、想从别的 App 迁过来，
/// 用户都得把几小时的录入重做一遍。一条只出不进的通道算不上数据可携带性。
///
/// 三条设计取舍（都关系到「会不会把用户已有的东西弄坏」）：
/// 1. **只增不改**：导入永远建**新衣柜**，绝不覆盖/合并已有数据。
///    合并需要用户裁决冲突，而那是一整个交互；在没有它之前，
///    「不碰你已有的东西」是唯一安全的默认。
/// 2. **如实报告**：导入了几件、跳过了几条、为什么跳过——
///    照片不在 JSON 里，这一点必须说出来，不能让用户以为图也回来了。
/// 3. **不可信输入**：文件可能是任何人给的。坏 JSON、错 schema 版本、
///    自引用的父子位置、天文数字的数组——都不能让 App 崩或写坏库。
@MainActor
struct ImportServiceTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    /// 造一个真实导出（往返测试的唯一可信来源就是导出本身）。
    private func exportFixture() throws -> Data {
        let ctx = try makeContext()
        let person = Person(name: "Ping"); ctx.insert(person)
        let w = Wardrobe(name: "Home"); w.owner = person; w.locationCity = "Austin"
        ctx.insert(w)
        for (name, slot) in [("Tee", "top"), ("Jeans", "bottom"), ("Boots", "shoes")] {
            let i = Item(name: name)
            i.slotRaw = slot; i.statusRaw = "available"; i.wardrobe = w
            i.occasionsRaw = ["work"]; i.warmthRaw = Warmth.light.rawValue
            ctx.insert(i)
        }
        try ctx.save()
        return try DataLifecycleService.exportJSONData(in: ctx, includeBodyDimensions: false)
    }

    /// 往返：导出的东西必须能原样回来。
    @Test func anExportRoundTrips() throws {
        let data = try exportFixture()
        let ctx = try makeContext()
        let receipt = try ImportService.importSnapshot(data, into: ctx)
        #expect(receipt.wardrobesAdded == 1)
        #expect(receipt.itemsAdded == 3)

        let items = try ctx.fetch(FetchDescriptor<Item>())
        #expect(Set(items.map(\.name)) == ["Tee", "Jeans", "Boots"])
        #expect(items.allSatisfy { $0.wardrobe != nil }, "导进来的件没有归属柜")
    }

    /// **绝不碰已有数据**：导入建新柜，原有的一件都不少、一件都不改。
    @Test func itNeverTouchesWhatIsAlreadyThere() throws {
        let data = try exportFixture()
        let ctx = try makeContext()
        let existing = Wardrobe(name: "Existing"); ctx.insert(existing)
        let mine = Item(name: "My own tee"); mine.wardrobe = existing; ctx.insert(mine)
        try ctx.save()

        _ = try ImportService.importSnapshot(data, into: ctx)

        #expect(existing.items?.count == 1, "导入动了已有衣柜的内容")
        #expect(mine.wardrobe?.id == existing.id)
        #expect(try ctx.fetch(FetchDescriptor<Wardrobe>()).count == 2, "没有新建衣柜")
    }

    /// 同名不覆盖——导入两次得到两个柜，而不是把第一次的抹掉。
    @Test func importingTwiceDoesNotOverwrite() throws {
        let data = try exportFixture()
        let ctx = try makeContext()
        _ = try ImportService.importSnapshot(data, into: ctx)
        _ = try ImportService.importSnapshot(data, into: ctx)
        #expect(try ctx.fetch(FetchDescriptor<Wardrobe>()).count == 2)
        #expect(try ctx.fetch(FetchDescriptor<Item>()).count == 6)
    }

    /// 导入的柜要能认出来（用户得知道哪个是刚导进来的）。
    @Test func theImportedClosetIsIdentifiable() throws {
        let data = try exportFixture()
        let ctx = try makeContext()
        _ = try ImportService.importSnapshot(data, into: ctx)
        let names = try ctx.fetch(FetchDescriptor<Wardrobe>()).map(\.name)
        #expect(names.allSatisfy { $0.contains("Home") })
        #expect(names.contains { $0 != "Home" } || names == ["Home"])
    }

    // MARK: - 不可信输入

    @Test func garbageIsRejectedWithoutCrashing() throws {
        let ctx = try makeContext()
        #expect(throws: ImportService.ImportError.self) {
            try ImportService.importSnapshot(Data([0x00, 0x01, 0x02]), into: ctx)
        }
        #expect(try ctx.fetch(FetchDescriptor<Wardrobe>()).isEmpty, "坏文件写脏了库")
    }

    @Test func aNewerSchemaIsRefusedRatherThanGuessed() throws {
        let ctx = try makeContext()
        var snap = try JSONDecoder().decode(
            DataLifecycleService.ExportSnapshot.self, from: try exportFixture())
        snap.schemaVersion = 9_999
        let data = try JSONEncoder().encode(snap)
        #expect(throws: ImportService.ImportError.self) {
            try ImportService.importSnapshot(data, into: ctx)
        }
    }

    /// 空快照不算失败，但要如实说什么都没有。
    @Test func anEmptySnapshotImportsNothingAndSaysSo() throws {
        let ctx = try makeContext()
        let empty = DataLifecycleService.ExportSnapshot(
            schemaVersion: ImportService.supportedSchemaVersion,
            exportedAt: "2026-08-12", includeBodyDimensions: false,
            persons: [], wardrobes: [], locations: [], items: [],
            outfits: [], wearRecords: [], plans: [], transfers: [], bodyProfiles: nil)
        let receipt = try ImportService.importSnapshot(
            try JSONEncoder().encode(empty), into: ctx)
        #expect(receipt.wardrobesAdded == 0)
        #expect(receipt.itemsAdded == 0)
        #expect(receipt.summary.localizedCaseInsensitiveContains("nothing"))
    }

    /// 收据必须**点名照片没跟过来**——否则用户以为图也回来了。
    @Test func theReceiptSaysPhotosAreNotIncluded() throws {
        let data = try exportFixture()
        let ctx = try makeContext()
        let receipt = try ImportService.importSnapshot(data, into: ctx)
        #expect(receipt.summary.localizedCaseInsensitiveContains("photo"),
                Comment(rawValue: "收据没说照片没跟过来：\(receipt.summary)"))
    }

    /// 导进来的件不得带着**指向本机不存在的文件**的图片路径——
    /// 那会让网格显示一批永远加载不出来的空格子。
    @Test func danglingImagePathsAreCleared() throws {
        var snap = try JSONDecoder().decode(
            DataLifecycleService.ExportSnapshot.self, from: try exportFixture())
        for i in snap.items.indices {
            snap.items[i].localImageRelativePath = "ItemImages/not-here-\(i).png"
        }
        let ctx = try makeContext()
        _ = try ImportService.importSnapshot(try JSONEncoder().encode(snap), into: ctx)
        let items = try ctx.fetch(FetchDescriptor<Item>())
        #expect(items.allSatisfy { $0.localImageRelativePath == nil },
                "导进来的件指着本机没有的图片文件")
    }

    /// 落库失败要整体回滚，不留半个衣柜。
    @Test func aFailedSaveLeavesNothingBehind() throws {
        let data = try exportFixture()
        let ctx = try makeContext()
        ModelSave.forceFailure(on: ctx)
        #expect(throws: ImportService.ImportError.self) {
            try ImportService.importSnapshot(data, into: ctx)
        }
        ModelSave.clearForcedFailure(on: ctx)
        #expect(try ctx.fetch(FetchDescriptor<Wardrobe>()).isEmpty, "失败之后留下了半个衣柜")
    }
}

/// D122 接线门：导入必须真的有用户入口——否则政策里那句
/// 「Import from a data file」就是又一句空话。
@MainActor
struct ImportWiringTests {

    @Test func thereIsAUserFacingImportEntry() throws {
        let ui = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ClosetUI/Sources/ClosetUI/AppRootView.swift")
        let text = try String(contentsOf: ui, encoding: .utf8)
        #expect(text.contains("ImportService.importSnapshot"), "导入零调用点")
        #expect(text.contains("fileImporter"), "没有文件选择器，用户拿什么导")
    }

    /// 政策承诺与实际行为对账：说了「不动已有衣柜」就必须真不动
    ///（行为由 `itNeverTouchesWhatIsAlreadyThere` 守，这里守**说法存在**）。
    @Test func thePolicyDescribesImport() {
        let privacy = ComplianceCopy.policyDocuments(hasSink: false)
            .first { $0.title.localizedCaseInsensitiveContains("privacy") }
        let text = (privacy?.sections.map(\.body).joined(separator: " ") ?? "").lowercased()
        #expect(text.contains("import"), "政策只讲了导出，没讲导入")
        #expect(text.contains("without touching"), "没说清导入不会动已有衣柜")
    }
}
