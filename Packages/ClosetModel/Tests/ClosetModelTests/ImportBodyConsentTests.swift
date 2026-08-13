import Testing
import Foundation
import SwiftData
@testable import ClosetModel
import ClosetCore

/// D177：**导入把身体围度直接写进本地库，完全绕过同意门。**
///
/// `BodyDataConsent` 的文件抬头写着「门必须在**任何 context.insert 之前**判定」，
/// 而 `ImportService` 那段 `for dto in snapshot.bodyProfiles ?? []` 从头到尾
/// 没有一处读 `isGranted`——同意开关是 off 的用户导入一份带围度的文件，
/// 围度照样落库，落库之后 `FitMarkService` / `OwnerBodyDerivation` 照常消费它。
///
/// 用户侧看到的是：Me → Body 仍然只显示那张「要不要用你的围度」的同意卡
///（`isGranted == false`），而 App 已经在拿他的围度算合身标记与体型头像。
/// 同意卡上印着 “we won't store them without your say-so”——这条路上它是假的。
///
/// 收据也只字不提：summary 只拼 pieces/closets/looks/wear records/plans/spots。
/// 用户既不知道导进来了，也不会知道被跳过了。
///
/// 处置：未同意 → **跳过**（不是先写后删——insert 之后再判会留 pending 脏行），
/// 并在收据里如实说明跳了几份、怎么才能拿回来。
@MainActor
struct ImportBodyConsentTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    /// 每个用例一份独立 defaults——同意开关是进程级单例，
    /// 共用会让并行跑的用例互相拨开关（D154/D158 同族）。
    private func consent(granted: Bool, _ label: String) -> BodyDataConsent {
        let defaults = UserDefaults(suiteName: "loomies.test.consent.\(label).\(UUID().uuidString)")!
        let c = BodyDataConsent(defaults: defaults)
        c.setGranted(granted)
        return c
    }

    /// 一份带围度的导出。
    private func exportWithBody() throws -> Data {
        let ctx = try makeContext()
        let person = Person(name: "Ping"); ctx.insert(person)
        let w = Wardrobe(name: "Home"); w.owner = person; ctx.insert(w)
        let tee = Item(name: "Tee"); tee.slotRaw = "top"; tee.wardrobe = w; ctx.insert(tee)
        let profile = PersonBodyProfile(personID: person.id)
        profile.bustInches = 36; profile.waistInches = 28; profile.hipInches = 38
        ctx.insert(profile)
        try ctx.save()
        return try DataLifecycleService.exportJSONData(in: ctx, includeBodyDimensions: true)
    }

    /// **本波的核心**：同意 off → 一条围度都不许落库。
    @Test func withoutConsentNoMeasurementLandsInTheStore() throws {
        let ctx = try makeContext()
        let receipt = try ImportService.importSnapshot(
            try exportWithBody(), into: ctx, consent: consent(granted: false, "off"))
        let profiles = try ctx.fetch(FetchDescriptor<PersonBodyProfile>())
        #expect(profiles.isEmpty, Comment(rawValue:
            "同意开关是 off，围度却落了 \(profiles.count) 份 —— "
            + "「we won't store them without your say-so」在这条路上是假的"))
        #expect(receipt.bodyProfilesAdded == 0)
        #expect(receipt.bodyProfilesSkippedForConsent == 1)
        // 衣柜/单品照常导入——跳过的只是身体维度
        #expect(receipt.itemsAdded == 1)
    }

    /// 跳过了就得说出口，并且要说清怎么拿回来。
    @Test func theReceiptSaysMeasurementsWereSkipped() throws {
        let ctx = try makeContext()
        let receipt = try ImportService.importSnapshot(
            try exportWithBody(), into: ctx, consent: consent(granted: false, "copy"))
        let summary = receipt.summary.lowercased()
        #expect(summary.contains("measurement"), Comment(rawValue:
            "收据一个字没提被跳过的围度：\(receipt.summary)"))
        // 只说「跳过了」不够——用户得知道下一步做什么
        #expect(summary.contains("turn on") || summary.contains("body measurements"),
                Comment(rawValue: "没告诉用户怎么把围度拿回来：\(receipt.summary)"))
    }

    /// 同意 on → 行为一个字不变（D134 导入完整性不得被这道门误伤）。
    @Test func withConsentMeasurementsStillComeOver() throws {
        let ctx = try makeContext()
        let receipt = try ImportService.importSnapshot(
            try exportWithBody(), into: ctx, consent: consent(granted: true, "on"))
        let profiles = try ctx.fetch(FetchDescriptor<PersonBodyProfile>())
        #expect(profiles.count == 1, "同意了却没导过来")
        #expect(profiles.first?.bustInches == 36)
        #expect(receipt.bodyProfilesAdded == 1)
        #expect(receipt.bodyProfilesSkippedForConsent == 0)
        #expect(!receipt.summary.lowercased().contains("turn on body measurements"),
                "没跳过任何东西却在收据里劝人开开关")
    }

    /// 文件里本来就没有围度时，不许凭空多出一句「被跳过了」。
    @Test func aFileWithoutMeasurementsSaysNothingAboutThem() throws {
        let ctx = try makeContext()
        let source = try makeContext()
        let w = Wardrobe(name: "Home"); source.insert(w)
        let tee = Item(name: "Tee"); tee.wardrobe = w; source.insert(tee)
        try source.save()
        let data = try DataLifecycleService.exportJSONData(
            in: source, includeBodyDimensions: false)

        let receipt = try ImportService.importSnapshot(
            data, into: ctx, consent: consent(granted: false, "none"))
        #expect(receipt.bodyProfilesSkippedForConsent == 0)
        #expect(!receipt.summary.lowercased().contains("measurement"),
                Comment(rawValue: "文件里没有围度，收据却提了：\(receipt.summary)"))
    }

    /// 结构门：身体档案的落库**必须**在同意判定之内。
    ///
    /// 行为用例只覆盖当前这一条导入路径；下一个往 `ImportService` 里加
    /// 身体维度写入的人不会自动被它挡住。判据认**构造**（`insert` 与
    /// `isGranted` 的相对位置），不认词——本仓已经六次栽在「认词不认构造」上。
    @Test func theBodyLoopSitsInsideTheConsentGate() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/ClosetModel/ImportService.swift")
        let text = try String(contentsOf: url, encoding: .utf8)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        func codeIndex(_ needle: String) -> Int? {
            lines.firstIndex {
                let t = $0.trimmingCharacters(in: .whitespaces)
                return t.contains(needle)
                    && !t.hasPrefix("//") && !t.hasPrefix("///") && !t.hasPrefix("*")
            }
        }
        let gate = try #require(codeIndex("consent.isGranted"), "导入里找不到同意判定")
        let insert = try #require(codeIndex("context.insert(profile)"), "找不到身体档案落库")
        #expect(gate < insert, Comment(rawValue:
            "身体档案在第 \(insert + 1) 行落库，而同意判定在第 \(gate + 1) 行 —— "
            + "insert 之后再判会留下 pending 脏行（BodyDataConsent 抬头那条铁律）"))
    }
}
