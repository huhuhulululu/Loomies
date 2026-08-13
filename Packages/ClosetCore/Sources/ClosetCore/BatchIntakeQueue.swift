import Foundation

/// 批量入库队列（D92，缺口 #9）。DESIGN §F1 明写「**批量为默认路径**」，
/// 而实现一直是 `selectionLimit = 1`——北极星是 7 天数字化 40 件，
/// 一件一件拍是这条漏斗上最大的阻力（MVP-PLAN M1 SI-1/2）。
///
/// **copilot 铁律不因批量而松动**：每件仍由用户拍板（确认 / 跳过），
/// 绝不做「选了就自动全入库」。本类型只负责游标与诚实记账，不碰图像与 SwiftData。
public struct BatchIntakeQueue: Equatable, Sendable {

    public enum Outcome: String, Sendable, Equatable {
        case added      // 用户确认入库
        /// D193：入库了，但**试穿层图没跟上**（抠图失败 / 归一失败 / 写盘失败）。
        ///
        /// 单张路径会在确认后弹一句诚实提示，批量路径此前把它整条丢掉——
        /// `recordBatch` 里的 `return` 在 `postConfirmFlash` 之前，
        /// 而它第一件事就是 `intakeVM.reset()`（清空 statusMessage）。
        /// 于是批量入库的用户永远不知道哪几件没有照片。
        case addedWithoutPhoto
        case skipped    // 用户跳过
        case failed     // 图片读不出来 / 落库失败
    }

    /// 一次最多挑多少张。再多会同时压垮内存与用户耐心；超出部分**如实告知**后截断。
    public static let maxSelection = 30

    public let total: Int
    public private(set) var outcomes: [Outcome] = []

    public init(total: Int) { self.total = max(0, total) }

    /// 已处理到第几张（0-based 游标）。
    public var index: Int { outcomes.count }
    public var isFinished: Bool { index >= total }

    /// 入库成功的件数（含没跟上照片的那些——它们确实进柜子了）。
    public var addedCount: Int {
        outcomes.filter { $0 == .added || $0 == .addedWithoutPhoto }.count
    }
    public var addedWithoutPhotoCount: Int {
        outcomes.filter { $0 == .addedWithoutPhoto }.count
    }
    public var skippedCount: Int { outcomes.filter { $0 == .skipped }.count }
    public var failedCount: Int { outcomes.filter { $0 == .failed }.count }
    public var remainingCount: Int { max(0, total - index) }

    /// 人读的进度（从 1 数起）。空队列不显示「Piece 1 of 0」。
    public var progressCaption: String {
        guard total > 0, !isFinished else { return "" }
        return "Piece \(index + 1) of \(total)"
    }

    /// 越界记账被忽略——UI 双击不得让游标跑飞。
    public mutating func record(_ outcome: Outcome) {
        guard index < total else { return }
        outcomes.append(outcome)
    }

    /// 走完的汇总：逐项如实，零项不提（噪音），且**绝不把全失败说成成功**。
    public var summary: String {
        guard total > 0 else { return "Nothing to add." }
        var parts: [String] = []
        if addedCount > 0 {
            parts.append("Added \(addedCount) \(addedCount == 1 ? "piece" : "pieces")")
        }
        if addedWithoutPhotoCount > 0 {
            let n = addedWithoutPhotoCount
            parts.append("\(n) without a try-on photo (add one from the piece's page)")
        }
        if skippedCount > 0 { parts.append("\(skippedCount) skipped") }
        if failedCount > 0 {
            parts.append("\(failedCount) couldn't be read")
        }
        guard !parts.isEmpty else { return "Nothing to add." }
        return parts.joined(separator: " · ") + "."
    }

    /// 中途退出的汇总。已确认入库的**不回滚**（用户逐件拍过板），
    /// 但必须说清还剩几张没处理——否则用户以为整批都进去了。
    public var summaryOnExit: String {
        guard !isFinished else { return summary }
        let base = summary == "Nothing to add." ? "" : summary + " "
        return base + "\(remainingCount) left unreviewed."
    }

    /// 超过上限时的**明说**截断提示；未超限返回 nil（无噪音）。
    public static func truncationNotice(picked: Int) -> String? {
        guard picked > maxSelection else { return nil }
        return "Taking the first \(maxSelection) of \(picked). "
            + "Add the rest in another batch."
    }
}

/// 批量入库文案（D92）。DESIGN §F1「批量为默认路径」——按钮就要说得出「多张」，
/// 否则用户不知道可以一次挑一沓。
public enum BatchIntakeCopy {
    public static let chooseTitle = "Choose photos — add several at once"
    public static let addAndContinueTitle = "Add and continue"
    public static let skipTitle = "Skip this one"
}
