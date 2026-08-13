import Testing
import Foundation
import SwiftData
@testable import ClosetUI
import ClosetModel
import ClosetCore

/// D175：头像体型推导的**状态矩阵**。此前四个视图各写一份、零测试覆盖，
/// 而它决定用户在四块屏幕上看到的身体长什么样。
@MainActor
struct OwnerBodyDerivationTests {

    private func profile(bust: Double? = nil, waist: Double? = nil,
                         hip: Double? = nil, highHip: Double? = nil,
                         override: PopularShape? = nil) -> PersonBodyProfile {
        let p = PersonBodyProfile(personID: UUID())
        p.bustInches = bust; p.waistInches = waist
        p.hipInches = hip; p.highHipInches = highHip
        p.popularShapeOverrideRaw = override?.rawValue
        return p
    }

    /// 没有档案 → 中性矩形，不替用户假设。
    @Test func noProfileDrawsTheNeutralBody() {
        #expect(OwnerBodyDerivation.shape(from: nil) == .rectangle)
    }

    /// 只手选过 → 画他选的那个。
    @Test func aVisualPickIsHonoured() {
        #expect(OwnerBodyDerivation.shape(from: profile(override: .pear)) == .pear)
    }

    /// 只量过 → 画量出来的。
    @Test func measurementsClassifyTheBody() {
        let p = profile(bust: 36, waist: 25, hip: 36, highHip: 33)
        #expect(OwnerBodyDerivation.shape(from: p) == .hourglass)
    }

    /// **既量过又手选过 → 画他选的**（画的是你说的样子）。
    /// 打分口径**有意不同**（实测优先），那条由 `BodyProfileServiceTests` 守。
    @Test func anExplicitPickWinsForTheDrawing() {
        let p = profile(bust: 36, waist: 25, hip: 36, highHip: 33, override: .pear)
        #expect(OwnerBodyDerivation.shape(from: p) == .pear)
        #expect(BodyProfileService.bodyShape(from: p)?.popularCategory == .hourglass,
                "打分口径被顺手改了 —— 那是另一条有意为之的分工")
    }

    /// 量了一半（缺上臀）→ 不硬判，回落中性。
    @Test func partialMeasurementsFallBack() {
        #expect(OwnerBodyDerivation.shape(from: profile(bust: 36, waist: 26, hip: 40))
                == .rectangle)
    }

    /// **等价性证明**：Today 此前的额外兜底（`vm.bodyShape?.popularCategory ?? .rectangle`）
    /// 与共享实现在**每一种档案状态**下取值相同——所以收成一处不改行为。
    /// 这条不是推断，是把状态矩阵跑一遍。
    @Test func todaysOldFallbackWasAlwaysEquivalent() {
        var cases: [PersonBodyProfile?] = [nil]
        for o in [nil, PopularShape.pear, .apple, .hourglass, .rectangle, .invertedTriangle] {
            for m in [(nil, nil, nil, nil), (36.0, 25.0, 36.0, 33.0),
                      (36.0, 26.0, 40.0, nil), (nil, 26.0, 40.0, 34.0)] as [(Double?, Double?, Double?, Double?)] {
                cases.append(profile(bust: m.0, waist: m.1, hip: m.2, highHip: m.3, override: o))
            }
        }
        for p in cases {
            let shared = OwnerBodyDerivation.shape(from: p)
            let legacyToday: PopularShape = {
                if let p, let s = BodyProfileService.displayPopularShape(from: p) { return s }
                guard let p else { return .rectangle }
                return BodyProfileService.bodyShape(from: p)?.popularCategory ?? .rectangle
            }()
            #expect(shared == legacyToday, Comment(rawValue:
                "两种兜底在某个档案状态下分叉了：shared=\(shared) legacy=\(legacyToday)"))
        }
    }

    /// 形变：无档案取预设，有档案按合成——两条路都给得出值（不返回退化值）。
    @Test func morphIsProducedForBothPaths() {
        let none = OwnerBodyDerivation.morph(from: nil)
        let some = OwnerBodyDerivation.morph(
            from: profile(bust: 36, waist: 25, hip: 36, highHip: 33))
        #expect(none.chest > 0 && none.waist > 0 && none.hip > 0)
        #expect(some.chest > 0 && some.waist > 0 && some.hip > 0)
    }
}

/// D175 结构门：**头像体型的推导只许有一处**。
///
/// 收口前它在四个视图里各写一份（三份逐字节相同）。本仓已经为这种重复付过账——
/// D144 两处披露走岔、D148 排序手抄 19 遍、D165 两张手工表各自过期。
@MainActor
struct OwnerBodyDerivationSingleSourceTests {

    @Test func noViewHandRollsTheDerivation() throws {
        let dir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/ClosetUI")
        var offenders: [String] = []
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: dir, includingPropertiesForKeys: nil)
        else { return }
        for case let url as URL in walker where url.pathExtension == "swift" {
            // 推导自身与推导服务不算犯规
            guard url.lastPathComponent != "OwnerBodyDerivation.swift" else { continue }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for line in text.split(separator: "\n") {
                let t = line.trimmingCharacters(in: .whitespaces)
                guard !t.hasPrefix("//"), !t.hasPrefix("///") else { continue }
                // D175：判据认**被收口的那四个成员**，不认底层 API 的任何使用——
                // 第一版拦到了头像渲染器、体型编辑 VM、onboarding 完备性检查
                // 这些完全正当的用法（判据太宽会把正常工作也挡下来，
                // 与判据太松是同一个病的两个方向）。
                let redeclares = ["var ownerShape", "var ownerMorph",
                                  "var heroShape", "var bodyMorph"]
                for m in redeclares where t.contains(m) && !t.contains("OwnerBodyDerivation") {
                    offenders.append("\(url.lastPathComponent): \(t.prefix(70))")
                }
            }
        }
        #expect(offenders.isEmpty, Comment(rawValue:
            "又有人自己拼头像体型推导：\(offenders) —— 用 `OwnerBodyDerivation`"))
    }
}
