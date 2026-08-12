import Foundation
import SwiftData
import ClosetCore

/// 穿着打卡（DESIGN §F5，v1.0「记录」环）：记录当天穿了哪些单品，固化衣柜快照。
public enum CheckInService {
    /// Customer toast when ModelSave fails on check-in (no silent success).
    public static let saveFailedMessage = "Couldn't save check-in — try again"

    /// Records wear. Returns `nil` when items is empty or ModelSave fails (insert rolled back; caller keeps selection).
    @discardableResult
    public static func recordWear(
        items: [Item], on date: Date, in wardrobe: Wardrobe,
        fitFeedback: String? = nil, in context: ModelContext
    ) -> WearRecord? {
        // 同柜守卫：外柜单品不得计入本柜快照（与 OutfitDraftService 不变量一致）。
        let items = items.filter { $0.wardrobe?.id == wardrobe.id }
        guard !items.isEmpty else {
            AppLog.error("checkIn rejected: no items wardrobe=\(AppLog.ref(wardrobe.id))", .data)
            return nil
        }
        let rec = WearRecord(date: date)
        rec.wornItemIDs = items.map { $0.id.uuidString }
        rec.wardrobeSnapshotID = wardrobe.id
        rec.fitFeedback = fitFeedback
        context.insert(rec)
        guard ModelSave.save(context, label: "checkIn") else {
            // rollback 一并丢弃 pending insert（delete 只删行，脏标记会滞留）
            context.rollback()   // 失败变更不得滞留，否则污染下一次无关 save
            AppLog.error("checkIn save failed wardrobe=\(AppLog.ref(wardrobe.id))", .data)
            return nil
        }
        AppLog.info("checkIn \(items.count) items wardrobe=\(AppLog.ref(wardrobe.id))", .data)
        return rec
    }

    /// Customer toast when the follow-up fit note fails to save.
    public static let fitFeedbackSaveFailedMessage = "Couldn't save fit feedback — try again"

    public static let deleteFailedMessage = "Couldn't remove this entry — try again"

    /// 删一条打卡记录（记错了日子）。删除住在服务层——表现层出现 `context.delete`
    /// 只可能是 create 失败的错误善后（`WiringLintTests` 守着这条）。
    /// 防重复窗口读的是同一批 WearRecord，删完即时生效，列表与推荐不会各说各话。
    @discardableResult
    public static func deleteRecord(_ record: WearRecord, in context: ModelContext) -> Bool {
        context.delete(record)
        guard ModelSave.save(context, label: "wearRecordDelete") else {
            context.rollback()   // 失败删除不得滞留，否则污染下一次无关 save
            AppLog.error("wear record delete failed \(AppLog.ref(record.id))", .data)
            return false
        }
        return true
    }

    /// 合身反馈的**唯一**写入入口（打卡后追问 + 手动打卡共用）：
    /// 空白 = 清除；非 `FitVerdict` 的脏值拒绝（`recordWear` 的宽松签名保留给历史用例，
    /// 合法性守卫收敛在这里）；失败还原内存值 + rollback。
    @discardableResult
    public static func setFitFeedback(
        _ raw: String?, on record: WearRecord, in context: ModelContext
    ) -> Bool {
        let normalized: String?
        if let key = TextNormalize.blankToNil(raw)?.lowercased() {
            guard let verdict = FitVerdict(rawValue: key) else {
                AppLog.error("rejected unknown fit feedback for record=\(AppLog.ref(record.id))", .data)
                return false
            }
            normalized = verdict.rawValue
        } else {
            normalized = nil   // 空白 = 清除
        }
        let previous = record.fitFeedback
        record.fitFeedback = normalized
        guard ModelSave.save(context, label: "fitFeedback") else {
            record.fitFeedback = previous
            context.rollback()   // 失败变更不得滞留，否则污染下一次无关 save
            AppLog.error("fitFeedback save failed record=\(AppLog.ref(record.id))", .data)
            return false
        }
        return true
    }
}

/// 穿着历史查询：喂 RecommendationService 的防重复（gate #3）。
public enum WearHistory {
    /// 截至 asOf 的近 days 个日历日（含当天）穿过的单品 id 集合（uuidString）。
    /// 日粒度而非固定秒数：压制期不随打卡钟点漂移，跨 DST 安全（UI 承诺「de-prioritized 7 days」）。
    public static func recentlyWornItemIDs(
        within days: Int, asOf date: Date, in context: ModelContext,
        calendar: Calendar = .current
    ) -> Set<String> {
        let today = calendar.startOfDay(for: date)
        guard days > 0,
              let cutoff = calendar.date(byAdding: .day, value: -(days - 1), to: today),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)
        else { return [] }
        let records = (try? context.fetch(FetchDescriptor<WearRecord>())) ?? []
        var result = Set<String>()
        for r in records where r.date >= cutoff && r.date < tomorrow {
            result.formUnion(r.wornItemIDs)
        }
        return result
    }
}
