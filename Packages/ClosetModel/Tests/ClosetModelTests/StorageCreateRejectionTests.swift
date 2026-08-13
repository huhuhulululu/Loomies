import Testing
import Foundation
import SwiftData
@testable import ClosetModel

/// D182：**建到第四层时，App 说的是「Couldn't add location — try again」——
/// 而重试永远无用。**
///
/// `create` 有四条拒绝理由，UI 只在提交前判了其中一条（同级重名），
/// 其余三条都落进那句笼统的 “try again”。最刺眼的是深度上限：
/// 专门为它写的诚实文案 `depthLimitMessage`（“Storage nests up to 3 levels.
/// Put this one a level up.”）在**全仓零生产调用点**——只有一条测试断言
/// 「这个常量含有 level 这个词」，那只证明常量存在。
///
/// 而这条路是走得到的：位置 Picker 用 `listWithDepth` 列**全部**层级、不做过滤，
/// 第三层节点照样能被选成父节点。
///
/// 接线门（`WiringLintTests`）扫的是 View 与 ViewModel，**文案常量不在扫描面内**——
/// 所以它从门底下漏过去是结构性的，不是巧合。
///
/// 处置：拒绝理由收成**一处**（`createRejection`），UI 只问这一次。
/// 原来 UI 里那句手抄的重名预检一并撤掉——同一条规则不该写两遍。
@MainActor
struct StorageCreateRejectionTests {

    private func makeContext() throws -> ModelContext {
        try ModelContext(try ModelContainer(
            for: LoomiesStore.fullSchema,
            migrationPlan: LoomiesMigrationPlan.self,
            configurations: LoomiesStore.mainConfiguration(inMemory: true),
            LoomiesStore.localConfiguration(inMemory: true)))
    }

    /// 建到上限那一层：**说清楚是层数满了**，别叫人重试。
    @Test func theDepthLimitSaysItIsTheDepthLimit() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Home"); ctx.insert(w); try ctx.save()
        var parent: StorageLocation?
        for i in 0..<StorageLocationService.maxDepth {
            parent = try #require(StorageLocationService.create(
                name: "L\(i)", in: w, parent: parent, context: ctx))
        }
        // 第四层
        let reason = StorageLocationService.createRejection(name: "L3", in: w, parent: parent)
        #expect(reason == StorageLocationService.depthLimitMessage, Comment(rawValue:
            "到达层数上限时给的是 \(reason ?? "nil") —— 用户会一直重试一件永远不会成的事"))
        #expect(StorageLocationService.create(
            name: "L3", in: w, parent: parent, context: ctx) == nil, "服务层没拒绝")
    }

    /// 同级重名仍然说重名（原 UI 预检的行为一个字不变）。
    @Test func aDuplicateSiblingStillSaysDuplicate() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Home"); ctx.insert(w); try ctx.save()
        _ = StorageLocationService.create(name: "Rail", in: w, context: ctx)
        #expect(StorageLocationService.createRejection(name: "rail", in: w)
                == StorageLocationService.duplicateSiblingMessage)
    }

    /// 跨柜父节点。
    @Test func aCrossClosetParentIsRefusedInWords() throws {
        let ctx = try makeContext()
        let home = Wardrobe(name: "Home"); ctx.insert(home)
        let lake = Wardrobe(name: "Lake"); ctx.insert(lake); try ctx.save()
        let there = try #require(StorageLocationService.create(
            name: "Shelf", in: lake, context: ctx))
        let reason = StorageLocationService.createRejection(name: "Bin", in: home, parent: there)
        #expect(reason != nil)
        #expect(reason != StorageLocationService.createSaveFailedMessage,
                "跨柜父节点被说成「重试一下」")
    }

    /// 空名。
    @Test func aBlankNameIsRefusedInWords() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Home"); ctx.insert(w); try ctx.save()
        #expect(StorageLocationService.createRejection(name: "   ", in: w) != nil)
    }

    /// 能建的时候不许报错。
    @Test func aLegitimateNameHasNoRejection() throws {
        let ctx = try makeContext()
        let w = Wardrobe(name: "Home"); ctx.insert(w); try ctx.save()
        #expect(StorageLocationService.createRejection(name: "Rail", in: w) == nil)
    }

    /// 结构门：**`create` 每多一条拒绝理由，`createRejection` 必须跟着说**。
    ///
    /// 手工维护的对照表会悄悄过期——本 session 已经撞见过两张。
    /// 判据数的是 `create` 里的拒绝分支（每条都带一句 `... blocked` 的日志），
    /// 与 `createRejection` 的返回分支数对齐。
    @Test func everyRejectionBranchHasWords() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/ClosetModel/StorageLocationService.swift")
        let text = try String(contentsOf: url, encoding: .utf8)

        func body(of signature: String, until stop: String) throws -> String {
            let r = try #require(text.range(of: signature),
                                 Comment(rawValue: "找不到 \(signature)"))
            let rest = text[r.lowerBound...]
            let end = rest.range(of: stop)?.lowerBound ?? rest.endIndex
            return String(rest[rest.startIndex..<end])
        }
        let createBody = try body(of: "public static func create(",
                                  until: "\n        let loc = StorageLocation(")
        let blocked = createBody.split(separator: "\n").filter {
            $0.contains("blocked") && !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        }.count
        let rejectionBody = try body(of: "public static func createRejection(",
                                     until: "\n    /// 从根到该节点")
        let worded = rejectionBody.split(separator: "\n").filter {
            let t = $0.trimmingCharacters(in: .whitespaces)
            return t.contains("return") && t.contains("Message")
                && !t.hasPrefix("//") && !t.hasPrefix("///")
        }.count
        #expect(blocked == worded, Comment(rawValue:
            "create 有 \(blocked) 条拒绝理由，createRejection 只说得出 \(worded) 条 —— "
            + "少的那条会落进笼统的「try again」"))
        #expect(blocked >= 4, Comment(rawValue: "只解析出 \(blocked) 条：解析口径坏了"))
    }
}
