import Testing
import Foundation

/// C2 合同 + A2 Liquid Glass 预算门。
///
/// 规则（对齐交接约束 C2）：
/// - 全 app 自定义 `glassEffect(` **≤ 2**；
/// - 一旦用了玻璃，就必须有 `GlassEffectContainer` 包裹（多块玻璃各自为政会
///   丢掉共享渲染 / 形变，视觉与性能都塌）；
/// - 内容层（衣物照片 / 网格 / 叠衣 hero）不上玻璃——那是控件层的材质，
///   这条**靠 review + snapshot 守**（源码扫描证明不了「哪块是内容」），
///   本门只守**数量 + 容器**这两条能被静态证据钉住的。
///
/// D208/D209/D160：遍历型 + 「上界」断言最容易假绿——遍历根一错就无声全过。
/// 所以本门额外做两件事：
/// 1. 计数扫过的源文件并断言下界（`scannedFileCount`），下界贴住实际值；
/// 2. 一个**自测**：喂一段已知超标 / 带注释 / 带相邻 API 的片段，
///    断言计数逻辑既抓得到真违规、又不误伤注释与 `glassEffectID(` / `GlassEffectContainer`。
struct GlassEffectBudgetTests {

    private var sourcesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // ClosetUITests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // ClosetUI（包根）
            .appendingPathComponent("Sources/ClosetUI")
    }

    /// 统计一段文本里 `glassEffect(` 的出现次数。
    /// - 跳过整行注释（`//` / `///`）——否则本仓大量提到「glassEffect」的说明会污染计数；
    /// - 只认紧跟 `(` 的 `glassEffect(`，故 `glassEffectID(` / `glassEffectUnion(` /
    ///   `GlassEffectContainer`（大写 G）都不会被误计。
    static func glassEffectCount(in text: String) -> Int {
        var n = 0
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = String(raw).trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("//"), !trimmed.hasPrefix("///") else { continue }
            var searchRange = trimmed.startIndex..<trimmed.endIndex
            while let r = trimmed.range(of: "glassEffect(", range: searchRange) {
                n += 1
                searchRange = r.upperBound..<trimmed.endIndex
            }
        }
        return n
    }

    /// 源码里是否出现 `GlassEffectContainer`（容器类型名）。
    static func hasGlassEffectContainer(in text: String) -> Bool {
        text.contains("GlassEffectContainer")
    }

    /// C2：全 app 自定义 glassEffect ≤ 2，且用了就得有容器。
    @Test func customGlassStaysWithinBudgetAndIsContained() throws {
        var scannedFileCount = 0
        var totalGlass = 0
        var containerFound = false
        var perFile: [String: Int] = [:]
        let fm = FileManager.default
        // 力求「扫不到就炸」而不是静默 return（D208：guard-let-else-return 比空转更彻底地假绿）。
        for case let url as URL in fm.enumerator(
            at: sourcesDir, includingPropertiesForKeys: nil)!
        where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            scannedFileCount += 1
            let c = Self.glassEffectCount(in: text)
            if c > 0 { perFile[url.lastPathComponent] = c }
            totalGlass += c
            if Self.hasGlassEffectContainer(in: text) { containerFound = true }
        }

        // D208/D209：自证扫到过东西。当前 ClosetUI 源文件 ~47，取 ~64% 下界
        //（与同目录 DesignSystemLintTests / SpacingGridLintTests 的 30 保持一套）。
        #expect(scannedFileCount >= 30, Comment(rawValue:
            "只扫到 \(scannedFileCount) 个源文件 —— 遍历坏了，这道门在空转"))

        #expect(totalGlass <= 2, Comment(rawValue:
            "自定义 glassEffect 超预算（\(totalGlass) > 2）：\(perFile)"))

        if totalGlass > 0 {
            #expect(containerFound, Comment(rawValue:
                "用了 \(totalGlass) 处 glassEffect 却没有 GlassEffectContainer 包裹：\(perFile)"))
        }
    }

    /// 自测：把一段**已知违规**喂给计数逻辑，证明它当场点名，且不误伤注释 / 相邻 API。
    /// （D160：结构门写完必须撞一次；D172：先确认破坏真的走到了那条路。）
    @Test func theCounterCatchesAKnownViolationWithoutFalsePositives() {
        // 3 处真实 glassEffect(（非注释行）、且无容器 → 会被预算门判红。
        let violating = """
        Image(systemName: "x").glassEffect(.regular, in: Circle())
        Text("y").glassEffect()
        control.glassEffect(.clear)
        """
        #expect(GlassEffectBudgetTests.glassEffectCount(in: violating) == 3)
        #expect(GlassEffectBudgetTests.glassEffectCount(in: violating) > 2)
        #expect(!GlassEffectBudgetTests.hasGlassEffectContainer(in: violating))

        // 注释行里的 glassEffect( 不计（否则连本门的中文说明都会被算进去）。
        let commented = """
        // .glassEffect(.regular, in: Circle())
        /// 见 glassEffect( 的用法说明
        """
        #expect(GlassEffectBudgetTests.glassEffectCount(in: commented) == 0)

        // 相邻 API 不得误伤：glassEffectID( 不是上玻璃，GlassEffectContainer 是容器不是效果。
        let neighbors = """
        view.glassEffectID(1, in: ns)
        GlassEffectContainer(spacing: 12) { child }
        """
        #expect(GlassEffectBudgetTests.glassEffectCount(in: neighbors) == 0)
        #expect(GlassEffectBudgetTests.hasGlassEffectContainer(in: neighbors))

        // 合规形态：2 处玻璃 + 有容器 → 恰好压线通过。
        let compliant = """
        GlassEffectContainer(spacing: 12) {
            filmButton.glassEffect(.regular, in: Circle())
            spinner.glassEffect(.regular, in: Circle())
        }
        """
        #expect(GlassEffectBudgetTests.glassEffectCount(in: compliant) == 2)
        #expect(GlassEffectBudgetTests.hasGlassEffectContainer(in: compliant))
    }
}
