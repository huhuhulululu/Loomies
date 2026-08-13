import Foundation
import ClosetCore

/// 图像缓存的统一清理（D132）。
///
/// 六个缓存合计 **440MB** 上限（128 + 96 + 64 + 64 + 48 + 40），
/// 彼此不知道对方存在，而**全 app 没有任何后台清理点**。
/// 真装满，这个 App 会在切后台后被系统 jetsam 掉——
/// 用户回来看到的是冷启动（试衣间白搭、Today 重算），而他只是去接了个电话。
///
/// 更要命的是此前**只有一个缓存有清空 API**：另外几个装满了就是装满了，
/// 除了 NSCache 自主逐出没有任何主动释放路径。
///
/// 这里**不重新分配预算**——那要设备 profile 才谈得上，凭空调数字只是换一种猜。
/// 只做两件确定的事：每个缓存都能被清空、切后台时统一清一次。
@MainActor
public enum ImageCaches {

    /// 清空全部图像缓存，返回清理的缓存个数（供门断言覆盖面）。
    ///
    /// 幂等：切后台可能连发两次。
    @discardableResult
    public static func purgeAll() -> Int {
        ThumbnailImageCache.shared.removeAll()          // 缩略图        40MB
        BodyAvatarImageCache.shared.purge()             // 头像图 + 平台图 128+64MB
        FullNudeBodyImageCache.shared.purge()           // 裸体底图      48MB
        BodyMorphImageCache.shared.purge()              // 形变图        96MB
        AppLog.debug("image caches purged", .app)
        // 覆盖的 **NSCache 实例**个数（`BodyAvatarImageCache` 内含两个）——
        // 数的是覆盖面，不是清掉多少字节。加新缓存忘了接进来，门会红。
        return coveredCacheCount
    }

    /// 本清理器覆盖的 NSCache 实例数。新增缓存必须同步这个数字与上面的调用。
    public static let coveredCacheCount = 5
}
