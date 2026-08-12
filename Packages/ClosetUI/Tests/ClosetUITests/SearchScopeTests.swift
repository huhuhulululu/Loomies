import Testing
import SwiftData
import Foundation
@testable import ClosetUI
@testable import ClosetModel
import ClosetCore

/// D85 波 C：跨柜检索。SearchService 早就支持 `wardrobeID = nil`（跨柜），
/// 但 UI 每次都强制钉当前柜——DESIGN §2.3/§7 承诺的全局检索无入口。
@MainActor
struct SearchScopeTests {
    init() { ItemImageTestRoot.install() }

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }

    func seedTwoClosets(_ ctx: ModelContext) throws -> (Wardrobe, Wardrobe) {
        let p = Person(name: "Ada"); ctx.insert(p)
        let nyc = Wardrobe(name: "NYC"); nyc.owner = p; ctx.insert(nyc)
        let bkk = Wardrobe(name: "BKK"); bkk.owner = p; ctx.insert(bkk)
        let a = Item(name: "Blue Shirt"); a.slotRaw = "top"; a.wardrobe = nyc; ctx.insert(a)
        let b = Item(name: "Blue Sarong"); b.slotRaw = "bottom"; b.wardrobe = bkk; ctx.insert(b)
        try ctx.save()
        return (nyc, bkk)
    }

    @Test func scopeControlsWhetherOtherClosetsAreSearched() throws {
        let ctx = try makeContext()
        let (nyc, _) = try seedTwoClosets(ctx)
        let vm = SearchViewModel()
        vm.homeWardrobeID = nyc.id
        vm.text = "blue"

        vm.scope = .thisCloset
        vm.run(in: ctx)
        #expect(vm.results.map(\.name) == ["Blue Shirt"])
        #expect(vm.effectiveWardrobeID == nyc.id)
        #expect(!vm.isCrossCloset)

        vm.scope = .allClosets
        vm.run(in: ctx)
        #expect(Set(vm.results.map(\.name)) == ["Blue Shirt", "Blue Sarong"])
        #expect(vm.effectiveWardrobeID == nil)
        #expect(vm.isCrossCloset)
    }

    @Test func scopeTitlesAreHumanAndExhaustive() {
        #expect(SearchScope.allCases.count == 2)
        for s in SearchScope.allCases { #expect(!s.displayTitle.isEmpty) }
        #expect(SearchScope.thisCloset.displayTitle != SearchScope.allClosets.displayTitle)
    }

    /// clear() 契约：作用域一并复位（安全默认），否则「清空」后仍在跨柜而用户不知情。
    @Test func clearResetsScopeAndHome() throws {
        let ctx = try makeContext()
        let (nyc, _) = try seedTwoClosets(ctx)
        let vm = SearchViewModel()
        vm.homeWardrobeID = nyc.id
        vm.hasOtherClosets = true
        vm.scope = .allClosets
        vm.text = "blue"
        vm.run(in: ctx)
        vm.clear()
        #expect(vm.scope == .thisCloset)
        #expect(vm.homeWardrobeID == nil)
        #expect(vm.hasOtherClosets == false)
        #expect(vm.effectiveWardrobeID == nil)   // home 也被清 → 无作用域可钉
        #expect(vm.results.isEmpty)
    }

    /// 清筛选保留作用域（chips 的「Clear search」不该把用户踢回本柜）。
    @Test func clearFiltersKeepsScopeAndHome() throws {
        let ctx = try makeContext()
        let (nyc, _) = try seedTwoClosets(ctx)
        let vm = SearchViewModel()
        vm.homeWardrobeID = nyc.id
        vm.hasOtherClosets = true
        vm.scope = .allClosets
        vm.text = "blue"
        vm.slotRaw = "top"
        vm.clearFiltersKeepingScope()
        #expect(vm.text.isEmpty)
        #expect(vm.slotRaw == nil)
        #expect(vm.scope == .allClosets)
        #expect(vm.homeWardrobeID == nyc.id)
        #expect(vm.hasOtherClosets)
    }

    /// 空态在有其他衣柜时要指出「可以搜全部」，且提供可行动的扩大入口判定。
    @Test func emptyStateOffersBroaderScopeOnlyWhenUseful() {
        let vm = SearchViewModel()
        vm.text = "zzz"
        vm.hasOtherClosets = true
        vm.scope = .thisCloset
        #expect(vm.canBroadenScope)
        #expect(vm.emptyStateDescription.localizedCaseInsensitiveContains("all closets"))
        // 已在跨柜 / 单柜用户 / 未筛选 → 不提议
        vm.scope = .allClosets
        #expect(!vm.canBroadenScope)
        vm.scope = .thisCloset
        vm.hasOtherClosets = false
        #expect(!vm.canBroadenScope)
        #expect(!vm.emptyStateDescription.localizedCaseInsensitiveContains("all closets"))
        vm.text = ""
        vm.hasOtherClosets = true
        #expect(!vm.canBroadenScope)
    }

    /// 跨柜结果必须显示所属衣柜——否则同名单品分不清是哪个柜的（可见文案与 VO 同源）。
    @Test func crossClosetRowMetaNamesTheCloset() throws {
        let ctx = try makeContext()
        let (nyc, _) = try seedTwoClosets(ctx)
        let item = try #require((nyc.items ?? []).first)
        let withCloset = ClosetItemRowCopy.metaLine(for: item, includesCloset: true)
        #expect(withCloset.hasPrefix("NYC"))
        let without = ClosetItemRowCopy.metaLine(for: item, includesCloset: false)
        #expect(!without.localizedCaseInsensitiveContains("NYC"))
        // 无归属柜时不得吐空段
        let orphan = Item(name: "loose"); orphan.slotRaw = "top"; ctx.insert(orphan)
        let orphanMeta = ClosetItemRowCopy.metaLine(for: orphan, includesCloset: true)
        #expect(orphanMeta.hasPrefix(ClosetItemRowCopy.unknownClosetName))
        #expect(!orphanMeta.hasPrefix(" ·"))
    }
}
