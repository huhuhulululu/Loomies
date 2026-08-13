import SwiftUI
import SwiftData
import Observation
import ClosetModel
import ClosetCore

/// 穿着历史回读（D88）。此前打卡是**只写不读**的：全 App 无任何界面 fetch
/// `WearRecord`，合身反馈采集后既不展示也不可修改——用户点错一次就永远改不回来，
/// 而 `FitFeedbackCopy.logCaption`（专为历史回显写的）零生产调用点。
/// 这与 copilot「用户掌舵、推荐永远可被覆盖」的定位直接冲突。
@MainActor
@Observable
public final class WearHistoryViewModel {
    public let wardrobe: Wardrobe
    public private(set) var entries: [Entry] = []
    public private(set) var message: String = ""

    public init(wardrobe: Wardrobe) { self.wardrobe = wardrobe }

    public static let title = "Wear history"
    public static let emptyMessage =
        "Nothing logged yet. Use “Log what I wore” on Today after you get dressed."
    public static let saveFailedMessage = "Couldn't update this entry — try again"
    public static let deleteFailedMessage = CheckInService.deleteFailedMessage

    /// 一条历史记录的**值快照**（不持 @Model：列表行在删除动画期间仍会求值）。
    public struct Entry: Identifiable, Equatable, Sendable {
        public let id: UUID
        public let date: Date
        public let pieceNames: [String]
        /// 已转移/删除、在本柜找不到的件数。
        public let missingCount: Int
        public let fitRaw: String?

        /// 合身回显；无值/脏值 → nil（不编造）。
        public var fitCaption: String? { FitFeedbackCopy.logCaption(fitRaw) }

        /// 「Tee · Jeans」/ 全没了时说清楚，不显示空白行。
        public var subtitle: String {
            var parts: [String] = []
            if !pieceNames.isEmpty { parts.append(pieceNames.joined(separator: " · ")) }
            if missingCount > 0 {
                parts.append("\(missingCount) \(missingCount == 1 ? "piece" : "pieces") "
                             + "no longer in this closet")
            }
            return parts.isEmpty ? "No pieces recorded" : parts.joined(separator: " — ")
        }
    }

    public func load(in context: ModelContext) {
        let records = (try? context.fetch(FetchDescriptor<WearRecord>())) ?? []
        // 本柜快照（转移不改历史统计口径——记录固化了当时的衣柜）
        let mine = records.filter { $0.wardrobeSnapshotID == wardrobe.id }
        // D147：`uniqueKeysWithValues` 对重复 key 直接 `fatalError`，而 schema
        // **没有**把 `Item.id` 声明为 unique——导入/同步产生的重复 id 会让一个
        // 「给历史行取几个名字」的路径把整页变成一次进程终止。
        // D105 已经在 `TransferHistory.closetNames`（按衣柜 id）判过同一件事，
        // 只是没走到这里；单品比衣柜多两个数量级，这一处暴露面更大。
        // 取**确定的**胜者：同一个库跑两次，用户看到的名字得一样。
        let byID = Dictionary(
            (wardrobe.items ?? []).map { ($0.id.uuidString, $0) }
        ) { lhs, rhs in
            (lhs.name, lhs.id.uuidString) <= (rhs.name, rhs.id.uuidString) ? lhs : rhs
        }
        entries = mine
            // 最近在前；同日按 id 决胜（排序确定性，禁止依赖 fetch 顺序）
            .sorted { ($0.date, $0.id.uuidString) > ($1.date, $1.id.uuidString) }
            .map { rec in
                let resolved = rec.wornItemIDs.compactMap { byID[$0] }
                return Entry(
                    id: rec.id,
                    date: rec.date,
                    pieceNames: resolved
                        .map(\.name)
                        .sorted { ($0, $0) < ($1, $1) },
                    missingCount: rec.wornItemIDs.count - resolved.count,
                    fitRaw: rec.fitFeedback)
            }
    }

    /// 改合身备注（记错了能纠正）。nil = 清除。
    @discardableResult
    public func updateFit(
        _ verdict: FitVerdict?, forEntryID id: UUID, in context: ModelContext
    ) -> Bool {
        guard let rec = record(id, in: context) else { return false }
        guard CheckInService.setFitFeedback(verdict?.rawValue, on: rec, in: context) else {
            message = Self.saveFailedMessage
            return false
        }
        message = ""
        load(in: context)
        return true
    }

    /// 删一条（记错了日子）。防重复窗口随之更新——列表与推荐不得各说各话。
    @discardableResult
    public func delete(entryID id: UUID, in context: ModelContext) -> Bool {
        guard let rec = record(id, in: context) else { return false }
        guard CheckInService.deleteRecord(rec, in: context) else {
            message = Self.deleteFailedMessage
            load(in: context)
            return false
        }
        message = ""
        load(in: context)
        return true
    }

    private func record(_ id: UUID, in context: ModelContext) -> WearRecord? {
        let all = (try? context.fetch(FetchDescriptor<WearRecord>())) ?? []
        return all.first { $0.id == id }
    }
}

/// 穿着历史列表：看得到、改得动、删得掉。
public struct WearHistoryView: View {
    let wardrobe: Wardrobe
    @Environment(\.modelContext) private var context
    @State private var vm: WearHistoryViewModel

    public init(wardrobe: Wardrobe) {
        self.wardrobe = wardrobe
        _vm = State(initialValue: WearHistoryViewModel(wardrobe: wardrobe))
    }

    public var body: some View {
        List {
            if vm.entries.isEmpty {
                Section {
                    Text(WearHistoryViewModel.emptyMessage)
                        .font(.callout).foregroundStyle(DS.muted)
                        .accessibilityLabel(WearHistoryViewModel.emptyMessage)
                }
            } else {
                ForEach(vm.entries) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.date, style: .date).font(.headline)
                        Text(entry.subtitle).font(.caption).foregroundStyle(DS.muted)
                        Picker(FitFeedbackCopy.prompt, selection: fitBinding(entry)) {
                            Text(WarmthPicker.unknownTitle).tag(Optional<FitVerdict>.none)
                            ForEach(FitFeedbackCopy.options, id: \.rawValue) { v in
                                Text(FitFeedbackCopy.choiceTitle(v)).tag(Optional(v))
                            }
                        }
                        .pickerStyle(.menu)
                        .accessibilityLabel(FitFeedbackCopy.prompt)
                    }
                    .padding(.vertical, 2)
                }
                .onDelete { offsets in
                    for i in offsets { vm.delete(entryID: vm.entries[i].id, in: context) }
                }
            }
            if !vm.message.isEmpty {
                Section {
                    Text(vm.message).font(.caption).foregroundStyle(.orange)
                        .accessibilityLabel(vm.message)
                }
            }
            Section {
                Text(FitFeedbackCopy.exportDisclosure)
                    .font(.caption2).foregroundStyle(DS.muted)
            }
        }
        .navigationTitle(WearHistoryViewModel.title)
        .onAppear { vm.load(in: context) }
    }

    private func fitBinding(_ entry: WearHistoryViewModel.Entry) -> Binding<FitVerdict?> {
        Binding(
            get: { FitFeedbackCopy.parse(entry.fitRaw) },
            set: { vm.updateFit($0, forEntryID: entry.id, in: context) })
    }
}
