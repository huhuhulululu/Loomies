import Testing
import Foundation
@testable import ClosetUI
import ClosetCore

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
        // D209：遍历型门必须自证「扫到过东西」——判据见 D208。
        var scannedFileCount = 0
        var offenders: [String] = []
        let fm = FileManager.default
        for case let url as URL in fm.enumerator(at: sourcesDir, includingPropertiesForKeys: nil)!
        where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            scannedFileCount += 1
            guard text.contains("totalCostLimit") else { continue }
            // 同一个文件里要么自己有清空口，要么被统一清理器点名
            let hasPurge = text.contains("removeAllObjects()")
            if !hasPurge { offenders.append(url.lastPathComponent) }
        }
        let census = try TraversalCensus.check(
            live: scannedFileCount,
            key: TraversalCensus.closetUISources,
            testFile: #filePath)
        #expect(census == nil, Comment(rawValue: census ?? ""))
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

/// D136：早安提醒的三处不诚实，共同点是**开关状态从不与现状对账**。
@MainActor
struct DailyRitualHonestyTests {

    private var uiDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Sources/ClosetUI")
    }

    /// 删库必须关掉提醒——否则挂起的七条每周提醒**没有任何东西能关掉它们**，
    /// 而 App 回到 Onboarding 后连那个开关都不在了：
    /// 用户删了全部数据，手机却继续每天早上叫他去看一个空 App。
    @Test func deletingEverythingAlsoStopsTheNudge() throws {
        let text = try String(
            contentsOf: uiDir.appendingPathComponent("AppRootView.swift"), encoding: .utf8)
        guard let range = text.range(of: "deleteAllUserData") else {
            Issue.record("找不到删库分支"); return
        }
        // D162：窗口式判据——加几行注释就可能把要找的调用挤出去（误红），
        // 或让它躲在窗口外（漏检）。改按结构边界取到该分支结束。
        let rest = text[range.lowerBound...]
        let stop = rest.range(of: "\n                Button(\"Cancel\"")?.lowerBound
            ?? rest.endIndex
        let block = String(rest[rest.startIndex..<stop])
        #expect(block.contains("DailyRitualScheduler.disable()"),
                "删库之后提醒还在，而 App 里已经没有关掉它的入口")
    }

    /// 进 Me 时与系统实况对账（用户可能在 iOS 设置里撤销了通知）。
    @Test func theSwitchReconcilesWithTheSystem() throws {
        let text = try String(
            contentsOf: uiDir.appendingPathComponent("AppRootView.swift"), encoding: .utf8)
        #expect(text.contains("reconcileDailyRitual"),
                "撤权之后开关仍显示「开」，而系统层面一条都不会发")
    }

    /// 衣柜件数变化要重排——「配不配打扰用户」取决于衣柜此刻的样子。
    @Test func closetChangesRescheduleTheNudge() throws {
        let text = try String(
            contentsOf: uiDir.appendingPathComponent("CopilotView.swift"), encoding: .utf8)
        #expect(text.contains("onChange(of: vm.availableItems.count)"),
                "加到第 8 件的当天不排、砍回 3 件仍照排")
    }
}

/// D136：回到前台要重读「今天穿了什么」——周二晚打卡、周三早上被提醒
/// 叫醒打开 App，顶部却还写着昨天那身。而早安提醒恰恰把用户导向这条路径。
@MainActor
struct SettledBandFreshnessTests {
    @Test func returningToTheForegroundRereadsToday() throws {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/ClosetUI/CopilotView.swift")
        let text = try String(contentsOf: file, encoding: .utf8)
        #expect(text.contains("onChange(of: scenePhase)"),
                "跨午夜回到前台仍显示昨天定的那身")
        #expect(text.contains("vm.reloadToday(in: context)"))
    }
}

/// D138：阶梯与毕业卡的两处文案矛盾。
@MainActor
struct ActivationCoherenceTests {

    private var uiDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Sources/ClosetUI")
    }

    /// 阶梯按**总件数**判——洗衣不该把 25 件的柜推回「再加几件」。
    @Test func theLadderIgnoresLaundry() throws {
        let text = try String(
            contentsOf: uiDir.appendingPathComponent("CopilotView.swift"), encoding: .utf8)
        #expect(text.contains("showsLadder(itemCount: vm.totalItemCount)"),
                "送洗几件就把衣柜推回激活阶梯 —— 用户什么都没少")
    }

    /// 「你的衣柜可以天天给你出主意了」不得出现在一个此刻拼不出任何一套的屏幕上。
    @Test func theReadyMomentNeverContradictsAnEmptyScreen() throws {
        let text = try String(
            contentsOf: uiDir.appendingPathComponent("CopilotView.swift"), encoding: .utf8)
        #expect(text.contains("!hasSeenReadyMoment, !vm.suggestions.isEmpty"),
                "毕业卡说「能天天穿」，而它下面就是「今天拼不出一身」")
    }
}
