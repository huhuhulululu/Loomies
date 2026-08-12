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
            for (i, line) in lines.enumerated() where line.contains("foregroundStyle(.white)") {
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
