import Testing
import Foundation
@testable import ClosetModel

/// D158：**磁盘失败钩子是进程级的，而套件之间是并行的。**
///
/// `ItemImageStore.forceFailure(true)` 拨的是一个 `static var`——五个测试文件
/// 跨两个包在用它。`@Suite(.serialized)` 只保证**套件内**串行，
/// 套件与套件之间照样同时跑：A 把开关拨开的那几毫秒里，B 正在存图，
/// 于是 B 的写入无缘无故失败。
///
/// 这是 D143（堆地址注册表）、D154（全局调试开关）之后**同一族的第三个**：
/// 共享可变状态 + 并行执行 + 没人声明所有权。
///
/// 这次用对的原语：`@TaskLocal`。它按**调用任务**作用域，而每个测试各跑在
/// 自己的任务里——天然不串味，也不需要锁和「记得还原」的纪律。
struct DiskFailureHookScopeTests {

    private func tinyPNGData() -> Data { Data([0x89, 0x50, 0x4E, 0x47]) }

    /// 作用域内失败。
    @Test func insideTheScopeSavesFail() {
        ItemImageStore.$forcedSaveFailure.withValue(true) {
            #expect(ItemImageStore.save(data: tinyPNGData(), for: UUID(), ext: "png") == nil)
        }
    }

    /// **出了作用域立刻恢复**——不依赖任何人记得还原。
    @Test func outsideTheScopeSavesWork() {
        ItemImageStore.$forcedSaveFailure.withValue(true) { _ = 0 }
        let rel = ItemImageStore.save(data: tinyPNGData(), for: UUID(), ext: "png")
        defer { if let rel { ItemImageStore.deleteAll(relativePath: rel) } }
        #expect(rel != nil, "作用域结束后写盘仍然失败 —— 开关漏在外面了")
    }

    /// **并行的另一条任务看不见它。** 这正是此前会互相污染的那一下。
    @Test func aConcurrentTaskIsUnaffected() async {
        async let neighbour: Bool = {
            // 邻居不在那个作用域里，写盘该照常成功
            let rel = ItemImageStore.save(data: Data([0x89, 0x50]), for: UUID(), ext: "png")
            defer { if let rel { ItemImageStore.deleteAll(relativePath: rel) } }
            return rel != nil
        }()
        ItemImageStore.$forcedSaveFailure.withValue(true) {
            _ = ItemImageStore.save(data: tinyPNGData(), for: UUID(), ext: "png")
        }
        #expect(await neighbour, "并行任务被别人的失败开关波及了")
    }

    /// 结构门：**不许再有进程级的失败开关。**
    @Test func noProcessWideFailureFlagRemains() throws {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/ClosetModel/ItemImageStore.swift")
        let text = try String(contentsOf: file, encoding: .utf8)
        let offends = text.split(separator: "\n").contains { line in
            let t = line.trimmingCharacters(in: .whitespaces)
            return t.contains("static var forceFailureEnabled")
                && !t.hasPrefix("//") && !t.hasPrefix("///")
        }
        #expect(!offends, "进程级失败开关还在 —— 并行套件会互相波及")
    }
}
