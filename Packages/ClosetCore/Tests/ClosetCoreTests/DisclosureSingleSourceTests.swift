import Testing
import Foundation
@testable import ClosetCore

/// D191：披露的四处走岔 + 三处说得比做得少。
struct DisclosureSingleSourceTests {

    // MARK: - #38 删库范围有三份手抄，且已经岔开

    /// FAQ 与隐私政策都得说**同一份**删除范围。
    ///
    /// 正本（`DataLifecycleService.deleteAllDisclosure`）列了
    /// closets / pieces / looks / wear history / plans / **storage spots** /
    /// **where pieces have moved** / **people** / measurements / local photos。
    /// FAQ 与政策各自手抄了一份，两份都漏掉那三类——
    /// D144 修的正是「同一件事两处文案注定走岔」，这里是同一形态在第三、第四处复发。
    ///
    /// 危害方向要说清：FAQ 给的是**更保守**的范围，不会诱导误删；
    /// 问题是用户据此以为存放位置树和转移历史留得住。
    @Test func theFAQAndPolicyQuoteTheCanonicalDeleteScope() {
        let faq = ComplianceCopy.faq
            .first { $0.question.localizedCaseInsensitiveContains("delete everything") }
        let answer = try? #require(faq?.answer)
        #expect((answer ?? "").contains(DeleteScopeCopy.removedList), Comment(rawValue:
            "FAQ 手抄了一份删除范围：\(answer ?? "nil")"))

        let policy = ComplianceCopy.policyDocuments(hasSink: false)
            .first { $0.title.localizedCaseInsensitiveContains("privacy") }
        let rights = policy?.sections
            .first { $0.heading.localizedCaseInsensitiveContains("rights") }?.body ?? ""
        #expect(rights.contains(DeleteScopeCopy.removedList), Comment(rawValue:
            "隐私政策手抄了第三份：\(rights)"))
    }

    /// 那份清单本身要点到名（门自己也要能被撞）。
    @Test func theCanonicalListNamesTheEasilyForgottenThree() {
        let list = DeleteScopeCopy.removedList.lowercased()
        for noun in ["storage spot", "moved", "people"] {
            #expect(list.contains(noun), Comment(rawValue: "清单漏了 \(noun)：\(list)"))
        }
    }

    // MARK: - #41 围度的备份披露比照片少

    /// 身体围度和照片一样会随**设备备份**上云——这件事要说出口。
    ///
    /// 文案原来只说「excluded from cloud sync」。那句不是谎言（两个 store 都
    /// `cloudKitDatabase: .none`），但**对更敏感的数据披露更少**：
    /// 照片那边明写「included in your device backup」，围度这边只字不提。
    /// 而 D90 的注释「身体维度不在此列——独立本地 store + D5 明令不同步」
    /// 本身就把 sync 与 backup 混为一谈——说明这不是深思后的取舍，是概念混淆。
    ///
    /// 「换新手机」那一问尤其要紧：用户会据此以为围度不随备份恢复。
    @Test func theBodyStorageCopySaysItIsInTheDeviceBackup() {
        let copy = BodyDataStorageCopy.whereItLives.lowercased()
        #expect(copy.contains("sync"), "不同步这条仍要说")
        #expect(copy.contains("backup"), Comment(rawValue:
            "只说了不同步，没说它和照片一样在设备备份里：\(copy)"))
    }

    /// 两处 FAQ 与政策都读同一句（第三次手抄就是第三次走岔的机会）。
    @Test func everyPlaceThatMentionsBodyStorageUsesTheSameSentence() {
        let mentions = ComplianceCopy.faq
            .filter { $0.answer.localizedCaseInsensitiveContains("body measurements")
                || $0.answer.localizedCaseInsensitiveContains("measurements live") }
        #expect(!mentions.isEmpty, "前提不成立：FAQ 里找不到讲围度存储的条目")
        for entry in mentions where entry.answer.localizedCaseInsensitiveContains("separate local store") {
            #expect(entry.answer.contains(BodyDataStorageCopy.whereItLives),
                    Comment(rawValue: "这一条自己写了一份：\(entry.answer)"))
        }
    }

    // MARK: - #43 尺码提示套的是女装表，却不说

    /// 换算表是女装的，就得说是女装的。
    ///
    /// `displayHint` 两条换算分支都经 `womensNumericBridge`，alpha 分支走
    /// `alphaToUSWomensMidpoint`（S→4 / M→8 / L→12 / XL→16）。
    /// 于是一件男装 L 被换算成「US 12 / EU 42 / UK 16」——数字本身没错，
    /// 错的是它没说这是哪张表。同文件里的 `mensChestInchesToAlpha` 零调用点。
    ///
    /// 不按品类自动切表：单品上没有性别字段，猜错比说清更糟。
    @Test func theSizeHintNamesWhichChartItUsed() {
        let alpha = try? #require(PublicSizeReference.displayHint(forLabel: "L"))
        #expect((alpha ?? "").localizedCaseInsensitiveContains("women"), Comment(rawValue:
            "没说这是女装表 —— 男装 L 会被读成 US 12：\(alpha ?? "nil")"))
        let numeric = try? #require(PublicSizeReference.displayHint(forLabel: "US 8"))
        #expect((numeric ?? "").localizedCaseInsensitiveContains("women"))
    }

    /// 不换算时那句话一个字不变（没有换算就没有「哪张表」的问题）。
    @Test func theNoConversionHintIsUnchanged() {
        let hint = PublicSizeReference.displayHint(forLabel: "42R")
        #expect(hint?.localizedCaseInsensitiveContains("kept as-is") == true)
        #expect(hint?.localizedCaseInsensitiveContains("women") != true)
    }

    // MARK: - #42 「Send feedback」没有收件方

    /// 没有收件方就别摆这个板块——它教用户「attach it to your message」，
    /// 而 App 里没有任何邮箱 / 表单 / 工单（`ReleaseFacts.supportContact` 为 nil）。
    ///
    /// 这条已经登记在提审阻断项里（填一个字符串即消失），但 TestFlight
    /// 阶段的测试者会实打实撞上这条死路。
    @Test func theFeedbackSectionOnlyShowsWhenThereIsSomewhereToSendIt() {
        #expect(ComplianceCopy.showsFeedbackSection(contact: nil) == false,
                "没有收件方却还在教用户把诊断包「attach to your message」")
        #expect(ComplianceCopy.showsFeedbackSection(contact: "help@example.com"))
        #expect(ComplianceCopy.showsFeedbackSection(contact: "   ") == false, "空白不算收件方")
    }

    /// 有收件方时，文案要把它说出来（否则用户仍然不知道寄给谁）。
    @Test func theFeedbackCopyNamesTheRecipient() {
        let body = ComplianceCopy.feedbackBody(contact: "help@example.com")
        #expect(body.contains("help@example.com"), Comment(rawValue: body))
    }
}

/// D193：批量入库把「衣服进柜了、图没跟上」这件事整条丢掉。
///
/// 单张路径确认后会弹一句诚实提示（抠图 / 归一 / 写盘失败三选一），
/// 而批量路径的 `return` 在 `postConfirmFlash` 之前，`recordBatch` 第一件事
/// 就是 `reset()`——statusMessage 当场没了。于是批量入库的用户
/// **永远不知道哪几件没有照片**，而批量正是默认路径。
///
/// 逐张弹提示会打断批量节奏，所以记进账、汇总里一次说清。
struct BatchPhotoLossSummaryTests {

    private func queue(_ outcomes: [BatchIntakeQueue.Outcome]) -> BatchIntakeQueue {
        var q = BatchIntakeQueue(total: outcomes.count)
        for o in outcomes { q.record(o) }
        return q
    }

    @Test func theSummaryNamesThePiecesThatLostTheirPhoto() {
        let q = queue([.added, .addedWithoutPhoto, .addedWithoutPhoto, .skipped])
        #expect(q.addedCount == 3, "没跟上照片的件确实进柜子了，要算进 added")
        #expect(q.addedWithoutPhotoCount == 2)
        #expect(q.summary.localizedCaseInsensitiveContains("without a try-on photo"),
                Comment(rawValue: "汇总一个字没提丢图的件：\(q.summary)"))
        #expect(q.summary.contains("2"))
    }

    /// 一件都没丢图时不许凭空多出这句（别造噪声）。
    @Test func aCleanBatchSaysNothingAboutPhotos() {
        let q = queue([.added, .added, .skipped])
        #expect(q.addedWithoutPhotoCount == 0)
        #expect(!q.summary.localizedCaseInsensitiveContains("without a try-on photo"))
    }

    /// 要指路——D185 之后补图这条路是真的存在的。
    @Test func itPointsAtTheReplacePhotoEntry() {
        let q = queue([.addedWithoutPhoto])
        #expect(q.summary.localizedCaseInsensitiveContains("page"), Comment(rawValue: q.summary))
    }
}
