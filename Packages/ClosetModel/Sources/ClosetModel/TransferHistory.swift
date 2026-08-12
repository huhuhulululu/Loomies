import Foundation
import SwiftData
import ClosetCore

/// 转移历史查询与文案（D94，缺口 #12）。
/// 软 UUID 引用意味着衣柜可能已被删除——**诚实显示**「已删除的衣柜」，不留空白，
/// 也不假装那次转移没发生过。
public enum TransferHistory {

    /// 某件的历史，最近在前；同刻按 id 决胜（排序确定性）。
    @MainActor
    public static func forItem(_ itemID: UUID, in context: ModelContext) -> [TransferRecord] {
        let all = (try? context.fetch(FetchDescriptor<TransferRecord>())) ?? []
        return all
            .filter { $0.itemID == itemID }
            .sorted { ($0.date, $0.id.uuidString) > ($1.date, $1.id.uuidString) }
    }

    public static let deletedClosetName = "a deleted closet"
    public static let unknownClosetName = "an unknown closet"

    /// 一行历史。`resolving` 是 id → 衣柜名的映射；查不到即已删除。
    public static func line(
        _ record: TransferRecord, resolving names: [UUID: String]
    ) -> String {
        func name(_ id: UUID?) -> String {
            guard let id else { return unknownClosetName }
            guard let raw = names[id], let n = TextNormalize.blankToNil(raw) else {
                return deletedClosetName
            }
            return n
        }
        return "Moved from \(name(record.fromWardrobeID)) to \(name(record.toWardrobeID))"
    }

    /// id → 名映射（调用方一次性取好，避免逐行 fetch）。
    @MainActor
    public static func closetNames(in context: ModelContext) -> [UUID: String] {
        let all = (try? context.fetch(FetchDescriptor<Wardrobe>())) ?? []
        return Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0.name) })
    }
}
