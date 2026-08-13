import Testing
import Foundation
@testable import ClosetUI
import ClosetCore

/// D115 视觉系统门。
///
/// 两条互相独立的病：
/// 1. `DS` 曾是五个硬编码**浅色**值——系统切深色时 Me 页的系统组件变深、
///    其余三个 tab 的自绘底仍是暖骨白，同一个 app 半深半浅。
/// 2. 大量 chip / 描边写 `Color.white.opacity(0.06…0.25)`——那是照深色底写的，
///    而 app 当时只有浅色：**暖骨白上叠 6% 白等于什么都没有**，
///    全 app 用得最多的控件因此没有可见边界。
///
/// 两条都是「写死一套配色」的后果，所以门也只有一条规则：
/// 颜色一律走语义 token，不在视图里硬编码。
@MainActor
struct DesignSystemLintTests {

    private var sourcesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/ClosetUI")
    }

    /// 视图里不得再出现写死的 sRGB 常量（`DesignSystem.swift` 与
    /// 绘制真实图像的渲染器除外——那些是像素，不是主题）。
    @Test func viewsDoNotHardcodeColours() throws {
        let renderers: Set<String> = [
            "DesignSystem.swift",       // token 定义处本身
            "AvatarBackdrop.swift",     // 摄影棚布光，是画面不是主题
            "BodyAvatarView.swift",     // 人体渲染
            "BodyMorphRaster.swift", "FullNudeBodyRaster.swift",
            "DemoGarmentSilhouette.swift", "MatteRetouchView.swift",
            "AvatarCinematicExporter.swift",
            "Mannequin3DView.swift",    // 3D 材质，是渲染不是主题
        ]
        var violations: [String] = []
        let fm = FileManager.default
        for case let url as URL in fm.enumerator(at: sourcesDir, includingPropertiesForKeys: nil)!
        where url.pathExtension == "swift" {
            guard !renderers.contains(url.lastPathComponent) else { continue }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for (i, raw) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let line = String(raw)
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//"), !trimmed.hasPrefix("///") else { continue }
                // 只抓**字面量**：`Color(red: entry.red, …)` 渲染的是用户数据
                //（衣服颜色、肤色），那不是主题色。
                if line.contains("Color(red:"),
                   line.range(of: #"Color\(red:\s*[0-9.]"#, options: .regularExpression) != nil {
                    violations.append("\(url.lastPathComponent):\(i + 1) 硬编码 sRGB")
                }
                if line.contains("Color.white.opacity(") {
                    violations.append("\(url.lastPathComponent):\(i + 1) 白色叠加（浅色底上不可见）")
                }
            }
        }
        #expect(violations.isEmpty, Comment(rawValue:
            "颜色要走 DS 语义 token，两套配色才都成立：\n" + violations.joined(separator: "\n")))
    }

    /// `DS` 必须真的按配色方案取色（而不是又退回常量）。
    @Test func tokensResolvePerColorScheme() throws {
        let text = try String(
            contentsOf: sourcesDir.appendingPathComponent("DesignSystem.swift"), encoding: .utf8)
        #expect(text.contains("Palette.dark"), "DS 没有引用深色那套")
        #expect(text.contains("adaptive("), "DS 的 token 不是按配色方案解析的")
        for token in ["bg", "surface", "ink", "muted", "accent", "onAccent", "hairline"] {
            #expect(text.contains("adaptive(\\.\(token))"),
                    Comment(rawValue: "token \(token) 没接自适应"))
        }
    }

    /// 压在强调色上的字必须用 `DS.onAccent`——深色下强调色提亮后，
    /// 写死 `.white` 会掉到 3:1 以下（`PaletteTests.textOnAccentMeetsAA` 守数值）。
    @Test func textOnAccentUsesTheToken() throws {
        var violations: [String] = []
        let fm = FileManager.default
        for case let url as URL in fm.enumerator(at: sourcesDir, includingPropertiesForKeys: nil)!
        where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            // D137：只认 `foregroundStyle(.white)` 字面量的话，
            // `on ? Color.white : DS.ink` 这种三元式一条都看不见——
            // D115 当时数出的「六处已压」正是漏掉了这五处。
            for (i, line) in lines.enumerated()
            where line.range(of: #"\bColor\.white\b|foregroundStyle\(\.white\)"#,
                             options: .regularExpression) != nil {
                let from = max(0, i - 3)
                let window = lines[from...i].joined(separator: "\n")
                if window.contains("DS.accent") {
                    violations.append("\(url.lastPathComponent):\(i + 1)")
                }
            }
        }
        #expect(violations.isEmpty, Comment(rawValue:
            "白字压在 accent 上，深色下对比度不够：\(violations)"))
    }

    /// 不得强制配色方案——那等于替用户决定，且会让上面这套白做。
    @Test func nothingForcesAColorScheme() throws {
        var violations: [String] = []
        let fm = FileManager.default
        for case let url as URL in fm.enumerator(at: sourcesDir, includingPropertiesForKeys: nil)!
        where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for (i, raw) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
            where String(raw).contains("preferredColorScheme(") {
                violations.append("\(url.lastPathComponent):\(i + 1)")
            }
        }
        #expect(violations.isEmpty, Comment(rawValue: "强制了配色方案：\(violations)"))
    }
}

/// D121：**全 app 没有排版层级**——`caption` + `caption2` 曾占全部字号调用的
/// **83%**（230/276），`headline`（17pt）以上只有 6 处：每一行都在小声说话，
/// 读起来像设置页而不是一个产品。
///
/// DESIGN §462 早就写明审美参照是「高端时尚电商的排版气质
/// （SSENSE 黑白克制、NAP/Sézane 的 serif 编辑感）」，§566 还要求
/// 「serif 标题也须缩放」——规范写了，实现从来没做。
@MainActor
struct TypeScaleLintTests {

    private var sourcesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Sources/ClosetUI")
    }

    private func allSources() -> [(name: String, text: String)] {
        var out: [(String, String)] = []
        let fm = FileManager.default
        for case let url as URL in fm.enumerator(at: sourcesDir, includingPropertiesForKeys: nil)!
        where url.pathExtension == "swift" {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                out.append((url.lastPathComponent, text))
            }
        }
        return out
    }

    /// 字阶必须存在，且**从 Dynamic Type 的文本样式派生**——
    /// `.system(size:)` 固定值不随用户字号缩放，直接违反 §566。
    @Test func theScaleIsBuiltOnDynamicType() throws {
        let ds = try String(
            contentsOf: sourcesDir.appendingPathComponent("DesignSystem.swift"), encoding: .utf8)
        #expect(ds.contains("enum Text"), "没有语义字阶")
        #expect(ds.contains("design: .serif"),
                "标题不是 serif —— DESIGN §462 的编辑感参照没落地")
        // 字阶内部不得出现固定磅值
        guard let range = ds.range(of: "public enum Text") else { return }
        let scale = String(ds[range.lowerBound...].prefix(1200))
        #expect(!scale.contains(".system(size:"),
                "字阶里出现固定磅值 —— Dynamic Type 全档缩放会失效（§566）")
    }

    /// 主视觉标题不得再和列表行一样大。
    @Test func theHeroTitleUsesTheDisplayRole() throws {
        let text = try String(
            contentsOf: sourcesDir.appendingPathComponent("CopilotView.swift"), encoding: .utf8)
        #expect(text.contains("Text(heroTitle)\n                .font(DS.Text.display)"),
                "Today 主视觉标题没有用 display 档")
    }

    /// **设计健康度**：小字占比不得再回到「什么都是 caption」。
    /// 这是个度量而不是风格规则——阈值给得宽，只拦住整体退化。
    @Test func theAppIsNotAllWhispers() {
        // 计数要精确到 token 边界：`.font(.caption` 也会匹配 `.font(.caption2`。
        func count(_ style: String, in text: String) -> Int {
            var n = 0
            var searchRange = text.startIndex..<text.endIndex
            while let r = text.range(of: ".font(.\(style)", range: searchRange) {
                let after = r.upperBound
                let next = after < text.endIndex ? text[after] : " "
                if !next.isNumber && next != "_" { n += 1 }
                searchRange = after..<text.endIndex
            }
            return n
        }
        // 语义档也要算——否则迁移到 `DS.Text.*` 会让分子分母**同时**减少，
        // 比例纹丝不动，这条度量就变成了摆设。
        func countRole(_ role: String, in text: String) -> Int {
            text.components(separatedBy: "DS.Text.\(role)").count - 1
        }
        var small = 0
        var total = 0
        for file in allSources() {
            let rawSmall = count("caption", in: file.text) + count("caption2", in: file.text)
            let roleSmall = countRole("meta", in: file.text) + countRole("micro", in: file.text)
            small += rawSmall + roleSmall
            var rawTotal = 0
            for style in ["largeTitle", "title3", "title2", "title", "headline",
                          "subheadline", "body", "callout", "caption", "caption2"] {
                rawTotal += count(style, in: file.text)
            }
            var roleTotal = roleSmall
            for role in ["display", "sectionTitle", "rowTitle", "body"] {
                roleTotal += countRole(role, in: file.text)
            }
            total += rawTotal + roleTotal
        }
        guard total > 0 else { return }
        let ratio = Double(small) / Double(total)
        #expect(ratio < 0.80, Comment(rawValue:
            "小字占比 \(Int(ratio * 100))% —— 每一行都在小声说话，读起来像设置页"))
    }
}

/// D129：**间距没有尺度**。全 app 实际用的是 2pt 网格，却混着 3 / 9 / 11——
/// 它们不来自任何判断，只是当时手感调出来的。
///
/// 离格值本身不致命，致命的是没有尺度：下一个人照着旁边那行写 13，
/// 再下一个写 7，「拼装感」就是这么一步步攒出来的。
///
/// 这条门**只挡离格**，不规定每一处该用哪一档——
/// 已经在格上的四十处间距刻意不动（盲改我无法目视验证，
/// 只会把不确定摊到全 app）。
@MainActor
struct SpacingGridLintTests {

    private var sourcesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Sources/ClosetUI")
    }

    /// 间距/内距一律落在 2pt 网格上。
    @Test func spacingStaysOnTheGrid() throws {
        var violations: [String] = []
        let patterns = [
            #"\.padding\((?:\.\w+,\s*)?(\d+)\)"#,
            #"spacing:\s*(\d+)"#,
        ]
        let fm = FileManager.default
        for case let url as URL in fm.enumerator(at: sourcesDir, includingPropertiesForKeys: nil)!
        where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            for (i, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//"), !trimmed.hasPrefix("///") else { continue }
                for pattern in patterns {
                    guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                    let ns = line as NSString
                    for match in regex.matches(
                        in: line, range: NSRange(location: 0, length: ns.length)) {
                        let value = Int(ns.substring(with: match.range(at: 1))) ?? 0
                        if value % 2 != 0 {
                            violations.append("\(url.lastPathComponent):\(i + 1) → \(value)")
                        }
                    }
                }
            }
        }
        #expect(violations.isEmpty, Comment(rawValue:
            "间距落在 2pt 网格外——没有尺度，下一个人就会写 13 或 7：\n"
            + violations.joined(separator: "\n")))
    }

    /// 尺度必须存在且各档不同（否则「有尺度」只是句空话）。
    @Test func theScaleIsDeclared() throws {
        let ds = try String(
            contentsOf: sourcesDir.appendingPathComponent("DesignSystem.swift"), encoding: .utf8)
        #expect(ds.contains("enum Space"))
        let steps = Set([DS.Space.xs, DS.Space.s, DS.Space.m, DS.Space.l, DS.Space.xl])
        #expect(steps.count == 5)
        #expect(steps.allSatisfy { $0.truncatingRemainder(dividingBy: 4) == 0 },
                "尺度自己就不在 4pt 步长上")
    }
}
