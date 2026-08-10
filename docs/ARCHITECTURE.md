# 架构目录（唯一真相）

> 与代码不一致时以代码为准并立即更新本文档。
> 最近同步：2026-08-10 — 15 轮打磨收敛（D80）+ 后续 a11y/测试质量/文案/工具链波（D81，含正确性波：日历日穿着窗口/天气竞态/Intake 卡死/平铺宽守卫/文本判空统一 TextNormalize），四包 **638 tests**（Core 216 / Model 169 / UI 211 / Intake 42）。

## 项目定位

每日穿搭与衣橱管理 iOS App（min iOS 26，首发美国区）。核心机制 = **copilot**（用户掌舵、App 跑腿，D19）。
设计真相见 `docs/DESIGN.md`，市场见 `docs/MARKET.md`，MVP 计划见 `docs/MVP-PLAN.md`，裁决见 `docs/decisions.md`，交接见 `docs/HANDOFF.md`。

## 代码模块

| 模块 | 路径 | 职责 | 验证 |
|------|------|------|------|
| ClosetCore | `Packages/ClosetCore/` | 引擎 + AppLog + Weather/FitMark/Telemetry + **BodyAvatar + BodyMorph + MannequinSegmentScales / AvatarBodySex / MannequinMeshCatalog（USDZ 名）** | `swift test` |
| ClosetModel | `Packages/ClosetModel/` | SwiftData + BodyProfile 双轨（快选/实测/`presentationSexRaw`）+ ItemStatus/… | `swift test` |
| ClosetUI | `Packages/ClosetUI/` | 全 tab + **BodyAvatarView → Mannequin3DView（USDZ 优先 / 程序化 fallback）+ 2D 叠衣 + AvatarBackdrop + Me 精调/性别** | `swift test` + build |
| ClosetIntake | `Packages/ClosetIntake/` | F1 入库 capability seam：抠图/打标/OCR 协议 + mock + IntakeViewModel + VisionMattingService（编译验证） | `swift test` + Vision swift build |

> App 外壳（`app-shell/`）：**XcodeGen `project.yml` → `ClosetApp.xcodeproj`**，本地 SPM 四包；模拟器 **BUILD SUCCEEDED**（2026-08-03，iPhone 17 Pro / iOS 26.2）。CloudKit 默认 off；Onboarding → AppRoot 4-tab。

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
| https://m424.tailb5f9cb.ts.net:10029/body-avatar/ | **Body Avatar（D68）** 8 表型正面 + 女锁脸 8 角 + 男 8 角 | 仅 tailnet |
| https://m424.tailb5f9cb.ts.net:10029/body-avatar/assets/phenotypes/ | 8×2 表型 catalog 正面 PNG | 仅 tailnet |
| https://m424.tailb5f9cb.ts.net:10029/body-avatar/assets/ | 入库 photoreal 正面/多角 PNG | 仅 tailnet |
| https://m424.tailb5f9cb.ts.net:10029/body-avatar/multi-angle-staging/ | 多角 staging 与 README | 仅 tailnet |
| https://m424.tailb5f9cb.ts.net:10029/body-avatar/pipeline/ | GPT 中间原料 JPG + README | 仅 tailnet |
| https://m424.tailb5f9cb.ts.net:10029/landing/ | 落地页 V1（推荐器 hero） | 仅 tailnet |
| https://m424.tailb5f9cb.ts.net:10029/landing/v2.html | 落地页 V2（规划器 hero） | 仅 tailnet |
| https://m424.tailb5f9cb.ts.net:10029/mockup/ | 产品 UI mockup | 仅 tailnet |
| https://m424.tailb5f9cb.ts.net:10029/mockup/redesign.html | UI 重构 mockup（Dawn/Mist） | 仅 tailnet |

## 文档结构

| 文件 | 职责 |
|------|------|
| `docs/DESIGN.md` | 产品与技术设计 |
| `docs/BODY-AVATAR-USER-FLOW.md` | Body 使用流程（客户路径 / 状态机 / 验收） |
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
| ClosetCore | OutfitCompleter, FitEngine, FFITClassifier, BodyMorphParams, BodyAvatarLayout, MannequinMeshCatalog, WeatherProviding, **OpenMeteo / OpenProductFacts / PublicSizeReference**, FitMarkCopy, TelemetryEvent | 纯逻辑 + 公开 API 客户端（免 key）+ 遥测 |
| ClosetModel | Transfer/Delete/Search/BodyProfile/FitMark/CalendarPlan/OutfitDraft/DemoSeed/Recommendation/CheckIn/**DataLifecycle** | 持久化 + 语义服务 + 导出/删除全部 |
| ClosetUI | BodyAvatarView/Mannequin3DView/AvatarBackdrop/DepthParallax/AvatarCinematicExporter/BodyMorphRaster, CalendarView, MeView, Copilot | 真人照片 catalog basewear 主路径（D63）+ 3D interim fallback + 景深/分享 |
| ClosetModel | … + **GarmentLayerNormalizer**（入库叠衣标准画布）+ **OutfitAvatarComposer**（displaySlot 叠衣） | 叠衣层 PNG 归一 + look→layers |
| ClosetIntake | MattingService, TaggingService, OCRService, IntakeViewModel | 入库能力缝 |
<!-- /AUTO-MANAGED:module-table -->

### 纸娃娃叠衣链路（D40 / D75）

```
Item[] / ScoredOutfit.itemIDs
  → OutfitAvatarComposer.layers  (displaySlot 纠偏 blazer-as-top 等)
  → BodyAvatarComposer.layers    (dress 压 top/bottom；z-order 鞋<裤<衣<外套)
  → BodyAvatarView.garmentLayer  (hasVisual → fullCanvas；侧角 MannequinGarmentVisibility)
```

- Demo seed：slot=`outerwear` + `DemoGarmentSilhouette` 512×768 PNG  
- 入库：`GarmentLayerNormalizer` 同画布（尊重 source-alpha：抠图半成品按 alpha 边界归一，不整画布铺满）；禁止槽位框再套一层（防胸前小贴纸）  
- 空层：Today 英雄区胶囊提示，非静默裸体

### 打磨不变量（Polish wave 2026-08，15 轮收敛（D80）+ 后续 a11y/测试质量/文案/工具链波（D81），638 tests）

- **保存失败原子性**：全部写路径走 `ModelSave`（snapshot → 操作 → 失败 `rollback` + 内存态恢复）；删除-only 失败留 dirty marker、不假装成功；测试中点保存禁止（no mid-operation saves）；测试钩子 `ModelSave.forceFailure` / `ItemImageStore.forceFailure`（图文件删除同样原子 + orphan 清理）。create 失败一律「断关系 + rollback」而非 `context.delete`（delete 只删行，关系幻影与脏标记滞留污染后续 save）——衣柜/Onboarding/QuickAdd/Intake confirm 全对齐 OutfitDraftService 模式。
- **Toast 代际**：自动消失计时器一律持单调 token 判「自己那条还在」，不按消息值判等（同文案连发会被旧计时器提前清）。
- **日志隐私**：AppLog 消息禁止插值用户内容——实体一律 `AppLog.ref(id)`（前 8 位稳定标识）、错误一律 `AppLog.errRef`（domain#code，禁 `\(error)` 全量 dump——NSFilePath 泄露容器路径）、城市/条码只报有无/长度；OSLog 全级别 `.private`（sysdiagnose 兜底脱敏）；LogRing 单条 512 字符截断；诊断包 `WardrobeSummary` 不携带衣柜名/城市（id 前缀 + hasCity）；静态隐私 lint 测试（`appLogCallSitesCarryNoPIIPatterns`）+ 端到端负向断言双锁；debug 面板入口仅 DEBUG 构建可见。
- **脏输入即缺失**：NaN / 0 / 负值在 FitEngine / FFITClassifier / ColorHarmony / WeatherFit / BodyMorph / FFIT 一律按 nil / 中性处理，绝不做「自信兜底」；持久化入口同标准——`ItemEditorService` 拒绝非有限/非正平铺宽，导出 encoder `convertToString` 兜底历史脏 Double。
- **UI 诚实**：`lastError` 与 `statusMessage` 互斥（失败清空 success 文案）；异步竞态用 generation counter last-call-wins（Intake process/enrich、Copilot applyWeather）；Intake 空图早退显式复位 `isProcessing`；Intake 分阶段失败文案 + rollback 清 orphan 文件。
- **日界口径**：穿着防重复窗口按日历日算（`WearHistory.recentlyWornItemIDs` 注入 `Calendar`，DST 安全），与 UI 承诺「de-prioritized 7 days」一致，不随打卡钟点漂移。天气「今天」按**衣柜城市时区**取日（geocode 的 IANA `timezone` 字段 → dayString 与请求参数同源；无字段退回设备历 + auto）——设备时区 ≠ 城市时区（出差/双城柜）不再取错日。离线气候表月份保持设备历（粗估 ±数°F，不为月界数小时加时区表——已评估不修）。**CalendarPlan 以 `dayKey`（"yyyy-MM-dd"，加法 schema）为日历日真相**：`date`（本地午夜瞬时值）跨时区会漂到前一天——查询/去重/展示（`displayDate` 本地正午反解）/导出全走 dayKey；空键旧数据退回 date 按设备历解释，覆盖写时顺带固化。
- **关键词折叠**：名称关键词分类（剪影/displaySlot）与搜索一律走 `TextNormalize.foldedKey`（大小写 locale 无关 + 变音符号折叠）；禁用 `localizedCaseInsensitiveContains` 做关键词匹配（tr locale 下 I≠i）；失败文案样式判定（"couldn't"，无 i 字符）不受限。
- **文本判空统一**：可选文本字段（brand/size/位置名/名称）「空白即缺失」一律走 `ClosetCore.TextNormalize`（trim 后判空/转 nil）；实时 TextField 绑定不 trim（输入中），落库口与判定口必 trim；空白名 patch 拒绝（return false）而非静默丢弃。
- **命名完整性**：衣柜 create/rename 与存放位置同级 create 拒绝重名（大小写/空白不敏感，`WardrobeManageActions.nameConflicts`）；运行时所有 name 排序按 `(name, id.uuidString)` 决胜，与导出快照约定一致——Swift sort 不稳定，同名顺序不得随 fetch 漂移。
- **推荐确定性**：同输入必同输出，不随 SwiftData 关系数组顺序/进程 hash seed 漂移——六三一聚族先按色相排序（置换不变性测试锁）、体型 affinity 按属性 rawValue 排序累加（防权重表引入非整数后浮点结合律绕过 tie-break）、Adapter 保「中性无 hue」语义可达（quick-add 衣柜不得全并列退化为 UUID 序推荐）。
- **叠衣确定性**：`OutfitAvatarComposer` displaySlot hint 排序 + composer 确定性 + zIndex 钉死 + dirty-dress 抑制；`OutfitCompleter.maxOptionsPerSlot` 限每槽候选数。
- **数据生命周期**：删除级联 person→profiles、wardrobe→plans+图文件、**deleteItem 随 commit 删本地图**（责任在服务层，调用方重复删幂等）、deleteAll 全走 `ModelSave`；`wipeItemImageDirectory` 全删才算成功，失败经 `DeleteReceipt.imageWipeFailed` 在 summaryLine 诚实提示（CCPA 删除权）；导出确定性（id tie-break 排序）；`Item.barcode` 端到端。
- **cinematic 临时文件**：MP4 生命周期闭环——分享面板 onDismiss 即删、换新前删旧、导出失败清残片（cancelWriting + removeItem）、Today bootstrap 扫尾 `sweepTemporaryExports`；exporter 内置衣物下限守卫（层声明本地照片但全部读不出 → `garmentsUnavailable`，不得静默产出纯裸体底座视频）。
- **跨柜不变量**在所有入口点强制（transfer / draft / search / copilot），非仅服务层。
- **Hero/cinematic**：30fps 解码缓存、yaw 门控、VO 标签、空层门、writer-death 挂起修复、确定性帧 fallback；`AvatarCinematicExporter` **非 MainActor**（48 帧合成 + 编码在协作池跑，主线程不冻结；bundle 探测走线程安全 `BodyAvatarImageCache`）。
- **设备传感器单例**：`SharedDeviceMotion` 是全 App 唯一 `CMMotionManager`（Apple 明文单实例），引用计数启停 + 弱引用自愈；`DepthParallaxMotion` 薄壳幂等 start/stop；View 侧 `onChange(reduceMotion)` 带可见性守卫（离屏视图树不得重启传感器）。
- **位图缓存边界**：`BodyAvatarImageCache` / `BodyMorphImageCache` 走 `NSCache` 按字节 cost 限额（128MB/96MB + countLimit 兜底；条目数限容会让解码位图峰值数百 MB → jetsam），近似 LRU 且内存压力自动清；负缓存语义保留（miss 也存，缺资产不得每 tick 打盘）——morph 缓存补齐 miss 负缓存；bundle probe 表 512 上限（key 域数据驱动防泄漏）；`bundleUIImage/NSImage` 平台原图独立计费缓存（morph render 输入不再每次读盘+全量解码）。
- **a11y**：`.combine` 只圈文本列、CTA 保持独立 VO target（入库拍摄、Closet 空态同规则）；hero orbit `accessibilityAdjustableAction`（`orbitAdjustableStep`）；tap target 下限 `orbitDotHitArea=24` / `lookPagerChevronHitArea=44` / `measureStepperHitArea=44` / `orbitChevronHitArea=44`。
- **测试隔离**：`ITEM_IMAGE_ROOT` per-process 临时目录（`ItemImageStore.swift:22-26`）；异步测试用 rendezvous 替代 wall-clock sleep。

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
| 外部公开 API | 用途 | 鉴权 | 实现 |
|--------------|------|------|------|
| Open-Meteo Geocoding | 城市 → lat/lon | 无 | `OpenMeteoWeatherProvider` |
| Open-Meteo Forecast | 日间高气温 °F | 无 | 同上；失败 → `CityClimateWeatherProvider` |
| Open Product Facts | 条码 → 品名/品牌 | 无 | `OpenProductFactsClient` |
| Open Beauty Facts | 个护条码回退 | 无 | 同上链式 host |
| Open Food Facts | 末位回退 | 无 | 同上 |
| （表数据）尺码参考桥 | US/EU/UK 提示 | n/a | `PublicSizeReference` |
| WeatherKit | 可选真机增强 | Apple | 未接；可实现 `WeatherProviding` |
<!-- /AUTO-MANAGED:api-table -->
