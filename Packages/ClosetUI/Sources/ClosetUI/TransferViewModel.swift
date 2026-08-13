import Foundation
import Observation
import SwiftData
import ClosetModel
import ClosetCore

/// 单品转移 UI（DESIGN §F7）。
@MainActor
@Observable
public final class TransferViewModel {
    public let item: Item
    public private(set) var destinations: [Wardrobe] = []
    public var selectedDestinationID: UUID?
    public private(set) var message: String = ""
    /// True after a successful Move — sheet should dismiss only then (no silent fail).
    public private(set) var didTransfer = false

    /// Customer chip when no destination selected (sheet stays open).
    public static let pickDestinationMessage = "Pick a closet."

    /// 搬家的两条后果，**事先**说清（D187）。
    ///
    /// 存放位置是无条件抹掉的（`TransferService` 第 38 行 `item.location = nil`，
    /// 因为位置属源柜），而且**搬回去也不会恢复**——用户一层层标好的柜格，
    /// 批量搬一次就没了几十个，而摘要只说「Moved 12 pieces.」。
    ///
    /// 搭配变缺件是可逆的（搬回即自动重算），所以只提一句、不吓唬人。
    /// 单件与批量读同一份——两处各写各的注定走岔（D183 刚栽过）。
    public static let consequenceNotice =
        "Moving clears each piece's storage spot — moving it back won't restore it. "
        + "Looks in this closet that use these pieces will show as missing pieces."

    /// Empty destination list — recovery is Me → Wardrobes (no silent Move enable).
    public static let noOtherWardrobesMessage =
        "No other closets. Create one in Me."

    /// Customer chip when ModelSave fails (sheet stays open; no silent “Moved”).
    public static let saveFailedMessage = TransferService.saveFailedMessage

    public init(item: Item) { self.item = item }

    public func loadDestinations(in context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<Wardrobe>())) ?? []
        destinations = all
            .filter { $0.id != item.wardrobe?.id }
            // 同名按 id 决胜：默认目的地不得因排序不稳定漂移到另一个同名柜
            .sortedByName()
        selectedDestinationID = destinations.first?.id
        didTransfer = false
    }

    /// Moves the piece. Returns `true` only when committed — UI dismisses on true only.
    @discardableResult
    public func transfer(in context: ModelContext) -> Bool {
        guard let id = selectedDestinationID,
              let dest = destinations.first(where: { $0.id == id }) else {
            message = Self.pickDestinationMessage
            didTransfer = false
            return false
        }
        guard TransferService.transfer(item, to: dest, in: context) else {
            message = Self.saveFailedMessage
            didTransfer = false
            return false
        }
        message = "Moved to \(dest.name)."
        didTransfer = true
        AppLog.notice("transfer item=\(AppLog.ref(item.id)) → wardrobe=\(AppLog.ref(dest.id))", .data)
        return true
    }
}
