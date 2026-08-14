import Testing
import Foundation
@testable import ClosetCore

/// D115：DESIGN §10.4 的**文案红线**是硬约束，写得很明确——
/// 「禁 flattering / slimming / hide / problem area 类词汇；
/// 合身语言只评价衣服不评价身体（『这件衣长偏短』✅ 『遮住你的胯』❌）——
/// body-positive 是目标人群的信任底线」。
///
/// 而 `OutfitScorer` 把 **"Flatters your body shape"** 当作排第一的推荐理由发了出去，
/// 属性录入的说明还写着「Cut details we use to flatter your body shape」。
/// 项目自己定的信任底线，被自己最显眼的一句话破了。
///
/// 这条门扫的是**全部产出给用户看的字面量**，不是某几个已知点——
/// 红线要拦的是「下次又写一句」，不是这一次。
struct BodyLanguageRedLineTests {

    /// 明令禁止的词根（§10.4 列举 + 同族）。
    static let banned = [
        "flatter", "flattering", "slimming", "slim you",
        "problem area", "hide your", "hides your", "conceal your",
        "camouflage", "figure flaw", "tummy", "muffin",
    ]

    private var packagesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // ClosetCoreTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // ClosetCore
            .deletingLastPathComponent()   // Packages
    }

    /// 从一行里取出双引号字面量（粗粒度够用：门宁可多看，不可漏看）。
    static func literals(in line: String) -> [String] {
        var out: [String] = []
        var current = ""
        var inside = false
        var escaped = false
        for ch in line {
            if escaped { if inside { current.append(ch) }; escaped = false; continue }
            if ch == "\\" { escaped = true; continue }
            if ch == "\"" {
                if inside { out.append(current); current = "" }
                inside.toggle()
                continue
            }
            if inside { current.append(ch) }
        }
        return out
    }

    @Test func noUserFacingStringEvaluatesTheUsersBody() throws {
        // D208：**遍历型门必须自证「扫到过东西」**。
        // 实证过：把遍历根指向不存在的目录，门照样绿——
        // 「不存在」断言 + 目录遍历 = 看不见的地方等于不存在（假绿，无征兆）。
        var scannedFileCount = 0
        var violations: [String] = []
        let fm = FileManager.default
        for case let url as URL in fm.enumerator(at: packagesDir, includingPropertiesForKeys: nil)!
        where url.pathExtension == "swift" {
            let path = url.path
            guard path.contains("/Sources/"), !path.contains("/Tests/") else { continue }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            scannedFileCount += 1
            for (i, raw) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let line = String(raw)
                // 注释行不算产出（注释里引用红线词是合法的，比如这条门自己的说明）
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//"), !trimmed.hasPrefix("///") else { continue }
                for literal in Self.literals(in: line) {
                    let lower = literal.lowercased()
                    for word in Self.banned where lower.contains(word) {
                        violations.append("\(url.lastPathComponent):\(i + 1) “\(literal)”")
                    }
                }
            }
        }
        #expect(scannedFileCount >= 3, Comment(rawValue:
            "只扫到 \(scannedFileCount) 个文件 —— 遍历坏了，这道门在空转"))
        #expect(violations.isEmpty, Comment(rawValue:
            "DESIGN §10.4 文案红线：合身语言只评价衣服，不评价身体。\n"
            + violations.joined(separator: "\n")))
    }

    /// 正例/反例：门本身别失灵。
    @Test func theGateActuallyCatchesTheBannedWording() {
        let line = #"reasons.append("Flatters your body shape")"#
        let hit = Self.literals(in: line).contains {
            Self.banned.contains(where: $0.lowercased().contains)
        }
        #expect(hit)
    }

    @Test func neutralGarmentLanguagePasses() {
        let line = #"reasons.append("Cut works with your proportions")"#
        let hit = Self.literals(in: line).contains {
            Self.banned.contains(where: $0.lowercased().contains)
        }
        #expect(!hit)
    }

    /// 替换后的理由必须仍然**说清为什么**（不能为了合规变成空话）。
    @Test func theReplacementStillExplainsItself() {
        let ctx = ScoringContext(bodyShape: .hourglass, bodyShapeWeight: 1.0)
        let items = [
            CandidateItem(id: "a", slot: .top, occasions: [], warmth: .light, status: .available),
            CandidateItem(id: "b", slot: .bottom, occasions: [], warmth: .light, status: .available),
        ]
        let score = OutfitScorer.score(Outfit(items: items), context: ctx)
        for reason in score.reasons {
            let lower = reason.lowercased()
            for word in Self.banned {
                #expect(!lower.contains(word),
                        Comment(rawValue: "推荐理由踩红线：\(reason)"))
            }
        }
    }
}
