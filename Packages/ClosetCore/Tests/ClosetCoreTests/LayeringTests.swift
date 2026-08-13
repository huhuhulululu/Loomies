import Testing
import Foundation

/// D167：**「ClosetCore 保持纯 Swift、依赖方向只能 UI → Model → Core」写在 CLAUDE.md 的
/// 关键约束里，而没有任何东西守着它。**
///
/// 实测当下 Core 只 import `Foundation`（45 处）与 `OSLog`（1 处，AppLog 用）——
/// 性质今天成立，靠的是历任作者记得。而破坏它**编得过**：
/// `import UIKit` 会因 macOS 构建失败被动挡住，但 `import SwiftData` /
/// `import SwiftUI` / `import CoreGraphics` 在两个平台都编得过，
/// 于是引擎会在没人察觉的情况下与持久化/视图层绑死。
///
/// 那正是这个包存在的理由：`RecommendationTypes` 的注释白纸黑字写着
/// 「RulesEngine 禁依赖 SwiftData」——一条只写在注释里的规则，等于没有规则。
struct LayeringTests {

    private var coreSources: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/ClosetCore")
    }

    /// Core 允许出现的 import。加新的要**在这里过一遍脑子**，不是随手加。
    private let allowed: Set<String> = [
        "Foundation",
        "OSLog",       // AppLog 的后端；纯日志，不引入 UI/持久化
    ]

    @Test func coreImportsNothingBeyondTheAllowList() throws {
        var offenders: [String] = []
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: coreSources, includingPropertiesForKeys: nil)
        else { return }
        for case let url as URL in walker where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for line in text.split(separator: "\n") {
                let t = line.trimmingCharacters(in: .whitespaces)
                guard t.hasPrefix("import ") else { continue }
                let module = t.dropFirst("import ".count)
                    .prefix { $0 != " " && $0 != "\n" }
                    .trimmingCharacters(in: .whitespaces)
                guard !allowed.contains(module) else { continue }
                offenders.append("\(url.lastPathComponent) ~ import \(module)")
            }
        }
        #expect(offenders.isEmpty, Comment(rawValue:
            "ClosetCore 引入了白名单之外的模块：\(offenders) —— "
            + "引擎是纯值层（CLAUDE.md 关键约束）；确实需要就先改白名单并说明理由"))
    }

    // D167：**依赖方向不需要测试来守**——实测在 Core 里写 `import ClosetModel`
    // 直接编译失败（`no such module 'ClosetModel'`，SwiftPM 的 target 依赖图挡的）。
    // 比测试更早、更硬。写一道测试反而制造「这里有守卫」的错觉，
    // 掩盖了真正的机制在哪。**已经被更强的机制守住的东西，不该再加一道弱的。**

    /// 门自身要能抓到真违规——白名单判据最容易写成「什么都放过」。
    @Test func theAllowListActuallyRejectsSomething() {
        #expect(!allowed.contains("SwiftData"))
        #expect(!allowed.contains("SwiftUI"))
        #expect(!allowed.contains("UIKit"))
        #expect(allowed.contains("Foundation"))
    }
}
