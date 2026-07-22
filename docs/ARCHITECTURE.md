# 架构目录（唯一真相）

> 项目当前处于**设计阶段**（无源码）；本目录随首行代码起按提交同步维护。
> 与代码不一致时以代码为准并立即更新本文档。

## 项目定位

每日穿搭与衣橱管理 iOS App（min iOS 26，首发美国区）。设计真相见 `docs/DESIGN.md`（v0.8），市场分析见 `docs/MARKET.md`，MVP 计划见 `docs/MVP-PLAN.md`，裁决日志见 `docs/decisions.md`，调研报告见 `docs/research/01-16`。

## 代码模块（建设中）

| 模块 | 路径 | 职责 | 验证 |
|------|------|------|------|
| ClosetModel | `Packages/ClosetModel/` | SwiftData 实体层（7 实体 + 身体档案本地域）+ 跨衣柜不变量 + 转移缺件级联 + 删除级联 + ClosetCore 适配层 + RecommendationService（衣柜→copilot 补全）+ CheckInService/WearHistory（打卡→防重复闭环）；CloudKit 兼容约束（optional/默认值/无 unique/关系带 inverse） | `swift test --package-path Packages/ClosetModel`（20 tests，含 RecommendationService 垂直切片 + 穿着打卡防重复闭环，内存 ModelContainer 验证） |
| ClosetCore | `Packages/ClosetCore/` | 纯 Swift 逻辑核心（无 iOS SDK 依赖）：FFIT 体型判定（plus-size 2020，9 类）+ ease 合身引擎 + **F4 推荐流水线**（outfit 语法、候选四条正确性过滤、日间时段天气、温区映射、组套 assembler、色彩规则 60-30-10/色轮、outfit 打分附「为什么推荐」、体型×属性加权、尺码归一化「尺码一等公民」、**copilot 补全器（锚定→补全→打分候选，v0.9 PIVOT 核心机制）**） | `cd Packages/ClosetCore && swift test`（85 tests, TDD RED→GREEN） |

| ClosetUI | `Packages/ClosetUI/` | SwiftUI copilot UI 层：DesignSystem tokens（§10 暖底+单 accent）+ CopilotViewModel/View + IntakeView + **AppRootView（TabView 壳）** + ClosetGridView | `swift test`（4 ViewModel tests）+ `swift build`（视图编译验证）；渲染需模拟器 |

| ClosetIntake | `Packages/ClosetIntake/` | F1 扫描入库（SI-0 capability seam）：抠图/打标/OCR 协议 + mock + IntakeViewModel + **VisionMattingService（真实抠图，编译验证）**；IntakeView（入库确认 UI）在 ClosetUI | `swift test`（4 tests mock + VisionMatting/IntakeView swift build 编译验证）；真机跑真实推理/渲染 |

> App 外壳（`app-shell/`，需 Xcode 组装）：ClosetApp 入口模板（双域 ModelConfiguration，D5 身体维度本地）+ 组装 README。唯一需 Xcode 的薄壳。

> 计划中的完整 SPM 结构见 `MVP-PLAN.md §3`（ClosetModel/ClosetSync/ScanIntake/RulesEngine/AIProxyClient/DesignSystem/Feature/*）。ClosetCore 是 RulesEngine 的纯逻辑先行部分，可命令行验证、无需 Xcode 模拟器。

## 对外链接登记

| 链接 | 用途 | 可见性 |
|------|------|--------|
| https://m424.tailb5f9cb.ts.net:10029/ | 项目状态页 + 审阅制品（status.html / DESIGN.md / MARKET.md / MVP-PLAN.md / DEMAND-VALIDATION.md 副本） | 仅 tailnet（私有，禁止 --public：含任务/进度/决策） |
| https://m424.tailb5f9cb.ts.net:10029/landing/ | 需求验证落地页 **V1（推荐器 hero）** 预览 | 仅 tailnet 预览；上线需接后端+换真实图+换品牌名+公网部署（见 DEMAND-VALIDATION §5）|
| https://m424.tailb5f9cb.ts.net:10029/landing/v2.html | 需求验证落地页 **V2（规划器 hero）** 预览 = A/B 的 B 臂 | 同上 |

> 落地页 canonical 源码在受版控的 `landing/index.html`（V1）与 `landing/v2.html`（V2）；`preview/landing/` 为发布副本。两变体只差 hero/how-it-works/首卡，A/B 隔离「推荐器 vs 规划器」。

> 状态页数据源：`preview/status.json`（commit 后与 Stop 时自动重渲染）+ `preview/agent-state.json`（实时活动）。
> `preview/` 内 DESIGN.md / MARKET.md 为发布副本，源文件在 `docs/`；重大更新后需重新拷贝。

## 文档结构

| 文件 | 职责 |
|------|------|
| `docs/DESIGN.md` | 产品与技术设计（数据模型/功能规格/架构/合规/路线图） |
| `docs/MARKET.md` | 市场与竞品深度分析（四假设判定/定价/增长） |
| `docs/decisions.md` | 裁决日志（只追加） |
| `docs/research/01-16` | 调研报告（含核查状态） |

## 模块详情表

<!-- AUTO-MANAGED:module-table -->
（暂无源码模块；首个 Xcode 工程建立后由 doc-updater 维护）
<!-- /AUTO-MANAGED:module-table -->

## 模块依赖 DAG

<!-- AUTO-MANAGED:dep-dag -->
（暂无）
<!-- /AUTO-MANAGED:dep-dag -->

## API 表

<!-- AUTO-MANAGED:api-table -->
（暂无；AI 代理端点设计定稿后登记）
<!-- /AUTO-MANAGED:api-table -->
