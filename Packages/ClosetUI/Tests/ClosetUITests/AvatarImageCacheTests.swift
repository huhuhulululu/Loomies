import Testing
import SwiftUI
import Foundation
@testable import ClosetUI

@Suite("AvatarImageCaches")
@MainActor
struct AvatarImageCacheTests {

    /// bundle probe 表有上限：key 域可被数据驱动（资产名来自调用方），
    /// 每个 miss 永久占一条会把缓存变成泄漏。
    @Test func resourceProbeTableIsBounded() {
        let cache = BodyAvatarImageCache()
        for i in 0..<600 {
            _ = cache.resourceURL(named: "definitely-missing-\(i)")
        }
        #expect(cache.resourceProbeCount <= 512)
        // 越界清空后仍可正常 probe
        _ = cache.resourceURL(named: "definitely-missing-after")
        #expect(cache.resourceProbeCount >= 1)
    }

    /// 负缓存语义保留：已知失败返回 .some(nil)，从未加载返回 nil。
    @Test func imageCacheKeepsNegativeSemantics() {
        let cache = BodyAvatarImageCache()
        #expect(cache.cachedImage(forKey: "never") == nil)
        cache.storeImage(nil, forKey: "known-miss")
        let hit = cache.cachedImage(forKey: "known-miss")
        #expect(hit != nil)          // 有缓存记录
        #expect(hit! == nil)         // 记录内容是「失败」
        cache.storeImage(Image(systemName: "circle"), forKey: "ok", cost: 1024)
        #expect(cache.cachedImage(forKey: "ok")! != nil)
    }

    /// 程序化裸体栅格缓存：同参数只栅格化一次——旧实现在 View body 里直接
    /// makeCGImage，30fps TimelineView 下每次重求值都全画布重绘 ~30 个抗锯齿椭圆。
    @Test func fullNudeCacheRendersOnce() {
        let cache = FullNudeBodyImageCache()
        let before = cache.renderAttempts
        _ = cache.image(sex: .female, phenotype: .eastAsian, morph: .neutral,
                        shape: nil, yaw: .deg0, width: 64, height: 96)
        _ = cache.image(sex: .female, phenotype: .eastAsian, morph: .neutral,
                        shape: nil, yaw: .deg0, width: 64, height: 96)
        #expect(cache.renderAttempts == before + 1)
        _ = cache.image(sex: .female, phenotype: .eastAsian, morph: .neutral,
                        shape: nil, yaw: .deg90, width: 64, height: 96)
        #expect(cache.renderAttempts == before + 2)
    }

    /// 非有限/非正宽度（首帧布局瞬态）安全降级为 nil，不 trap（Int(NaN) 陷阱）。
    @Test func morphCacheSurvivesNonFiniteWidth() {
        let cache = BodyMorphImageCache()
        #expect(cache.image(named: "x", morph: .neutral, width: .nan) == nil)
        #expect(cache.image(named: "x", morph: .neutral, width: .infinity) == nil)
        #expect(cache.image(named: "x", morph: .neutral, width: 0) == nil)
        #expect(cache.image(named: "x", morph: .neutral, width: -5) == nil)
    }

    /// morph 缓存对 miss（资产缺失）也要负缓存：缺资产不得每 tick 重走读盘+解码。
    @Test func morphCacheCachesMisses() {
        let cache = BodyMorphImageCache()
        let before = cache.renderAttempts
        _ = cache.image(named: "no-such-asset-xyz", morph: .neutral, width: 100)
        _ = cache.image(named: "no-such-asset-xyz", morph: .neutral, width: 100)
        _ = cache.image(named: "no-such-asset-xyz", morph: .neutral, width: 100)
        #expect(cache.renderAttempts == before + 1)
    }
}
