import Testing
import Foundation
@testable import ClosetModel
import ClosetCore

/// D174（功能覆盖普查）：`BodyFitConfidence.userLabel` 是**用户看得见的置信度标签**
/// ——「Measured」还是「Visual pick only」直接决定用户信不信那条合身结论——
/// 而它零测试。
///
/// 这类标签正是本 session 反复修的那种东西的高发地：
/// 说得比实际大（快选说成实测）、或说得含糊（用户不知道该不该信）。
struct ConfidenceLabelTests {

    /// 每一档都有话说，且互不相同——两档共用一句话，用户就分辨不出差别。
    @Test func everyLevelSaysSomethingDistinct() {
        let levels: [BodyFitConfidence] = [.none, .visualOnly, .provisional, .measured, .mixed]
        let labels = levels.map(\.userLabel)
        #expect(labels.allSatisfy { !$0.isEmpty })
        #expect(Set(labels).count == levels.count,
                Comment(rawValue: "有两档说的是同一句话：\(labels)"))
    }

    /// **快选不得自称实测。** 这条是 D101/D115 那一族的底线：
    /// 用户按视觉挑的体型，权重与可信度都低于四围实测，标签不许混同。
    @Test func aVisualPickNeverClaimsToBeMeasured() {
        let visual = BodyFitConfidence.visualOnly.userLabel.lowercased()
        #expect(!visual.contains("measured"),
                Comment(rawValue: "快选标签自称实测：\(BodyFitConfidence.visualOnly.userLabel)"))
        #expect(visual.contains("visual") || visual.contains("pick"))
    }

    /// 推断出来的部分要说出口——上臀是算的，不是量的。
    @Test func anEstimatedMeasurementIsDisclosed() {
        let label = BodyFitConfidence.provisional.userLabel.lowercased()
        #expect(label.contains("estimat") || label.contains("provisional"),
                Comment(rawValue: "推断上臀却不告诉用户：\(BodyFitConfidence.provisional.userLabel)"))
    }

    /// 没设过就说没设，不给一个像结论的词。
    @Test func anUnsetProfileSaysSo() {
        let label = BodyFitConfidence.none.userLabel.lowercased()
        #expect(label.contains("incomplete") || label.contains("not"),
                Comment(rawValue: BodyFitConfidence.none.userLabel))
        #expect(!label.contains("measured"))
    }

    /// 混合档要同时点出两个来源（只说一个就是漏报另一个）。
    @Test func theMixedLevelNamesBothSources() {
        let label = BodyFitConfidence.mixed.userLabel.lowercased()
        #expect(label.contains("measured"))
        #expect(label.contains("shape") || label.contains("pick") || label.contains("preference"))
    }

    /// 体型来源枚举的原始值是**存储契约**（落库字符串），改名即丢已发布用户数据。
    @Test func theSourceRawValuesAreAStorageContract() {
        #expect(BodyShapeSource.allCases.map(\.rawValue).sorted()
                == ["measured", "mixed", "none", "provisional", "visualPick"])
    }
}
