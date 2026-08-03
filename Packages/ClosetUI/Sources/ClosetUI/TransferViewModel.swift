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

    public init(item: Item) { self.item = item }

    public func loadDestinations(in context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<Wardrobe>())) ?? []
        destinations = all
            .filter { $0.id != item.wardrobe?.id }
            .sorted { $0.name < $1.name }
        selectedDestinationID = destinations.first?.id
    }

    public func transfer(in context: ModelContext) {
        guard let id = selectedDestinationID,
              let dest = destinations.first(where: { $0.id == id }) else {
            message = "Pick a wardrobe."
            return
        }
        TransferService.transfer(item, to: dest, in: context)
        message = "Moved to \(dest.name)."
        AppLog.notice("transfer \(item.name) → \(dest.name)", .data)
    }
}
