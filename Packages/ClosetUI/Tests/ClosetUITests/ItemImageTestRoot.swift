import Foundation

/// 将 ItemImageStore 重定向到按进程隔离的临时根目录。
/// 多个 package 测试进程并行时共享真实 ~/Library/Application Support/ItemImages，
/// 会互相看到（目录快照断言 flake）甚至删到（兜底清理误删）对方的文件。
/// 触盘套件在 init 调一次即可（幂等；struct suite 每个测试都会新建实例）。
enum ItemImageTestRoot {
    static func install() {
        let dir = NSTemporaryDirectory()
            .appending("ItemImages-\(ProcessInfo.processInfo.processIdentifier)")
        setenv("ITEM_IMAGE_ROOT", dir, 1)
    }
}
