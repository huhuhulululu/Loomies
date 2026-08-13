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

/// D134：**导入此前只搬了衣柜/单品/搭配**——穿着历史、计划、存放位置、
/// 主人、身体档案一条都没导，而收据只说「照片没跟过来」。
/// 用户以为搬完了，实际丢了一年的记录，且导入的柜**永远没有主人**：
/// copilot 的个性化与合身标记对它永久关闭。
@MainActor
struct ImportCompletenessTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    /// 造一份「什么都有」的导出。
    private func richExport() throws -> Data {
        let ctx = try makeContext()
        let person = Person(name: "Ping"); person.coldBias = 1; ctx.insert(person)
        let w = Wardrobe(name: "Home"); w.owner = person; ctx.insert(w)
        let rail = StorageLocation(name: "Rail"); rail.wardrobe = w; ctx.insert(rail)
        let tee = Item(name: "Tee"); tee.slotRaw = "top"; tee.statusRaw = "available"
        tee.wardrobe = w; tee.location = rail; ctx.insert(tee)
        let look = ClosetModel.Outfit(name: "Look"); look.wardrobe = w; look.items = [tee]
        ctx.insert(look)
        let rec = WearRecord(date: Date().addingTimeInterval(-86_400))
        rec.wornItemIDs = [tee.id.uuidString]; rec.wardrobeSnapshotID = w.id
        ctx.insert(rec)
        let plan = CalendarPlan(date: Date()); plan.outfit = look; ctx.insert(plan)
        let profile = PersonBodyProfile(personID: person.id)
        profile.bustInches = 36; profile.waistInches = 28; ctx.insert(profile)
        try ctx.save()
        return try DataLifecycleService.exportJSONData(in: ctx, includeBodyDimensions: true)
    }

    @Test func everyTableComesOver() throws {
        let ctx = try makeContext()
        let receipt = try ImportService.importSnapshot(try richExport(), into: ctx)
        #expect(receipt.locationsAdded == 1, "存放位置没导过来")
        #expect(receipt.wearRecordsAdded == 1, "穿着历史没导过来 —— 用户丢了一年的记录")
        #expect(receipt.plansAdded == 1, "日历计划没导过来")
        #expect(try ctx.fetch(FetchDescriptor<Person>()).count == 1, "主人没导过来")
    }

    /// **导入的柜必须有主人**——没有主人就没有体型档案，
    /// copilot 个性化与合身标记对它永久关闭。
    @Test func theImportedClosetHasAnOwner() throws {
        let ctx = try makeContext()
        // D177 起身体档案要过同意门；这条测的是「跟着主人走」，故显式授予。
        let granted = BodyDataConsent(defaults: UserDefaults(
            suiteName: "loomies.test.owner.\(UUID().uuidString)")!)
        granted.setGranted(true)
        _ = try ImportService.importSnapshot(try richExport(), into: ctx, consent: granted)
        let w = try #require(try ctx.fetch(FetchDescriptor<Wardrobe>()).first)
        #expect(w.owner != nil)
        let profiles = try ctx.fetch(FetchDescriptor<PersonBodyProfile>())
        #expect(profiles.first?.personID == w.owner?.id, "身体档案没跟着主人过来")
    }

    /// 穿着记录里的单品引用是**软引用**，必须重映射到新 id——
    /// 不映射的话导进来的记录指向一批本机不存在的单品，等于没导。
    @Test func wearRecordsPointAtTheImportedPieces() throws {
        let ctx = try makeContext()
        _ = try ImportService.importSnapshot(try richExport(), into: ctx)
        let tee = try #require(try ctx.fetch(FetchDescriptor<Item>()).first)
        let rec = try #require(try ctx.fetch(FetchDescriptor<WearRecord>()).first)
        #expect(rec.wornItemIDs == [tee.id.uuidString])
        #expect(rec.wardrobeSnapshotID == tee.wardrobe?.id, "记录挂在别的柜的快照上")
    }

    /// 单品的存放位置要跟过来（否则位置树是空的，而件说自己没地方放）。
    @Test func itemsKeepTheirStorageSpot() throws {
        let ctx = try makeContext()
        _ = try ImportService.importSnapshot(try richExport(), into: ctx)
        let tee = try #require(try ctx.fetch(FetchDescriptor<Item>()).first)
        #expect(tee.location?.name == "Rail")
    }

    /// 收据要**说出**这些也搬过来了——否则用户无从判断搬全了没有。
    @Test func theReceiptNamesWhatElseCameOver() throws {
        let ctx = try makeContext()
        let receipt = try ImportService.importSnapshot(try richExport(), into: ctx)
        #expect(receipt.summary.localizedCaseInsensitiveContains("wear"),
                Comment(rawValue: receipt.summary))
    }
}

/// D138：导入的边界。文件是**最不可信的输入**——谁给的都可能。
@MainActor
struct ImportEdgeCaseTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    private func snapshot(items: [DataLifecycleService.ItemDTO],
                          wardrobes: [DataLifecycleService.WardrobeDTO] = []) throws -> Data {
        try JSONEncoder().encode(DataLifecycleService.ExportSnapshot(
            schemaVersion: ImportService.supportedSchemaVersion,
            exportedAt: "2026-08-13", includeBodyDimensions: false,
            persons: [], wardrobes: wardrobes, locations: [], items: items,
            outfits: [], wearRecords: [], plans: [], transfers: [], bodyProfiles: nil))
    }

    private func item(_ id: String, notes: String? = nil, wardrobeID: String? = nil)
        -> DataLifecycleService.ItemDTO {
        DataLifecycleService.ItemDTO(
            id: id, name: "Tee", wardrobeID: wardrobeID, locationID: nil,
            statusRaw: "available", slotRaw: "top", subtype: nil,
            occasionsRaw: [], warmthRaw: nil, colorHue: nil, colorIsNeutral: false,
            attributesRaw: [], brand: nil, sizeLabel: nil, sizeSystemRaw: nil,
            chestFlatWidthInches: nil, waistFlatWidthInches: nil, hipFlatWidthInches: nil,
            localImageRelativePath: nil, barcode: nil, careRaw: [], notes: notes,
            lastWashedAt: nil)
    }

    /// **备注要过净化门**——实体注释写着「落库前必过 sanitize」，
    /// 而导入的文件恰恰是最不可信的输入。
    @Test func importedNotesGoThroughTheSanitiser() throws {
        let ctx = try makeContext()
        let hostile = String(repeating: "x", count: 10_000) + "\u{0}\u{1}"
        _ = try ImportService.importSnapshot(
            try snapshot(items: [item("a", notes: hostile)]), into: ctx)
        let stored = try #require(try ctx.fetch(FetchDescriptor<Item>()).first)
        #expect(stored.notes == ItemNotes.sanitize(hostile))
        #expect((stored.notes ?? "").count < hostile.count, "长度上限没生效")
    }

    /// 有件没柜时不得留下**任何界面都看不到**的孤儿——
    /// `Wardrobe.items` 是唯一入口，没有归属就等于不存在，
    /// 而收据还会写「导入 N 件到 0 个衣柜」。
    @Test func itemsWithoutAClosetGetOne() throws {
        let ctx = try makeContext()
        let receipt = try ImportService.importSnapshot(
            try snapshot(items: [item("a"), item("b")]), into: ctx)
        #expect(receipt.wardrobesAdded == 1, "件被导进来却没有任何衣柜")
        let stored = try ctx.fetch(FetchDescriptor<Item>())
        #expect(stored.allSatisfy { $0.wardrobe != nil })
        #expect(!receipt.summary.contains("0 closets"))
    }
}
