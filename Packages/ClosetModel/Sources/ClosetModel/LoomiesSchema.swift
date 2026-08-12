import Foundation
import SwiftData

/// Schema 版本化与容器装配单一入口（D84，DESIGN §11.1 blocking 单向门）。
///
/// 此前实体清单只存在于 app-shell 的字面量里，ClosetModel 无法自证 schema——
/// 加实体要改两处，漏一处 App 直接崩在 `fatalError`。收口到 Model 层后
/// app-shell / 测试 / 单向门守卫共用同一真相。
public enum LoomiesSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    /// 主域（CloudKit 可同步面，当前 cloudKitDatabase: .none）。
    public static let mainModels: [any PersistentModel.Type] = [
        Person.self, Wardrobe.self, StorageLocation.self, Item.self,
        Outfit.self, WearRecord.self, CalendarPlan.self,
    ]

    /// 本地域（D5：身体维度独立存储，永不进 CloudKit）。
    public static let localModels: [any PersistentModel.Type] = [
        PersonBodyProfile.self,
    ]

    public static var models: [any PersistentModel.Type] { mainModels + localModels }
}

/// 迁移计划。v1 无前驱故 stages 为空；v2 起在此 append
/// `MigrationStage.lightweight(fromVersion:toVersion:)`（加法式变更）。
public enum LoomiesMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [LoomiesSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

/// 容器装配单一入口。
/// ⚠️ 两个 ModelConfiguration 必须**各带自己的子 schema**（D5 载荷）——
/// 都传 fullSchema 会让两个 store 都建全量表，身体数据会落进主库。
/// ⚠️ config 的 `name`（"main"/"local"）直接派生 store 文件名，改名即丢已发布用户数据。
public enum LoomiesStore {
    public static let mainConfigurationName = "main"
    public static let localConfigurationName = "local"

    public static var fullSchema: Schema { Schema(versionedSchema: LoomiesSchemaV1.self) }
    public static var mainSchema: Schema { Schema(LoomiesSchemaV1.mainModels) }
    public static var localSchema: Schema { Schema(LoomiesSchemaV1.localModels) }

    public static func mainConfiguration(inMemory: Bool = false) -> ModelConfiguration {
        ModelConfiguration(
            mainConfigurationName, schema: mainSchema,
            isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
    }

    public static func localConfiguration(inMemory: Bool = false) -> ModelConfiguration {
        ModelConfiguration(
            localConfigurationName, schema: localSchema,
            isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
    }

    /// app-shell 与测试共用的唯一装配路径（带 migrationPlan）。
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer(
            for: fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: mainConfiguration(inMemory: inMemory),
            localConfiguration(inMemory: inMemory))
    }
}
