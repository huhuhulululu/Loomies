import Testing
import Foundation
import SwiftData
@testable import ClosetModel
import ClosetCore

/// D186：**导出带得走、导入接不住的四处。**
///
/// D134 那波把「六类表全部补上」写进了决策，而这轮核查逐字段对了一遍导出 DTO
/// 与导入回填，发现四处仍然只出不进：
///
/// 1. **转移历史整张表零读取** —— 导出侧按时间倒序序列化了 `TransferRecord`，
///    导入侧全仓 grep `snapshot.transfers` 零命中。单品详情页真在渲染
///    「Moved from X to Y」，换手机之后那一栏空了。
/// 2. **身体档案的六个字段** —— `fineChest/fineWaist/fineHip/fineHeight` 与
///    `presentationSexRaw/presentationPhenotypeRaw`。它们落到默认值意味着
///    头像的性别/人种被**静默改回**女性/东亚，而精调滑杆全部归 1。
/// 3. **搭配的场合与缺件标记** —— `occasionRaw` 在卡片背景与「N pieces · Work」
///    上都在用；`permanentlyMissing` 重置成 false 会让一个成员已被删的残缺 look
///    重新混进收藏列表且不带任何警示。
/// 4. **「Nothing to import」的同时其实已经落库** —— 收据只看衣柜数与件数，
///    而人、身体档案、穿着历史、计划在 save 之前已无条件 insert。
///
/// 为什么门没红：`everyTableComesOver` 只断言四个计数
/// （locations/wear/plans/Person.count），删掉一整张表照样绿；
/// 而 `richExport` 的夹具**从头到尾没插过 TransferRecord**——
/// 这是本轮第五次撞见「夹具没造出那条数据，于是断言测不到它」。
@MainActor
struct ImportFidelityTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    private func grantedConsent(_ label: String) -> BodyDataConsent {
        let c = BodyDataConsent(defaults: UserDefaults(
            suiteName: "loomies.test.fidelity.\(label).\(UUID().uuidString)")!)
        c.setGranted(true)
        return c
    }

    /// 一份**什么都有**的导出：这次连转移历史、精调值、展示底座、
    /// 搭配的场合与缺件标记都造齐（原来的夹具缺了它们，于是断言测不到）。
    private func richExport() throws -> Data {
        let ctx = try makeContext()
        let person = Person(name: "Ping"); ctx.insert(person)
        let home = Wardrobe(name: "Home"); home.owner = person; ctx.insert(home)
        let lake = Wardrobe(name: "Lake"); lake.owner = person; ctx.insert(lake)
        let tee = Item(name: "Tee"); tee.slotRaw = "top"; tee.wardrobe = home
        ctx.insert(tee)
        let look = ClosetModel.Outfit(name: "Look"); look.wardrobe = home; look.items = [tee]
        look.occasionRaw = "work"
        look.permanentlyMissing = true
        look.isFavorite = true
        ctx.insert(look)
        let profile = PersonBodyProfile(personID: person.id)
        profile.bustInches = 36; profile.waistInches = 28
        profile.fineChest = 1.08; profile.fineWaist = 0.94
        profile.fineHip = 1.03; profile.fineHeight = 1.02
        profile.presentationSexRaw = AvatarBodySex.male.rawValue
        profile.presentationPhenotypeRaw = AvatarBodyPhenotype.allCases.last?.rawValue
        ctx.insert(profile)
        ctx.insert(TransferRecord(itemID: tee.id, from: lake.id, to: home.id))
        try ctx.save()
        return try DataLifecycleService.exportJSONData(in: ctx, includeBodyDimensions: true)
    }

    /// #31 转移历史导得回来，且**重映射到新 id**（软引用直接照抄等于没导）。
    @Test func moveHistoryComesBack() throws {
        let ctx = try makeContext()
        let receipt = try ImportService.importSnapshot(
            try richExport(), into: ctx, consent: grantedConsent("moves"))
        let records = try ctx.fetch(FetchDescriptor<TransferRecord>())
        #expect(records.count == 1, Comment(rawValue:
            "转移历史没导过来 —— 详情页那栏「Moved from X to Y」换手机后就空了"))
        #expect(receipt.transfersAdded == 1)
        let item = try #require(try ctx.fetch(FetchDescriptor<Item>()).first)
        #expect(records.first?.itemID == item.id, "软引用没重映射，指向本机不存在的单品")
        let closets = try ctx.fetch(FetchDescriptor<Wardrobe>())
        #expect(closets.contains { $0.id == records.first?.toWardrobeID },
                "目的柜 id 没重映射")
    }

    /// #32 展示底座与精调值一并回来（否则头像被静默改回默认女性/东亚）。
    @Test func theAvatarKeepsItsPresentationAndFineTuning() throws {
        let ctx = try makeContext()
        _ = try ImportService.importSnapshot(
            try richExport(), into: ctx, consent: grantedConsent("avatar"))
        let profile = try #require(try ctx.fetch(
            FetchDescriptor<PersonBodyProfile>()).first)
        #expect(profile.presentationSexRaw == AvatarBodySex.male.rawValue, Comment(rawValue:
            "展示性别被静默改回默认：\(profile.presentationSexRaw ?? "nil")"))
        #expect(profile.presentationPhenotypeRaw != nil, "人种被静默改回默认")
        #expect(profile.fineChest == 1.08, "精调滑杆全部归 1")
        #expect(profile.fineHeight == 1.02)
    }

    /// #33 搭配的场合与缺件标记（残缺 look 不得静默混回收藏列表）。
    @Test func aLookKeepsItsOccasionAndMissingFlag() throws {
        let ctx = try makeContext()
        _ = try ImportService.importSnapshot(
            try richExport(), into: ctx, consent: grantedConsent("look"))
        let look = try #require(try ctx.fetch(FetchDescriptor<ClosetModel.Outfit>()).first)
        #expect(look.occasionRaw == "work", Comment(rawValue:
            "场合丢了，卡片上的「N pieces · Work」退成「—」：\(look.occasionRaw ?? "nil")"))
        #expect(look.permanentlyMissing, "缺件标记被重置 —— 残缺的 look 会不带警示地混回收藏")
    }

    /// #34 有东西落库就不许说「Nothing to import」。
    @Test func aFileWithOnlyPeopleDoesNotClaimNothingHappened() throws {
        let ctx = try makeContext()
        let data = try JSONEncoder().encode(DataLifecycleService.ExportSnapshot(
            schemaVersion: ImportService.supportedSchemaVersion,
            exportedAt: "2026-08-13", includeBodyDimensions: false,
            persons: [DataLifecycleService.PersonDTO(
                id: UUID().uuidString, name: "Ping", coldBias: 1,
                personalColorSeasonRaw: nil, primaryOccasionRaw: nil)],
            wardrobes: [], locations: [], items: [], outfits: [],
            wearRecords: [], plans: [], transfers: [], bodyProfiles: nil))

        let receipt = try ImportService.importSnapshot(
            data, into: ctx, consent: grantedConsent("nothing"))
        #expect(try ctx.fetch(FetchDescriptor<Person>()).count == 1, "人确实落库了")
        #expect(!receipt.summary.localizedCaseInsensitiveContains("nothing to import"),
                Comment(rawValue: "东西已经进库了，收据却说什么都没导：\(receipt.summary)"))
    }

    /// 真的什么都没有时仍然照实说。
    @Test func atrulyEmptyFileStillSaysNothing() throws {
        let ctx = try makeContext()
        let data = try JSONEncoder().encode(DataLifecycleService.ExportSnapshot(
            schemaVersion: ImportService.supportedSchemaVersion,
            exportedAt: "2026-08-13", includeBodyDimensions: false,
            persons: [], wardrobes: [], locations: [], items: [], outfits: [],
            wearRecords: [], plans: [], transfers: [], bodyProfiles: nil))
        let receipt = try ImportService.importSnapshot(
            data, into: ctx, consent: grantedConsent("empty"))
        #expect(receipt.summary.localizedCaseInsensitiveContains("nothing to import"))
    }

    /// 结构门：**导出 DTO 的每个字段都得有人接。**
    ///
    /// 手工对照表会过期，而这正是本条缺陷的成因——D134 说「六类全部补上」，
    /// 之后 DTO 又长出了新字段，没人回头看导入侧。
    /// 判据认构造：DTO 里声明的属性名，必须在 `ImportService` 的回填里出现。
    @Test func everyExportedFieldHasAnImporter() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/ClosetModel")
        let dtoText = try String(
            contentsOf: sources.appendingPathComponent("DataLifecycleService.swift"),
            encoding: .utf8)
        let importText = try String(
            contentsOf: sources.appendingPathComponent("ImportService.swift"),
            encoding: .utf8)
        let importCode = importText.split(separator: "\n").filter {
            let t = $0.trimmingCharacters(in: .whitespaces)
            return !t.hasPrefix("//") && !t.hasPrefix("///") && !t.hasPrefix("*")
        }.joined(separator: "\n")

        /// 这些字段**刻意**不导（各有理由，改了要连同理由一起改）。
        let deliberatelyDropped: Set<String> = [
            "id",                  // 一律重新分配（只增不改，绝不覆盖已有行）
            "schemaVersion", "exportedAt", "includeBodyDimensions",
            "localImageRelativePath",  // 照片不在数据文件里（收据明说）
            "sourceRaw",           // 生产零读取点（来源标签，只写不读）
            "notes",               // Outfit.notes 生产零写入/零读取点
        ]
        var missing: [String] = []
        var scanned = 0
        for dto in ["TransferDTO", "BodyProfileDTO", "OutfitDTO", "PersonDTO",
                    "WearRecordDTO", "CalendarPlanDTO"] {
            guard let r = dtoText.range(of: "public struct \(dto)") else { continue }
            let rest = dtoText[r.upperBound...]
            let end = rest.range(of: "\n    }")?.lowerBound ?? rest.endIndex
            for line in rest[rest.startIndex..<end].split(separator: "\n") {
                let t = line.trimmingCharacters(in: .whitespaces)
                guard t.hasPrefix("public var ") else { continue }
                let name = String(t.dropFirst("public var ".count)
                    .prefix { $0 != ":" && $0 != " " })
                guard !deliberatelyDropped.contains(name) else { continue }
                scanned += 1
                if !importCode.contains("dto.\(name)") { missing.append("\(dto).\(name)") }
            }
        }
        #expect(scanned >= 25, Comment(rawValue: "只扫到 \(scanned) 个字段：解析口径坏了"))
        #expect(missing.isEmpty, Comment(rawValue:
            "这些字段导得出、导不回：\(missing) —— 用户以为搬完了"))
    }
}
