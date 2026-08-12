import Testing
import Foundation
import CoreGraphics
@testable import ClosetUI
import ClosetModel
import ClosetCore

/// D109：缩略图此前在 `body` 里**同步读盘 + 解码**，而 SwiftUI 会在滚动、
/// 父状态变化、多选勾选、字号变化时反复求值 body——D95 只把解码的尺寸降下来了，
/// 解码本身仍逐格发生在主线程。首次访问还会同步**生成派生图**（缩放 + 重编码），
/// 卡在滑到该格的那一帧上。
@MainActor
struct ThumbnailImageCacheTests {
    init() { ItemImageTestRoot.install() }

    func makeJPEG() throws -> Data {
        let ctx = try #require(CGContext(
            data: nil, width: 300, height: 400, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.setFillColor(CGColor(red: 0.4, green: 0.5, blue: 0.6, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 300, height: 400))
        let image = try #require(ctx.makeImage())
        return try #require(ItemImageDerivatives.encodeJPEG(image))
    }

    /// 解码一次后命中缓存——第二次不再碰磁盘。
    @Test func decodedImageIsCachedAndReused() async throws {
        let id = UUID()
        let rel = try #require(ItemImageStore.save(data: try makeJPEG(), for: id))
        defer {
            ItemImageStore.deleteAll(relativePath: rel)
            ThumbnailImageCache.shared.evict(path: rel)
        }
        ThumbnailImageCache.shared.evict(path: rel)
        #expect(ThumbnailImageCache.shared.image(path: rel, variant: .grid) == nil)

        let decoded = try #require(await ThumbnailImageCache.decode(path: rel, variant: .grid))
        ThumbnailImageCache.shared.store(decoded, path: rel, variant: .grid)
        #expect(ThumbnailImageCache.shared.image(path: rel, variant: .grid) != nil)

        // 原图删掉后仍能从缓存拿到（证明第二次没有走磁盘）
        ItemImageStore.deleteAll(relativePath: rel)
        #expect(ThumbnailImageCache.shared.image(path: rel, variant: .grid) != nil)
    }

    /// 键含 variant——grid 与 detail 是两张不同的图，混用会显示错档。
    @Test func gridAndDetailAreCachedSeparately() async throws {
        let id = UUID()
        let rel = try #require(ItemImageStore.save(data: try makeJPEG(), for: id))
        defer {
            ItemImageStore.deleteAll(relativePath: rel)
            ThumbnailImageCache.shared.evict(path: rel)
        }
        let grid = try #require(await ThumbnailImageCache.decode(path: rel, variant: .grid))
        ThumbnailImageCache.shared.store(grid, path: rel, variant: .grid)
        #expect(ThumbnailImageCache.shared.image(path: rel, variant: .detail) == nil,
                "grid 的缓存不得被当成 detail 档拿出来")
    }

    /// 图被删/换时逐出——否则界面继续显示一张已经不存在的图。
    @Test func evictionRemovesEveryVariant() async throws {
        let id = UUID()
        let rel = try #require(ItemImageStore.save(data: try makeJPEG(), for: id))
        defer { ItemImageStore.deleteAll(relativePath: rel) }
        for variant in ItemImageVariant.allCases {
            let img = try #require(await ThumbnailImageCache.decode(path: rel, variant: variant))
            ThumbnailImageCache.shared.store(img, path: rel, variant: variant)
        }
        ThumbnailImageCache.shared.evict(path: rel)
        for variant in ItemImageVariant.allCases {
            #expect(ThumbnailImageCache.shared.image(path: rel, variant: variant) == nil)
        }
    }

    /// 读不出来就是 nil——不得返回一张占位图冒充真图。
    @Test func missingOrCorruptYieldsNil() async throws {
        #expect(await ThumbnailImageCache.decode(path: nil, variant: .grid) == nil)
        #expect(await ThumbnailImageCache.decode(
            path: "ItemImages/gone-\(UUID().uuidString).jpg", variant: .grid) == nil)
        let id = UUID()
        let rel = try #require(ItemImageStore.save(data: Data([0, 1, 2, 3]), for: id))
        defer { ItemImageStore.deleteAll(relativePath: rel) }
        #expect(await ThumbnailImageCache.decode(path: rel, variant: .grid) == nil)
    }
}
