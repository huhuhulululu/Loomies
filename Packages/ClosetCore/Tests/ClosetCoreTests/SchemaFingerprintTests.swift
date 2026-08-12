import Testing
import Foundation
@testable import ClosetCore

/// Schema 单向门差分引擎（D84）：纯字符串逻辑，可穷举反例而不必真去改实体
///（真改会污染 golden 并影响其余数百个测试）。
struct SchemaFingerprintTests {

    let base = [
        "VERSION 1.0.0",
        "ENTITY Item domain=main",
        "  A name type=String opt=0 uniq=0 trans=0 hasDefault=1",
        "  A note type=String opt=1 uniq=0 trans=0 hasDefault=0",
        "  R wardrobe dest=Wardrobe rule=nullify inverse=items opt=1 toOne=1",
        "ENTITY Wardrobe domain=main",
        "  A name type=String opt=0 uniq=0 trans=0 hasDefault=1",
    ]

    @Test func identicalFingerprintsCompareIdentical() {
        #expect(SchemaFingerprint.compare(golden: base, current: base) == .identical)
    }

    @Test func removedAttributeIsDestructive() {
        let current = base.filter { !$0.contains("A note ") }
        let v = SchemaFingerprint.compare(golden: base, current: current)
        guard case .destructive(let violations) = v else {
            Issue.record("expected destructive, got \(v)"); return
        }
        #expect(violations.contains { $0.kind == .removed && $0.detail.contains("note") })
    }

    @Test func removedEntityIsDestructive() {
        let current = base.filter { !$0.contains("Wardrobe") }
        guard case .destructive(let v) = SchemaFingerprint.compare(golden: base, current: current)
        else { Issue.record("expected destructive"); return }
        #expect(v.contains { $0.kind == .removed })
    }

    @Test func changedTypeOrTightenedOptionalIsDestructive() {
        // 改类型
        let retyped = base.map { $0.replacingOccurrences(of: "A note type=String", with: "A note type=Int") }
        #expect(SchemaFingerprint.compare(golden: base, current: retyped).isDestructive)
        // 收紧 optional（1 → 0）
        let tightened = base.map {
            $0.replacingOccurrences(of: "A note type=String opt=1", with: "A note type=String opt=0")
        }
        #expect(SchemaFingerprint.compare(golden: base, current: tightened).isDestructive)
        // 改 deleteRule / inverse
        let ruleChanged = base.map { $0.replacingOccurrences(of: "rule=nullify", with: "rule=cascade") }
        #expect(SchemaFingerprint.compare(golden: base, current: ruleChanged).isDestructive)
        let inverseChanged = base.map { $0.replacingOccurrences(of: "inverse=items", with: "inverse=-") }
        #expect(SchemaFingerprint.compare(golden: base, current: inverseChanged).isDestructive)
        // 改 domain（本地域字段挪进主库 = D5 破防）
        let domainChanged = base.map { $0.replacingOccurrences(of: "ENTITY Item domain=main", with: "ENTITY Item domain=local") }
        #expect(SchemaFingerprint.compare(golden: base, current: domainChanged).isDestructive)
    }

    @Test func safeAdditionsAreAdditive() {
        // optional 新字段 / 带默认值新字段 / optional+有 inverse 的新关系 / 全新实体
        let current = base + [
            "  A newOptional type=String opt=1 uniq=0 trans=0 hasDefault=0",
            "  A newDefaulted type=Int opt=0 uniq=0 trans=0 hasDefault=1",
            "  R newRel dest=Tag rule=nullify inverse=items opt=1 toOne=0",
            "ENTITY Tag domain=main",
            "  A label type=String opt=0 uniq=0 trans=0 hasDefault=1",
        ]
        guard case .additive(let added) = SchemaFingerprint.compare(golden: base, current: current)
        else { Issue.record("expected additive"); return }
        #expect(added.count == 5)
    }

    @Test func unsafeAdditionsAreDestructive() {
        // 既非 optional 又无默认值 → CloudKit 轻量迁移不可行
        let noDefault = base + ["  A hard type=String opt=0 uniq=0 trans=0 hasDefault=0"]
        #expect(SchemaFingerprint.compare(golden: base, current: noDefault).isDestructive)
        // unique 约束（CloudKit 禁）
        let unique = base + ["  A code type=String opt=1 uniq=1 trans=0 hasDefault=0"]
        #expect(SchemaFingerprint.compare(golden: base, current: unique).isDestructive)
        // 新关系非 optional
        let requiredRel = base + ["  R owner dest=Person rule=nullify inverse=items opt=0 toOne=1"]
        #expect(SchemaFingerprint.compare(golden: base, current: requiredRel).isDestructive)
        // 新关系无 inverse（CloudKit 要求双向）
        let noInverse = base + ["  R owner dest=Person rule=nullify inverse=- opt=1 toOne=1"]
        #expect(SchemaFingerprint.compare(golden: base, current: noInverse).isDestructive)
    }

    /// VERSION 头行显式建模：bump 版本号不得静默通过（迁移语义的锚）。
    @Test func versionBumpIsDestructiveNotSilent() {
        let bumped = base.map { $0 == "VERSION 1.0.0" ? "VERSION 2.0.0" : $0 }
        guard case .destructive(let v) = SchemaFingerprint.compare(golden: base, current: bumped)
        else { Issue.record("expected destructive"); return }
        #expect(v.contains { $0.kind == .versionChanged })
    }

    /// golden 被手改坏（缺 ENTITY 头 / 未知 kind / 重复行）必须报错，不得静默当空。
    @Test func malformedGoldenIsRejected() {
        let orphanAttr = ["VERSION 1.0.0", "  A x type=String opt=1 uniq=0 trans=0 hasDefault=0"]
        #expect(SchemaFingerprint.compare(golden: orphanAttr, current: base).isDestructive)
        let unknownKind = base + ["  Z weird stuff"]
        #expect(SchemaFingerprint.compare(golden: base, current: unknownKind).isDestructive)
        let duplicated = base + ["  A name type=String opt=0 uniq=0 trans=0 hasDefault=1"]
        #expect(SchemaFingerprint.compare(golden: duplicated, current: base).isDestructive)
        let noVersion = base.filter { !$0.hasPrefix("VERSION") }
        #expect(SchemaFingerprint.compare(golden: noVersion, current: base).isDestructive)
    }

    /// 违规输出顺序确定（禁止依赖 Dictionary 迭代序）。
    @Test func violationsAreDeterministicallyOrdered() {
        let current = base.filter { !$0.contains("A note ") && !$0.contains("A name type=String opt=0 uniq=0 trans=0 hasDefault=1") }
        guard case .destructive(let a) = SchemaFingerprint.compare(golden: base, current: current),
              case .destructive(let b) = SchemaFingerprint.compare(golden: base, current: current)
        else { Issue.record("expected destructive"); return }
        #expect(a == b)
        #expect(a == a.sorted { ($0.entity, $0.detail) < ($1.entity, $1.detail) })
    }

    /// record 模式的守门：破坏性变更永远不得落盘（否则一条环境变量就能洗白删字段）。
    @Test func recordRefusesToWriteDestructiveChange() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("schema-golden-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("golden.txt")
        try base.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)

        let destructive = base.filter { !$0.contains("A note ") }
        let v = SchemaFingerprint.recordOrVerify(goldenURL: url, current: destructive, record: true)
        #expect(v.isDestructive)
        let onDisk = try String(contentsOf: url, encoding: .utf8)
        #expect(onDisk.contains("A note"))   // 未被洗白

        // 加法式在 record 下才写盘
        let additive = base + ["  A fresh type=String opt=1 uniq=0 trans=0 hasDefault=0"]
        _ = SchemaFingerprint.recordOrVerify(goldenURL: url, current: additive, record: true)
        #expect(try String(contentsOf: url, encoding: .utf8).contains("fresh"))
    }

    @Test func verifyModeNeverWrites() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("schema-golden-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("golden.txt")
        try base.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        let additive = base + ["  A fresh type=String opt=1 uniq=0 trans=0 hasDefault=0"]
        let v = SchemaFingerprint.recordOrVerify(goldenURL: url, current: additive, record: false)
        if case .additive = v {} else { Issue.record("expected additive, got \(v)") }
        #expect(try !String(contentsOf: url, encoding: .utf8).contains("fresh"))
    }
}
