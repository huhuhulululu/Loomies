# 架构目录（唯一真相）

> 与代码不一致时以代码为准并立即更新本文档。
> 最近同步：2026-08-12 — D104 日间天气/打分权重/导出场合/派生档可达/a11y 单列。四包 **1168 tests**（Core 387 / Model 308 / UI 425 / Intake 48）。D82：photoreal shape 维度 + 资产 QA 门 + 试衣间。D83：属性录入面（温区/颜色/风格属性）。D84：Schema 单向门（VersionedSchema + 指纹 golden + 装配单一入口）。D85：零 UI 入口接线全部完成（删柜/删人、位置树、跨柜检索、合身反馈、手动打卡）。D86：产品外壳合规（出网面披露、遥测 opt-in 门、帮助/FAQ、政策与署名、身体数据同意）。D87：导出包（JSON + 原图 ZIP，后台压缩）。**D88：D83-D87 交付复审的 25 项发现全部关闭**——属性录入接到了真正的新增路径（此前打在零呈现点的 `QuickAddSheet` 上）、删柜判空与单次确认、合身反馈失败不再静默、身体数据同意门真正关上、颜色往返、删除权重置同意位、遥测真接线、位置树删除告知/深度上限/防成环、导出诚实计数与临时目录回收、穿着历史回读（打卡此前只写不读）。新增结构性门：孤儿 View 棘轮、伪造默认值、表现层 `context.delete`、客户文案词汇、遥测事件产出方、出网 host 运行时对账、盘上库升级路径。**D89**：切换器唯一真相（`WardrobeSwitcher` 纯值：排序/同名消歧/active 解析；死 VM 删除，app-shell 平行实现收编）+ 防重复语义定夺（默认硬门，会清空候选时降级为降权并如实告知）+ ViewModel 接线门（D88 只管了 View）。**D90**：冷热偏置接线（`ColdBias` 平移温区，Me → Profile 入口，端到端证据）+ iCloud 备份策略裁决（`ItemImages` 不排除备份，决策钉成可执行断言 + 文案对账）+ 推荐卡存放位置提示（`OutfitStorageHint`）。**D91**：冷启动激活面（`ActivationProgress` 预赋进度 + 场合里程碑按槽位覆盖真实计算，双路径空状态）——清单最后一个 critical 项。**D92**：批量入库（PHPicker 多选 + 逐张懒加载 + `BatchIntakeQueue` 诚实记账，每张仍由用户拍板）。**D93**：护理（`CareSymbol` 结构化，不进推荐打分）+ 备注（`ItemNotes`，不可信输入的长度/控制字符闸）——加法 schema，golden 已重录审 diff。**D94**：转移历史（`TransferRecord` 软 UUID 引用，删柜不抹历史）+ 批量转移（多选网格 → `transferAll`，逐件走同一条服务路径）——新实体同步进删除权与导出。**D95**：三派生缩略图管线（`ItemImageVariant` grid/detail + 原图，ImageIO 生成、落盘复用；孤儿对账与删除全链认账）。**D96**：抠图边缘手修（`MatteRetouch` 笔画式，撤销＝少一笔重渲染；找回从原图取像素）——**缺口清单功能项至此全部清空**。**D97**：补齐 #14 的「场合构成」问题（`OccasionMix`，onboarding 可跳过 → Today 默认过滤 + 里程碑打头；修掉「全休闲衣柜今天空屏」的真 bug），并修正里程碑口径措辞（衣柜完备度 ≠ 今天能穿）。**D98**：24-agent 对抗审计发现**整个激活面在真实首启路径上不可达**（onboarding 自动播 9 件 demo 越过冷启动阈值 8）——去掉自动播种让双路径真成用户的选择，并修掉删库死结、横幅三数打架、demo 死键、场合承诺无兑现路径、onboarding 死字段与假漏斗指标、快选绕过同意门、真实起步文案不符；§206 胶囊模板补拍显式记为延期。**D99**：收口审计尾项（回归门抽 `forToday` 工厂才守得住、里程碑不再替未标场合的件点名、Oxford 列表连接、删恒真死参数、姓名不再当激活闸门）。**D100**：tab 口径裁决（DESIGN 自相矛盾 → 以实现 4 tab 为准 + 双向对账门）+ F2 死码族逐族处置（Sizing/DressCode 删除并留复活条件；`hipFlatWidthInches` 接进下装合身判定，取腰/臀更紧者）——第一轮完整性审计缺口清单全部清空。**D101**：第二轮审计（46 agent）修 6 条 HIGH——onboarding 同意控件缺失致体型选择器永远拒绝、网格与详情合身判定不一致、Today 不跟随切柜、空态甩锅给已放宽的门 + 开发者语言外泄、AppLog 违反自身 PII 规则且 lint 有两个洞、「iCloud 已同步」假声明（正确文案零调用点）。**D102**：收掉剩余 3 条 HIGH——日历静默跨柜回退（且滑删会删别柜的）、一条结构上不可能失败的迁移测试（改为说清边界 + 补实体注册完整性门）、识别是永久 mock 而成功路径零披露。**D103**：删柜残害别柜搭配（数据损坏）、「Plan」隐藏收藏副作用 + 失败留孤儿、入库偷加 casual 架空场合硬门。**D107-D110**：录入质量波——城市改为**标准名选择器**（`CitySearch` + Open-Meteo geocoding，三个入口统一）、尺寸录入 locale 容错（`MeasurementEntry` 按分隔符**位置**判小数点，不按 locale）、场合改多选（打错字不再让衣服永久不被推荐）、缩略图后台解码 + NSCache（`ThumbnailImageCache`）；D110 另修**标准名打断离线气候回退**（表按裸城市名建，取第一段再查）与**切柜后 @State 不跟随**（日历/收藏/存放树留着上一个柜的数据，且删除会真删到那个柜）——门通用化为「持 `let wardrobe` + 缓存 @State 必须跟随切柜」。**D111**（隐私/发布 16-agent 审计）：**用户原始照片旁挂档**（`<stem>@source.jpg` ≤2048px —— 此前只存归一层图，相机拍的原图被永久丢弃，导出承诺的「original photos」兑现不了；删除/对账/导出全链认账）、政策正文按 `hasSink` 实况生成（D105 只修了状态行）、城市搜索纳入出网面披露与运行时对账（打字即发，第一条请求在欢迎屏）、`PolicySite` 从同一份文案生成可托管静态页 + `ReleaseReadiness` 把提审缺口（Privacy/Support URL、客服联系方式）做成可执行清单。**D112**（引擎/性能/数据层 48-agent 审计）：防重复降级判定从单品层移到**搭配层**（按一次「Wore it」就空屏的真 bug）+ 搭配层排序纳入近期穿着降权；`ownerProfile` 三处由渲染路径 fetch 改 `@Query` 内存查找、背景图接 `BodyAvatarImageCache`（含负缓存）；`discardOrphan`/位置 create/demo 播种三处补「rollback 前还原关系」，并加 `RollbackDisciplineLintTests` 类级门。**D113**：测试可信度——25 处 `@Test(.serialized)` 是无操作（移到 `@Suite`）、测试对生产图片根做整目录破坏（收口 + `TestIsolationLintTests`）；缓存一致性——删库接 `removeAll()`、换图后 `@State decoded` 不重置致永久显示旧图（抽 `shouldDropStaleDecoded` 纯函数可测）。**D114**：两条入库路径的场合从单选改为与详情页同一个 `OccasionChips`（拍照建的衣柜此前每件只带一个场合，换场合被硬门筛成零；空集还被显示成「已选 Casual」）；`CalendarPlan.outfit` 无反向关系致悬挂引用 —— 加反向端被 golden 判为破坏性且 TF 已有安装数据，改由 `CalendarPlanService.unbindPlans` 维持 + `PlanUnbindLintTests` 守。**D115**（市场/设计盘点第一波）：**深色模式**——`Palette`（纯值进 Core，对比度可测）+ `DS` 按配色方案解析，新增 `onAccent`/`hairline` token，类别色（槽位/场合）进系统；修掉只在浅色下发作的「白色叠加等于没有边界」；文案红线 `BodyLanguageRedLineTests`（推荐理由「Flatters your body shape」违反 DESIGN §10.4）。**D116**（市场盘点 Wave 0/1）：采纳信号从「翻轮播」移到「真穿了」+ `wear_as_is`（§8.1 判定协议此前量错了）、`TelemetryGate.configure(sink:)` 可注入且无 sink 进提审阻断项、天气未解析显示「—°F」不再伪造 70、Today 加「settled」常驻带（打卡不再被当场抹掉，跨启动回读）、冷启动文案改说人话。**D117**（Wave 2 两个 ★ 差异化）：`OutfitFitMark` 把合身结论端进 Today 建议行与试衣间（此前 `FitMarkService` 在两个决策现场零引用，取最紧那件 + 如实报未实测数 + 全无实测时给入口）；头像加「Make it look like me」叠加式入口（刻意不整块可点，避免吞掉 orbit 手势）。**D118**：**每日回访**（此前全仓 0 处 `UNUserNotificationCenter`，D30 留存证伪线无从谈起）——策略纯函数 `DailyRitual` 进 Core，`DailyRitualScheduler` 排**七条按周重复**（一条每日重复会让星期名变假话）；衣柜凑不出一身不排、文案不点名单品不承诺已选好、授权被拒把开关拨回去、排程点在 Today 而非设置页；通知点击经 `NotificationRouter` 归因（`source`=nudge/organic，读取即清零）。**D119**：`WearStatsService` 把穿着记录回读到详情页（此前写了一年零出口，DEMAND-VALIDATION 的 #1 JTBD）；激活阶梯从「<8 件」延到「<20 件」（8 正是北极星区间起点，此前 8→20 无人引导）+ 跨阈值的一次性毕业卡。**D120**：检索加**色板筛**+「你已经有 N 件」+ 每行「上次穿」——回答 #1 JTBD 的后半句（店里那一刻的检索词是颜色+品类，不是名字；未标颜色不算命中，只给数不给相似度分数）。**D121**：`DS.Text` 六档语义字阶（serif 标题，全部从 Dynamic Type 文本样式派生）——此前 caption/caption2 占全部字号调用 83%、主视觉标题与列表行一样大，而 DESIGN §462/§566 早有规范。

## 项目定位

每日穿搭与衣橱管理 iOS App（min iOS 26，首发美国区）。核心机制 = **copilot**（用户掌舵、App 跑腿，D19）。
设计真相见 `docs/DESIGN.md`，市场见 `docs/MARKET.md`，MVP 计划见 `docs/MVP-PLAN.md`，裁决见 `docs/decisions.md`，交接见 `docs/HANDOFF.md`。

## 代码模块

| 模块 | 路径 | 职责 | 验证 |
|------|------|------|------|
| ClosetCore | `Packages/ClosetCore/` | 引擎 + AppLog + Weather/FitMark/Telemetry + **BodyAvatar + BodyMorph + MannequinSegmentScales / AvatarBodySex / MannequinMeshCatalog（USDZ 名）** | `swift test` |
| ClosetModel | `Packages/ClosetModel/` | SwiftData + BodyProfile 双轨（快选/实测/`presentationSexRaw`）+ ItemStatus/… | `swift test` |
| ClosetUI | `Packages/ClosetUI/` | 全 tab + **BodyAvatarView（2D catalog + 叠衣，产品视觉）+ AvatarBackdrop + Me 精调/性别**。`Mannequin3DView` 是未接线能力探针，不是最终视觉 | `swift test` + build |
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

> **能力探针 / 未接线（D104）**：`Mannequin3DView` 与 USDZ 解析仍在仓里，但产品面 7 处 `usesMannequin3D: false`，且 `NudeBodyBaseSpec.allowsMeshOrSimulationAsFinalVisual == false` 在编译期关掉网格最终视觉。ARCHITECTURE 不得把它写成 live avatar 路径。复活条件：开关打开 + 至少一处产品调用点。

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

### 打磨不变量（Polish wave 2026-08，15 轮收敛（D80）+ 后续 a11y/测试质量/文案/工具链波（D81），655 tests）

- **保存失败原子性**：全部写路径走 `ModelSave`（snapshot → 操作 → 失败 `rollback` + 内存态恢复）；删除-only 失败留 dirty marker、不假装成功；测试中点保存禁止（no mid-operation saves）；测试钩子 `ModelSave.forceFailure` / `ItemImageStore.forceFailure`（图文件删除同样原子 + orphan 清理）。create 失败一律「断关系 + rollback」而非 `context.delete`（delete 只删行，关系幻影与脏标记滞留污染后续 save）——衣柜/Onboarding/QuickAdd/Intake confirm 全对齐 OutfitDraftService 模式。
- **Toast 代际**：自动消失计时器一律持单调 token 判「自己那条还在」，不按消息值判等（同文案连发会被旧计时器提前清）。
- **日志隐私**：AppLog 消息禁止插值用户内容——实体一律 `AppLog.ref(id)`（前 8 位稳定标识）、错误一律 `AppLog.errRef`（domain#code，禁 `\(error)` 全量 dump——NSFilePath 泄露容器路径）、城市/条码只报有无/长度；OSLog 全级别 `.private`（sysdiagnose 兜底脱敏）；LogRing 单条 512 字符截断；诊断包 `WardrobeSummary` 不携带衣柜名/城市（id 前缀 + hasCity）；静态隐私 lint 测试（`appLogCallSitesCarryNoPIIPatterns`）+ 端到端负向断言双锁；debug 面板入口仅 DEBUG 构建可见。
- **脏输入即缺失**：NaN / 0 / 负值在 FitEngine / FFITClassifier / ColorHarmony / WeatherFit / BodyMorph / FFIT 一律按 nil / 中性处理，绝不做「自信兜底」；持久化入口同标准——`ItemEditorService` 拒绝非有限/非正平铺宽、未知风格属性（allowed-set，与 warmthRaw 同款）、越界/非有限 hue，导出 encoder `convertToString` 兜底历史脏 Double。
- **属性录入面（D83）**：温区/颜色/风格属性是推荐三条链（天气硬过滤 / 配色打分 / 体型加权）的**唯一**输入，此前无录入 UI 导致真实衣柜数据上空转（demo seed 掩盖）。`ClosetCore.GarmentAttributeCatalog` 提供人话标题 + `GarmentColorPalette`（16 色板，id 稳定、中性/彩色不串台、`nearest` 回读）；`ItemEditorService.Patch` 加 `attributesRaw` / `colorHue+colorIsNeutral+replaceColor` / `replaceWarmth`（nil 默认「不动」，整表提交才是「清为未知」）；`QuickAddDraft` 把快速添加落库抽成可测值类型——**未选 = 未知（nil）**，禁止替用户假设成 `Warmth.light` / 中性（旧硬编码是冷天必空推荐的根因）。控件 `WarmthPicker` / `ColorSwatchPicker`（44pt 命中区）/ `StyleAttributePicker` 复用于详情与快速添加。
- **UI 诚实**：`lastError` 与 `statusMessage` 互斥（失败清空 success 文案）；异步竞态用 generation counter last-call-wins（Intake process/enrich、Copilot applyWeather）；Intake 空图早退显式复位 `isProcessing`；Intake 分阶段失败文案 + rollback 清 orphan 文件。
- **日界口径**：穿着防重复窗口按日历日算（`WearHistory.recentlyWornItemIDs` 注入 `Calendar`，DST 安全），与 UI 承诺「de-prioritized 7 days」一致，不随打卡钟点漂移。天气「今天」按**衣柜城市时区**取日（geocode 的 IANA `timezone` 字段 → dayString 与请求参数同源；无字段退回设备历 + auto）——设备时区 ≠ 城市时区（出差/双城柜）不再取错日。离线气候表月份保持设备历（粗估 ±数°F，不为月界数小时加时区表——已评估不修）。**CalendarPlan 以 `dayKey`（"yyyy-MM-dd"，加法 schema）为日历日真相**：`date`（本地午夜瞬时值）跨时区会漂到前一天——查询/去重/展示（`displayDate` 本地正午反解）/导出全走 dayKey；空键旧数据退回 date 按设备历解释，覆盖写时顺带固化。
- **关键词折叠**：名称关键词分类（剪影/displaySlot）与搜索一律走 `TextNormalize.foldedKey`（大小写 locale 无关 + 变音符号折叠）；禁用 `localizedCaseInsensitiveContains` 做关键词匹配（tr locale 下 I≠i）；失败文案样式判定（"couldn't"，无 i 字符）不受限。
- **文本判空统一**：可选文本字段（brand/size/位置名/名称）「空白即缺失」一律走 `ClosetCore.TextNormalize`（trim 后判空/转 nil）；实时 TextField 绑定不 trim（输入中），落库口与判定口必 trim；空白名 patch 拒绝（return false）而非静默丢弃。
- **零 UI 入口接线（D85）**：服务层就绪但用户够不着的能力逐项接通——删衣柜/删人（`WardrobeManageActions.DeleteOutcome` 带**类型化** `blockedReason`，View 靠它升级二段确认，不得用 message 字符串相等；确认对话框持**值类型快照** `PendingWardrobeDelete`，绝不在 @State 里持 @Model——删后重求值是未定义行为；force 警告完整告知级联面含 CalendarPlan；当前打开的衣柜不可删；失败着色由返回值驱动而非关键词嗅探）；存放位置树（`listWithDepth` 缩进展示 + 父节点 Picker + `siblingNameConflicts` 提交前诚实报重名——父层判定显式分支，不用 `parent?.children ?? 根层` 的回落，否则子层与根层同名会被误报）。
- **导出包（D87）**：`ExportBundleService` 两段式——`plan` 在 MainActor 读 SwiftData 出值类型计划，`writeBundle` **nonisolated**（几百张图的拷贝+压缩在主线程会冻结 UI 数秒到数分钟，`AvatarCinematicExporter` 已有同类判例）；UI 侧 `Task.detached` + 进行中禁用按钮。Foundation-only 压缩（`NSFileCoordinator .forUploading`，无第三方依赖）；反向孤儿与单张拷贝失败静默跳过（诚实地少一张胜过整包失败）；staging 目录用后即删；分享面板关闭清理临时 zip（与 cinematic MP4 同纪律）。`ShareBox` 支持文本/文件两种载荷，诊断导出路径不受影响。
- **合规诚实（D86）**：**出网面单一真相** `NetworkSurfaceCatalog`——任何新增网络请求必须登记，否则对账测试 `everyOutboundHostIsDisclosed` 变红（比「禁用词黑名单」强得多；旧 About 笼统写「images never leave」，而条码查询确实会把用户扫到的商品条码发往 Open*Facts）。`ComplianceCopy` 是帮助/FAQ/隐私/署名/政策链接的唯一真相（署名按名排序，含许可与用途）。**遥测**：`TelemetryGate` 是唯一发送出口——opt-in 默认关闭、`sanitize` 是 `track` 的内部步骤、sink 协议不暴露原始 payload（绕过白名单在类型层就做不到）；生产无 sink，状态行如实说「Nothing is sent yet」。**身体数据同意** `BodyDataConsent`：门必须在**任何 insert 之前**（insert 之后 return false 会留 pending insert + 关系幻影污染下一次 save），仅围度受门约束、体型快选不设路障。
- **检索作用域（D85 波 C）**：`SearchScope`（本柜/全部）——服务层早支持 `wardrobeID = nil`，UI 此前恒钉当前柜使 §2.3 承诺的全局检索无入口。`effectiveWardrobeID` 由 scope 派生；跨柜结果行**必须**显示所属衣柜（可见文案与 VO 同源，否则同名单品分不清）；跨柜结果的合身标记按**该单品所属柜主人**取身体档案（不能用当前柜主人）；`clear()` 一并复位 scope（清空后不得仍停在跨柜而用户不知情），`clearFiltersKeepingScope()` 保留作用域；每次打开搜索回到本柜（安全默认，与文档描述一致）。
- **打卡语义唯一（D85 波 D）**：Today「Wore it」与手动 `CheckInView` 写的是**同一种** WearRecord，不是两套打卡概念；合身反馈是同一条记录的 update，`CheckInService.setFitFeedback` 是**唯一**写入入口（校验 FitVerdict + 快照回滚），`recordWear` 的宽松签名保留给历史用例但 UI 不再走它——两条 UI 路径共用同一守卫，脏值不会绕过。v1.0 只采集不喂 FitEngine，文案不得暗示会改变推荐，且如实披露会随 Export my data 导出。
- **命名完整性**：衣柜 create/rename 与存放位置同级 create 拒绝重名（大小写/空白不敏感，`WardrobeManageActions.nameConflicts`）；运行时所有 name 排序按 `(name, id.uuidString)` 决胜，与导出快照约定一致——Swift sort 不稳定，同名顺序不得随 fetch 漂移。
- **推荐确定性**：同输入必同输出，不随 SwiftData 关系数组顺序/进程 hash seed 漂移——六三一聚族先按色相排序（置换不变性测试锁）、体型 affinity 按属性 rawValue 排序累加（防权重表引入非整数后浮点结合律绕过 tie-break）、Adapter 保「中性无 hue」语义可达（quick-add 衣柜不得全并列退化为 UUID 序推荐）。组合枚举按 grammar 硬规则拆枝（裙枝/上下装枝分开，N=12 冷天 34 万次迭代 → 2.4 万），grammar 仍是最终裁判；每槽截断前按体型 affinity 预打分（(预分, id) 序——纯 id 前缀截断等于打分前随机抽样，大衣柜最合体型单品可能从未被评估）。程序化裸体栅格走 `FullNudeBodyImageCache`（View body 不得每次重求值全画布重绘）。
- **同槽择优口径**：`OutfitAvatarComposer` 的「有图」= 文件真实存在（`ItemImageStore.fileExists`，stat 不读内容），非路径非空——反向孤儿死路径不得劫持择优。`Int(CGFloat)` 转换一律浮点域先钳非有限值（GeometryReader 首帧 0/∞ → `Int(NaN)` 是运行时陷阱；3 处修复）。
- **图片对账**：`ImageReconcileService`（Today bootstrap 触发）——孤儿文件（无行引用）删文件、死路径（文件消失）清 nil 落库（失败内存还原 + rollback），崩溃窗口/部分失败产生的两类孤儿自愈闭环；文件名即 `{itemID}.{ext}` 使对账 O(n)。
- **叠衣确定性**：`OutfitAvatarComposer` displaySlot hint 排序 + composer 确定性 + zIndex 钉死 + dirty-dress 抑制；`OutfitCompleter.maxOptionsPerSlot` 限每槽候选数。
- **Schema 单向门（D84）**：容器装配唯一入口 `LoomiesStore.makeContainer()`（`LoomiesSchemaV1: VersionedSchema` + `LoomiesMigrationPlan`）——实体清单只此一处，app-shell 不得手搓 `Schema([...])`（有 lint）。两个 `ModelConfiguration` **各带子 schema**（D5 载荷：都传 fullSchema 会让身体数据落主库），`name`（main/local）派生 store 文件名**禁止改名**。破坏性 schema 变更由 `ClosetCore.SchemaFingerprint` + 入库 golden `Fixtures/SchemaFingerprint-v1.txt` 硬拦（旧行消失/版本 bump/golden 畸形皆 destructive；record 模式先差分后写盘，破坏性永不落盘）；加法安全 = 属性 optional **或**有默认且非 unique、关系 optional 且有 inverse。改 app-shell 装配须 `xcodebuild` 真编译验证。
- **数据生命周期**：删除级联 person→profiles、wardrobe→plans+图文件、**deleteItem 随 commit 删本地图**（责任在服务层，调用方重复删幂等）、deleteAll 全走 `ModelSave`；`wipeItemImageDirectory` 全删才算成功，失败经 `DeleteReceipt.imageWipeFailed` 在 summaryLine 诚实提示（CCPA 删除权）；导出确定性（id tie-break 排序）；`Item.barcode` 端到端。
- **cinematic 临时文件**：MP4 生命周期闭环——分享面板 onDismiss 即删、换新前删旧、导出失败清残片（cancelWriting + removeItem）、Today bootstrap 扫尾 `sweepTemporaryExports`；exporter 内置衣物下限守卫（层声明本地照片但全部读不出 → `garmentsUnavailable`，不得静默产出纯裸体底座视频）。
- **跨柜不变量**在所有入口点强制（transfer / draft / search / copilot），非仅服务层。
- **Hero/cinematic**：30fps 解码缓存、yaw 门控、VO 标签、空层门、writer-death 挂起修复、确定性帧 fallback；`AvatarCinematicExporter` **非 MainActor**（48 帧合成 + 编码在协作池跑，主线程不冻结；bundle 探测走线程安全 `BodyAvatarImageCache`）。
- **Photoreal shape 维度**：命名 `photoreal_{sex}_{phenotype}_{shape}_{front|yaw###}`，resolve 链 shape 专属 → 表型 → 通用（D69 防换人守卫不变）；shape 真图命中时 View 旁路 preset warp（`BodyMorphParams.removingShapePreset`，防「真体型 + 拉伸」双重效果）；认证白名单已收 shape token。**资产 QA 门 `PhotorealInventoryQATests`**：矩阵账本（缺格 == 已知待补清单，当前 = eastAsian 13 张锁脸转角）、全库严格 2:3 尺寸、命名合法性——出图落盘必先过此门（任务清单见 BODY-AVATAR-IMAGE-PROMPTS §10）。
- **设备传感器单例**：`SharedDeviceMotion` 是全 App 唯一 `CMMotionManager`（Apple 明文单实例），引用计数启停 + 弱引用自愈；`DepthParallaxMotion` 薄壳幂等 start/stop；View 侧 `onChange(reduceMotion)` 带可见性守卫（离屏视图树不得重启传感器）。
- **位图缓存边界**：`BodyAvatarImageCache` / `BodyMorphImageCache` 走 `NSCache` 按字节 cost 限额（128MB/96MB + countLimit 兜底；条目数限容会让解码位图峰值数百 MB → jetsam），近似 LRU 且内存压力自动清；负缓存语义保留（miss 也存，缺资产不得每 tick 打盘）——morph 缓存补齐 miss 负缓存；bundle probe 表 512 上限（key 域数据驱动防泄漏）；`bundleUIImage/NSImage` 平台原图独立计费缓存（morph render 输入不再每次读盘+全量解码）。
- **a11y**：`.combine` 只圈文本列、CTA 保持独立 VO target（入库拍摄、Closet 空态同规则）；hero orbit `accessibilityAdjustableAction`（`orbitAdjustableStep`）；tap target 下限 `orbitDotHitArea=24` / `lookPagerChevronHitArea=44` / `measureStepperHitArea=44` / `orbitChevronHitArea=44`。Closet 网格与 Body 表型/体型格在 `DynamicTypeSize >= .accessibility1` 收成单列（`AccessibilityGridColumns`）。
- **测试隔离**：`ITEM_IMAGE_ROOT` per-process 临时目录——**全部触盘套件**（Model/Intake/UI 三包共 12+ 套件）init 装 `ItemImageTestRoot.install()`，勿写真机目录（reconcile 类测试在真目录上会误删）；异步测试用 rendezvous 替代 wall-clock sleep。
- **存储目录 fail-closed**：`ItemImageStore` 基目录取不到时不退 tmp（tmp 被系统按存储压力清空 = 全部单品图必然反向孤儿）——`rootDirectory: URL?` 返回 nil → save 诚实失败。

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
