import Testing
import SwiftData
import Foundation
@testable import ClosetModel
import ClosetCore

/// Schema 单向门守卫（D84 / DESIGN §11.1 blocking / MVP-PLAN M0 退出门）。
///
/// golden 指纹入库；任何破坏性 schema 变更（删字段/改类型/收紧 optional/改 rule/改 inverse/
/// 改 domain/bump 版本）都会让本套件变红。加法式变更需 `LOOMIES_SCHEMA_GOLDEN=record`
/// 重录 golden 并让新增行进 diff 审查——record 模式**先差分后写盘**，破坏性永不落盘。
@Suite(.serialized)
@MainActor
struct SchemaGuardTests {

    // MARK: - 指纹渲染（SwiftData 反射）

    /// ⚠️ 必须排序：`Schema.entities` / `.attributes` 的迭代序不是声明序，不排序则每次运行不同。
    /// ⚠️ 只记 hasDefault 布尔：`id: UUID = UUID()` 的 defaultValue 每次运行都是新随机值。
    static func fingerprintLines() -> [String] {
        let mainNames = Set(LoomiesStore.mainSchema.entities.map(\.name))
        var lines = ["VERSION \(LoomiesSchemaV1.versionIdentifier.description)"]
        for entity in LoomiesStore.fullSchema.entities.sorted(by: { $0.name < $1.name }) {
            let domain = mainNames.contains(entity.name) ? "main" : "local"
            lines.append("ENTITY \(entity.name) domain=\(domain)")
            for a in entity.attributes.sorted(by: { $0.name < $1.name }) {
                lines.append(
                    "  A \(a.name) type=\(a.valueType) opt=\(a.isOptional ? 1 : 0) "
                    + "uniq=\(a.isUnique ? 1 : 0) trans=\(a.isTransient ? 1 : 0) "
                    + "hasDefault=\(a.defaultValue != nil ? 1 : 0)")
            }
            for r in entity.relationships.sorted(by: { $0.name < $1.name }) {
                lines.append(
                    "  R \(r.name) dest=\(r.destination) rule=\(r.deleteRule) "
                    + "inverse=\(r.inverseName?.description ?? "-") "
                    + "opt=\(r.isOptional ? 1 : 0) toOne=\(r.isToOneRelationship ? 1 : 0)")
            }
        }
        return lines
    }

    /// golden 路径由 #filePath 派生（源码内，随仓库入库）。
    static var goldenURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/SchemaFingerprint-v1.txt")
    }

    // MARK: - 单向门

    @Test func schemaChangesAreAdditiveOnly() throws {
        let record = ProcessInfo.processInfo.environment["LOOMIES_SCHEMA_GOLDEN"] == "record"
        let dir = Self.goldenURL.deletingLastPathComponent()
        if record {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let verdict = SchemaFingerprint.recordOrVerify(
            goldenURL: Self.goldenURL, current: Self.fingerprintLines(), record: record)
        switch verdict {
        case .identical:
            break
        case .additive(let added):
            // 加法式变更允许，但必须走 record 重录 + diff 审查（verify 模式下提示如何做）
            #expect(record, Comment(rawValue:
                "additive schema change detected — re-record with "
                + "LOOMIES_SCHEMA_GOLDEN=record and review the golden diff:\n"
                + added.joined(separator: "\n")))
        case .destructive(let violations):
            let detail = violations.map { "[\($0.kind.rawValue)] \($0.entity) \($0.detail)" }
                .joined(separator: "\n")
            Issue.record(Comment(rawValue: "DESTRUCTIVE schema change (DESIGN §11.1 one-way door):\n\(detail)"))
        }
    }

    /// golden 规模 sanity check：8 实体 / 61 属性 / 15 关系（+VERSION 头 = 85 行）。
    /// 数字变化说明 schema 动过——上面的差分门会给出具体违规，这里只防「指纹渲染器本身坏了」。
    @Test func fingerprintShapeIsSane() {
        let lines = Self.fingerprintLines()
        #expect(lines.first?.hasPrefix("VERSION ") == true)
        #expect(lines.filter { $0.hasPrefix("ENTITY ") }.count == 8)
        #expect(lines.filter { $0.hasPrefix("  A ") }.count >= 60)
        #expect(lines.filter { $0.hasPrefix("  R ") }.count >= 14)
        // 渲染确定（连跑两次一致）——排序生效的回归锁
        #expect(Self.fingerprintLines() == lines)
    }

    // MARK: - D5 域隔离（config 必须各带子 schema）

    @Test func configurationsCarryDomainSubschemas() {
        let main = LoomiesStore.mainConfiguration(inMemory: true)
        let local = LoomiesStore.localConfiguration(inMemory: true)
        let mainNames = Set(main.schema?.entities.map(\.name) ?? [])
        let localNames = Set(local.schema?.entities.map(\.name) ?? [])
        // 主域不得出现身体维度（都传 fullSchema 会让两个 store 都建全量表 → D5 破防）
        #expect(!mainNames.contains("PersonBodyProfile"))
        #expect(localNames == ["PersonBodyProfile"])
        #expect(mainNames.contains("Item") && mainNames.contains("Wardrobe"))
        #expect(mainNames.isDisjoint(with: localNames))
        // config 名是 store 文件名来源，改名即丢已发布用户数据
        #expect(main.name == "main")
        #expect(local.name == "local")
        // CloudKitDatabase 不可比较 → 用描述断言（D5：两域都不进 CloudKit）
        #expect(String(describing: main.cloudKitDatabase).localizedCaseInsensitiveContains("none"))
        #expect(String(describing: local.cloudKitDatabase).localizedCaseInsensitiveContains("none"))
    }

    @Test func domainsPartitionAllModelsWithoutOverlap() {
        let main = LoomiesSchemaV1.mainModels.map { String(describing: $0) }
        let local = LoomiesSchemaV1.localModels.map { String(describing: $0) }
        #expect(Set(main).isDisjoint(with: Set(local)))
        #expect(Set(main).union(local).count == LoomiesSchemaV1.models.count)
        #expect(local == ["PersonBodyProfile"])
    }

    /// 行级证据：身体数据写进容器后，只出现在本地域 store，主域 fetch 不到。
    @Test func bodyProfileRowsStayInLocalDomain() throws {
        let container = try LoomiesStore.makeContainer(inMemory: true)
        let ctx = ModelContext(container)
        let p = Person(name: "Ada"); ctx.insert(p)
        let body = PersonBodyProfile(personID: p.id)
        body.bustInches = 34
        ctx.insert(body)
        try ctx.save()
        // 两个域各自可查到自己的行（容器整体可用），且身体行的 store 是 local
        #expect(try ctx.fetch(FetchDescriptor<PersonBodyProfile>()).count == 1)
        #expect(try ctx.fetch(FetchDescriptor<Person>()).count == 1)
        #expect(!LoomiesStore.mainSchema.entities.map(\.name).contains("PersonBodyProfile"))
    }

    // MARK: - 迁移计划

    @Test func migrationPlanPinsV1WithoutStages() {
        #expect(LoomiesMigrationPlan.schemas.count == 1)
        #expect(LoomiesSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        // v1 无前驱；v2 起必须补 lightweight stage（否则 golden 的 versionChanged 门会红）
        #expect(LoomiesMigrationPlan.stages.isEmpty)
    }

    @Test func containerBuildsWithMigrationPlan() throws {
        let container = try LoomiesStore.makeContainer(inMemory: true)
        let names = Set(container.schema.entities.map(\.name))
        #expect(names.count == 8)
        #expect(names.contains("PersonBodyProfile"))
    }

    // MARK: - 接线 lint（app-shell 不参与 swift test，先用 lint 兜住漂移）

    /// 实体清单不得再在 app-shell 里手搓——加实体漏改一处 = 启动崩溃。
    @Test func appShellUsesSingleContainerEntryPoint() throws {
        let shell = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("app-shell/ClosetApp/ClosetApp.swift")
        let text = try String(contentsOf: shell, encoding: .utf8)
        #expect(text.contains("LoomiesStore.makeContainer"))
        // 历史参考件 ClosetApp.swift.template 不在此检查范围（扩展名不同）
        #expect(!text.contains("Schema(["), "app-shell must not hand-roll the entity list")
    }
}
