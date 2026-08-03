import Foundation
import Observation
import SwiftData
import ClosetModel

/// 全局查找 UI 逻辑（DESIGN §F3）：跨柜属性/标签检索。
@MainActor
@Observable
public final class SearchViewModel {
    public var text: String = ""
    public var slotRaw: String?
    public var occasion: String?
    public var statusRaw: String?
    /// nil = 跨全部衣柜
    public var wardrobeID: UUID?
    public private(set) var results: [Item] = []

    public init() {}

    public func run(in context: ModelContext) {
        results = SearchService.searchItems(
            .init(text: text, slotRaw: slotRaw, occasion: occasion,
                  statusRaw: statusRaw, wardrobeID: wardrobeID),
            in: context)
    }

    public func clear() {
        text = ""
        slotRaw = nil
        occasion = nil
        statusRaw = nil
        wardrobeID = nil
        results = []
    }
}
