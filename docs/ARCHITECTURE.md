# 架构目录（唯一真相）

> 与代码不一致时以代码为准并立即更新本文档。
> 最近同步：2026-08-03 — Wave v1.0 CLI Completeness（139 tests）。

## 项目定位

每日穿搭与衣橱管理 iOS App（min iOS 26，首发美国区）。核心机制 = **copilot**（用户掌舵、App 跑腿，D19）。
设计真相见 `docs/DESIGN.md`，市场见 `docs/MARKET.md`，MVP 计划见 `docs/MVP-PLAN.md`，裁决见 `docs/decisions.md`，交接见 `docs/HANDOFF.md`。

## 代码模块

| 模块 | 路径 | 职责 | 验证 |
|------|------|------|------|
| ClosetCore | `Packages/ClosetCore/` | 纯 Swift 逻辑（无 iOS SDK）：FFIT 9 类 + ease 合身 + F4 推荐流水线（语法/过滤/组套/配色/打分/体型加权/尺码归一）+ **copilot 补全器** + **WeatherProviding / FixedWeatherProvider** | `swift test` **87 tests** |
| ClosetModel | `Packages/ClosetModel/` | SwiftData 7 实体 + PersonBodyProfile 本地域 + §2.3 全语义（跨柜不变量/转移缺件/删除级联）+ Adapter + RecommendationService + CheckIn/WearHistory + **SearchService** + **BodyProfileService（R13 门）** + **FitMarkService** + **CalendarPlanService**；Item 加法字段平铺宽 | `swift test` **35 tests**（内存 ModelContainer） |
| ClosetUI | `Packages/ClosetUI/` | DesignSystem（§10）+ CopilotViewModel/View（wear history + bodyShape + weather 注入）+ IntakeView + **OnboardingViewModel** + **CheckInViewModel** + **AppRootView 4-tab 壳**（Today/Closet/Calendar/Me）+ ClosetGridView + Calendar/Me placeholder | `swift test` **13 tests** + `swift build` |
| ClosetIntake | `Packages/ClosetIntake/` | F1 入库 capability seam：抠图/打标/OCR 协议 + mock + IntakeViewModel + VisionMattingService（编译验证） | `swift test` **4 tests** + Vision swift build |

> App 外壳（`app-shell/`，需 Xcode）：ClosetApp 入口模板（双域 ModelConfiguration，D5）+ 组装 README。

> 计划中完整 SPM 结构见 `MVP-PLAN.md §3`。当前 4 包覆盖 RulesEngine 先行部分 + 数据层 + UI 逻辑 + 入库 seam。

## 模块依赖 DAG

```
ClosetUI ──► ClosetModel ──► ClosetCore
   │              ▲
   └─► ClosetIntake ─┘
```

- ClosetCore：零外部 SPM 依赖（Foundation only）
- ClosetModel → ClosetCore
- ClosetIntake → ClosetCore（+ ClosetModel for confirm 落库）
- ClosetUI → ClosetModel + ClosetCore + ClosetIntake

## 核心回路（已闭合、可测）

```
Onboarding → 入库(Intake) → 管理(网格/转移/删除/检索)
                              ↓
                    copilot 补全（天气×场合×体型×防重复）
                              ↓
                    打卡(CheckIn) → WearHistory ──┘
                              ↓
                    日历计划(CalendarPlan) ↔ 缺件 needsAttention
```

## 对外链接登记

| 链接 | 用途 | 可见性 |
|------|------|--------|
| https://m424.tailb5f9cb.ts.net:10029/ | 项目状态页 + 审阅制品 | 仅 tailnet |
| https://m424.tailb5f9cb.ts.net:10029/landing/ | 落地页 V1（推荐器 hero） | 仅 tailnet |
| https://m424.tailb5f9cb.ts.net:10029/landing/v2.html | 落地页 V2（规划器 hero） | 仅 tailnet |
| https://m424.tailb5f9cb.ts.net:10029/mockup/ | 产品 UI mockup | 仅 tailnet |
| https://m424.tailb5f9cb.ts.net:10029/mockup/redesign.html | UI 重构 mockup（Dawn/Mist） | 仅 tailnet |

## 文档结构

| 文件 | 职责 |
|------|------|
| `docs/DESIGN.md` | 产品与技术设计 |
| `docs/MARKET.md` | 市场与竞品 |
| `docs/decisions.md` | 裁决日志（只追加） |
| `docs/HANDOFF.md` | Xcode 接手入口 |
| `docs/MVP-PLAN.md` | 实施计划 |
| `docs/research/*` | 调研报告 |
| `docs/validation-kit/` | R1 真人验证启动包（D20 已跳过，备用） |

## 模块详情表

<!-- AUTO-MANAGED:module-table -->
| 模块 | 关键类型/服务 | 说明 |
|------|--------------|------|
| ClosetCore | OutfitCompleter, CandidateFilter, FitEngine, FFITClassifier, WeatherProviding | 纯逻辑引擎 |
| ClosetModel | TransferService, DeleteService, SearchService, BodyProfileService, FitMarkService, CalendarPlanService, RecommendationService, CheckInService | 持久化 + 语义服务 |
| ClosetUI | CopilotViewModel, OnboardingViewModel, CheckInViewModel, AppRootView | UI 逻辑 + 壳 |
| ClosetIntake | MattingService, TaggingService, OCRService, IntakeViewModel | 入库能力缝 |
<!-- /AUTO-MANAGED:module-table -->

## 模块依赖 DAG

<!-- AUTO-MANAGED:dep-dag -->
```
ClosetCore
  ↑
ClosetModel ← ClosetIntake
  ↑              ↑
  └──── ClosetUI ┘
```
<!-- /AUTO-MANAGED:dep-dag -->

## API 表

<!-- AUTO-MANAGED:api-table -->
（无后端 API；AI 代理 Worker 端点定稿后登记）
<!-- /AUTO-MANAGED:api-table -->
