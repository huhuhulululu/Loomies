import Foundation
import Observation
import SwiftData
import ClosetModel
import ClosetCore

/// 衣柜切换器（DESIGN §F7：全局一级导航）。
/// 列当前 Person 名下衣柜、选中 active、新建。
@MainActor
@Observable
public final class WardrobeSwitcherViewModel {
    public let person: Person
    public private(set) var active: Wardrobe?
    public var newName: String = ""
    public var newCity: String = ""
    /// Customer flash after create (empty on success; save/validation failure is honest).
    public private(set) var message: String = ""

    public init(person: Person, active: Wardrobe? = nil) {
        self.person = person
        self.active = active ?? (person.wardrobes ?? [])
            .sorted { ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString) }.first
    }

    public var wardrobes: [Wardrobe] {
        (person.wardrobes ?? []).sorted { ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString) }
    }

    public func select(_ wardrobe: Wardrobe) {
        guard wardrobe.owner?.id == person.id || (person.wardrobes ?? []).contains(where: { $0.id == wardrobe.id })
        else { return }
        active = wardrobe
    }

    /// 新建衣柜并设为 active。名非空。Save failure rolls back insert (no silent success).
    /// Copy shares `WardrobeManageActions` (Me → Wardrobes list create path).
    @discardableResult
    public func createWardrobe(in context: ModelContext) -> Wardrobe? {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            message = WardrobeManageActions.needNameMessage
            return nil
        }
        guard !WardrobeManageActions.nameConflicts(name, among: person.wardrobes ?? []) else {
            message = WardrobeManageActions.duplicateNameMessage
            return nil
        }
        let city = newCity.trimmingCharacters(in: .whitespacesAndNewlines)
        let w = Wardrobe(name: name, locationCity: city.isEmpty ? nil : city)
        w.owner = person
        context.insert(w)
        guard ModelSave.save(context, label: "wardrobeCreate") else {
            // 先解开内存关系（rollback 不回写内存幻影），再 rollback 丢弃 pending insert + 清脏标记
            //（delete 只删行，脏标记与 person.wardrobes 里的幻影都会滞留，OutfitDraftService 同款）
            w.owner = nil
            context.rollback()   // 失败变更不得滞留，否则污染下一次无关 save
            message = WardrobeManageActions.createFailedMessage
            AppLog.error("wardrobe create save failed", .app)
            return nil
        }
        active = w
        newName = ""
        newCity = ""
        message = ""
        return w
    }
}
