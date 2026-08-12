import Testing
import Foundation
@testable import ClosetCore

/// D93（缺口 #13）：护理（结构化）+ 备注（自由文本）。
/// DESIGN §90「护理（结构化：只干洗/手洗/不可烘干等，可由洗标 OCR 填充）」、
/// §95「备注：自由文本特殊需求（『需配腰带』『易皱』）」。
///
/// **DESIGN §321 把单品备注明列为不可信输入**——即便 v1.0 还没接 LLM，
/// 长度上限与结构化承载现在就得立住，否则等接了再补就是又一次「先上线后补门」。
struct CareAndNotesTests {

    // MARK: - 护理符号

    @Test func careSymbolsCoverTheLabelBasics() {
        let raws = Set(CareSymbol.allCases.map(\.rawValue))
        // 洗标上最影响「今天能不能穿」的几条必须在
        #expect(raws.contains("dryCleanOnly"))
        #expect(raws.contains("handWash"))
        #expect(raws.contains("noTumbleDry"))
        #expect(CareSymbol.allCases.count >= 6)
    }

    @Test func everySymbolHasDistinctHumanTitle() {
        let titles = CareSymbol.allCases.map(\.displayTitle)
        #expect(titles.allSatisfy { !$0.isEmpty })
        #expect(Set(titles).count == titles.count)
        // 不得直接把 rawValue 抛给用户
        #expect(!titles.contains("dryCleanOnly"))
    }

    /// 落库 raw → 类型，脏值丢弃（历史/OCR 可能写进不认识的东西）。
    @Test func parseDropsUnknownRawValues() {
        let parsed = CareSymbol.parse(["handWash", "nonsense", "noTumbleDry"])
        #expect(parsed == [.handWash, .noTumbleDry])
        #expect(CareSymbol.parse([]).isEmpty)
    }

    /// 落库顺序确定（禁止依赖 Set 的偶然序）。
    @Test func persistOrderIsDeterministic() {
        let a = CareSymbol.persistOrder([.noTumbleDry, .handWash])
        let b = CareSymbol.persistOrder([.handWash, .noTumbleDry])
        #expect(a == b)
        #expect(a == a.sorted())
    }

    /// 冲突组合要能被指出来——「只干洗」和「机洗」不该同时成立。
    @Test func conflictingSymbolsAreNamed() {
        let warning = CareSymbol.conflictWarning([.dryCleanOnly, .machineWash])
        let text = try! #require(warning)
        #expect(text.localizedCaseInsensitiveContains("dry clean"))
        // 不冲突时不出提示（无噪音）
        #expect(CareSymbol.conflictWarning([.handWash, .noTumbleDry]) == nil)
        #expect(CareSymbol.conflictWarning([]) == nil)
    }

    /// 护理影响的是「洗完多久能再穿」，不是推荐——文案不得暗示它改推荐。
    @Test func careCaptionDoesNotOverpromise() {
        #expect(!CareSymbol.entryHint.localizedCaseInsensitiveContains("recommend"))
        #expect(CareSymbol.entryHint.localizedCaseInsensitiveContains("label"))
    }

    // MARK: - 备注（不可信输入）

    @Test func notesAreTrimmedAndBlankBecomesNil() {
        #expect(ItemNotes.sanitize("  needs a belt  ") == "needs a belt")
        #expect(ItemNotes.sanitize("   ") == nil)
        #expect(ItemNotes.sanitize(nil) == nil)
    }

    /// 长度上限（§321 不可信输入的第一道闸）：超长截断而不是原样存。
    @Test func notesAreCappedAtAKnownLength() {
        #expect(ItemNotes.maxLength >= 120)
        let long = String(repeating: "x", count: ItemNotes.maxLength + 50)
        let out = try! #require(ItemNotes.sanitize(long))
        #expect(out.count == ItemNotes.maxLength)
    }

    /// 换行/控制字符归一——避免把版式炸开，也避免藏指令。
    @Test func controlCharactersAreNormalized() {
        let out = try! #require(ItemNotes.sanitize("needs\na belt\t\tand care"))
        #expect(!out.contains("\n"))
        #expect(!out.contains("\t"))
        #expect(out.contains("needs a belt"))
    }

    /// 剩余字数提示（用户得知道快到头了）。
    @Test func remainingCountIsAccurate() {
        #expect(ItemNotes.remaining("abc") == ItemNotes.maxLength - 3)
        #expect(ItemNotes.remaining(String(repeating: "x", count: ItemNotes.maxLength + 10)) == 0)
    }

    /// v1.0 没有 LLM——文案不得暗示备注会被「理解」。
    /// 按**词**判，不按子串（"detail" 里含 "ai"，子串断言会误伤）。
    @Test func notesHintMakesNoAIPromise() {
        let words = Set(ItemNotes.entryHint.lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init))
        #expect(!words.contains("ai"))
        #expect(!words.contains("understand"))
        #expect(!words.contains("understands"))
        #expect(!words.contains("smart"))
        #expect(words.contains("you") || words.contains("your"))
    }
}
