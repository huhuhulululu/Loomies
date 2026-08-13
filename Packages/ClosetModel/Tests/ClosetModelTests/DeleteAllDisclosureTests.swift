import Testing
import Foundation
import SwiftData
@testable import ClosetModel

/// D144：**删库的披露少说了三类数据，而 VoiceOver 版本比可见版本还少。**
///
/// 确认弹窗说的是「closets, pieces, looks, wear history, plans, and local photos」，
/// 而 `deleteAllUserData` 实际还抹掉了**存放位置树**（用户一层层建起来的柜格）、
/// **转移历史**（这件衣服去过哪儿）和 **Person**。用户按下「删除一切」时
/// 确实想删一切——问题不在删，在于他事后才知道自己删了什么。
///
/// 更硬的一条：`deleteAllButtonAccessibilityHint` 只说
/// 「closets, pieces, looks, and body data」——**视障用户拿到的披露
/// 比明眼用户更差**。同一件事两处文案，注定走岔。
///
/// 处置：披露收成**唯一一份** `DataLifecycleService.deleteAllDisclosure`，
/// 弹窗与 a11y hint 都读它；再加一道结构门——删库里每多抹一张表，
/// 披露必须跟着点名，否则红。
@MainActor
struct DeleteAllDisclosureTests {

    private var serviceSource: String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/ClosetModel/DataLifecycleService.swift")
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    /// 实体 → 用户读得懂的说法。**新表进删库就必须在这里有一行**，
    /// 否则下面那条门会红——这正是它存在的意义。
    private let nouns: [String: [String]] = [
        "CalendarPlan": ["plan"],
        "TransferRecord": ["transfer", "have moved"],
        "WearRecord": ["wear history", "worn"],
        "Outfit": ["look"],
        "Item": ["piece"],
        // D161：原来这里放了 "where"——而披露里「where pieces have moved」
        // （那是**转移历史**的说法）恰好也含 "where"，于是拿掉「storage spots」
        // 之后门照样绿。同义词要**互不串味**，否则一个实体的说法会替另一个背书。
        "StorageLocation": ["storage spot"],
        "Wardrobe": ["closet"],
        "Person": ["people", "person", "profile"],
        "PersonBodyProfile": ["body"],
    ]

    /// 结构门：删库抹掉的每一张表，披露都得点到名。
    @Test func everyWipedTableIsDisclosed() throws {
        let source = serviceSource
        #expect(!source.isEmpty)
        let wiped = source
            .components(separatedBy: "wipeAll(")
            .dropFirst()
            .compactMap { $0.components(separatedBy: ".self").first }
            .filter { !$0.contains("(") && !$0.isEmpty }
        #expect(wiped.count >= 8, Comment(rawValue: "只解析出 \(wiped): 解析口径坏了"))

        let disclosure = DataLifecycleService.deleteAllDisclosure.lowercased()
        for entity in Set(wiped) {
            guard let synonyms = nouns[entity] else {
                Issue.record(Comment(rawValue:
                    "\(entity) 进了删库，而披露里没有对应说法 —— "
                    + "用户删掉了一类他从没被告知的数据"))
                continue
            }
            #expect(synonyms.contains { disclosure.contains($0) },
                    Comment(rawValue: "披露没点名 \(entity)：\(disclosure)"))
        }
    }

    /// 本地照片也要说（盘上文件不在任何一张表里，最容易漏）。
    @Test func localPhotosAreNamedToo() {
        #expect(DataLifecycleService.deleteAllDisclosure
            .localizedCaseInsensitiveContains("photo"))
    }

    /// 不可撤销必须说出口。
    @Test func theDisclosureSaysItCannotBeUndone() {
        #expect(DataLifecycleService.deleteAllDisclosure
            .localizedCaseInsensitiveContains("undone")
            || DataLifecycleService.deleteAllDisclosure
            .localizedCaseInsensitiveContains("permanent"))
    }

    /// **VoiceOver 不得拿到更差的披露。** hint 与弹窗读同一份，
    /// 两处文案注定走岔——D144 之前它们已经走岔了。
    @Test func voiceOverGetsTheSameDisclosure() {
        let hint = DataLifecycleService.deleteAllButtonAccessibilityHint
        #expect(hint.contains(DataLifecycleService.deleteAllDisclosure),
                Comment(rawValue: "a11y hint 与可见文案不同源：\(hint)"))
    }

    /// 回执要认账转移历史——删了却不记，等于删除权的账目缺一笔。
    @Test func theReceiptCountsTransferRecords() throws {
        let ctx = try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
        let w = Wardrobe(name: "Main"); ctx.insert(w)
        let item = Item(name: "Tee"); item.wardrobe = w; ctx.insert(item)
        ctx.insert(TransferRecord(itemID: item.id, from: w.id, to: UUID()))
        try ctx.save()

        let receipt = try DataLifecycleService.deleteAllUserData(
            in: ctx, wipeItemImages: false)
        #expect(receipt.deletedTransferRecords == 1,
                "转移历史被删了，回执里一个数都没有")
    }

    /// 回执自己往返得开。
    ///
    /// **写这条时撞出一件计划外的事**：`imageWipeFailed` 的注释写着
    /// 「默认 false 兼容旧回执解码」，而 Swift 合成的 `Decodable`
    /// 根本不看默认值——缺键直接 `keyNotFound`，那个保证从来不成立。
    /// 回执生产上只构造、不解码，所以不去加自定义 `init(from:)`
    /// （那是没人要的防御），但注释已改成不再声称它。
    @Test func theReceiptRoundTrips() throws {
        let receipt = DataLifecycleService.DeleteReceipt(
            deletedAt: "2026-08-13T00:00:00Z", deletedPersons: 1, deletedWardrobes: 1,
            deletedLocations: 2, deletedItems: 3, deletedOutfits: 1,
            deletedWearRecords: 4, deletedPlans: 1, deletedBodyProfiles: 1,
            wipedItemImages: true, imageWipeFailed: false, resetConsent: true,
            deletedTransferRecords: 5)
        let back = try JSONDecoder().decode(
            DataLifecycleService.DeleteReceipt.self,
            from: try JSONEncoder().encode(receipt))
        #expect(back == receipt)
    }
}
