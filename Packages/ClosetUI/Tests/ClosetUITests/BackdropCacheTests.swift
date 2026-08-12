import Testing
import Foundation
@testable import ClosetUI

/// D112（性能审计）：`AvatarBackdropView.bundleImage` 每次求值都
/// **重新探 Bundle + 重新解码** 一张 768×1152 的 PNG（盘上 412KB–961KB，解码约 3.5MB），
/// 只为了填一个 56×84pt 的缩略图。收藏行、日历行、Today 建议行每一行都付这笔账，
/// 而 `.id(backdrop)` 让不同场合各自独立，行之间不复用任何东西。
///
/// 同一个文件里另一条路（`BodyAvatarView.bundleUIImage`）早就学会了这一课
/// ——「photoreal 帧解析每 tick 不再打 Bundle」。这里接同一个缓存，不另造轮子。
@MainActor
struct BackdropCacheTests {

    /// 结构门：背景图不得再有未经缓存的 Bundle 解码路径。
    @Test func backdropLoadingGoesThroughTheSharedCache() throws {
        let src = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/ClosetUI/AvatarBackdrop.swift")
        let text = try String(contentsOf: src, encoding: .utf8)
        #expect(text.contains("BodyAvatarImageCache"),
                "没有接上模块里现成的 bundle 图缓存")
        // 解码必须在查缓存**之后**：顺序反了等于没缓存。
        let lookup = text.range(of: "cachedImage(forKey:")
        let decode = text.range(of: "contentsOfFile:") ?? text.range(of: "NSImage(contentsOf:")
        let lo = try #require(lookup?.lowerBound)
        let de = try #require(decode?.lowerBound)
        #expect(lo < de, "背景图先解码后查缓存 —— 每行仍付 ~3.5MB 解码只为画 56×84pt")
    }

    /// 同名资源两次取回同一张（第二次不再解码）。
    @Test func repeatedLoadsReturnTheSameImage() {
        let name = AvatarBackdrop.studio.imageResourceName
        _ = AvatarBackdropView.bundleImage(named: name)
        let key = AvatarBackdropView.cacheKey(for: name)
        #expect(BodyAvatarImageCache.shared.cachedImage(forKey: key) != nil,
                "第一次加载之后缓存里什么都没有 —— 说明根本没写进去")
    }

    /// 缺失资源要**负缓存**：否则每帧都去 probe 一次不存在的文件。
    @Test func missingResourceIsNegativelyCached() {
        let name = "definitely-not-a-backdrop-\(UUID().uuidString)"
        #expect(AvatarBackdropView.bundleImage(named: name) == nil)
        let cached = BodyAvatarImageCache.shared.cachedImage(
            forKey: AvatarBackdropView.cacheKey(for: name))
        #expect(cached != nil, "miss 没有被记住，下一帧还会再探一次 Bundle")
        #expect(cached! == nil, "不存在的资源被当成有图")
    }
}
