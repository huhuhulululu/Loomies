import Foundation
import Observation
import SwiftData
import ClosetModel
import ClosetCore

/// 单品详情/编辑（管理环缺口）。
@MainActor
@Observable
public final class ItemDetailViewModel {
    public let item: Item
    public var name: String
    public var slotRaw: String
    public var brand: String
    public var sizeLabel: String
    public var statusRaw: String
    public var occasionsText: String  // comma-separated
    public var chestFlat: String
    public var waistFlat: String
    public private(set) var fitLabel: String?
    public private(set) var message: String = ""

    public init(item: Item) {
        self.item = item
        self.name = item.name
        self.slotRaw = item.slotRaw
        self.brand = item.brand ?? ""
        self.sizeLabel = item.sizeLabel ?? ""
        self.statusRaw = item.statusRaw
        self.occasionsText = item.occasionsRaw.joined(separator: ", ")
        self.chestFlat = item.chestFlatWidthInches.map { String($0) } ?? ""
        self.waistFlat = item.waistFlatWidthInches.map { String($0) } ?? ""
    }

    public var statuses: [String] { Array(ItemStatusService.allowed).sorted() }

    public func refreshFit(profile: PersonBodyProfile?) {
        guard let profile else { fitLabel = nil; return }
        if let v = FitMarkService.mark(item: item, profile: profile) {
            fitLabel = FitMarkCopy.label(v)
        } else {
            fitLabel = nil
        }
    }

    public func save(in context: ModelContext) {
        let occ = occasionsText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        ItemEditorService.apply(
            .init(name: name, slotRaw: slotRaw, occasionsRaw: occ,
                  brand: brand, sizeLabel: sizeLabel,
                  chestFlatWidthInches: Double(chestFlat),
                  waistFlatWidthInches: Double(waistFlat)),
            to: item, in: context)
        _ = ItemStatusService.setStatus(item, to: statusRaw, in: context)
        message = "Saved."
        AppLog.info("ItemDetail save \(item.name)", .app)
    }
}
