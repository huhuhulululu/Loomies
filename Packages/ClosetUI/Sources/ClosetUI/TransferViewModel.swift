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
            .sorted { ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString) }
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
