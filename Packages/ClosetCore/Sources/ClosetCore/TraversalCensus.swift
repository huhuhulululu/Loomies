import Foundation

/// D216：宽扫遍历门的文件数账本。
///
/// D209 的下界是手填常数（当时 137 → `>= 80`）。文件涨到 300 时那条下界
/// 形同虚设；naive 自动下调又会把「扫描变窄」藏起来。
///
/// 规则：
/// - 下界 = `max(3, recorded × 6 / 10)`（删几个文件仍过，腰斩或走错目录红）
/// - live **大于** recorded → 红，逼人重录（下界只涨不降）
/// - live 落在 `[floor, recorded]` → 过
///
/// 只给**宽扫**用。扫三五个文件的窄门继续 `>= 3`。
/// 重录：`LOOMIES_TRAVERSAL_RECORD=1 swift test --package-path Packages/ClosetCore --filter TraversalCensus`
public enum TraversalCensus {
    public static let allPackageSources = "allPackageSources"
    public static let packageAndAppShellSources = "packageAndAppShellSources"
    public static let closetUISources = "closetUISources"
    public static let closetUITests = "closetUITests"
    public static let closetModelTests = "closetModelTests"

    public static let recordEnvironmentKey = "LOOMIES_TRAVERSAL_RECORD"

    public struct Snapshot: Codable, Equatable, Sendable {
        public var counts: [String: Int]
        public init(counts: [String: Int]) { self.counts = counts }
    }

    public enum Verdict: Equatable, Sendable {
        case pass
        case grew(live: Int, recorded: Int)
        case collapsed(live: Int, floor: Int, recorded: Int)
    }

    public static func fixtureURL(repoRoot: URL) -> URL {
        repoRoot.appendingPathComponent(
            "Packages/ClosetCore/Tests/ClosetCoreTests/Fixtures/TraversalCensus.json")
    }

    /// 从测试文件往上找仓根（认 `docs/HANDOFF.md`，不数层数）。
    public static func repoRoot(startingAt filePath: String) -> URL? {
        var url = URL(fileURLWithPath: filePath)
        for _ in 0..<16 {
            url.deleteLastPathComponent()
            let marker = url.appendingPathComponent("docs/HANDOFF.md")
            if FileManager.default.fileExists(atPath: marker.path) { return url }
        }
        return nil
    }

    public static func load(repoRoot: URL) throws -> Snapshot {
        let data = try Data(contentsOf: fixtureURL(repoRoot: repoRoot))
        return try JSONDecoder().decode(Snapshot.self, from: data)
    }

    public static func floor(recorded: Int) -> Int {
        max(3, recorded * 6 / 10)
    }

    public static func evaluate(live: Int, recorded: Int) -> Verdict {
        if live > recorded { return .grew(live: live, recorded: recorded) }
        let bound = floor(recorded: recorded)
        if live < bound { return .collapsed(live: live, floor: bound, recorded: recorded) }
        return .pass
    }

    public static func check(live: Int, key: String, snapshot: Snapshot) -> String? {
        guard let recorded = snapshot.counts[key] else {
            return "TraversalCensus 没有 key \(key) —— 先记进 Fixtures/TraversalCensus.json"
        }
        switch evaluate(live: live, recorded: recorded) {
        case .pass:
            return nil
        case .grew(let live, let recorded):
            return "扫到 \(live) 个文件，超过账本 \(recorded)（\(key)）。"
                + "下界跟着涨：\(recordEnvironmentKey)=1 swift test "
                + "--package-path Packages/ClosetCore --filter TraversalCensus"
        case .collapsed(let live, let bound, let recorded):
            return "只扫到 \(live) 个文件（\(key) 账本 \(recorded)，下界 \(bound)）"
                + "—— 遍历坏了或变窄了"
        }
    }

    public static func check(live: Int, key: String, repoRoot: URL) throws -> String? {
        try check(live: live, key: key, snapshot: load(repoRoot: repoRoot))
    }

    public static func check(live: Int, key: String, testFile: String) throws -> String? {
        guard let root = repoRoot(startingAt: testFile) else {
            return "找不到仓根（从 \(testFile) 往上找不到 docs/HANDOFF.md）"
        }
        return try check(live: live, key: key, repoRoot: root)
    }

    public static func countSwift(under root: URL, matching: ((URL) -> Bool)? = nil) -> Int {
        guard let walker = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: nil)
        else { return 0 }
        var n = 0
        for case let url as URL in walker where url.pathExtension == "swift" {
            if let matching, !matching(url) { continue }
            n += 1
        }
        return n
    }

    public static func recount(repoRoot: URL) -> [String: Int] {
        let packages = repoRoot.appendingPathComponent("Packages")
        let appShell = repoRoot.appendingPathComponent("app-shell")
        return [
            allPackageSources: countSwift(under: packages) {
                $0.path.contains("/Sources/")
            },
            packageAndAppShellSources:
                countSwift(under: packages) { $0.path.contains("/Sources/") }
                + countSwift(under: appShell),
            closetUISources: countSwift(
                under: packages.appendingPathComponent("ClosetUI/Sources")),
            closetUITests: countSwift(
                under: packages.appendingPathComponent("ClosetUI/Tests")),
            closetModelTests: countSwift(
                under: packages.appendingPathComponent("ClosetModel/Tests")),
        ]
    }

    public static func record(_ counts: [String: Int], repoRoot: URL) throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var data = try enc.encode(Snapshot(counts: counts))
        if data.last != 0x0A { data.append(0x0A) }
        try data.write(to: fixtureURL(repoRoot: repoRoot), options: .atomic)
    }
}
