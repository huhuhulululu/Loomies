import Foundation

/// 将 ItemImageStore 重定向到按进程隔离的临时根目录。
/// 多个 package 测试进程并行时共享真实 ~/Library/Application Support/ItemImages，
/// 会互相看到（目录快照断言 flake）甚至删到（兜底清理误删）对方的文件。
/// 触盘套件在 init 调一次即可（幂等；struct suite 每个测试都会新建实例）。
enum ItemImageTestRoot {

    /// D143：**`setenv` 只跑一次。**
    ///
    /// 此前每个套件的每个测试实例都调一次（struct suite 每例新建实例，
    /// 五个触盘套件并行 = 上百次），而 POSIX 的 `setenv` 与 `getenv`
    /// 并发不安全：`setenv` 会重建 `environ` 数组，而
    /// `ProcessInfo.environment` 那边正在读——写的值虽然每次都一样，
    /// **竞态本身与值无关**，踩中就是进程级崩溃。
    ///
    /// `static let` 的初始化由运行时保证「至多一次且线程安全」，
    /// 后来的调用只是读一个已初始化的常量。
    private static let installed: Bool = {
        let dir = NSTemporaryDirectory()
            .appending("ItemImages-\(ProcessInfo.processInfo.processIdentifier)")
        setenv("ITEM_IMAGE_ROOT", dir, 1)
        return true
    }()

    static func install() {
        _ = installed
    }
}
