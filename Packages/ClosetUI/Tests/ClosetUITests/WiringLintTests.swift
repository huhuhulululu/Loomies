import Testing
import Foundation
@testable import ClosetUI
import ClosetModel

/// 结构性接线门。来源是一次实证失败：D83 把属性录入控件接进了 `QuickAddSheet`——
/// 一个自 46dc6ff 起零呈现点的死 View——而 commit / decisions.md / ARCHITECTURE.md
/// 都把它写成「已交付」，用户真正点到的「Enter manually」照旧硬编码温区与中性色。
///
/// 本项目的历史病根正是「能力就绪 + 有测试 + 零调用点」。人眼复查抓不住它
/// （每个单点看都对），只能靠门。这三条门扫源码文本，与 AppLog 隐私 lint 同法。
struct WiringLintTests {

    /// Packages/ 与 app-shell/ 下的全部生产源码（不含 Tests）。
    static func productionSources() -> [URL] {
        let packages = URL(fileURLWithPath: #filePath)   // …/ClosetUITests/WiringLintTests.swift
            .deletingLastPathComponent()                 // ClosetUITests
            .deletingLastPathComponent()                 // Tests
            .deletingLastPathComponent()                 // ClosetUI
            .deletingLastPathComponent()                 // Packages
        let appShell = packages.deletingLastPathComponent()
            .appendingPathComponent("app-shell", isDirectory: true)
        var files: [URL] = []
        let fm = FileManager.default
        for root in [packages, appShell] {
            let en = fm.enumerator(at: root, includingPropertiesForKeys: nil)
            while let url = en?.nextObject() as? URL {
                guard url.pathExtension == "swift",
                      url.path.contains("/Sources/") || url.path.contains("/app-shell/"),
                      !url.path.contains("/Tests/"), !url.path.contains("/.build/")
                else { continue }
                files.append(url)
            }
        }
        return files
    }

    /// 每个 View 都必须有呈现点。已知死 View 用**精确集合**锁定（棘轮）：
    /// 新增孤儿 → 红；清理掉某个孤儿而不更新清单 → 也红，逼清单只减不增。
    ///
    /// 清单里这四个是本次交付**之前**就存在的孤儿，属产品决策（3D 人台是否做、
    /// IntakeView 是否替换 AddPieceSheet），不在本波顺手删——但从此被钉住不再增长。
    @Test func everyViewHasACallSiteExceptTheKnownDeadList() throws {
        let knownDead: Set<String> = [
            "BodyMorphStripView",   // 体型调节条：BodyProfileView 走 shape 卡片，未接
            "IntakeView",           // 旧入库面：已被 AddPieceSheet 取代，未删
            "Mannequin3DView",      // 3D 人台：能力探针，未接产品面
            "PlaceholderCroquis",   // 占位人形：真实 croquis 落地后未清理
        ]
        var texts: [URL: String] = [:]
        for url in Self.productionSources() {
            texts[url] = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }
        var declared: [(name: String, file: URL)] = []
        for (url, text) in texts {
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                let s = line.trimmingCharacters(in: .whitespaces)
                guard s.hasPrefix("struct ") || s.hasPrefix("public struct "),
                      s.contains(":"), s.contains("View"), s.hasSuffix("{")
                else { continue }
                // `struct X: View {` / `public struct X: Identifiable, View {`
                let afterStruct = s.replacingOccurrences(of: "public ", with: "")
                    .dropFirst("struct ".count)
                guard let colon = afterStruct.firstIndex(of: ":") else { continue }
                let conformances = afterStruct[afterStruct.index(after: colon)...]
                    .dropLast()  // trailing {
                    .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                guard conformances.contains("View") else { continue }
                let name = afterStruct[..<colon].trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { declared.append((name, url)) }
            }
        }
        #expect(declared.count > 20, "View 扫描器失效（只找到 \(declared.count) 个）")

        var orphans: Set<String> = []
        for (name, declFile) in declared {
            // 调用点：`Name(` 或尾随闭包 `Name {`——两种都算呈现
            var used = false
            for (url, text) in texts {
                for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                    let s = line.trimmingCharacters(in: .whitespaces)
                    if s.hasPrefix("struct \(name)") || s.hasPrefix("public struct \(name)") {
                        continue  // 声明行本身不算调用
                    }
                    guard s.contains(name) else { continue }
                    // app-shell 的 RootView / OnboardingScreen 由 @main 场景挂载，同文件内即算
                    if s.contains("\(name)(") || s.contains("\(name) {") || s.contains("\(name)()") {
                        used = true
                        break
                    }
                }
                if used { break }
                _ = url
            }
            if !used { orphans.insert(name) }
            _ = declFile
        }
        #expect(orphans == knownDead,
                Comment(rawValue: "新孤儿 \(orphans.subtracting(knownDead).sorted())；"
                        + "清单已过期 \(knownDead.subtracting(orphans).sorted())"))
    }

    /// ViewModel 也必须有呈现方。D88 补了 View 的门，但 `WardrobeSwitcherViewModel`
    /// 从这张网底下漏了过去：app-shell 自己写了一套切换 Menu，VM 零调用点——
    /// 于是它的重名守卫、(name, id) 排序、owner 归属校验全部形同虚设，
    /// 连我接进它的 `.wardrobeSwitched` 遥测都发不出来。
    @Test func everyViewModelHasAProductionCallSite() throws {
        var texts: [URL: String] = [:]
        for url in Self.productionSources() {
            texts[url] = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }
        var declared: [(name: String, file: URL)] = []
        for (url, text) in texts {
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                let s = line.trimmingCharacters(in: .whitespaces)
                guard s.hasSuffix("ViewModel {"),
                      s.contains("final class") || s.contains("class ")
                else { continue }
                guard let name = s.split(separator: " ").last(where: { $0.hasSuffix("ViewModel") })
                        .map(String.init) else { continue }
                declared.append((name, url))
            }
        }
        #expect(declared.count >= 8, "VM 扫描器失效（只找到 \(declared.count) 个）")

        var orphans: [String] = []
        for (name, declFile) in declared {
            // 呈现方可以是直接构造 `VM(` ，**也可以是静态工厂** `VM.forToday(` ——
            // 后者同样是真接线（D98 抽工厂后一度被误判为孤儿）。
            // 但静态工厂算数的前提是：VM 自己的文件里确实构造了它。
            let selfConstructs = texts[declFile]?.contains("\(name)(") == true
            let used = texts.contains { url, text in
                guard url != declFile else { return false }   // 自己文件里的初始化不算接线
                if text.contains("\(name)(") { return true }
                guard selfConstructs else { return false }
                // `VM.someFactory(` —— 静态入口
                return text.range(of: "\(name)\\.[A-Za-z_][A-Za-z0-9_]*\\(",
                                  options: .regularExpression) != nil
            }
            // 同文件内的 View 持有它也算（WearHistoryViewModel 与其 View 同文件）
            let selfHosted = texts[declFile]?.contains("State(initialValue: \(name)(") == true
            if !used, !selfHosted { orphans.append(name) }
        }
        #expect(orphans.isEmpty, Comment(rawValue: "零呈现方的 ViewModel：\(orphans.sorted())"))
    }

    /// 入库路径不得**替用户假设**温区与颜色。未选 = 未知（nil），
    /// 冷天硬过滤与配色打分都按未知处理，而不是伪造「薄款 + 中性」。
    @Test func addPathsDoNotFabricateWarmthOrNeutralColor() throws {
        var violations: [String] = []
        for url in Self.productionSources() {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for (n, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let s = line.trimmingCharacters(in: .whitespaces)
                guard !s.hasPrefix("//"), !s.hasPrefix("///") else { continue }
                if s.contains("Warmth.light.rawValue") || s.contains("warmth: .light")
                    || s.contains("colorIsNeutral = true") {
                    violations.append("\(url.lastPathComponent):\(n + 1) ~ \(s)")
                }
            }
        }
        #expect(violations.isEmpty, Comment(rawValue: "\(violations)"))
    }

    /// create 失败一律「断关系 + rollback」。`context.delete` 只删行，
    /// 关系幻影与脏标记会滞留并污染下一次无关 save。
    ///
    /// 扫描面限定在 **UI / Intake 层**：真正的删除功能（DeleteService /
    /// DataLifecycleService / CalendarPlanService）住在 ClosetModel，那里的
    /// `context.delete` 是本职工作；而表现层出现它，只可能是 create 失败的错误善后。
    @Test func createFailurePathsRollbackInsteadOfDelete() throws {
        var violations: [String] = []
        for url in Self.productionSources()
        where url.path.contains("/ClosetUI/") || url.path.contains("/ClosetIntake/")
                || url.path.contains("/app-shell/") {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            for (n, line) in lines.enumerated() where line.contains("context.delete(") {
                let s = line.trimmingCharacters(in: .whitespaces)
                guard !s.hasPrefix("//"), !s.hasPrefix("///") else { continue }
                violations.append("\(url.lastPathComponent):\(n + 1) ~ \(s)")
            }
        }
        #expect(violations.isEmpty, Comment(rawValue: "\(violations)"))
    }
}

/// 面向用户的文案不得再出现「wardrobe」。D85/D86 把词汇统一成 closet 之后
/// 留了两处漂移：Me 的分区标题仍写 "Wardrobes"（其中那一行却叫 "Closets & people"），
/// Transfer 让用户去 "Me → Wardrobes" 找一个已经不存在的标签。
struct CustomerCopyVocabularyTests {

    /// 剥掉字符串插值再判——`\(wardrobe.items)` 是代码，不是给用户看的话。
    static func customerProse(in literal: String) -> String {
        var out = ""
        var depth = 0
        var i = literal.startIndex
        while i < literal.endIndex {
            if literal[i] == "\\", literal.index(after: i) < literal.endIndex,
               literal[literal.index(after: i)] == "(" {
                depth += 1
                i = literal.index(i, offsetBy: 2)
                continue
            }
            if depth > 0 {
                if literal[i] == "(" { depth += 1 }
                if literal[i] == ")" { depth -= 1 }
            } else {
                out.append(literal[i])
            }
            i = literal.index(after: i)
        }
        return out
    }

    @Test func noCustomerFacingStringSaysWardrobe() throws {
        var violations: [String] = []
        for url in WiringLintTests.productionSources()
        where url.path.contains("/ClosetUI/") || url.path.contains("/ClosetIntake/") {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for (n, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let s = line.trimmingCharacters(in: .whitespaces)
                guard !s.hasPrefix("//"), !s.hasPrefix("///"), !s.contains("AppLog.") else { continue }
                var scanning = false
                var literal = ""
                for ch in s {
                    if ch == "\"" {
                        if scanning {
                            let prose = Self.customerProse(in: literal)
                            // 带空格 = 句子（标识符 / 键名 / 日志标签不算）
                            if prose.localizedCaseInsensitiveContains("wardrobe"),
                               prose.contains(" ") {
                                violations.append("\(url.lastPathComponent):\(n + 1) ~ \(prose)")
                            }
                        }
                        scanning.toggle(); literal = ""
                    } else if scanning { literal.append(ch) }
                }
            }
        }
        #expect(violations.isEmpty, Comment(rawValue: "\(violations)"))
    }

    /// 门本身要能抓到真违规（防止上面的剥离逻辑把什么都吃掉 = 空转的门）。
    @Test func theLintItselfCatchesRealProse() {
        #expect(Self.customerProse(in: "No other wardrobes. Create one in Me.")
            .localizedCaseInsensitiveContains("wardrobe"))
        #expect(!Self.customerProse(in: "\\((wardrobe.items ?? []).count) pieces")
            .localizedCaseInsensitiveContains("wardrobe"))
    }
}

/// D100（缺口 #21）：tab 集合是**文档与实现的共同契约**，不得再各说各的。
/// DESIGN §10.2 原文把「入库」列为 tab，同一行又写「tab bar 只做导航不放动作」——
/// 入库是动作不是目的地，那句话本就否定了入库 tab。裁决以实现为准（4 内容 tab），
/// 文档已改；这道门钉住两边不再漂移。
///
/// D212（A2 液态导航）：`AppRootView` 从弃用的 `.tabItem { Label(` 迁到 iOS 26 的
/// `Tab(_:systemImage:)`，搜索改成语义化 `Tab(role: .search)`（系统自动置尾端分离）。
/// 这门也随代码迁移——从 grep `.tabItem` 改成认新 `Tab(` API：
/// **内容 tab 恰好这四个**（Today/Closet/Calendar/Me，C1），外加**恰好一个**搜索角色 tab，
/// 且不得回退到 `.tabItem`。搜索是目的地不是第五个内容 tab、更不是入库 tab。
struct TabSkeletonTests {

    static let expected = ["Today", "Closet", "Calendar", "Me"]

    @Test func appExposesExactlyTheDocumentedTabs() throws {
        let root = WiringLintTests.productionSources().first {
            $0.lastPathComponent == "AppRootView.swift"
        }
        let text = try String(contentsOf: try #require(root), encoding: .utf8)
        // D215：四内容 tab + 恰好一个 search role。只数代码行（注释里的 API 名不算）。
        // 滚动收起钉**调用点**（D214 教训：只断言符号存在，删调用门照绿）。
        var found: [String] = []
        var searchRoles = 0
        var usesDeprecatedTabItem = false
        var callsMinimizeHelper = false
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.hasPrefix("//") else { continue }
            if line.contains(".tabItem") { usesDeprecatedTabItem = true }
            if line.contains(".minimizesTabBarOnScroll()") { callsMinimizeHelper = true }
            if line.hasPrefix("Tab(role: .search)") {
                searchRoles += 1
            } else if line.hasPrefix("Tab(\""), line.contains("systemImage:"),
                      let open = line.range(of: "Tab(\""),
                      let close = line[open.upperBound...].firstIndex(of: "\"") {
                found.append(String(line[open.upperBound..<close]))
            }
        }
        #expect(found == Self.expected, Comment(rawValue: "实际内容 tab：\(found)"))
        #expect(searchRoles == 1,
                Comment(rawValue: "Tab(role: .search) 出现 \(searchRoles) 次，应恰好一次"))
        #expect(found.count + searchRoles <= 5)
        #expect(text.contains("tabBarMinimizeBehavior(.onScrollDown)"),
                "tab bar 不再滚动收起 —— DESIGN §10.2 的照片展示承诺掉了")
        #expect(callsMinimizeHelper,
                "滚动收起的调用点没了 —— extension 还在但没人用它")
        #expect(!usesDeprecatedTabItem,
                "AppRootView 仍在用弃用的 .tabItem API")
    }

    /// 文档必须与实现一致（此前 DESIGN 写五 tab、实现四 tab，两年没人对账）。
    @Test func designDocumentsTheSameTabs() throws {
        let design = WiringLintTests.productionSources().first?
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/DESIGN.md")
        let text = try String(contentsOf: try #require(design), encoding: .utf8)
        let line = try #require(
            text.split(separator: "\n").first { $0.contains("导航骨架：底部 TabView") })
        #expect(line.contains("4 tab"))
        #expect(!line.contains("入库 / 日历"), "入库不再是 tab")
    }
}

/// D101/D110：切柜时 `AppRootView` 只是**换值重新求值**，子视图的结构身份不变——
/// 于是子视图自己的 `@State` **全都不跟随**。
///
/// ⚠️ D101 这条注释原本写着「其余三个 tab 持 `let wardrobe`，天然跟随」——
/// **那个前提是错的**：持 `let wardrobe` 只让**派生读**跟随，视图自己缓存的
/// `@State` 不跟。正因为门里写着这句错话，日历缓存旧柜计划、
/// 滑动删除删掉别柜数据这条（D110）才漏了过去。
///
/// SwiftUI 的身份行为在仓内测不出来（无 ViewInspector），只能钉住写法：
/// 凡是持 `let wardrobe` 且把衣柜派生数据存进 `@State` 的视图，
/// 必须带 `.id(wardrobe.id)` 或 `.onChange(of: wardrobe.id)`。
struct StateBackedTabIdentityTests {

    @Test func todayTabIsRebuiltWhenTheClosetChanges() throws {
        let root = WiringLintTests.productionSources().first {
            $0.lastPathComponent == "AppRootView.swift"
        }
        let text = try String(contentsOf: try #require(root), encoding: .utf8)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let mount = try #require(lines.firstIndex { $0.contains("CopilotView(wardrobe:") })
        // 挂载点之后若干行内必须出现 .id(wardrobe.id)
        let window = lines[mount..<min(mount + 8, lines.count)].joined(separator: "\n")
        #expect(window.contains(".id(wardrobe.id)"),
                "CopilotView 的 VM 是 @State 初值，不带 .id 就不会跟随切柜")
    }

    /// 每个缓存衣柜派生数据的视图都必须跟随切柜（D110 通用化）。
    @Test func everyWardrobeScopedViewFollowsAClosetSwitch() throws {
        var violations: [String] = []
        for url in WiringLintTests.productionSources()
        where url.path.contains("/ClosetUI/") {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            // 把文件按 `struct X: View {` 切块，逐块判断
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            var current: String? = nil
            var block: [String] = []
            func check() {
                guard let name = current else { return }
                let body = block.joined(separator: "\n")
                // 只看：持 let wardrobe + 有 @State 缓存 + 有 reload 式刷新
                guard body.contains("let wardrobe: Wardrobe"),
                      body.contains("@State private var"),
                      body.contains("func reload") else { return }
                let follows = body.contains("onChange(of: wardrobe.id)")
                    || body.contains(".id(wardrobe.id)")
                if !follows {
                    violations.append("\(url.lastPathComponent):\(name)")
                }
            }
            for line in lines {
                let s = line.trimmingCharacters(in: .whitespaces)
                if s.hasPrefix("struct ") || s.hasPrefix("public struct "), s.contains(": View") {
                    check()
                    current = s.split(separator: " ").first { $0.hasSuffix("View") }.map(String.init)
                        ?? s
                    block = []
                } else {
                    block.append(String(line))
                }
            }
            check()
        }
        #expect(violations.isEmpty,
                Comment(rawValue: "缓存了衣柜派生数据却不跟随切柜（会显示并可能删掉别柜数据）：\(violations)"))
    }

    /// 反向锁：VM 若改成从 `let wardrobe` 每次求值（不再是 @State 初值），
    /// 这条门就该被重新审视，而不是留着一个没人懂的 .id。
    @Test func copilotViewStillInitializesItsViewModelInState() throws {
        let view = WiringLintTests.productionSources().first {
            $0.lastPathComponent == "CopilotView.swift"
        }
        let text = try String(contentsOf: try #require(view), encoding: .utf8)
        #expect(text.contains("_vm = State(initialValue:"),
                "若已改为非 @State 持有，请一并重新评估 AppRootView 上的 .id")
    }
}

/// D104: every declared on-disk image size class must be reachable from production.
struct ImageVariantReachabilityTests {
    @Test func itemThumbnailUsesTheSharedSelector() throws {
        let thumb = try #require(WiringLintTests.productionSources().first {
            $0.lastPathComponent == "PhotoCaptureViews.swift"
        })
        let text = try String(contentsOf: thumb, encoding: .utf8)
        #expect(text.contains("ItemImageVariant.forDisplayHeight"),
                "ItemThumbnailView must not re-inline a height cut that can miss .detail")
    }

    @Test func itemDetailFrameRequestsTheDetailDerivative() throws {
        let detail = try #require(WiringLintTests.productionSources().first {
            $0.lastPathComponent == "FeatureViews.swift"
        })
        let text = try String(contentsOf: detail, encoding: .utf8)
        #expect(text.contains("ItemThumbnailView(item: vm.item, height: 200)"),
                "Detail hero is the 200pt frame that must map to .detail")
        #expect(ItemImageVariant.forDisplayHeight(200) == .detail)
    }

    @Test func closetAndFeatureGridsUseTheA11yColumnHelper() throws {
        let closet = try String(
            contentsOf: try #require(WiringLintTests.productionSources().first {
                $0.lastPathComponent == "AppRootView.swift"
            }), encoding: .utf8)
        let feature = try String(
            contentsOf: try #require(WiringLintTests.productionSources().first {
                $0.lastPathComponent == "FeatureViews.swift"
            }), encoding: .utf8)
        #expect(closet.contains("AccessibilityGridColumns.items"))
        #expect(feature.contains("AccessibilityGridColumns.items"))
    }
}

/// D110：城市**每一个写入方**都必须经过辅助输入控件。
/// D107 的 ADR 写「onboarding 与 Me → City 两处都换成了这个控件」——
/// 而 `Wardrobe.locationCity` 其实有**三个**写入方，第三个（Me → Closets & people →
/// Add closet）从没被审，于是那条路径上的城市依旧没有校验、没有标准名。
/// 这条门让第四个写入方不可能悄悄出现。
struct CityEntryWiringTests {

    /// 除 `CityPickerField` 自身外，不得有别处直接给城市文本框绑值。
    @Test func everyCityFieldGoesThroughThePicker() throws {
        var violations: [String] = []
        for url in WiringLintTests.productionSources()
        where url.lastPathComponent != "CityPickerField.swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for (n, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let s = line.trimmingCharacters(in: .whitespaces)
                guard !s.hasPrefix("//"), !s.hasPrefix("///") else { continue }
                guard s.contains("TextField(") else { continue }
                // 标签里提到 city 的文本框 = 城市录入，必须走控件
                let mentionsCity = s.localizedCaseInsensitiveContains("city")
                if mentionsCity {
                    violations.append("\(url.lastPathComponent):\(n + 1) ~ \(s)")
                }
            }
        }
        #expect(violations.isEmpty,
                Comment(rawValue: "绕过城市辅助输入的裸文本框：\(violations)"))
    }

    /// 反向自证：门确实认得出 `CityPickerField` 的存在（不是空转）。
    @Test func thePickerItselfIsPresentAndUsed() throws {
        var callSites = 0
        for url in WiringLintTests.productionSources()
        where url.lastPathComponent != "CityPickerField.swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if text.contains("CityPickerField(") { callSites += 1 }
        }
        // onboarding / Me → City / Me → Add closet
        #expect(callSites >= 3, "城市录入面少于三处——是不是又漏了一个写入方？")
    }
}
