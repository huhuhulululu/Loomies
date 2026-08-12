import Testing
import SwiftData
import Foundation
@testable import ClosetUI
@testable import ClosetModel // for ModelSave.forceFailure test hook

@MainActor
/// D89：`WardrobeSwitcherViewModel` 已删除——它零生产调用点（app-shell 自写 Menu 绕开它），
/// 而它的新建路径与 `WardrobeManageActions.create` 逐条重复。切换语义收进纯值
/// `WardrobeSwitcher`（两侧共用），新建只剩 Me → Closets & people 一条真路径。
struct WardrobeSwitcherViewModelTests {

    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: config)
        return ModelContext(container)
    }



    /// Manage 入口同守卫（两条 create 路径同一标准）。
    @Test func manageCreateRejectsDuplicateName() throws {
        let ctx = try makeContext()
        let person = Person(name: "Alex"); ctx.insert(person)
        let trip = Wardrobe(name: "Trip"); trip.owner = person; ctx.insert(trip)
        try ctx.save()
        let (msg, w) = WardrobeManageActions.create(
            name: " trip ", city: "", existingPeople: [person], in: ctx)
        #expect(w == nil)
        #expect(msg == WardrobeManageActions.duplicateNameMessage)
        #expect((person.wardrobes ?? []).count == 1)
    }

    /// 重命名撞其他衣柜名拒绝；重命名为自己当前名（大小写调整）放行。
    @Test func renameRejectsOtherWardrobesName() throws {
        let ctx = try makeContext()
        let person = Person(name: "Alex"); ctx.insert(person)
        let trip = Wardrobe(name: "Trip"); trip.owner = person; ctx.insert(trip)
        let home = Wardrobe(name: "Home"); home.owner = person; ctx.insert(home)
        try ctx.save()
        #expect(!ProfileLabels.applyWardrobeName("trip", to: home, in: ctx))
        #expect(home.name == "Home")
        // 自身大小写调整不是冲突
        #expect(ProfileLabels.applyWardrobeName("TRIP", to: trip, in: ctx))
        #expect(trip.name == "TRIP")
    }

    /// 同名实体排序确定性：(name, id) 决胜，与导出快照同约定。
    @Test func sameNameWardrobesSortStableByID() throws {
        let ctx = try makeContext()
        let person = Person(name: "Alex"); ctx.insert(person)
        let a = Wardrobe(name: "Trip"); a.owner = person; ctx.insert(a)
        let b = Wardrobe(name: "Trip 2"); b.owner = person; ctx.insert(b)
        try ctx.save()
        // 改成同名（绕过 create 守卫，模拟历史数据）
        b.name = "Trip"
        try ctx.save()
        let expected = [a, b].sorted { $0.id.uuidString < $1.id.uuidString }.map(\.id)
        let ordered = WardrobeSwitcher.ordered(person.wardrobes ?? [])
        #expect(ordered.map(\.id) == expected)
        #expect(WardrobeSwitcher.resolveActive(id: nil, among: ordered)?.id == expected.first)
        // 同名两行必须能分辨（此前 app-shell 菜单里是两行一模一样的 "Trip"）
        #expect(WardrobeSwitcher.menuTitle(a, among: ordered)
                != WardrobeSwitcher.menuTitle(b, among: ordered))
    }


    /// Manage 入口同守卫（含自动创建的 "Me" person 一并不残留）。
    @Test func manageCreateSaveFailureLeavesNoPhantom() throws {
        let ctx = try makeContext()
        ModelSave.forceFailure(on: ctx)
        defer { ModelSave.clearForcedFailure(on: ctx) }
        let (msg, w) = WardrobeManageActions.create(
            name: "Trip", city: "", existingPeople: [], in: ctx)
        #expect(w == nil)
        #expect(msg == WardrobeManageActions.createFailedMessage)
        #expect(!ctx.hasChanges)
        #expect(try ctx.fetch(FetchDescriptor<Person>()).isEmpty)
        #expect(try ctx.fetch(FetchDescriptor<Wardrobe>()).isEmpty)
    }

    /// 新建后新柜可被解析为 active（此前由死 VM 演练；真路径是 Me → Closets & people）。
    @Test func createdWardrobeBecomesResolvableActive() throws {
        let ctx = try makeContext()
        let person = Person(name: "Alex"); ctx.insert(person)
        try ctx.save()
        let (msg, w) = WardrobeManageActions.create(
            name: "Paris", city: "Paris", existingPeople: [person], in: ctx)
        let created = try #require(w)
        #expect(created.name == "Paris")
        #expect(created.locationCity == "Paris")
        #expect(msg.localizedCaseInsensitiveContains("created"))
        // ModelSave commit (not silent try?)
        #expect(try ctx.fetch(FetchDescriptor<Wardrobe>()).contains { $0.name == "Paris" })
        #expect(WardrobeSwitcher.resolveActive(id: created.id, among: [created])?.id == created.id)
    }

    @Test func createRequiresName() throws {
        let ctx = try makeContext()
        let person = Person(name: "Alex"); ctx.insert(person)
        let (msg, w) = WardrobeManageActions.create(
            name: "   ", city: "", existingPeople: [person], in: ctx)
        #expect(w == nil)
        #expect(msg == WardrobeManageActions.needNameMessage)
        #expect(msg.localizedCaseInsensitiveContains("name"))
        #expect(try ctx.fetch(FetchDescriptor<Wardrobe>()).isEmpty)
        // Switcher + Manage list share fail/need-name voice (no dual hardcoded strings).
        #expect(WardrobeManageActions.createFailedMessage
            .localizedCaseInsensitiveContains("couldn't create"))
        #expect(CustomerFlashStyle.isFailure(WardrobeManageActions.createFailedMessage))
        #expect(!CustomerFlashStyle.isFailure(WardrobeManageActions.needNameMessage))
    }

    /// Me → Wardrobes list create — honest name gate + commit (no silent “Created” on empty).
    @Test func manageCreateRequiresNameAndCommits() throws {
        let ctx = try makeContext()
        let empty = WardrobeManageActions.create(
            name: "  ", city: "NYC", existingPeople: [], in: ctx)
        #expect(empty.wardrobe == nil)
        #expect(empty.message == WardrobeManageActions.needNameMessage)
        #expect(try ctx.fetch(FetchDescriptor<Wardrobe>()).isEmpty)

        let person = Person(name: "Alex"); ctx.insert(person)
        try ctx.save()
        let ok = WardrobeManageActions.create(
            name: "Paris", city: "Paris", existingPeople: [person], in: ctx)
        #expect(ok.wardrobe?.name == "Paris")
        #expect(ok.wardrobe?.locationCity == "Paris")
        #expect(ok.message == WardrobeManageActions.createdMessage("Paris"))
        #expect(!ok.message.localizedCaseInsensitiveContains("couldn't"))
        let fetched = try ctx.fetch(FetchDescriptor<Wardrobe>())
        #expect(fetched.contains { $0.name == "Paris" && $0.owner?.id == person.id })
    }

    /// Me Wardrobes list meta — empty city is Title Case “No city”, not “no city”.
    @Test func manageListSubtitleCityCopyIsHuman() {
        #expect(WardrobeManageActions.listSubtitle(itemCount: 0, locationCity: nil)
            == "0 items · No city")
        #expect(WardrobeManageActions.listSubtitle(itemCount: 3, locationCity: "  ")
            == "3 items · No city")
        #expect(WardrobeManageActions.listSubtitle(itemCount: 2, locationCity: "Chicago")
            == "2 items · Chicago")
        #expect(WardrobeManageActions.noCityCaption == "No city")
        #expect(WardrobeManageActions.noCityCaption != "no city")
    }

    /// Empty closets list VO — points to Add form; no try-on / sync claims.
    @Test func manageEmptyListCopyIsHonestForVoiceOver() {
        #expect(WardrobeManageActions.emptyListMessage
            .localizedCaseInsensitiveContains("no closets"))
        #expect(WardrobeManageActions.emptyListMessage
            .localizedCaseInsensitiveContains("add"))
        #expect(!WardrobeManageActions.emptyListMessage
            .localizedCaseInsensitiveContains("try-on"))
        #expect(!WardrobeManageActions.emptyListMessage
            .localizedCaseInsensitiveContains("sync"))
        #expect(!CustomerFlashStyle.isFailure(WardrobeManageActions.emptyListMessage))
        #expect(CustomerFlashStyle.isFailure(WardrobeManageActions.createFailedMessage))
    }
}

/// D89：切换器的**唯一真相**。此前 app-shell 自己写了一套 Menu，绕开
/// `WardrobeSwitcherViewModel`——单键 `@Query(sort: \Wardrobe.name)` 排序、
/// 列出全库衣柜（跨主人）、同名衣柜在菜单里两行一模一样分辨不出。
/// 服务层的重名守卫在这条真正被点到的路径上形同虚设。
@MainActor
struct WardrobeSwitcherMenuTests {

    func makeContext() throws -> ModelContext {
        try ModelContext(ModelContainer(
            for: Person.self, Wardrobe.self, StorageLocation.self, Item.self,
            Outfit.self, WearRecord.self, CalendarPlan.self, PersonBodyProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    /// (name, id) 双键——同名衣柜的菜单顺序不得随 fetch 漂移。
    @Test func orderingIsDeterministicOnNameAndID() throws {
        let ctx = try makeContext()
        let a = Wardrobe(name: "Home"); ctx.insert(a)
        let b = Wardrobe(name: "Home"); ctx.insert(b)
        let c = Wardrobe(name: "Away"); ctx.insert(c)
        try ctx.save()
        let ordered = WardrobeSwitcher.ordered([b, a, c])
        #expect(ordered.map(\.name) == ["Away", "Home", "Home"])
        let sameName = ordered.filter { $0.name == "Home" }
        #expect(sameName.map { $0.id.uuidString } == sameName.map { $0.id.uuidString }.sorted())
    }

    /// 同名衣柜必须能被区分——先用城市，再用主人；都没有才退回裸名。
    @Test func sameNameClosetsAreDisambiguated() throws {
        let ctx = try makeContext()
        let ada = Person(name: "Ada"); ctx.insert(ada)
        let bo = Person(name: "Bo"); ctx.insert(bo)
        let austin = Wardrobe(name: "Home", locationCity: "Austin"); austin.owner = ada
        let tokyo = Wardrobe(name: "Home", locationCity: "Tokyo"); tokyo.owner = ada
        ctx.insert(austin); ctx.insert(tokyo)
        try ctx.save()
        let all = [austin, tokyo]
        #expect(WardrobeSwitcher.menuTitle(austin, among: all).contains("Austin"))
        #expect(WardrobeSwitcher.menuTitle(tokyo, among: all).contains("Tokyo"))
        #expect(WardrobeSwitcher.menuTitle(austin, among: all)
                != WardrobeSwitcher.menuTitle(tokyo, among: all))

        // 城市相同 → 用主人区分
        let adaHome = Wardrobe(name: "Home", locationCity: "Austin"); adaHome.owner = ada
        let boHome = Wardrobe(name: "Home", locationCity: "Austin"); boHome.owner = bo
        ctx.insert(adaHome); ctx.insert(boHome)
        try ctx.save()
        let pair = [adaHome, boHome]
        #expect(WardrobeSwitcher.menuTitle(adaHome, among: pair)
                != WardrobeSwitcher.menuTitle(boHome, among: pair))
        #expect(WardrobeSwitcher.menuTitle(boHome, among: pair).contains("Bo"))
    }

    /// 名字唯一时不加噪音后缀。
    @Test func uniqueNamesStayClean() throws {
        let ctx = try makeContext()
        let a = Wardrobe(name: "Home", locationCity: "Austin"); ctx.insert(a)
        let b = Wardrobe(name: "Lake", locationCity: "Tahoe"); ctx.insert(b)
        try ctx.save()
        #expect(WardrobeSwitcher.menuTitle(a, among: [a, b]) == "Home")
    }

    /// 空名不得显示成空白行。
    @Test func blankNameFallsBackToAReadableLabel() throws {
        let ctx = try makeContext()
        let a = Wardrobe(name: "   "); ctx.insert(a)
        try ctx.save()
        #expect(!WardrobeSwitcher.menuTitle(a, among: [a]).trimmingCharacters(
            in: .whitespaces).isEmpty)
    }

    /// active 解析确定：给定 id 用它，否则取排序后的第一个（不是 fetch 顺序的第一个）。
    @Test func activeResolutionIsDeterministic() throws {
        let ctx = try makeContext()
        let a = Wardrobe(name: "Zed"); ctx.insert(a)
        let b = Wardrobe(name: "Alpha"); ctx.insert(b)
        try ctx.save()
        #expect(WardrobeSwitcher.resolveActive(id: a.id, among: [a, b])?.id == a.id)
        // 未知 id（衣柜已被删）→ 回落到排序首位，而不是 nil 或随机一个
        #expect(WardrobeSwitcher.resolveActive(id: UUID(), among: [a, b])?.id == b.id)
        #expect(WardrobeSwitcher.resolveActive(id: nil, among: [a, b])?.id == b.id)
        #expect(WardrobeSwitcher.resolveActive(id: nil, among: []) == nil)
    }
}
