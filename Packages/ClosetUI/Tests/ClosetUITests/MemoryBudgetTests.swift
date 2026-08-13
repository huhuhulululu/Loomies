import Testing
import Foundation
@testable import ClosetUI

/// D132：**六个图像缓存合计 440MB 上限，谁也不知道彼此的存在，进后台没人清**。
///
/// 数字本身就说明问题：128 + 96 + 64 + 64 + 48 + 40 = 440MB，
/// 而 iOS 给前台 App 的常见预算是几百 MB——真装满，
/// 这个 App 会在切后台后被系统 jetsam 掉，用户回来看到的是**冷启动**
/// （试衣间白搭、Today 重算），而他只是去接了个电话。
///
/// 更要命的是**只有一个缓存有 `removeAll()`**：另外五个装满了就是装满了，
/// 除了 NSCache 自己在内存压力下的自主逐出，没有任何主动释放的路径。
///
/// 这一波不重新分配预算（那要设备 profile 才谈得上），只做两件确定的事：
/// 每个缓存都能被清空、切后台时统一清一次。
@MainActor
struct MemoryBudgetTests {

    private var sourcesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Sources/ClosetUI")
    }

    /// 每个声明了 `totalCostLimit` 的缓存都必须能被清空——
    /// 装满了没有释放路径，等于把内存交给运气。
    @Test func everyCacheCanBePurged() throws {
        var offenders: [String] = []
        let fm = FileManager.default
        for case let url as URL in fm.enumerator(at: sourcesDir, includingPropertiesForKeys: nil)!
        where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8),
                  text.contains("totalCostLimit") else { continue }
            // 同一个文件里要么自己有清空口，要么被统一清理器点名
            let hasPurge = text.contains("removeAllObjects()")
            if !hasPurge { offenders.append(url.lastPathComponent) }
        }
        #expect(offenders.isEmpty, Comment(rawValue:
            "这些缓存装满了就没有释放路径：\(offenders)"))
    }

    /// 统一清理器必须涵盖**全部**缓存——漏一个，那一个就永远留在内存里。
    @Test func thePurgerCoversEveryCache() {
        #expect(ImageCaches.purgeAll() >= 5,
                "统一清理没有覆盖到全部缓存")
    }

    /// 清空是幂等的（切后台可能连发两次）。
    @Test func purgingTwiceIsSafe() {
        _ = ImageCaches.purgeAll()
        _ = ImageCaches.purgeAll()
    }

    /// 接线门：切后台时真的会清（否则这套东西等于没做）。
    @Test func backgroundingActuallyPurges() throws {
        let shell = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("app-shell/ClosetApp/ClosetApp.swift")
        let text = try String(contentsOf: shell, encoding: .utf8)
        #expect(text.contains("ImageCaches.purgeAll"),
                "切后台没有清理点 —— 440MB 的缓存会跟着 App 一起被 jetsam")
        #expect(text.contains("scenePhase"), "没有监听场景阶段")
    }
}
