import Testing
import Foundation
@testable import ClosetUI

/// D183：**日历的提示条永不清除。**
///
/// `CalendarView` 的 `message` 只有两处赋值（排期后、删除失败），
/// **零处置 nil**，而 overlay 是无条件常驻的静态 chip。于是：
///
/// - 每次排期后那句「Planned …」永久压在屏幕底部；
/// - 一次删除失败之后，后续删除**成功了**，屏幕上仍写着
///   「Couldn't remove plan — try again」。
///
/// `CalendarView` 是 TabView 的直接子视图、没有 `.id()` 强制重建，
/// 切 tab 回来 `@State` 原样保留，换柜的 `onChange` 也只 reload 不清 message。
///
/// 同仓其余三处（Favorites / Closet 网格 / Today）都做了「token + 定时清」，
/// 而且**各写了一份**（2s / 3s / 2s）。这是同一条规则的第四次抄写机会——
/// 与其再抄一遍，不如收成一处。
@MainActor
struct FlashStateTests {

    /// 提示要能自己消失。
    @Test func aFlashClearsItself() async {
        let flash = FlashState()
        flash.show("Planned Look.", seconds: 0.05)
        #expect(flash.message == "Planned Look.")
        try? await Task.sleep(nanoseconds: 200_000_000)
        #expect(flash.message == nil, "提示没有自己消失 —— 它会一直压在屏幕上")
    }

    /// **后一条要接管前一条的定时**：先来的那条到点时不许把后来的清掉。
    @Test func aNewerFlashCancelsTheOlderTimer() async {
        let flash = FlashState()
        flash.show("first", seconds: 0.05)
        flash.show("second", seconds: 1.0)
        try? await Task.sleep(nanoseconds: 200_000_000)
        #expect(flash.message == "second", Comment(rawValue:
            "旧提示的定时把新提示清掉了：\(flash.message ?? "nil")"))
    }

    /// 成功路径显式清除（不必等定时）。
    @Test func clearRemovesItRightAway() {
        let flash = FlashState()
        flash.show("Couldn't remove plan — try again", seconds: 10)
        flash.clear()
        #expect(flash.message == nil)
    }

    /// 结构门：**渲染提示条的地方必须由 `FlashState` 驱动。**
    ///
    /// 判据对准缺陷本身——日历、试衣间、批量移动三处都是「画了 chip 却没有任何
    /// 清除路径」。第一版判据写的是「文件里出现 token 自增 + `Task.sleep`」，
    /// 当场误伤了 `cinematicExportFailed`：那是给失败三角计时的**布尔**标记，
    /// 不是提示文案，硬塞进一个字符串容器只会更糟。
    ///
    /// 判据太宽与太松是同一个病的两个方向（D175 记过一次）：
    /// 前者把正当代码挡下来，很快会被绕过或删掉。
    @Test func everyFlashChipIsDrivenByFlashState() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/ClosetUI")
        let fm = FileManager.default
        var offenders: [String] = []
        var rendered = 0
        for case let url as URL in fm.enumerator(at: sources, includingPropertiesForKeys: nil)!
        where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let lines = text.split(separator: "\n").map {
                $0.trimmingCharacters(in: .whitespaces)
            }.filter { !$0.hasPrefix("//") && !$0.hasPrefix("///") }
            // 渲染点（不算定义 chip 样式的那个函数本身）
            let rendersChip = lines.contains {
                ($0.contains("overlayChip(") || $0.contains("feedbackChip("))
                    && !$0.contains("static func") && !$0.contains("private func")
            }
            guard rendersChip else { continue }
            rendered += 1
            // 驱动它的状态必须来自 FlashState（View 自己持有，或它的 VM 持有）
            let viewModel = url.deletingPathExtension().lastPathComponent + "Model.swift"
            let vmText = (try? String(
                contentsOf: url.deletingLastPathComponent()
                    .appendingPathComponent(viewModel), encoding: .utf8)) ?? ""
            if !text.contains("FlashState") && !vmText.contains("FlashState") {
                offenders.append(url.lastPathComponent)
            }
        }
        #expect(rendered >= 4, Comment(rawValue: "只扫到 \(rendered) 处渲染点：口径坏了"))
        #expect(offenders.isEmpty, Comment(rawValue:
            "这些视图画了提示条却没有任何清除路径：\(offenders) —— 用 FlashState"))
    }
}
