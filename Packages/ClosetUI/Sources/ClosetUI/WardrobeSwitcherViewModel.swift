import Foundation
import Observation
import SwiftData
import ClosetModel

/// 衣柜切换器（DESIGN §F7：全局一级导航）。
/// 列当前 Person 名下衣柜、选中 active、新建。
@MainActor
@Observable
public final class WardrobeSwitcherViewModel {
    public let person: Person
    public private(set) var active: Wardrobe?
    public var newName: String = ""
    public var newCity: String = ""

    public init(person: Person, active: Wardrobe? = nil) {
        self.person = person
        self.active = active ?? (person.wardrobes ?? []).sorted { $0.name < $1.name }.first
    }

    public var wardrobes: [Wardrobe] {
        (person.wardrobes ?? []).sorted { $0.name < $1.name }
    }

    public func select(_ wardrobe: Wardrobe) {
        guard wardrobe.owner?.id == person.id || (person.wardrobes ?? []).contains(where: { $0.id == wardrobe.id })
        else { return }
        active = wardrobe
    }

    /// 新建衣柜并设为 active。名非空。
    @discardableResult
    public func createWardrobe(in context: ModelContext) -> Wardrobe? {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let city = newCity.trimmingCharacters(in: .whitespacesAndNewlines)
        let w = Wardrobe(name: name, locationCity: city.isEmpty ? nil : city)
        w.owner = person
        context.insert(w)
        try? context.save()
        active = w
        newName = ""
        newCity = ""
        return w
    }
}
