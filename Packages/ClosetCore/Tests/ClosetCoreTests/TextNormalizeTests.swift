import Testing
@testable import ClosetCore

struct TextNormalizeTests {
    @Test func blankToNilTrimsAndCollapses() {
        #expect(TextNormalize.blankToNil(nil) == nil)
        #expect(TextNormalize.blankToNil("") == nil)
        #expect(TextNormalize.blankToNil("   ") == nil)
        #expect(TextNormalize.blankToNil("\n\t ") == nil)
        #expect(TextNormalize.blankToNil("Sézane") == "Sézane")
        #expect(TextNormalize.blankToNil("  Acne Studios  ") == "Acne Studios")
    }

    /// Locale 无关折叠：土耳其 I（İ/I→i）、变音符号（é→e）都归一到 ASCII 小写，
    /// 关键词匹配不随设备 locale 变（localizedCaseInsensitiveContains 在 tr 下 I≠i）。
    @Test func foldedKeyIsLocaleIndependentAndDiacriticInsensitive() {
        #expect(TextNormalize.foldedKey("MIDI SKIRT") == "midi skirt")
        #expect(TextNormalize.foldedKey("Sézane") == "sezane")
        #expect(TextNormalize.foldedKey("İstanbul Jacket").contains("jacket"))
        #expect(TextNormalize.foldedKey("BLAZÉR").contains("blazer"))
    }

    @Test func isBlankMatchesBlankToNil() {
        #expect(TextNormalize.isBlank(nil))
        #expect(TextNormalize.isBlank(" "))
        #expect(!TextNormalize.isBlank(" M "))
    }
}
