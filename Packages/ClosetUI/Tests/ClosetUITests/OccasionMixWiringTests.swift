import Testing
import SwiftData
import Foundation
@testable import ClosetUI
import ClosetModel
import ClosetCore

/// D97：「场合构成」这一题的**端到端证据**——不是存了个值，而是真的改变了
/// Today 的默认过滤与冷启动里打头的那条里程碑。
@MainActor
struct OccasionMixWiringTests {

    func setup() throws -> (ModelContext, Person, Wardrobe) {
        let ctx = try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
        let p = Person(name: "Ada"); ctx.insert(p)
        let w = Wardrobe(name: "Main"); w.owner = p; ctx.insert(w)
        try ctx.save()
        return (ctx, p, w)
    }

    /// onboarding 答了就落库；跳过就是 nil（**不猜**成某个具体场合）。
    @Test func onboardingPersistsTheAnswerAndRespectsSkip() throws {
        let ctx = try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
        let vm = OnboardingViewModel()
        vm.displayName = "Ada"; vm.city = "Austin"
        vm.primaryOccasion = "casual"
        #expect(vm.finish(in: ctx))
        let person = try #require(try ctx.fetch(FetchDescriptor<Person>()).first)
        #expect(person.primaryOccasionRaw == "casual")

        // 跳过的那条路径
        let ctx2 = try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
        let skipped = OnboardingViewModel()
        skipped.displayName = "Bo"; skipped.city = "Tokyo"
        #expect(skipped.finish(in: ctx2))
        let person2 = try #require(try ctx2.fetch(FetchDescriptor<Person>()).first)
        #expect(person2.primaryOccasionRaw == nil)
    }

    /// 答案真的改变了 Today 的默认过滤：只有休闲装的衣柜，
    /// 答「casual」能看到建议，而此前硬编码 "work" 会给出空结果。
    @Test func statedOccasionChangesWhatTodayShows() throws {
        let (ctx, person, w) = try setup()
        func add(_ name: String, _ slot: String) {
            let i = Item(name: name); i.slotRaw = slot; i.wardrobe = w
            i.statusRaw = "available"; i.occasionsRaw = ["casual"]
            i.warmthRaw = Warmth.light.rawValue
            ctx.insert(i)
        }
        add("Tee", "top"); add("Jeans", "bottom"); add("Sneakers", "shoes")
        for i in 0..<10 { add("Filler \(i)", "accessory") }
        try ctx.save()

        // 没答 → 中性默认 work → 这个全休闲衣柜给不出建议
        let neutral = CopilotViewModel(
            wardrobe: w,
            occasion: OccasionMix.effectiveOccasion(stated: person.primaryOccasionRaw),
            daytimeTempF: 70)
        neutral.fullAuto = true
        neutral.refresh()
        #expect(neutral.occasion == "work")
        #expect(neutral.suggestions.isEmpty)

        // 答了 casual → 同一个衣柜给得出建议
        person.primaryOccasionRaw = "casual"
        try ctx.save()
        let stated = CopilotViewModel(
            wardrobe: w,
            occasion: OccasionMix.effectiveOccasion(stated: person.primaryOccasionRaw),
            daytimeTempF: 70)
        stated.fullAuto = true
        stated.refresh()
        #expect(stated.occasion == "casual")
        #expect(!stated.suggestions.isEmpty)
    }

    /// 打头的里程碑跟随用户说的那个场合（他关心的那条先看到）。
    @Test func headlineMilestoneFollowsTheStatedOccasion() throws {
        let (ctx, _, w) = try setup()
        // work 侧齐全、gala 侧空
        func add(_ name: String, _ slot: String, _ occ: [String]) {
            let i = Item(name: name); i.slotRaw = slot; i.wardrobe = w
            i.statusRaw = "available"; i.occasionsRaw = occ
            ctx.insert(i)
        }
        add("Shirt", "top", ["work"]); add("Slacks", "bottom", ["work"])
        add("Loafers", "shoes", ["work"])
        try ctx.save()
        let candidates = (w.items ?? []).map { $0.toCandidateItem() }

        // 没答 → 按进度挑，会挑到 work（唯一有进展的）
        let byProgress = try #require(
            ActivationProgress.headlineMilestone(items: candidates))
        #expect(byProgress.occasion == "work")

        // 答了 gala → 即使 gala 一套都没有，也该先让他看到那条的差距
        let stated = try #require(ActivationProgress.headlineMilestone(
            items: candidates, statedOccasion: "gala"))
        #expect(stated.occasion == "gala")
        #expect(!stated.canDressOnce)
        #expect(!stated.missingSlots.isEmpty)   // 点名还缺什么
    }

    /// 脏值不得让打头里程碑漂走（历史/导入数据可能写进不认识的东西）。
    @Test func dirtyStatedOccasionFallsBackToProgress() throws {
        let (ctx, _, w) = try setup()
        let i = Item(name: "Tee"); i.slotRaw = "top"; i.wardrobe = w
        i.statusRaw = "available"; ctx.insert(i)
        try ctx.save()
        let candidates = (w.items ?? []).map { $0.toCandidateItem() }
        let m = try #require(ActivationProgress.headlineMilestone(
            items: candidates, statedOccasion: "brunch-with-aliens"))
        #expect(ActivationProgress.trackedOccasions.contains(m.occasion))
    }
}
