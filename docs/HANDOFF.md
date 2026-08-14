# Loomies 交接指南（HANDOFF）

> 2026-08-13 全仓盘点（6 路并行扫描 + 主线合成，110 条原始发现去重为下列条目）。
> **1700 tests 全绿**（Core 580 / Model 424 / UI 614 / Intake 82）+ iOS 真编译；TestFlight **build 43** 在 ASC。
> 读这份文档的你（agent 或人）：先读 §1-§4 再动手，§5 起是活。

## 0. 一句话状态

本地 v1.0 功能闭环已完成，三轮对抗审计（24+46+64 agent）缺口清单全部清空；
剩余工作集中在**四类**：真机/云端才能验的、外部账号/法务/资产阻塞的、
产品决策待裁的、明文延期 v1.x 的。**没有已知的未修 bug。**

## 1. 30 秒上手

```bash
# 全量验证（四包必须全绿）
for p in ClosetCore ClosetModel ClosetUI ClosetIntake; do swift test --package-path Packages/$p; done

# app-shell / 任何 #if os(iOS) 改动后必须真编译（swift test 编不到那些块，D92）
xcodebuild -project app-shell/ClosetApp.xcodeproj -scheme ClosetApp -destination 'generic/platform=iOS' build

# TestFlight 上传（仅用户说「发」时；当前 build 43，version 见 project.yml）
cd app-shell && set -a && . ./.env.asc && set +a && ./scripts/tf-upload-now.sh
```

改代码前：查 `docs/DOC-SYNC.md` 你要改的文件命中哪条 glob → 去复查那条承诺（D206）。

## 2. 不可违反的约束

1. **copilot 原则**（D19）：推荐永远可被用户覆盖，不做全自动决策
2. **依赖方向**：UI → Model → Core；Core 零 iOS SDK（Foundation only）；Widget 只依赖 Core
3. **D84 schema 单向门**：改实体先读 D84；加法式变更 `LOOMIES_SCHEMA_GOLDEN=record swift test --package-path Packages/ClosetModel --filter SchemaGuard` 重录 golden 并审 diff；**TestFlight 已有真实安装数据，破坏性变更不可行**；ModelConfiguration 的 name（main/local）派生 store 文件名，禁止改名
4. **D5 双域**：PersonBodyProfile 在独立本地 ModelConfiguration，永不进 CloudKit、永不出沙盒（分区保证而非开关保证，D170）
5. **遥测白名单**：TelemetryEvents/Payload；install id + timestamp 必须由 sink 侧补，App 故意不发（D201）
6. **身体语言红线**（DESIGN §10.4）：合身语言只评价衣服不评价身体；`BodyLanguageRedLineTests` 守着
7. **UI 诚实铁律**（D130 三值语义族）：不能诚实显示就什么都不显示——温度未知不印 70°F、单色渲染不画色点、认不出的调色板 id 留白、过期快照不冒充今天
8. **锁脸出图纪律**（D69）：body avatar 出图必须走锁脸流程防换人；`PhotorealInventoryQATests` 是资产账本

## 3. 接手必踩的坑（全部实证过）

| 坑 | 症状 | 处置 | 出处 |
|---|---|---|---|
| swift test 编不到 `#if os(iOS)` | macOS 全绿，真机编译爆错（7 个文件含此类块） | 改后必须 xcodebuild | D92 |
| SwiftPM stale cache | 改底层包 struct/init 后依赖包 Undefined symbols / segfault | `rm -rf Packages/<依赖包>/.build` | D200 |
| swift-testing 失败在 **stdout** | 脚本抓 stderr 会把全红判成全绿（一次误判过 12 道门） | 断言输出看 stdout | D209 |
| 名字推断槽位 | 测试夹具不设 `slotUserSet=true` 时 "Navy blazer" 被推断成 outerwear，报 add a top | 夹具显式 `i.slotUserSet = true` | D194/D210 |
| 窄不换行空格 U+202F | 系统时刻格式化 AM/PM 前不是普通空格，字面量断言肉眼一样却失败 | 期望值同源（取自 `DailyRitual.hourLabel`），不手抄 | D211 |
| 性能门本机不跑 | load 长期 17-38（外部进程），三道时间门 `➜ skipped` | 判性能红三步：隔离复跑 → `git worktree` 旧代码**同一时刻**对照 → 看 load。相对基准（比值）实测同样飘 | D211/D185 |
| project.yml 重复 key | 第二个 `dependencies:` 静默覆盖前一个（YAML last-wins） | 改 project.yml 后全文检查重复 key | D197 |
| 撞门三种解释 | 「注入了但门没红」= 门假绿 / 破坏没走到 / **观察通道错了** | 先验破坏落地、再验观察通道、最后判门 | D172/D209 |
| 遍历门空转 | 遍历根错 → 「不存在」断言无声全绿 | 新遍历门必须 `scannedFileCount` 下界自检（贴实际值 60-70%，`> 0` 不够） | D208/D209 |
| labelOCR 与打标是两个能力位 | 合并成一个开关会让披露文案说错话（读的说读的、猜的说猜的） | `recognitionAvailable` 与 `labelOCRAvailable` 保持分立 | D102/D123 |

## 4. 防回归资产（碰它们前必读）

- **~28 道目录遍历型结构门**分布四包 Tests：隐私出网面（`ComplianceCopyTests`：运行时 host 对账 + 话术对账）、身体语言红线、分层（Core import 白名单）、回滚纪律（删除必先解绑）、DS token 四道、调试开关隔离、AM/PM 手拼（`LocaleFormattingLintTests`）、DOC-SYNC 表自守（`DocSyncMapTests`）、Widget 快照 JSON 键白名单等。**新建同类门必须：带自测（喂已知违规）、带遍历自证、写完撞一次真实破坏。**
- **全仓唯一 golden**：`Fixtures/SchemaFingerprint-v1.txt`（schema 指纹，重录命令见 §2.3）。
- **零调用点但刻意保留**的能力（各有书面复活条件，勿当死码删）：`mensChestInchesToAlpha`（等 Item 品类信号）、`Mannequin3DView`（能力探针，USDZ 未采购）、`OutfitCompleter.missingSlots` 的胶囊消费端（§206 延期）。

---

## 5. 待办总览（去重后 46 条，按「谁能做」分组）

### A 组 · agent 立即可做（本机可验证）

| # | 条目 | 规模 | 详单 |
|---|---|---|---|
| A1 | **CI 搭建**（GitHub Actions：四包 swift test + xcodebuild；性能门跑安静 runner） | 中 | §6.1 |
| A2 | Liquid Glass 手工项 ×5（glassEffect ≤2 处 / backgroundExtensionEffect / scrollEdgeEffectStyle / tabBarMinimizeBehavior / Tab(role:.search)） | 中 | §6.2 |
| A3 | Widget 旧快照（pieceNames 版）解码迁移 | 小 | §6.3 |
| A4 | 胶囊模板补拍接线（`missingSlots` 已算好，无人消费；DESIGN §206） | 中 | §6.4 |
| A5 | 条码相机扫描（DataScanner；现只能手输数字） | 中 | §6.5 |
| A6 | Icon Composer 分层图标（六外观变体） | 小-中 | §6.2 |
| A7 | App Intents SnippetIntent「今日搭配」快捷卡 | 中 | §6.6 |
| A8 | WidgetKit 服务端 push 刷新（客户端半；服务端属 C 组） | 中 | §6.6 |
| A9 | 遍历门下界自动跟随（可选优化；D209 明文「另一个真相源它自己也会过期」，谨慎） | 小 | — |
| A10 | ~~E 组文档债 5 条~~（本次盘点已清） | — | E 组 |

### B 组 · 需真机 / 用户配合执行

| # | 条目 | 依赖 |
|---|---|---|
| B1 | `DEVICE-ACCEPTANCE.md` 整册 39 项（§0-§7 + §5b；**仅 2 项已验**）——相机入库 9 条 / 补图换图 3 / 跨时间 3 / 合身回流 3（**§4 期望文案已被 D200 改掉，先修清单再验**，见 E1）/ Widget 全节 / 24h 时刻 / 渲染手感 7 / 云端规模 | 真机 + App Group（C1） |
| B2 | M1「单件入库端到端 <15s」真机计时 | 真机 |
| B3 | M3 §11.4 性能预算：百件 p95≥58fps / 冷启≤2s / 内存≤400MB（Instruments） | 真机 |
| B4 | CloudKit：M0 开发环境同步 → M3 双机竞态 → 隐私审计 CloudKit 部分（entitlements 连 iCloud capability 都未开；两域 `cloudKitDatabase` 均 `.none`） | 真机+云端容器+付费账号 |
| B5 | Vision 真抠图效果、OCR 真推理效果（代码已接，效果需真机看） | 真机 |

### C 组 · 外部 / 用户账号 / 法务 / 资产阻塞

| # | 条目 | 阻塞点 |
|---|---|---|
| C1 | **App Group `group.com.pinglin.closet` 开发者后台注册**（entitlements 整段注释着；profile 名 "Loomies Widget App Store" 硬编码 project.yml）——未注册前 Widget 全线 inert | 开发者后台 |
| C2 | **ReleaseFacts 三件真实世界事实**全 nil（`ReleaseReadiness` 阻断清单非空，提审前必填） | 用户填 |
| C3 | **ASC 网页端提交材料**：隐私营养标签 / 年龄分级 / 商店截图 / 审核备注 | ASC 网页 |
| C4 | **遥测 sink 接入**（D10 口径：TelemetryDeck 类匿名聚合，无 IDFA）。不接则 MARKET §8 留存三条第 6 周算不出。接入判据：`hasSink` 翻真后全文不得再现「no analytics service」话术（门已在）；**核对 SDK 提供装机标识+时间戳**（D201） | 选型+账号 |
| C5 | **出图资产 93 张**：eastAsian 锁脸转角 13 张（账本 `PhotorealInventoryQATests.knownPending`；落盘后删 `BodyAvatarLayout.swift` eastAsian 豁免）+ shape 正面 80 张（`shapeFrontLedger` 现 0/80；rectangle 16 张可后补）。prompt 手册：`BODY-AVATAR-IMAGE-PROMPTS.md` §10。**落盘必须同步更新账本断言，命名过白名单，严格 2:3** | 出图工具+人审 |
| C6 | ≥100 张人工标注**抠图基准语料** + 评分器（M0 交付物；没有它 M1「抠图 ≥90%」永不可判） | 人工标注 |
| C7 | 法务确认 ×3：身体数据隐私标签分类口径（Health? 5.1.3 解读）/ Embedding 模型训练数据链（FashionCLIP 停在待评估）/ 扩区逐国合规（现仅 US） | 法务 |
| C8 | 落地页 `FORM_ENDPOINT` 占位未接后端 | 后端选型 |
| C9 | 云端 AI Worker（无状态代理 + App Attest + 配额账本，DESIGN §4.1）完全未建——打标真推理（D 组 D1）的前置 | 云端基建 |
| C10 | 真实人体 USDZ 网格许可/采购（`Mannequin3DView` 降级为探针中） | 采购 |

### 产品决策待裁（用户三连）

| # | 决策 | 现状锚点 |
|---|---|---|
| P1 | 体型两档「可辨差异 ≥5%」实测最大 3.6%：调大 preset（可能 uncanny，真机才看得出）还是改标准？ | D202；`ShapeDistinctnessCriterionTests` 钉着现状 |
| P2 | 合身反馈降权 `reportedTightPenalty = 0.2/件` 量纲是否合适（介于色彩 ±0.3 与 60-30-10 的 0.1 之间） | D200；需真实穿着数据回看 |
| P3 | 定价数字（买断 $9.99 / Plus $34.99 年为 D21 预注册值）+ R1 需求验证做不做前置轻验证 | D21/MVP-PLAN P1 |

### D 组 · 明文延期（范围决定，非缺陷；动工前先过对应门）

- **D1 · AI 打标真推理**（类型/场合/温区）——v1.x 第一优先（D102）。`IntakeServiceFactory.recognitionAvailable` 恒 false；接上后翻 true，披露文案自动收起。**前置：C9**
- **D2 · IAP/paywall**（买断+Plus，StoreKit 2 绑 originalTransactionID，D6/D16）。买断 CVR 判定线在它之前无数据通路；200 件打标撞墙需补升级出口
- **D3 · 公制切换**（温度+身体维度；引擎温区表/OuterwearCue 阈值全华氏，切换要换算数值。`LocaleFormattingLintTests.temperatureIsStillImperialOnly` 钉着现状，做了它会红提醒改文档）
- **D4 · FFIT 完整 9 类判定**（v1.0 只留最小合身标记，M2 范围决定）
- **D5 · Embedding 语义检索 + LLM 编排层**（v1.x；前置 C7 法务）
- **D6 · 品牌尺码表种子库** Top 50-100（R5 冷启动风险开放）
- **D7 · 统计簇**（cost-per-wear/闲置/季度回顾）+ 差旅打包 + 补记过去日期 + 换季批量移位 + 分享图卡 + WeatherKit（seam 已留，主路径 Open-Meteo）+ EventKit 场合识别
- **D8 · v2 簇**：RoomPlan 衣柜地图 / 双照片 AI 体测 / 生成式试穿 / 孩子档案（**必须随完整 COPPA 同批**，D2）
- **D9 · 侧背叠衣 per-yaw 层图**（结构性缺口，成本极高——每件单品多视角抠图；现状是侧角淡出掩盖。先出产品裁决再动）
- **D10 · M4 发布面**整段（提审检查单对账 / 法务文档托管 / phased release / Beta 招募）——排期未到

### E 组 · 文档债（**本次盘点已全部清掉**，留档备查）

| # | 债 | 处置 |
|---|---|---|
| E1 | `DEVICE-ACCEPTANCE.md` §4 期望文案被 D200 改掉 | ✅ 已改（含新增「降权不排除」验收条） |
| E2 | `FEATURE-GAP.md` Widget 行第二次过期 | ✅ 已更新为已交付+剩余依赖 |
| E3 | `MVP-PLAN.md` §7 待裁决四条中三条已被 D15/D16/D20 裁掉未标 | ✅ 已补对账块 |
| E4 | `.claude-state/progress.md` 留账两条（#01 已被 D194 关、#03 半关） | ✅ 已批注 |
| E5 | 零调用点死码复活条件未集中登记 | ✅ 并入本文件 §4 |

---

## 6. A 组详单

### 6.1 CI（A1，最高优）
无 `.github/workflows`。四包回归 + xcodebuild 全靠本机手跑，且本机 load 长期 17-38 → 三道性能门恒 skip（**性能守护实质悬空**，D211 明文）。
**验收**：push 触发四包 `swift test` + `xcodebuild generic/platform=iOS`；性能门在 CI runner 上真跑（`PerfEnvironment.machineIsQuietEnough` 判 load < 核数半，CI 满足）。
**坑**：macOS runner 需 Xcode 26 SDK（iOS 26.2）；`xcodegen generate` 先行；无签名跑 build 用 `CODE_SIGNING_ALLOWED=NO`。

### 6.2 Liquid Glass 手工项（A2/A6）
DESIGN §10.2 写「手工项集中在四处」，**SDK 26.2 已确认 API 全部存在**（D210 查过）。
- `glassEffect` 全 App ≤2 处、必须包 `GlassEffectContainer`；内容层禁玻璃；regular/clear 不混用
- `backgroundExtensionEffect`：搭配详情 hero 图（Apple 点名 product page 场景）
- `scrollEdgeEffectStyle`：自定义悬浮元素注册
- `tabBarMinimizeBehavior(.onScrollDown)`：衣橱网格页
- `Tab(role:.search)`：现在是老式 `.tabItem`（`AppRootView.swift:18-30`）
**验收**：xcodebuild 过 + 视觉走 `DEVICE-ACCEPTANCE.md` §6 追加条目。**坑**：改 TabView 结构会碰 `WiringLintTests` 的 tab 对账门（D100 双向对账）。

### 6.3 Widget 旧快照迁移（A3）
`TodayWidgetSnapshot` 从 `pieceNames:[String]` 改成 `pieces:[Piece]`（D210），旧 JSON 解码失败按无快照降级（「Open Loomies…」，App 一开重写）。**一次刷新的降级，可接受**；真要迁移：读旧键失败时试老结构再转换。规模小，优先级低。

### 6.4 胶囊模板补拍（A4）
`OutfitCompleter.missingSlots` 已算好缺哪个槽位，无人消费（D98 显式延期，无收口 ADR）。DESIGN §206：冷启动时按缺口引导「先拍一件下装」。
**验收**：冷启动空态出现槽位级引导且可跳过（copilot 原则）；`ActivationProgress` 联动。

### 6.5 条码扫描（A5）
`OpenProductFactsClient` 已接（手输数字通路全绿），相机 DataScanner 未做。
**验收**：扫码填入同一 `normalizeBarcode` 通路；模拟器降级手输；真机验收补条目。

### 6.6 系统表面（A7/A8）
SnippetIntent「今日搭配」交互卡（⚠️ DESIGN 注明 updates 页 June 2026 段属 iOS 27 SDK，min iOS 26 不可依赖——只用 26 可用面）；WidgetKit push 刷新客户端注册可做，服务端触发属 C9 同族基建。

---

## 7. 发布路径（现在离提审差什么，按序）

1. C1 App Group 注册 → Widget 激活
2. B1 真机验收整册（先清 E1）
3. C2 ReleaseFacts 三件 + C3 ASC 材料
4. C4 sink 接入（否则上线了也算不出 §8 判定，D116 已把它列为 ReleaseReadiness 阻断项）
5. P3 定价/验证策略拍板
6. D10 M4 发布面（phased release / Beta 招募 / R1 激活基准）
7. 上线后第 6+10 周按 MARKET §8 预注册口径判 GO/PIVOT/KILL（**禁 HARKing**，变更规则已预注册）

## 8. 文档地图

| 文件 | 读它的时机 |
|---|---|
| `CLAUDE.md` | 每 session 自动加载：约束 + 撞门纪律 |
| `docs/ARCHITECTURE.md` | 定位模块/检修；每次提交同步 |
| `docs/decisions.md` | 211 条 ADR；改任何行为前查关联决策 |
| `docs/DOC-SYNC.md` | **改文件前查 glob → 承诺**（DocSyncMapTests 守着） |
| `docs/DESIGN.md` | 产品真相；⚠️ 标注 = 实现与设计的已知偏差 |
| `docs/MVP-PLAN.md` | 里程碑退出门（✅/❌/⚠️ 标记约定见 D203） |
| `docs/DEVICE-ACCEPTANCE.md` | 真机验收清单（B1） |
| `docs/MARKET.md` §8 | 上线判定协议（预注册，禁改） |
| `docs/BODY-AVATAR-IMAGE-PROMPTS.md` | 出图 prompt 手册（C5） |
| `.claude-state/requirements.md` | 三轮审计对账台账（历史） |
