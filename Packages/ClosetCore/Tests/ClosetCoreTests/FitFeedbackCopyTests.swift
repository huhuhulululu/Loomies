import Testing
@testable import ClosetCore

/// D85 波 D：合身反馈文案。`WearRecord.fitFeedback` 三层就绪却无 UI 入口。
struct FitFeedbackCopyTests {

    @Test func optionsAreOrderedAndHumanLabeled() {
        #expect(FitFeedbackCopy.options == [.tight, .fitted, .loose])
        let titles = FitFeedbackCopy.options.map(FitFeedbackCopy.choiceTitle)
        #expect(Set(titles).count == 3)
        for t in titles {
            #expect(!t.isEmpty)
            #expect(t.first?.isUppercase == true)
        }
        #expect(!FitFeedbackCopy.prompt.isEmpty)
        #expect(!FitFeedbackCopy.skipTitle.isEmpty)
    }

    @Test func recordedMessageNamesTheVerdictWithoutFalseClaims() {
        for v in FitFeedbackCopy.options {
            let msg = FitFeedbackCopy.recordedMessage(v)
            #expect(!msg.isEmpty)
            // 不得声称推荐会因此改变——v1.0 只采集，不喂 FitEngine
            #expect(!msg.localizedCaseInsensitiveContains("recommend"))
            #expect(!CustomerFlashStyleProbe.looksLikeFailure(msg))
        }
    }

    @Test func parseRoundTripsAndRejectsGarbage() {
        for v in FitFeedbackCopy.options {
            #expect(FitFeedbackCopy.parse(v.rawValue) == v)
        }
        #expect(FitFeedbackCopy.parse(nil) == nil)
        #expect(FitFeedbackCopy.parse("  ") == nil)
        #expect(FitFeedbackCopy.parse("fit") == nil)          // 历史脏值
        #expect(FitFeedbackCopy.parse("TIGHT") == .tight)     // 大小写容错
    }

    @Test func logCaptionOnlyForKnownVerdicts() {
        #expect(FitFeedbackCopy.logCaption("tight") != nil)
        #expect(FitFeedbackCopy.logCaption("nonsense") == nil)
        #expect(FitFeedbackCopy.logCaption(nil) == nil)
    }

    /// 导出披露：合身反馈会随 Export my data 出去，文案必须说明（不得让用户自己发现）。
    @Test func exportDisclosureExists() {
        #expect(FitFeedbackCopy.exportDisclosure
            .localizedCaseInsensitiveContains("export"))
    }
}

/// 与 ClosetUI.CustomerFlashStyle 同口径的失败关键词探针（Core 不依赖 UI）。
enum CustomerFlashStyleProbe {
    static func looksLikeFailure(_ text: String) -> Bool {
        let t = text.lowercased()
        return t.contains("couldn't") || t.contains("failed") || t.contains("missing from closet")
    }
}
