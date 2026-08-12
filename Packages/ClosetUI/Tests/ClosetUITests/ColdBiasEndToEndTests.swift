import Testing
import SwiftData
import Foundation
@testable import ClosetUI
@testable import ClosetModel   // ModelSave.forceFailure test hook
import ClosetCore

/// D90：冷热偏置的**端到端**证据——不是只把数字存进库，而是真的改变了今天的建议。
/// 此前 `Person.coldBias` 有字段、进导出、无 UI 无消费者。
@MainActor
struct ColdBiasEndToEndTests {

    func makeContext() throws -> ModelContext {
        try ModelContext(ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    /// 60°F 默认档 = light…warm；怕冷 +1 → medium…veryWarm。
    /// 精确构造：唯一的 light 上装只在默认档可选，唯一的 veryWarm 上装只在 +1 档可选。
    /// 建议里那件上装必须**换人**——证明偏置真的走到了天气门，不是只存了个数。
    @Test func coldBiasChangesWhichPieceSurvivesTheWeatherGate() throws {
        let ctx = try makeContext()
        let person = Person(name: "Ada"); ctx.insert(person)
        let w = Wardrobe(name: "Main"); w.owner = person; ctx.insert(w)

        @discardableResult
        func add(_ name: String, _ slot: String, _ warmth: Warmth?) -> Item {
            let i = Item(name: name); i.slotRaw = slot; i.wardrobe = w
            i.statusRaw = "available"; i.occasionsRaw = ["work"]
            i.warmthRaw = warmth?.rawValue
            ctx.insert(i)
            return i
        }
        let lightTop = add("Light Top", "top", .light)          // 只在默认档
        let heavyTop = add("Heavy Top", "top", .veryWarm)       // 只在 +1 档
        add("Jeans", "bottom", .medium)                          // 两档都过
        add("Boots", "shoes", .medium)                           // 两档都过
        // 越过冷启动门槛：配饰件（温区未知不参与天气过滤，也不占核心槽位）
        for i in 0..<10 { add("Filler \(i)", "accessory", nil) }
        try ctx.save()

        let base = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 60)
        base.fullAuto = true
        #expect(!base.isColdStart)
        base.refresh()
        let baseIDs = Set(base.suggestions.flatMap(\.outfit.itemIDs))
        #expect(baseIDs.contains(lightTop.id.uuidString))
        #expect(!baseIDs.contains(heavyTop.id.uuidString))

        // 怕冷 +1 → 温区整体上移
        #expect(ProfileLabels.applyColdBias(1, to: person, in: ctx))
        let cold = CopilotViewModel(wardrobe: w, occasion: "work", daytimeTempF: 60)
        cold.fullAuto = true
        cold.refresh()
        let coldIDs = Set(cold.suggestions.flatMap(\.outfit.itemIDs))
        #expect(coldIDs.contains(heavyTop.id.uuidString),
                "怕冷档没把厚上装放进来 —— 偏置没走到天气门")
        #expect(!coldIDs.contains(lightTop.id.uuidString))
    }

    /// 落库失败不得留脏（与其余 Me 编辑同一条铁律）。
    @Test func coldBiasSaveFailureLeavesNoDirtyState() throws {
        let ctx = try makeContext()
        let person = Person(name: "Ada"); ctx.insert(person)
        try ctx.save()
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        #expect(!ProfileLabels.applyColdBias(2, to: person, in: ctx))
        #expect(person.coldBias == 0)
        #expect(!ctx.hasChanges)
    }

    /// 超范围输入被夹紧后落库（脏数据不得把天气门推成全通）。
    @Test func outOfRangeBiasIsClampedOnSave() throws {
        let ctx = try makeContext()
        let person = Person(name: "Ada"); ctx.insert(person)
        try ctx.save()
        #expect(ProfileLabels.applyColdBias(99, to: person, in: ctx))
        #expect(person.coldBias == ColdBias.allowedRange.upperBound)
    }
}
