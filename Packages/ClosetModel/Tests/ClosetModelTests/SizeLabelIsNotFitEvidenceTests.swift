import Testing
import Foundation
import SwiftData
@testable import ClosetModel
import ClosetCore

/// D205：`docs/requirements` W3.2 的**真意图**——尺码标签不得当合身证据。
///
/// 原文写的是「合身标记仍**只依赖**身体围度 + 平铺宽」。那句话现在**字面已不成立**：
/// D196 让用户穿过之后反复报告的结论压过了尺寸算出来的预测。
///
/// 但它的**意图**没变，而且意图比字面重要：`W3.1` 那条尺码参考提示自己写着
/// 「not brand-true」——同一个 M 在两个品牌之间不可比。
/// 拿它当合身证据，等于把一个已知不可比的东西喂进决策层。
///
/// 所以这条钉的是意图：**`sizeLabel` / `sizeSystemRaw` 永远不进合身链。**
/// 而不是钉那句已经过期的字面。
@MainActor
struct SizeLabelIsNotFitEvidenceTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    /// **行为**：换掉尺码标签，合身结论一个字不变。
    @Test func changingTheSizeLabelDoesNotMoveTheFitMark() throws {
        let ctx = try makeContext()
        let person = Person(name: "P"); ctx.insert(person)
        let profile = PersonBodyProfile(personID: person.id)
        profile.bustInches = 36; profile.waistInches = 28
        profile.hipInches = 38; profile.highHipInches = 34
        ctx.insert(profile)
        let tee = Item(name: "Tee"); tee.slotRaw = "top"
        tee.chestFlatWidthInches = 20
        ctx.insert(tee)
        try ctx.save()

        let before = FitMarkService.mark(item: tee, profile: profile)
        for label in ["XS", "M", "XXL", "US 2", "EU 46", ""] {
            tee.sizeLabel = label
            tee.sizeSystemRaw = label.hasPrefix("EU") ? "eu" : "us"
            #expect(FitMarkService.mark(item: tee, profile: profile) == before,
                    Comment(rawValue: "尺码标签改成「\(label)」之后合身结论变了 —— "
                            + "而同一个码在两个品牌之间不可比（W3.1 自己写着 not brand-true）"))
        }
    }

    /// **结构**：合身链上的三个文件，一个字都不许读尺码。
    ///
    /// 行为测试只覆盖当前这条路径；下一个往打分或合身里接尺码的人不会被它挡住。
    @Test func noFitCodeReadsTheSizeLabel() throws {
        let packages = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let fitChain = [
            "ClosetModel/Sources/ClosetModel/FitMarkService.swift",
            "ClosetCore/Sources/ClosetCore/FitEngine.swift",
            "ClosetCore/Sources/ClosetCore/Recommendation/OutfitScorer.swift",
        ]
        var offenders: [String] = []
        var scanned = 0
        for relative in fitChain {
            let url = packages.appendingPathComponent(relative)
            let text = try String(contentsOf: url, encoding: .utf8)
            scanned += 1
            for (n, line) in text.split(separator: "\n").enumerated() {
                let t = line.trimmingCharacters(in: .whitespaces)
                guard !t.hasPrefix("//"), !t.hasPrefix("///"), !t.hasPrefix("*") else { continue }
                if t.contains("sizeLabel") || t.contains("sizeSystem") {
                    offenders.append("\(url.lastPathComponent):\(n + 1)")
                }
            }
        }
        #expect(scanned == fitChain.count, "合身链的文件路径变了 —— 判据要跟着改")
        #expect(offenders.isEmpty, Comment(rawValue:
            "尺码标签进了合身链：\(offenders) —— 它 not brand-true，不能当证据"))
    }

    /// 合身链**现在**吃哪几样，写下来（W3.2 的字面已随 D196 变化，这里是新口径）。
    @Test func theCurrentFitInputsAreRecorded() throws {
        let ctx = try makeContext()
        let person = Person(name: "P"); ctx.insert(person)
        let profile = PersonBodyProfile(personID: person.id)
        profile.bustInches = 36; profile.waistInches = 28
        profile.hipInches = 38; profile.highHipInches = 34
        ctx.insert(profile)
        let tee = Item(name: "Tee"); tee.slotRaw = "top"
        tee.chestFlatWidthInches = 20
        ctx.insert(tee)
        try ctx.save()

        // ① 身体围度 + 平铺宽 → 预测
        #expect(FitMarkService.mark(item: tee, profile: profile) == .fitted)
        // ② 用户穿过之后反复报告的结论 → 压过预测（D196）
        let reported = FitFeedbackHistory.Settled(verdict: .tight, count: 2, total: 2)
        #expect(FitMarkService.mark(item: tee, profile: profile, reported: reported) == .tight)
        // ③ 槽位（鞋/配饰没有这个维度，D180）
        tee.slotRaw = "shoes"
        #expect(FitMarkService.mark(item: tee, profile: profile, reported: reported) == nil)
    }
}
