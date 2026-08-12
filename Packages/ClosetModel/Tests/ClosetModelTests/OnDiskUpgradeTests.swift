import Testing
import SwiftData
import Foundation
@testable import ClosetModel
import ClosetCore

/// D88：**盘上库**的升级路径。D84 把容器装配从「手搓 8 类型 + 两个 config、无
/// migrationPlan」换成了带 `LoomiesMigrationPlan` 的 `LoomiesStore.makeContainer`，
/// 而全部测试都跑在 `inMemory: true` 上——已发布用户（TestFlight build 30）的冷启动
/// 走的正是盘上路径，失败形态是启动 fatalError，app-shell 又不参与 swift test。
/// 「两边隐式版本都是 1.0.0 所以兼容」是推断，不是证据。这里给出证据。
@MainActor
struct OnDiskUpgradeTests {

    func makeStoreDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("loomies-store-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 旧写法建盘上库 → 新写法（带 migrationPlan）打开同一路径 → 数据完好。
    @Test func legacyOnDiskStoreOpensWithMigrationPlan() throws {
        let dir = try makeStoreDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let mainURL = dir.appendingPathComponent("main.store")
        let localURL = dir.appendingPathComponent("local.store")
        let personID = UUID()

        // ① 旧装配：无 migrationPlan，schema 由类型列表隐式推导
        do {
            let legacyMain = ModelConfiguration(
                LoomiesStore.mainConfigurationName,
                schema: Schema(LoomiesSchemaV1.mainModels),
                url: mainURL, cloudKitDatabase: .none)
            let legacyLocal = ModelConfiguration(
                LoomiesStore.localConfigurationName,
                schema: Schema(LoomiesSchemaV1.localModels),
                url: localURL, cloudKitDatabase: .none)
            let legacy = try ModelContainer(
                for: Schema(LoomiesSchemaV1.models),
                configurations: legacyMain, legacyLocal)
            let ctx = ModelContext(legacy)
            let p = Person(name: "Ada"); ctx.insert(p)
            let w = Wardrobe(name: "Main"); w.owner = p; ctx.insert(w)
            let item = Item(name: "tee"); item.slotRaw = "top"; item.wardrobe = w
            item.statusRaw = "available"; ctx.insert(item)
            let body = PersonBodyProfile(personID: personID); body.bustInches = 34
            ctx.insert(body)
            try ctx.save()
        }

        // ② 新装配（带 migrationPlan）打开同一批文件
        let upgradedMain = ModelConfiguration(
            LoomiesStore.mainConfigurationName, schema: LoomiesStore.mainSchema,
            url: mainURL, cloudKitDatabase: .none)
        let upgradedLocal = ModelConfiguration(
            LoomiesStore.localConfigurationName, schema: LoomiesStore.localSchema,
            url: localURL, cloudKitDatabase: .none)
        let upgraded = try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: upgradedMain, upgradedLocal)
        let ctx = ModelContext(upgraded)

        // ③ 数据完好——包括本地域的身体维度（跨两个 store 文件）
        #expect(try ctx.fetch(FetchDescriptor<Person>()).first?.name == "Ada")
        #expect(try ctx.fetch(FetchDescriptor<Wardrobe>()).first?.name == "Main")
        #expect(try ctx.fetch(FetchDescriptor<Item>()).first?.name == "tee")
        let bodies = try ctx.fetch(FetchDescriptor<PersonBodyProfile>())
        #expect(bodies.count == 1)
        #expect(bodies.first?.bustInches == 34)
        #expect(bodies.first?.personID == personID)
    }

    /// 身体维度**确实**落在另一个 store 文件里（D5 的行级证据）。
    /// 此前的断言只证明了「主域 schema 不含该实体」——那是类型层的事实，
    /// 与「这一行写到了哪个文件」是两回事。
    @Test func bodyRowsLandInTheLocalStoreFileNotTheMainOne() throws {
        let dir = try makeStoreDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let mainURL = dir.appendingPathComponent("main.store")
        let localURL = dir.appendingPathComponent("local.store")

        let container = try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations:
                ModelConfiguration(LoomiesStore.mainConfigurationName,
                                   schema: LoomiesStore.mainSchema,
                                   url: mainURL, cloudKitDatabase: .none),
                ModelConfiguration(LoomiesStore.localConfigurationName,
                                   schema: LoomiesStore.localSchema,
                                   url: localURL, cloudKitDatabase: .none))
        let ctx = ModelContext(container)
        let p = Person(name: "Ada"); ctx.insert(p)
        let body = PersonBodyProfile(personID: p.id); body.bustInches = 34
        ctx.insert(body)
        try ctx.save()

        // 行级归属：两行的 storeIdentifier 必须不同（在不同的 store 文件里）
        let personStore = p.persistentModelID.storeIdentifier
        let bodyStore = body.persistentModelID.storeIdentifier
        #expect(personStore != nil)
        #expect(bodyStore != nil)
        #expect(personStore != bodyStore,
                Comment(rawValue: "身体数据与主数据落在同一个 store：\(bodyStore ?? "nil")"))
    }

    /// 只打开主域（本地域文件不给）时，主库里读不到任何身体维度——
    /// 「身体数据不在主库」这句承诺的最直接证据。
    @Test func mainStoreAloneCarriesNoBodyData() throws {
        let dir = try makeStoreDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let mainURL = dir.appendingPathComponent("main.store")
        let localURL = dir.appendingPathComponent("local.store")

        do {
            let container = try ModelContainer(
                for: LoomiesStore.fullSchema,
                migrationPlan: LoomiesMigrationPlan.self,
                configurations:
                    ModelConfiguration(LoomiesStore.mainConfigurationName,
                                       schema: LoomiesStore.mainSchema,
                                       url: mainURL, cloudKitDatabase: .none),
                    ModelConfiguration(LoomiesStore.localConfigurationName,
                                       schema: LoomiesStore.localSchema,
                                       url: localURL, cloudKitDatabase: .none))
            let ctx = ModelContext(container)
            let p = Person(name: "Ada"); ctx.insert(p)
            let body = PersonBodyProfile(personID: p.id); body.bustInches = 34
            ctx.insert(body)
            try ctx.save()
        }

        // 单独打开主域：Person 在，PersonBodyProfile 连实体都不在这个 schema 里
        let mainOnly = try ModelContainer(
            for: LoomiesStore.mainSchema,
            configurations: ModelConfiguration(
                LoomiesStore.mainConfigurationName, schema: LoomiesStore.mainSchema,
                url: mainURL, cloudKitDatabase: .none))
        let ctx = ModelContext(mainOnly)
        #expect(try ctx.fetch(FetchDescriptor<Person>()).count == 1)
        #expect(!mainOnly.schema.entities.map(\.name).contains("PersonBodyProfile"))
    }
}
