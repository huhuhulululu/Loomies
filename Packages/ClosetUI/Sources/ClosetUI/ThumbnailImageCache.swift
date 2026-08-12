import Foundation
import ClosetModel
#if canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
public typealias PlatformImage = NSImage
#endif

/// 已解码缩略图的内存缓存（D109）。
///
/// `ItemThumbnailView.body` 此前每次求值都**同步读盘 + 解码 JPEG**——而 SwiftUI 会在
/// 滚动、父状态变化、多选勾选、字号变化时反复求值 body。D95 把解码的**尺寸**降下来了，
/// 解码本身仍逐格发生在主线程上，正是百件网格卡顿的剩余来源。
///
/// 更糟的是首次访问还会**同步生成派生图**（缩放 + 重编码），那是几十毫秒级的活儿，
/// 卡在第一次滑到该格的那一帧上。
///
/// 与 `BodyAvatarImageCache` 同法：NSCache + 按字节计费 + 内存压力自动清空。
public final class ThumbnailImageCache: @unchecked Sendable {
    public static let shared = ThumbnailImageCache()

    private let cache = NSCache<NSString, CacheBox>()

    private final class CacheBox {
        let image: PlatformImage
        init(_ image: PlatformImage) { self.image = image }
    }

    private init() {
        // 约 40MB：480px 长边的 JPEG 解码后约 0.9MB，够放几十格可见 + 预取
        cache.totalCostLimit = 40 * 1024 * 1024
    }

    /// 键含 variant——grid 与 detail 是两张不同的图，混用会显示错档。
    private func key(_ path: String, _ variant: ItemImageVariant) -> NSString {
        "\(path)|\(variant.rawValue)" as NSString
    }

    public func image(path: String?, variant: ItemImageVariant) -> PlatformImage? {
        guard let path, !path.isEmpty else { return nil }
        return cache.object(forKey: key(path, variant))?.image
    }

    public func store(_ image: PlatformImage, path: String, variant: ItemImageVariant) {
        #if canImport(UIKit)
        let bytes = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        #else
        let bytes = Int(image.size.width * image.size.height * 4)
        #endif
        cache.setObject(CacheBox(image), forKey: key(path, variant), cost: max(1, bytes))
    }

    /// 单品图被替换/删除时逐出——否则会继续显示已经不存在的旧图。
    public func evict(path: String?) {
        guard let path, !path.isEmpty else { return }
        for variant in ItemImageVariant.allCases {
            cache.removeObject(forKey: key(path, variant))
        }
    }

    public func removeAll() { cache.removeAllObjects() }

    /// 后台解码：读盘、必要时生成派生图，都不在主线程做。
    /// 返回 nil = 这张图读不出来（调用方显示占位，不假装有图）。
    public static func decode(path: String?, variant: ItemImageVariant) async -> PlatformImage? {
        guard let path, !path.isEmpty else { return nil }
        return await Task.detached(priority: .utility) {
            guard let data = ItemImageStore.derivedData(relativePath: path, variant: variant)
                    ?? ItemImageStore.loadData(relativePath: path)
            else { return nil }
            #if canImport(UIKit)
            return UIImage(data: data)
            #elseif canImport(AppKit)
            return NSImage(data: data)
            #else
            return nil
            #endif
        }.value
    }
}
