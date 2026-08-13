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
            // 指纹的每一行都来自 SwiftData 反射结果的**字符串描述**，那不是有稳定性
            // 契约的 API。工具链升级若把 `Optional<String>` 印成 `Swift.Optional<Swift.String>`
            // 之类，golden 的旧行会**全体消失** → 门以最高危形态报破坏性变更，而 schema
            // 一个字没动。此时若盲目 record 重录，正好把真实的删除也一起洗白。
            let removedEntities = Set(violations.map(\.entity))
            let looksLikeToolchainDrift =
                violations.count >= 20 && removedEntities.count >= 6
            let hint = looksLikeToolchainDrift
                ? "\n\n⚠️ 全实体大面积「removed」——先怀疑工具链的类型描述漂移，"
                    + "不是真的删了字段。核对方式：git diff 看 schema 源码是否真有改动；"
                    + "若确属描述漂移，先规范化 valueType 渲染再对比，**不要**直接 record 重录。"
                : ""
            Issue.record(Comment(rawValue:
                "DESTRUCTIVE schema change (DESIGN §11.1 one-way door):\n\(detail)\(hint)"))
        }
    }

    /// golden 规模 sanity check。**精确值由 golden 文件守**（上面的差分门给出具体违规），
    /// 这里只防「指纹渲染器本身坏了」——故用下界而非等值，加字段不会误红。
    @Test func fingerprintShapeIsSane() {
        let lines = Self.fingerprintLines()
        #expect(lines.first?.hasPrefix("VERSION ") == true)
        #expect(lines.filter { $0.hasPrefix("ENTITY ") }.count == 9)
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
        // CloudKitDatabase 不可比较 → 用描述断言。子串匹配会被 `.private("…none…")`
        // 之类蒙混，故用**完全相等**；本地域是 D5 铁律（永久锁），主域是当前状态。
        let noneDescription = String(describing: ModelConfiguration.CloudKitDatabase.none)
        #expect(String(describing: local.cloudKitDatabase) == noneDescription,
                "本地域进 CloudKit = D5 破了（身体数据永不同步）")
        // ⚠️ MVP-PLAN M0 的退出门要求主库将来开 CloudKit 同步——届时这条应改为
        // 断言 .private 的容器标识符，**不要**顺手放宽成子串匹配。
        #expect(String(describing: main.cloudKitDatabase) == noneDescription)
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
        #expect(names.count == 9)
        #expect(names.contains("PersonBodyProfile"))
        #expect(names.contains("TransferRecord"))
    }

    // MARK: - 接线 lint（app-shell 不参与 swift test，先用 lint 兜住漂移）

    /// 实体清单不得再在 app-shell 里手搓——加实体漏改一处 = 启动崩溃。
    /// 实体清单只有一份。**扫描 app-shell 下所有文件，含 .template**——
    /// 此前 lint 靠扩展名把历史模板排除在外，而那份模板正是漏网的第二份清单
    /// （D84 的立论就是「清单存在两处」，当时只砍掉了会编译的那一处）。
    @Test func appShellUsesSingleContainerEntryPoint() throws {
        let shellDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("app-shell", isDirectory: true)
        let entry = shellDir.appendingPathComponent("ClosetApp/ClosetApp.swift")
        #expect(try String(contentsOf: entry, encoding: .utf8)
            .contains("LoomiesStore.makeContainer"))

        var handRolled: [String] = []
        var scanned = 0
        let fm = FileManager.default
        let en = fm.enumerator(at: shellDir, includingPropertiesForKeys: nil)
        while let url = en?.nextObject() as? URL {
            let ext = url.pathExtension
            guard ext == "swift" || ext == "template" else { continue }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            scanned += 1
            if text.contains("Schema([") { handRolled.append(url.lastPathComponent) }
        }
        #expect(scanned >= 2, "扫描器失效（只看到 \(scanned) 个文件）")
        #expect(handRolled.isEmpty,
                Comment(rawValue: "手搓实体清单：\(handRolled)"))
    }
}

/// D102（审计 HIGH/MEDIUM 两条合并处置）：
/// 1. `OnDiskUpgradeTests` 号称是「已发布用户的盘上库扛得住 D84 装配变更」的证据，
///    但它两侧都用 `Schema(LoomiesSchemaV1.mainModels)` ——**同一个表达式**，
///    所以它**结构上不可能因 schema 漂移而失败**。它真正证明的是「无 migrationPlan
///    写出的盘上库能被带 migrationPlan 的装配打开」，那是装配差异，不是漂移防护。
///    漂移防护是 golden 指纹（D84）的职责，本文件上方那条门。
/// 2. 真正没人守的是**完整性**：D84 砍掉了重复的实体清单，却没有任何东西保证
///    幸存的那一份**列全了**——新增一个 @Model 却忘记注册，它就不进 schema、
///    不进 golden、不进迁移，而 fetch 会在运行时炸。
struct SchemaRegistrationCompletenessTests {

    /// ClosetModel 源码里声明的每个 `@Model` 都必须出现在 `LoomiesSchemaV1.models` 里。
    @Test func everyDeclaredModelIsRegistered() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // ClosetModelTests
            .deletingLastPathComponent()      // Tests
            .deletingLastPathComponent()      // ClosetModel（包根）
            .appendingPathComponent("Sources/ClosetModel", isDirectory: true)
        var declared: Set<String> = []
        let fm = FileManager.default
        let en = fm.enumerator(at: sources, includingPropertiesForKeys: nil)
        while let url = en?.nextObject() as? URL {
            guard url.pathExtension == "swift",
                  let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            for (i, line) in lines.enumerated()
            where line.trimmingCharacters(in: .whitespaces) == "@Model" {
                // 下一行形如 `public final class Item {`
                guard i + 1 < lines.count else { continue }
                let next = lines[i + 1].trimmingCharacters(in: .whitespaces)
                guard let range = next.range(of: "class ") else { continue }
                let name = next[range.upperBound...]
                    .prefix { $0.isLetter || $0.isNumber || $0 == "_" }
                if !name.isEmpty { declared.insert(String(name)) }
            }
        }
        #expect(declared.count >= 8, "@Model 扫描器失效（只找到 \(declared.sorted())）")

        let registered = Set(LoomiesSchemaV1.models.map { String(describing: $0) })
        let missing = declared.subtracting(registered)
        #expect(missing.isEmpty,
                Comment(rawValue: "声明了但没注册进 schema 的实体：\(missing.sorted())"
                        + " —— 它不进 golden、不进迁移，fetch 会在运行时炸"))
        // 反向：注册了但源码里已不存在的（改名/删除后忘了从清单摘）
        let stale = registered.subtracting(declared)
        #expect(stale.isEmpty, Comment(rawValue: "清单里有源码中已不存在的实体：\(stale.sorted())"))
    }

    /// 主域 + 本地域的并集必须等于全集（D5 分域不得漏掉某个实体）。
    @Test func domainPartitionCoversEveryRegisteredModel() {
        let all = Set(LoomiesSchemaV1.models.map { String(describing: $0) })
        let main = Set(LoomiesSchemaV1.mainModels.map { String(describing: $0) })
        let local = Set(LoomiesSchemaV1.localModels.map { String(describing: $0) })
        #expect(main.union(local) == all)
        #expect(main.isDisjoint(with: local))
    }
}

/// D170：把 M0 退出门那条 ⚠️ 补到能证伪。
///
/// MVP-PLAN 的 M0 门写着「身体数据不进 CloudKit 的单测硬门绿 ⚠️ **部分**——
/// 当前 `cloudKitDatabase: .none`，语义未被真正验证」。真开 CloudKit 需要
/// 真机与云端，这里开不了。
///
/// 但**能验证一件更本质的事**：分区与同步开关**无关**。
/// 身体数据不进 CloudKit 靠的不是「现在没开同步」，而是
/// **它根本不在主域那份 schema 里**——所以哪天主域开了 `.private(…)`，
/// 被同步的仍然只有主域那八张表。这条今天就能证伪，且它才是 D5 真正的支点。
@MainActor
struct BodyDataStaysLocalRegardlessOfSyncTests {

    /// 假设主域**开了**同步：身体档案仍不在它的 schema 里。
    @Test func turningOnMainSyncWouldNotCarryBodyData() {
        let syncedMain = ModelConfiguration(
            "main", schema: LoomiesStore.mainSchema,
            cloudKitDatabase: .private("iCloud.test.container"))
        let names = Set(syncedMain.schema?.entities.map(\.name) ?? [])
        #expect(!names.isEmpty)
        #expect(!names.contains("PersonBodyProfile"),
                "主域开同步后身体数据会跟着走 —— D5 破了")
        #expect(names.contains("Item"), "主域该有的表反而没了（判据本身坏了）")
    }

    /// 反过来：本地域的 schema 里**只有**身体档案——
    /// 它是一份独立的 store，主域同步与否与它无关。
    @Test func theLocalDomainCarriesOnlyBodyData() {
        let names = Set(LoomiesStore.localSchema.entities.map(\.name))
        #expect(names == ["PersonBodyProfile"],
                Comment(rawValue: "本地域装了别的表：\(names.sorted())"))
    }

    /// 支点说清楚：两份 schema **不相交**，所以「同步哪一份」这个问题
    /// 对身体数据没有意义。
    @Test func theTwoSchemasShareNothing() {
        let main = Set(LoomiesStore.mainSchema.entities.map(\.name))
        let local = Set(LoomiesStore.localSchema.entities.map(\.name))
        #expect(main.isDisjoint(with: local))
        #expect(!main.isEmpty && !local.isEmpty)
    }
}
