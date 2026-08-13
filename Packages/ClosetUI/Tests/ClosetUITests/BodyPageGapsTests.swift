import Testing
import Foundation
import SwiftData
@testable import ClosetUI
import ClosetModel
import ClosetCore

/// D190：身体这一块的四条。
@MainActor
struct BodyPageGapsTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    private func consent(_ label: String, granted: Bool = true) -> BodyDataConsent {
        let c = BodyDataConsent(defaults: UserDefaults(
            suiteName: "loomies.test.body.\(label).\(UUID().uuidString)")!)
        c.setGranted(granted)
        return c
    }

    private func setup(_ label: String) throws -> (ModelContext, Person, BodyProfileViewModel) {
        let ctx = try makeContext()
        let person = Person(name: "Ping"); ctx.insert(person)
        let w = Wardrobe(name: "Home"); w.owner = person; ctx.insert(w)
        try ctx.save()
        let vm = BodyProfileViewModel(personID: person.id, bodyDataConsent: consent(label))
        vm.load(in: ctx)
        return (ctx, person, vm)
    }

    // MARK: - #26 预览画的身体与其余四屏不是同一个

    /// 三围齐、上臀空时，**预览不许偷偷推断**。
    ///
    /// 其余四屏（Today / 试衣间 / 日历 / 收藏）走 `OwnerBodyDerivation`，
    /// 它要求四围齐全，缺一即中性。而 Body 页的预览自己用腰臀补了个上臀，
    /// 于是同一份档案：这一页画出曲线，那四页画中性——用户看到两个身体。
    ///
    /// 页面上本来就有一个「Estimate high hip from waist & hip」按钮。
    /// 想要曲线就按它（按了会落库，五处随即一致）；不按就照实显示。
    @Test func thePreviewMatchesWhatTheRestOfTheAppWillDraw() throws {
        let (_, _, vm) = try setup("preview")
        vm.bustInches = 40; vm.waistInches = 34; vm.hipInches = 44
        vm.highHipInches = nil
        vm.refreshPreview()
        #expect(vm.liveMeasurements == nil, Comment(rawValue:
            "预览偷偷补了上臀 —— 这一页画曲线，Today 画中性，同一份档案两个身体"))
    }

    /// 按下那个按钮之后，预览与其余四屏一起变（推断值是**存下来**的）。
    @Test func estimatingTheHighHipMakesAllFiveAgree() throws {
        let (ctx, person, vm) = try setup("estimate")
        vm.bustInches = 40; vm.waistInches = 34; vm.hipInches = 44
        vm.applyInferredHighHip()
        #expect(vm.liveMeasurements != nil)
        vm.save(in: ctx)

        let stored = try #require(try ctx.fetch(
            FetchDescriptor<PersonBodyProfile>()).first { $0.personID == person.id })
        #expect(stored.highHipInches != nil, "推断值没落库，其余四屏还是中性")
        #expect(stored.highHipInferred, "落了库却没标成推断值 —— 置信度会虚高")
        #expect(OwnerBodyDerivation.shape(from: stored) != OwnerBodyDerivation.fallbackShape
                || BodyProfileService.measurements(from: stored) != nil)
    }

    // MARK: - #29 同一页两套保存语义

    /// **本波的核心**：页面上任何一次「已保存」，说的都得是整页。
    ///
    /// 此前四围只在显式 Save 时落库，而快选/性别/表型/精调滑杆各自即时落库。
    /// 于是：点满四围 → 屏显 Measures 4/4、头像变形 → 顺手点一下快选、
    /// 看到「Saved Pear…」→ 退出 → **四围全丢**。
    /// 那句「Saved」在用户眼里是对整页说的。
    @Test func anyInstantSaveOnThePageAlsoKeepsTheMeasurements() throws {
        let (ctx, person, vm) = try setup("instant")
        vm.bustInches = 38; vm.waistInches = 30; vm.hipInches = 40
        vm.highHipInches = 36
        // 用户没点 Save，而是顺手点了快选
        vm.selectPopularShape(.pear, in: ctx)

        let stored = try #require(try ctx.fetch(
            FetchDescriptor<PersonBodyProfile>()).first { $0.personID == person.id })
        #expect(stored.bustInches == 38, Comment(rawValue:
            "屏上刚说了「Saved」，四围却没落库 —— 退出即丢"))
        #expect(stored.hipInches == 40)
        #expect(stored.popularShapeOverrideRaw == PopularShape.pear.rawValue)
    }

    /// 精调滑杆那条路同样（它也是即时落库的）。
    @Test func theFineTuneSaveAlsoKeepsTheMeasurements() throws {
        let (ctx, person, vm) = try setup("fine")
        vm.bustInches = 38; vm.waistInches = 30; vm.hipInches = 40
        vm.fineChest = 1.05
        vm.saveFineTune(in: ctx)
        let stored = try #require(try ctx.fetch(
            FetchDescriptor<PersonBodyProfile>()).first { $0.personID == person.id })
        #expect(stored.bustInches == 38)
        #expect(stored.fineChest == 1.05)
    }

    // MARK: - #30 说了「随时可以删」，却没有任何入口

    /// 同意卡承诺「You can delete them any time.」——那就得真的能删。
    @Test func measurementsCanActuallyBeDeleted() throws {
        let (ctx, person, vm) = try setup("forget")
        vm.bustInches = 38; vm.waistInches = 30; vm.hipInches = 40
        vm.highHipInches = 36
        vm.save(in: ctx)
        #expect(try ctx.fetch(FetchDescriptor<PersonBodyProfile>())
            .contains { $0.personID == person.id && $0.bustInches != nil })

        #expect(vm.forgetBodyData(in: ctx))
        let after = try ctx.fetch(FetchDescriptor<PersonBodyProfile>())
            .filter { $0.personID == person.id }
        #expect(after.allSatisfy { $0.bustInches == nil && $0.waistInches == nil
            && $0.hipInches == nil && $0.highHipInches == nil },
            "围度还在库里 —— 同意卡上那句「随时可以删」兑现不了")
        #expect(vm.bustInches == nil, "表单还留着刚删掉的数")
    }

    /// 删掉围度**同时撤回同意**——否则开关还开着，而库里已经没有数据。
    @Test func deletingAlsoRevokesTheConsent() throws {
        let ctx = try makeContext()
        let person = Person(name: "Ping"); ctx.insert(person); try ctx.save()
        let gate = consent("revoke")
        let vm = BodyProfileViewModel(personID: person.id, bodyDataConsent: gate)
        vm.load(in: ctx)
        vm.bustInches = 38; vm.save(in: ctx)

        #expect(vm.forgetBodyData(in: ctx))
        #expect(gate.isGranted == false, "同意开关还开着，而库里已经没有围度了")
    }

    /// 只删身体维度——**别的东西一根汗毛都不许动**。
    @Test func forgettingBodyDataTouchesNothingElse() throws {
        let (ctx, person, vm) = try setup("scope")
        let w = try #require(try ctx.fetch(FetchDescriptor<Wardrobe>()).first)
        let tee = Item(name: "Tee"); tee.wardrobe = w; ctx.insert(tee)
        try ctx.save()
        vm.bustInches = 38; vm.save(in: ctx)

        #expect(vm.forgetBodyData(in: ctx))
        #expect(try ctx.fetch(FetchDescriptor<Item>()).count == 1, "把单品也删了")
        #expect(try ctx.fetch(FetchDescriptor<Wardrobe>()).count == 1, "把衣柜也删了")
        #expect(try ctx.fetch(FetchDescriptor<Person>()).contains { $0.id == person.id },
                "把人也删了")
    }

    /// 文案要说清删的是什么、不删的是什么。
    @Test func theDeleteCopyIsSpecific() {
        let copy = BodyProfileViewModel.forgetConfirmMessage
        #expect(copy.localizedCaseInsensitiveContains("measurement"))
        #expect(copy.localizedCaseInsensitiveContains("closet")
                || copy.localizedCaseInsensitiveContains("piece")
                || copy.localizedCaseInsensitiveContains("nothing else"),
                Comment(rawValue: "没说清别的数据不受影响：\(copy)"))
    }

    /// 结构门：**承诺与入口同生共死。**
    /// 同意卡上只要还写着「随时可以删」，界面上就必须有那个入口。
    @Test func thePromiseHasARealEntry() throws {
        guard BodyDataConsent.explainer
            .localizedCaseInsensitiveContains("delete them any time") else { return }
        let ui = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/ClosetUI")
        var callSites = 0
        for case let url as URL in FileManager.default
            .enumerator(at: ui, includingPropertiesForKeys: nil)!
        where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            callSites += text.split(separator: "\n").filter {
                let t = $0.trimmingCharacters(in: .whitespaces)
                return t.contains("forgetBodyData(in:")
                    && !t.hasPrefix("//") && !t.hasPrefix("///")
            }.count
        }
        #expect(callSites > 0, Comment(rawValue:
            "同意卡写着「You can delete them any time」，而界面上没有任何删除入口"))
    }
}
