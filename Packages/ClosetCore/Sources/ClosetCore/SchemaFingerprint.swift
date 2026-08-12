import Foundation

/// Schema 单向门差分引擎（D84，DESIGN §11.1 blocking）。
///
/// CloudKit 同步的 SwiftData 只支持**加法式**轻量迁移（不能删字段/改名/改类型/收紧约束），
/// 且生产 schema 部署后不可回滚。本引擎把「当前 schema 指纹」与入库 golden 逐行比对：
/// 旧行消失 = 破坏性（硬失败），新行必须满足加法安全规则才放行。
///
/// 纯字符串逻辑（Foundation only，符合 ClosetCore 零 SDK 依赖）：反例可表驱动穷举，
/// 不必真去改实体触发 RED。指纹渲染在 ClosetModel 测试侧（需要 SwiftData 反射）。
public enum SchemaFingerprint {

    public enum ViolationKind: String, Sendable, Equatable {
        /// golden 里存在、当前已消失（删字段/删实体/改类型/改 optional/改 rule/改 inverse/改 domain 都归此类）
        case removed
        /// 新增但不满足加法安全规则
        case unsafeAddition
        /// versionIdentifier 变了——迁移语义的锚，不得静默通过
        case versionChanged
        /// 指纹文件本身畸形（缺 VERSION / 孤儿属性行 / 未知 kind / 重复行）
        case malformed
    }

    public struct Violation: Sendable, Equatable {
        public let kind: ViolationKind
        public let entity: String
        public let detail: String
    }

    public enum Verdict: Sendable, Equatable {
        case identical
        /// 全部为加法式变更（附新增行，供 diff 审查）
        case additive([String])
        case destructive([Violation])

        public var isDestructive: Bool {
            if case .destructive = self { return true }
            return false
        }
    }

    // MARK: - 解析

    struct Parsed: Equatable {
        var version: String?
        /// entity → 该实体名下的行（含 ENTITY 头行本身，头行携带 domain）
        var byEntity: [String: [String]] = [:]
        var order: [String] = []          // 实体出现序（仅用于确定性输出）
        var malformed: [Violation] = []
    }

    static func parse(_ lines: [String]) -> Parsed {
        var out = Parsed()
        var current: String?
        var seen = Set<String>()
        for raw in lines {
            let line = raw.trimmingCharacters(in: .newlines)
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            if line.hasPrefix("VERSION ") {
                if out.version != nil {
                    out.malformed.append(.init(kind: .malformed, entity: "", detail: "duplicate VERSION"))
                }
                out.version = String(line.dropFirst("VERSION ".count))
                continue
            }
            if line.hasPrefix("ENTITY ") {
                let name = line.dropFirst("ENTITY ".count).split(separator: " ").first.map(String.init) ?? ""
                if name.isEmpty {
                    out.malformed.append(.init(kind: .malformed, entity: "", detail: line))
                    continue
                }
                if out.byEntity[name] != nil {
                    out.malformed.append(.init(kind: .malformed, entity: name, detail: "duplicate ENTITY \(name)"))
                }
                current = name
                out.order.append(name)
                out.byEntity[name, default: []].append(line)
                continue
            }
            let body = line.trimmingCharacters(in: .whitespaces)
            let kind = body.split(separator: " ").first.map(String.init) ?? ""
            guard kind == "A" || kind == "R" else {
                out.malformed.append(.init(kind: .malformed, entity: current ?? "", detail: "unknown line: \(body)"))
                continue
            }
            guard let entity = current else {
                out.malformed.append(.init(kind: .malformed, entity: "", detail: "orphan line: \(body)"))
                continue
            }
            if !seen.insert("\(entity)|\(body)").inserted {
                out.malformed.append(.init(kind: .malformed, entity: entity, detail: "duplicate line: \(body)"))
                continue
            }
            out.byEntity[entity, default: []].append(body)
        }
        if out.version == nil {
            out.malformed.append(.init(kind: .malformed, entity: "", detail: "missing VERSION header"))
        }
        return out
    }

    // MARK: - 加法安全规则

    /// 字段值解析（`opt=1` → "1"）。
    static func field(_ line: String, _ key: String) -> String? {
        for token in line.split(separator: " ") where token.hasPrefix("\(key)=") {
            return String(token.dropFirst(key.count + 1))
        }
        return nil
    }

    /// 新增行是否加法安全。
    /// 属性：`opt=1 || hasDefault=1`（迁移时每个属性都要有值：要么可空、要么有默认）且 `uniq=0`
    ///（CloudKit 禁 unique）。关系：必须 optional 且声明 inverse（CloudKit 要求双向可空）。
    /// ⚠️ DESIGN §11.1 散文写「optional + 默认值」，实测代码基线（`id: UUID = UUID()` 等）
    /// 是「非 optional 但有默认」——采 OR 口径并在 D84 显式裁决，不静默偏离。
    static func additionSafety(_ line: String) -> String? {
        let kind = line.split(separator: " ").first.map(String.init) ?? ""
        if kind == "A" {
            if field(line, "uniq") == "1" { return "unique attribute (CloudKit forbids)" }
            let optional = field(line, "opt") == "1"
            let defaulted = field(line, "hasDefault") == "1"
            if !optional && !defaulted { return "new attribute must be optional or defaulted" }
            return nil
        }
        if kind == "R" {
            if field(line, "opt") != "1" { return "new relationship must be optional" }
            if (field(line, "inverse") ?? "-") == "-" { return "new relationship must declare inverse" }
            return nil
        }
        return "unknown line kind"
    }

    // MARK: - 比对

    public static func compare(golden: [String], current: [String]) -> Verdict {
        let g = parse(golden)
        let c = parse(current)
        var violations = g.malformed + c.malformed

        if let gv = g.version, let cv = c.version, gv != cv {
            violations.append(.init(
                kind: .versionChanged, entity: "",
                detail: "versionIdentifier \(gv) → \(cv) requires an explicit migration stage + re-recorded golden"))
        }

        // (a) golden 每一行必须逐字仍在（含 ENTITY 头，故 domain 变更也被覆盖）
        for (entity, lines) in g.byEntity {
            let currentLines = Set(c.byEntity[entity] ?? [])
            for line in lines where !currentLines.contains(line) {
                violations.append(.init(kind: .removed, entity: entity, detail: line))
            }
        }

        // (b) 新增行必须加法安全
        var added: [String] = []
        for (entity, lines) in c.byEntity {
            let goldenLines = Set(g.byEntity[entity] ?? [])
            for line in lines where !goldenLines.contains(line) {
                added.append("\(entity): \(line)")
                if line.hasPrefix("ENTITY ") { continue }   // 新实体头本身无安全约束
                if let reason = additionSafety(line) {
                    violations.append(.init(kind: .unsafeAddition, entity: entity, detail: "\(line) — \(reason)"))
                }
            }
        }

        if !violations.isEmpty {
            // 确定性输出：(kind, entity, detail) 三键排序
            return .destructive(violations.sorted {
                ($0.entity, $0.detail, $0.kind.rawValue) < ($1.entity, $1.detail, $1.kind.rawValue)
            })
        }
        return added.isEmpty ? .identical : .additive(added.sorted())
    }

    // MARK: - golden 读写（路径注入，测试可用临时文件）

    /// verify（默认）：只比对。record：**先比对**，仅在非破坏性时写盘——
    /// 否则一条环境变量就能把删字段洗白，单向门形同虚设。
    @discardableResult
    public static func recordOrVerify(goldenURL: URL, current: [String], record: Bool) -> Verdict {
        let goldenText = (try? String(contentsOf: goldenURL, encoding: .utf8)) ?? ""
        let golden = goldenText.isEmpty
            ? []
            : goldenText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        // 首次录制（golden 尚不存在）
        if golden.isEmpty {
            if record {
                try? current.joined(separator: "\n").write(to: goldenURL, atomically: true, encoding: .utf8)
                return .additive(current)
            }
            return .destructive([.init(kind: .malformed, entity: "", detail: "golden fingerprint missing")])
        }
        let verdict = compare(golden: golden, current: current)
        if record, !verdict.isDestructive {
            try? current.joined(separator: "\n").write(to: goldenURL, atomically: true, encoding: .utf8)
        }
        return verdict
    }
}
