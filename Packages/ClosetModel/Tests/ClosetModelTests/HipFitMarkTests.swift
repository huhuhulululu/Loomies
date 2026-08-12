import Testing
import SwiftData
import Foundation
@testable import ClosetModel
import ClosetCore

/// D100（缺口 #23 之一）：`hipFlatWidthInches` 一直是**已落库但无录入面、无消费者**的字段。
/// 删它是破坏性 schema 变更（撞 D84 单向门），而它本身是下装的真约束——
/// 腰上合、臀上卡的裤子太常见了。接上它比删掉更对。
///
/// 语义：下装同时有腰宽与臀宽时，取**更紧的那个判定**——臀上紧的裤子就是紧，
/// 不得因为腰上宽松就报「合身」。
@MainActor
struct HipFitMarkTests {

    func profile(waist: Double, hip: Double) -> PersonBodyProfile {
        let p = PersonBodyProfile(personID: UUID())
        p.waistInches = waist
        p.hipInches = hip
        return p
    }

    /// 只有腰宽时行为不变（不凭空发明臀部判定）。
    @Test func waistOnlyBehavesAsBefore() {
        let p = profile(waist: 28, hip: 38)
        let withHip = FitMarkService.mark(
            slotRaw: "bottom", chestFlatWidthInches: nil,
            waistFlatWidthInches: 15, hipFlatWidthInches: nil, profile: p)
        let legacy = FitMarkService.mark(
            slotRaw: "bottom", chestFlatWidthInches: nil,
            waistFlatWidthInches: 15, profile: p)
        #expect(withHip == legacy)
        #expect(withHip != nil)
    }

    /// 腰宽松但臀部紧 → 判定必须是紧（取更紧的那个）。
    @Test func tightHipWinsOverRoomyWaist() {
        let p = profile(waist: 28, hip: 40)
        // 腰：flat 16 → 周长 32，宽松；臀：flat 19 → 周长 38 < 40，紧
        let verdict = FitMarkService.mark(
            slotRaw: "bottom", chestFlatWidthInches: nil,
            waistFlatWidthInches: 16, hipFlatWidthInches: 19, profile: p)
        #expect(verdict == .tight)
    }

    /// 两处都合身 → 合身（不因为多看一处就变悲观）。
    @Test func bothComfortableStaysComfortable() {
        let p = profile(waist: 28, hip: 38)
        let waistOnly = FitMarkService.mark(
            slotRaw: "bottom", chestFlatWidthInches: nil,
            waistFlatWidthInches: 15.5, hipFlatWidthInches: nil, profile: p)
        let both = FitMarkService.mark(
            slotRaw: "bottom", chestFlatWidthInches: nil,
            waistFlatWidthInches: 15.5, hipFlatWidthInches: 20.5, profile: p)
        #expect(both == waistOnly)
    }

    /// 身上没有臀围时忽略衣物臀宽（缺一边就判不了，不得瞎猜）。
    @Test func missingBodyHipIgnoresGarmentHip() {
        let p = PersonBodyProfile(personID: UUID())
        p.waistInches = 28
        let verdict = FitMarkService.mark(
            slotRaw: "bottom", chestFlatWidthInches: nil,
            waistFlatWidthInches: 15, hipFlatWidthInches: 10, profile: p)
        #expect(verdict != nil)     // 腰这边还判得了
    }

    /// 脏臀宽（0/负）视为缺失，不得让整条判定塌掉。
    @Test func dirtyHipValueIsTreatedAsMissing() {
        let p = profile(waist: 28, hip: 38)
        for dirty in [0.0, -3.0] {
            let verdict = FitMarkService.mark(
                slotRaw: "bottom", chestFlatWidthInches: nil,
                waistFlatWidthInches: 15, hipFlatWidthInches: dirty, profile: p)
            #expect(verdict != nil)
        }
    }

    /// 上装不看臀宽（槽位语义不得串台）。
    @Test func topsIgnoreHipEntirely() {
        let p = PersonBodyProfile(personID: UUID())
        p.bustInches = 34
        let a = FitMarkService.mark(
            slotRaw: "top", chestFlatWidthInches: 17,
            waistFlatWidthInches: nil, hipFlatWidthInches: 5, profile: p)
        let b = FitMarkService.mark(
            slotRaw: "top", chestFlatWidthInches: 17,
            waistFlatWidthInches: nil, hipFlatWidthInches: nil, profile: p)
        #expect(a == b)
    }

    /// 从 Item 取值时把臀宽一并传下去（此前它在 Item 上躺着没人读）。
    @Test func itemOverloadPassesHipThrough() throws {
        let ctx = try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
        let item = Item(name: "Jeans"); item.slotRaw = "bottom"
        item.waistFlatWidthInches = 16
        item.hipFlatWidthInches = 19
        ctx.insert(item)
        try ctx.save()
        let p = profile(waist: 28, hip: 40)
        #expect(FitMarkService.mark(item: item, profile: p) == .tight)
    }
}
