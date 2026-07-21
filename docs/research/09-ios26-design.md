# 09 — iOS 26 世代原生设计语言（Liquid Glass）与采用要求

> 调研日期：2026-07-21。产品背景：min iOS 26 的数字衣橱 App（美国职业女性 25-45，图片密集、卡片列表、按场合/天气推荐、每日推送）。
> 结论先行：**min iOS 26 意味着 App 天然全量运行在 Liquid Glass 世代，无兼容负担；设计上应把玻璃留给导航/控件层，把全部视觉预算投给衣物内容层（content-first）。**

---

## 1. Liquid Glass 设计语言：核心原则与世代差异

### 1.1 是什么

- 2025-06-09 WWDC25 发布，覆盖 iOS 26 / iPadOS 26 / macOS Tahoe 26 / tvOS 26 / watchOS 26（visionOS 已先行），是 iOS 7（2013 扁平化）以来最大的一次统一设计换代。Alan Dye："combines the optical qualities of glass with a fluidity only Apple can achieve"。（[Apple Newsroom](https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/)）
- 官方定义：一种**动态数字材质（meta-material）**，实时地"弯曲、塑形、汇聚光线"（lensing），结合玻璃光学特性与流体运动感；模糊其后内容、反射周围颜色与光线、对触摸/指针实时反应。（[WWDC25 #219 Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/)，[Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)）

### 1.2 核心原则（与 iOS 7-18 扁平世代的关键差异）

| 维度 | iOS 7-18 扁平世代 | iOS 26 Liquid Glass 世代 |
|------|------------------|--------------------------|
| 层级模型 | 控件与内容基本同层，靠毛玻璃 bar 分区 | **两层制**：内容层（content layer）+ 浮在其上的玻璃功能层（controls/navigation）；玻璃层"floats above content" |
| 材质 | 静态 blur（UIBlurEffect 系） | 动态 lensing：实时折射/反射/高光，随内容明暗自动切换深浅外观 |
| 形状 | 独立圆角，与硬件无关 | **同心圆角（concentricity）**：控件曲率派生自硬件圆角，胶囊/同心矩形嵌套对齐 |
| 运动 | 过渡动画为主 | 材质本身参与交互：控件按压时"充能发光"、按钮 morphing 成菜单/popover、tab bar 滚动收缩 |
| bar 形态 | 全宽、贴边、不透明底 | 悬浮胶囊分组（"context-aware bubbles"），内容从下方透出并滚动可见 |
| 图标 | 单层位图 + 固定圆角 | **分层图标**：系统实时加高光/折射/阴影，6 种外观变体（default/dark/clear×2/tinted×2） |
| 排版 | 常规权重 | 更粗、关键时刻左对齐（alerts/onboarding），强调层级 |

（来源：[WWDC25 #356 Get to know the new design system](https://developer.apple.com/videos/play/wwdc2025/356/)、[HIG Materials](https://developer.apple.com/design/human-interface-guidelines/materials)）

### 1.3 两种玻璃变体（不可混用）

- **regular**：默认，具备全部自适应行为（模糊+亮度调节保证文字可读），绝大多数系统组件用它；文字多的组件（sidebar/alert/popover）必须用它。
- **clear**：高度透明、无自适应，仅用于**媒体富背景之上**（照片/视频上的悬浮控件），且底层内容偏亮时要自行加 ~35% 不透明度的暗色 dimming 层。
- 官方规则："never be mixed"。（[HIG Materials — Liquid Glass](https://developer.apple.com/design/human-interface-guidelines/materials)、WWDC25 #219）

### 1.4 HIG 更新要点与后续演化

- HIG 于 2025-06-09 全面加入 Liquid Glass 指南，2025-09、2025-12 两轮更新措辞（各页 Change log 可查）。
- 舆论侧：发布后可读性批评集中（透明度过高、强光下文字难读）；Apple 在 beta 期间提高了导航栏不透明度，并在 **iOS 26.1（2025-10）加入用户侧 "Liquid Glass → Clear / Tinted" 选项**（Tinted 提高不透明度）；WWDC 2026 宣布 iOS 27 进一步降低默认透明度。**设计含义：不要依赖"玻璃一定透明"，UI 必须在 Clear 与 Tinted 两种用户偏好下都成立。**（[Wikipedia: Liquid Glass](https://en.wikipedia.org/wiki/Liquid_Glass)）

---

## 2. 开发采用路径（SwiftUI）

### 2.1 Xcode 26 重编译行为：自动获得 vs 手工适配

**用 Xcode 26 SDK 重编译即自动获得**（前提：使用标准组件、未硬编码布局/未加自定义背景）：

- NavigationSplitView 侧栏、TabView、toolbar、sheet 的 Liquid Glass 材质
- 控件新外观：按钮默认胶囊形、控件更圆更大、开关/滑杆交互时旋钮变玻璃
- toolbar 自动分组 + 图标单色渲染 + 系统 scroll edge effect（bar 下内容滚动时自动模糊压暗）
- sheet 新圆角、half-sheet 内缩、action sheet 从触发控件弹出
- 列表/表单更大行高与内边距、分节标题改 Title Case（全大写标题会被系统规范化，需检查文案）

（[Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)、[WWDC25 #323 Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/)）

**需要手工适配的部分**：

1. **删除自定义 bar/sheet 背景**——任何自定义背景会覆盖或干扰系统玻璃与 scroll edge effect（官方点名 split view、tab bar、toolbar）。
2. 自定义控件想要玻璃 → `glassEffect` 系列 API（见 2.2）。
3. 自定义悬浮 bar 上有内容滚过 → 手动注册 `scrollEdgeEffectStyle(_:for:)`。
4. 边到边内容体验 → `backgroundExtensionEffect()`（hero 图延伸到 sidebar/inspector 之下，镜像+模糊）。
5. 图标 → Icon Composer 重做分层图标（见 §4）。
6. 逃生舱：Info.plist `UIDesignRequiresCompatibility` 可暂时保持旧外观（临时兼容 key；min iOS 26 新 App 不应使用）。

### 2.2 新 API 清单（SwiftUI）

```swift
// 玻璃效果
.glassEffect()                                   // 默认 regular + Capsule
.glassEffect(in: .rect(cornerRadius: 16))        // 自定形状
.glassEffect(.regular.tint(.orange).interactive()) // 着色 + 触摸响应
GlassEffectContainer(spacing: 40) { ... }        // 多玻璃元素合并渲染/形变（性能必需）
.glassEffectID("id", in: namespace)              // morphing 过渡
.glassEffectUnion(id:namespace:)                 // 多视图并成一颗胶囊
.buttonStyle(.glass) / .buttonStyle(.glassProminent)

// 结构
.tabBarMinimizeBehavior(.onScrollDown)           // tab bar 滚动收缩
.tabViewBottomAccessory { MiniPlayerView() }     // tab bar 附属条（Music MiniPlayer 形态）
Tab(role: .search) { ... }                       // 语义化搜索 tab（自动置尾端分离）
ToolbarSpacer(.fixed / .flexible)                // toolbar 分组
.scrollEdgeEffectStyle(.soft / .hard, for: .top)
.backgroundExtensionEffect()
.searchToolbarBehavior(.minimize)
```

（[Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)、WWDC25 #323）

### 2.3 常见采用错误与 Apple 官方告诫

1. **滥用玻璃**（最高频告诫，HIG 与 Adopting 文档各重复一次）："Avoid overusing Liquid Glass effects…limit these effects to the most important functional elements"——玻璃的存在意义是突出内容，自定义控件到处上玻璃会喧宾夺主。
2. **内容层用玻璃**："Don't use Liquid Glass in the content layer"——内容层用标准材质（ultraThin/thin/regular/thick）做区隔；例外仅为滑杆/开关这类交互瞬时元素。
3. **玻璃叠玻璃**：禁止；玻璃上的元素用填充/透明度/vibrancy，不再套一层材质。
4. **regular 与 clear 混用**：禁止。
5. **全员着色**："when everything is tinted, nothing stands out"——tint 只留给唯一主操作；品牌色放内容层。
6. **保留自定义 bar 背景/边框**：与系统效果冲突，必须清理。
7. **游离的玻璃元素不进 GlassEffectContainer**：渲染性能劣化 + 无法 morphing。
8. **忽视用户设置**：Reduce Transparency / Increase Contrast / Reduce Motion / 26.1 的 Tinted 偏好都会改变玻璃形态，需全配置测试。

（[HIG Materials](https://developer.apple.com/design/human-interface-guidelines/materials)、[Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)、WWDC25 #219）

---

## 3. 导航与结构模式（iOS 26 形态）

### 3.1 Tab bar

- 悬浮于屏幕底部内容之上，玻璃底、内容透出；**只做导航不放动作**。
- 可选 `tabBarMinimizeBehavior` 滚动收缩（下滚缩小、反向滚回弹），配 `tabViewBottomAccessory` 附属条（如常驻迷你播放器位）。
- 支持尾端**独立搜索 tab**（`Tab(role: .search)`，系统自动分离摆放）。
- 色彩告诫：内容层已经鲜艳（衣物照片就是）→ tab bar 倾向**单色外观**，或选对比度足够的 accent 色；避免 tab 标签色与内容背景色相近。
- iPadOS：tab bar 居顶，可 `sidebarAdaptable` 自动转侧栏。
（[HIG Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)）

### 3.2 Search

iOS 三种入口（按 App 形态选）：
1. **搜索 tab**：标准式（落地页承载建议/分类，适合内容探索型）或按钮式（点击直接聚焦键盘，速查型）。
2. **toolbar 内**：底部（优先，够得着）或顶部（底部要让位内容时）。
3. **内容内联**：过滤单一列表时贴着列表放。
点击搜索框时随键盘上滑是系统性约定，需测试一致。（[HIG Search fields](https://developer.apple.com/design/human-interface-guidelines/search-fields)）

### 3.3 Toolbar

- 三个位置组：leading（返回/侧栏钮+标题）、center、trailing（重要动作+搜索+More）；分组≤3，用 `ToolbarSpacer` 分隔。
- 常用动作用无边框 SF Symbols 图标；文字按钮与图标按钮不共容器；主操作用 `.prominent`（着色分离），一屏只一个。
- 溢出由系统管理，勿手工加 More 菜单再嵌一层。
- 每个图标必须有 accessibility label。
（[HIG Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)、WWDC25 #356）

### 3.4 其他结构

- sheet：更大圆角、half-sheet 内缩露出底层内容；勿自加背景视图。
- action sheet 从触发控件锚点弹出（须指定 source）。
- 列表/表单：更高行距、分节圆角与系统曲率同心、Title Case 标题。
- 分屏/侧栏布局用 NavigationSplitView + `backgroundExtensionEffect` 做边到边 hero 图（官方点名"product pages 的 hero image"场景）。

---

## 4. 图标：Icon Composer 与分层图标

- iOS/iPadOS/macOS/watchOS 图标改为**分层制**（背景层 + ≤4 个前景层组），系统实时施加高光/折射/半透明/阴影；提供 default、dark、clear light/dark、tinted light/dark 六种外观（用户可在主屏切换），未提供的变体系统自动生成。
- **Icon Composer**（随 Xcode 26 附带，可独立下载）：导入 SVG（首选，文字转轮廓）/PNG 分层 → 分组、调透明度/高光/折射 → 预览各平台外观 → 产出单一 `.icon` 文件进 Xcode。**该文件会取代原有 AppIcon asset catalog**；若 App 还支持旧系统，Xcode 会自动从它生成旧版图标（min iOS 26 无此顾虑）。
- 设计要点：简化为实心、可叠加的半透明形状；**不要自绘高光/阴影/模糊**（与系统动态效果冲突）；不要预裁圆角（系统统一 mask，1024×1024 方形画布）；主体居中防裁切；dark/tinted 变体保持特征一致。
- 审核注意：备用图标（alternate icons）也必须提供全部暗色/透明/着色变体。
（[HIG App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)、[Creating your app icon using Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)、[Adopting Liquid Glass — App icons](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)）

---

## 5. 内容型 App（图片密集、卡片列表）的具体指导

**Content-first 是整代设计的第一性原理**："Liquid Glass defines a new functional layer in the UI, floating above your content to bring structure and clarity, without ever stealing focus."（WWDC25 #356）

对照本 App（衣物照片网格、搭配卡片、体型可视化）：

1. **内容层零玻璃**：衣物卡片、照片网格、搭配详情都属内容层——用标准材质/纯色分区，绝不 `glassEffect`。玻璃只出现在 tab bar、toolbar、搜索、悬浮主操作。
2. **鲜艳内容 → 单色控件**：HIG Color 明确"app 已有 bright, colorful content（衣物照片正是）→ toolbar/tab bar 用默认单色外观"，品牌色下沉到内容层表达；唯一 accent 留给主 CTA（如"生成今日搭配"）。
3. **媒体上的悬浮控件才考虑 clear 变体**：如全屏查看衣物照片/试穿可视化时的浮层控件，且亮背景需加 dimming。
4. **滚动下的可读性**：照片网格滚过 bar 时靠系统 scroll edge effect 保证对比；自定义悬浮元素必须注册 `scrollEdgeEffectStyle`。彩色内容会从玻璃下透出——检查静止态（页面顶端）不与控件标签色打架。
5. **边到边体验**：搭配详情页 hero 图用 `backgroundExtensionEffect` 延伸至侧栏/inspector 之下（iPad 分屏形态）；横向轮播默认滑入侧栏之下。
6. **层级靠布局不靠装饰**：不给卡片上的按钮加边框底色"配重"；分组、间距、同心圆角表达层级；嵌套卡片圆角用 concentric 让系统自动算内径。
7. **交互元素例外**：内容层里的滑杆/开关（如筛选面板）激活瞬间自动变玻璃，是系统行为，无需干预。

（[HIG Materials](https://developer.apple.com/design/human-interface-guidelines/materials)、[HIG Color — Liquid Glass color](https://developer.apple.com/design/human-interface-guidelines/color)、WWDC25 #356）

---

## 6. 无障碍要求（新设计语言下）

| 设置 | 系统行为（标准组件自动） | App 责任 |
|------|--------------------------|----------|
| Reduce Transparency | 玻璃变"磨砂"（frostier，近不透明） | 自定义玻璃元素/自定义颜色须测试；不得依赖透出内容传达信息 |
| Increase Contrast | 玻璃变黑白为主 + 对比描边 | 自定义色需提供 increased-contrast 变体（light/dark 各一） |
| Reduce Motion | 弹性/形变效果减弱或停用 | 自定义 morphing/弹簧动画要降级为 fade；避免 z 轴深度动画 |
| iOS 26.1 Clear/Tinted 用户偏好 | 全局改变玻璃透明度 | 两种偏好下均需可读 |
| Dynamic Type | 系统字体/文本样式自动缩放 | 用内置 text styles；布局适配至最大无障碍字号（文本可放大 ≥200%）；SF Symbols 随字号缩放；大字号下改纵向堆叠、减列数、少截断 |
| 对比度 | — | WCAG AA：≤17pt 文字 4.5:1，≥18pt 或粗体 3:1；优先系统色（自带自适应变体） |

另：即便 App 只出一种外观，也要提供 light+dark 双色值——玻璃自适应会在明暗间切换取色。每个图标控件必须有 accessibility label（VoiceOver/Voice Control）。
（[HIG Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)、[HIG Typography — Supporting Dynamic Type](https://developer.apple.com/design/human-interface-guidelines/typography)、WWDC25 #219、[Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)）

---

## 7. 每日推送/穿搭日历可用的系统表面（iOS 26 现状）

### 7.1 Widget（WidgetKit）

- iOS 26 起主屏 widget 四种外观：light/dark（全彩）、**clear**（去饱和+玻璃底）、**tinted**（去饱和+用户 tint）；适配靠 `widgetAccentable(_:)` + `WidgetAccentedRenderingMode` 划分 accent/primary 组——**"今日搭配" widget 必须在去色渲染下仍可辨**（衣物照片会被去饱和，需测试）。
- 锁屏 vibrant 模式：灰度+材质，图片资产要按亮度层级重制。
- **WidgetKit push**（iOS 26 新）：`WidgetPushHandler` 允许服务端推送触发 timeline 刷新——适合"每晚生成明日搭配"场景。
- systemSmall 自动上 CarPlay（需检查显示）；watchOS 支持 relevance widgets（`RelevanceConfiguration`，按情境浮到 Smart Stack 顶端）。
（[WidgetKit updates](https://developer.apple.com/documentation/updates/widgetkit)、[HIG Widgets](https://developer.apple.com/design/human-interface-guidelines/widgets)）

### 7.2 Live Activities

- 呈现面：锁屏、灵动岛（compact/minimal/expanded）、StandBy、**Mac 菜单栏、watchOS Smart Stack、CarPlay Dashboard**（后三者为近世代扩展，自动从 compact 组合默认视图，可自定义布局）。
- 设计要求：先设计 iPhone 各 presentation，再按需为 StandBy/CarPlay/Watch 定制；结束即移除（锁屏可留 15-30min 摘要）。
- 对本 App：适用于强时效事件（如"出门前搭配确认""洗衣/取衣提醒"）；每日推荐这类低频静态信息更适合 Widget + 通知，不适合长挂 Live Activity。
（[HIG Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities)）

### 7.3 App Intents（iOS 26 现状）

- **SnippetIntent（iOS 26 新）**：交互式 snippet——Siri/Shortcuts/Spotlight 内直接展示可交互结果卡（如"今天穿什么"返回搭配卡+换一套按钮），不必开 App。
- **IndexedEntity + Spotlight**：衣物/搭配作为 AppEntity 进系统索引，可被系统搜索到。
- **Visual Intelligence 集成（iOS 26）**：`IntentValueQuery` 向系统视觉智能提供 App 实体（衣物识别入口潜力）。
- Interactive widgets 用 Button/Toggle + AppIntent；Controls（控制中心/锁屏/Action button）自 iOS 18 可用。
- 注意：updates 页 "June 2026" 段（LongRunningIntent、UndoableIntent 等）属 **iOS 27 SDK**，min iOS 26 不可直接依赖。
（[App Intents updates](https://developer.apple.com/documentation/updates/appintents)）

---

## 8. 对本 App 的设计决策建议（进设计文档「设计语言 + UX」章）

1. **导航骨架**：底部 TabView（≤5 tab：衣橱 / 搭配 / + 入库 / 日历 / 我的）+ `Tab(role: .search)` 或衣橱页内联搜索；衣橱网格页开 `tabBarMinimizeBehavior(.onScrollDown)` 让照片内容最大化。
2. **视觉预算分配**：衣物摄影 = 品牌。控件层全部交给系统默认玻璃 + 单色图标；全 App 唯一 accent 色只用于主 CTA 与 prominent 按钮。
3. **自定义玻璃仅两处以内**：如悬浮"今日搭配"快捷入口；必须包进 GlassEffectContainer。
4. **图标**：以"衣橱/衣架"级简形状 2-3 层设计，Icon Composer 产出，六变体验收。
5. **无障碍即产品力**（目标人群含通勤强光场景）：Dynamic Type 全档验收、Reduce Transparency/Tinted 偏好双态截图验收纳入 DoD。
6. **系统表面路线**：V1 = 今日搭配 Widget（含 tinted/clear 渲染适配）+ WidgetKit push 每晚刷新；V1.x = SnippetIntent"今天穿什么"+ 衣物 IndexedEntity；Live Activities 仅留给强时效场景。

---

## 来源清单

**Apple 一手**
- Adopting Liquid Glass — https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass
- Liquid Glass overview — https://developer.apple.com/documentation/technologyoverviews/liquid-glass
- Applying Liquid Glass to custom views — https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views
- HIG: Materials / Color / Tab bars / Toolbars / Search fields / App icons / Widgets / Live Activities / Accessibility / Typography — https://developer.apple.com/design/human-interface-guidelines/{materials,color,tab-bars,toolbars,search-fields,app-icons,widgets,live-activities,accessibility,typography}
- Icon Composer — https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer
- WidgetKit updates — https://developer.apple.com/documentation/updates/widgetkit
- App Intents updates — https://developer.apple.com/documentation/updates/appintents
- WWDC25 #219 Meet Liquid Glass — https://developer.apple.com/videos/play/wwdc2025/219/
- WWDC25 #356 Get to know the new design system — https://developer.apple.com/videos/play/wwdc2025/356/
- WWDC25 #323 Build a SwiftUI app with the new design — https://developer.apple.com/videos/play/wwdc2025/323/
- Apple Newsroom（2025-06-09）— https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/

**第三方/演化脉络**
- Wikipedia: Liquid Glass（reception、iOS 26.1 Clear/Tinted、iOS 27 方向）— https://en.wikipedia.org/wiki/Liquid_Glass
