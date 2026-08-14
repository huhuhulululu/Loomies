# Loomies 交接指南（HANDOFF）

> 2026-08-13 全仓盘点（6 路扫描，110 条 → 46 条）。2026-08-14 合入 fleet A1–A8（D215）；A9 遍历账本（D216）。
> 实测 Core 590 / Model 424 / Intake 82 / UI 624（本机 load 下 `AbandonSuperseded` 仍可能超时，D211）。
> TestFlight **build 44** 在 ASC（无 Widget：C1 profile 未装）。读这份文档的你：先读 §1-§4 再动手，§5 起是活。用户动作见 §9。

## 给接手 agent 的开工指引（按此顺序）

1. **先跑一遍 §1 的验证命令**——四包全绿 + xcodebuild 成功是你的基线，任何时候红了先回这里对照。
2. **通读 §2 约束与 §3 坑表**——本仓 90% 的返工都栽在这两张表里的某一条。
3. **选活**：A1–A9 已收口。其余是 B 真机 / C 外部 / P 产品三连（用户包在 §9）。
4. **每波必做的收尾**：`docs/decisions.md` 追加 ADR（编号接续，当前至 D217）；改行为前查 `docs/DOC-SYNC.md`；
   涉及结构就同步 `docs/ARCHITECTURE.md`；HANDOFF 对应行标收口。
5. **别碰的**：B/C/P 组是用户或真机的事，做不了别硬做；D 组动工前先过它标的前置门。
6. **不确定就查 ADR**——每个「为什么这么怪」的问题几乎都有一条 D 编号写着理由。

## 0. 一句话状态

本地 v1.0 功能闭环已完成；A 组本机可做项（CI / 液态导航 / 旧快照 / 胶囊 CTA /
条码扫描 / 分层图标 / App Intent + Widget push 客户端 / 遍历账本）已合进 main（D215/D216）。
剩余工作集中在**四类**：真机/云端才能验的、外部账号/法务/资产阻塞的、
产品决策待裁的、明文延期 v1.x 的。**没有已知的未修 bug。** agent 做不了的见 §9，别硬做。

## 1. 30 秒上手

```bash
# 全量验证（四包必须全绿）
for p in ClosetCore ClosetModel ClosetUI ClosetIntake; do swift test --package-path Packages/$p; done

# app-shell / 任何 #if os(iOS) 改动后必须真编译（swift test 编不到那些块，D92）
xcodebuild -project app-shell/ClosetApp.xcodeproj -scheme ClosetApp -destination 'generic/platform=iOS' build

# TestFlight 上传（仅用户说「发」时；当前 build 44，version 见 project.yml）
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
| 遍历门空转 | 遍历根错 → 「不存在」断言无声全绿 | 宽扫走 `TraversalCensus`（下界跟账本）；窄门 `>= 3`；`> 0` 不够 | D208/D209/D216 |
| labelOCR 与打标是两个能力位 | 合并成一个开关会让披露文案说错话（读的说读的、猜的说猜的） | `recognitionAvailable` 与 `labelOCRAvailable` 保持分立 | D102/D123 |

## 4. 防回归资产（碰它们前必读）

- **~28 道目录遍历型结构门**分布四包 Tests：隐私出网面（`ComplianceCopyTests`：运行时 host 对账 + 话术对账）、身体语言红线、分层（Core import 白名单）、回滚纪律（删除必先解绑）、DS token 四道、调试开关隔离、AM/PM 手拼（`LocaleFormattingLintTests`）、DOC-SYNC 表自守（`DocSyncMapTests`）、Widget 快照 JSON 键白名单等。**新建同类门必须：带自测（喂已知违规）、带遍历自证、写完撞一次真实破坏。**
- **全仓唯一 golden**：`Fixtures/SchemaFingerprint-v1.txt`（schema 指纹，重录命令见 §2.3）。
- **零调用点但刻意保留**的能力（各有书面复活条件，勿当死码删）：`mensChestInchesToAlpha`（等 Item 品类信号）、`Mannequin3DView`（能力探针，USDZ 未采购）。`OutfitCompleter.missingSlots` 的胶囊消费端已接 `CapsuleGapCTA`（D215）。

---

## 5. 待办总览（去重后 46 条，按「谁能做」分组）

### A 组 · agent 立即可做（本机可验证）

| # | 条目 | 规模 | 详单 |
|---|---|---|---|
| A1 | ~~CI 搭建~~ workflow 已备（D213/D215）；剩「建 GitHub repo + push」归用户（C11） | — | §6.1 ✅ |
| A2 | ~~Liquid Glass~~ D215：search tab + hero 玻璃 + 滚动收起（D214 的「三项不适用」被实测推翻） | — | §6.2 ✅ |
| A3 | ~~Widget 旧快照迁移~~ read 时 `pieceNames` → `pieces` | — | §6.3 ✅ |
| A4 | ~~胶囊补拍~~ `CapsuleGapCTA` 可跳过 | — | §6.4 ✅ |
| A5 | ~~条码扫描~~ DataScanner，仍走原归一通路 | — | §6.5 ✅ |
| A6 | ~~分层图标~~ `AppIcon.icon`；旧栅格回退未删 | — | §6.2 ✅ |
| A7 | ~~「今日搭配」快捷卡~~ iOS 26 `AppIntent` | — | §6.6 ✅ |
| A8 | ~~Widget push 客户端半~~ 挂钩已留；服务端仍属 C 组 | — | §6.6 ✅ |
| A9 | ~~遍历门下界自动跟随~~ `TraversalCensus`：floor = recorded×0.6，涨了重录 | — | §6.7 ✅ |
| A10 | ~~E 组文档债 5 条~~（本次盘点已清） | — | E 组 |

### B 组 · 需真机 / 用户配合执行

| # | 条目 | 依赖 |
|---|---|---|
| B1 | `DEVICE-ACCEPTANCE.md` 整册 **48** 项（§0-§7 + §5b；**仅 2 项已验**）——相机入库 10 条 / 补图换图 3 / 跨时间 3 / 合身回流 4 / Widget 9 / 24h 时刻 2 / 渲染手感 13 / 云端 3 + App Group 前置 | 真机 + App Group（C1） |
| B2 | M1「单件入库端到端 <15s」真机计时 | 真机 |
| B3 | M3 §11.4 性能预算：百件 p95≥58fps / 冷启≤2s / 内存≤400MB（Instruments） | 真机 |
| B4 | CloudKit：M0 开发环境同步 → M3 双机竞态 → 隐私审计 CloudKit 部分（entitlements 连 iCloud capability 都未开；两域 `cloudKitDatabase` 均 `.none`） | 真机+云端容器+付费账号 |
| B5 | Vision 真抠图效果、OCR 真推理效果（代码已接，效果需真机看） | 真机 |

### C 组 · 外部 / 用户账号 / 法务 / 资产阻塞

| # | 条目 | 阻塞点 |
|---|---|---|
| C1 | **App Group `group.com.pinglin.closet` 开发者后台注册**（entitlements 整段注释着；profile 名 "Loomies Widget App Store" 硬编码 project.yml）——未注册前 Widget 全线 inert | 开发者后台 |
| C2 | **ReleaseFacts 三件真实世界事实**全 nil。三页已生成（privacy/terms/support）；缺的是**公网托管 + 填 URL + 邮箱** | 用户填 |
| C3 | **ASC 网页端提交材料**：隐私营养标签 / 年龄分级 / 商店截图 / 审核备注 | ASC 网页 |
| C4 | **遥测 sink 接入**（D10 口径：TelemetryDeck 类匿名聚合，无 IDFA）。不接则 MARKET §8 留存三条第 6 周算不出。接入判据：`hasSink` 翻真后全文不得再现「no analytics service」话术（门已在）；**核对 SDK 提供装机标识+时间戳**（D201） | 选型+账号 |
| C5 | **出图资产 93 张**：eastAsian 锁脸转角 13 张（账本 `PhotorealInventoryQATests.knownPending`；落盘后删 `BodyAvatarLayout.swift` eastAsian 豁免）+ shape 正面 80 张（`shapeFrontLedger` 现 0/80；rectangle 16 张可后补）。prompt 手册：`BODY-AVATAR-IMAGE-PROMPTS.md` §10。**落盘必须同步更新账本断言，命名过白名单，严格 2:3** | 出图工具+人审 |
| C6 | ≥100 张人工标注**抠图基准语料** + 评分器（约定在 `docs/MATTING-CORPUS.md`；仓里没有图也没有 scorer，别造假绿） | 人工标注 |
| C7 | 法务确认 ×3：身体数据隐私标签分类口径（Health? 5.1.3 解读）/ Embedding 模型训练数据链（FashionCLIP 停在待评估）/ 扩区逐国合规（现仅 US） | 法务 |
| C8 | 落地页 `FORM_ENDPOINT` 占位未接后端 | 后端选型 |
| C9 | 云端 AI Worker（无状态代理 + App Attest + 配额账本，DESIGN §4.1）完全未建——打标真推理（D 组 D1）的前置 | 云端基建 |
| C10 | 真实人体 USDZ 网格许可/采购（`Mannequin3DView` 降级为探针中） | 采购 |
| C11 | **建 GitHub repo + push**（CI workflow 已备好即刻生效；仓库无 remote，外发代码归用户决策）。push 后看 Actions 第一跑的「Show toolchain」确认 runner 有 Xcode 26，没有则按 ci.yml 头注释换镜像 | 用户 |

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

### 6.1 CI（A1）✅
`.github/workflows/ci.yml`：`macos-26` + 显式 Xcode 26.2（没有就硬失败）；四包 `swift test`（ClosetModel `--no-parallel`）；`xcodegen generate` + 无签名 iOS `xcodebuild`。本机 load 17-38 时性能门仍 skip。
**剩余（C11）**：建 GitHub repo + push。首跑看「Show toolchain」。

### 6.2 Liquid Glass + 分层图标（A2/A6）✅
- Today hero：`backgroundExtensionEffect` + `scrollEdgeEffectStyle`；自定义 `glassEffect` 恰 2 处且在 `GlassEffectContainer`（`GlassEffectBudgetTests` 守）
- 导航：`Tab(_:systemImage:)` ×4 + `Tab(role:.search)` → `SearchTabView`；`#if os(iOS) tabBarMinimizeBehavior(.onScrollDown)`
- 图标：`app-shell/ClosetApp/AppIcon.icon`（骨色/陶土分层 SVG）；旧 `AppIcon.appiconset` 栅格回退未删
**还要人看**：`DEVICE-ACCEPTANCE.md` §6 追加的视觉条。

### 6.3 Widget 旧快照迁移（A3）✅
`TodayWidgetSnapshot.read`：新 JSON 走 `pieces`；无 `pieces` 时试 `pieceNames` 再转（色点全 nil）；垃圾输入仍 nil。encode **不**写回 `pieceNames`。

### 6.4 胶囊模板补拍（A4）✅
`CapsuleGapCTA` 消费 `ActivationProgress.Milestone.missingSlots`，冷启动横幅里出可跳过的槽位级 CTA（点开既有 `AddPieceSheet`）。不取代「真实起步 / Load samples」。

### 6.5 条码扫描（A5）✅
真机：`BarcodeScannerView`（VisionKit `DataScannerViewController`）扫到的字符串进同一条 `normalizeBarcode` → `enrichFromPublicBarcode`。模拟器/macOS：无扫码钮，手输保留；caption 按平台诚实。三个能力开关未合并。**还要人看**：`DEVICE-ACCEPTANCE.md` §1 扫码条。

### 6.6 系统表面（A7/A8）✅ 客户端
`TodayLookIntent` + `AppShortcuts`：只读 `TodayWidgetSnapshotStore`（无快照/过期用既有文案）。Widget 午夜 timeline 仍在；`WidgetPushSupport` 是休眠挂钩，**不声称服务端已接通**（C9）。

### 6.7 遍历账本（A9）✅
`TraversalCensus` + `Fixtures/TraversalCensus.json`。宽扫（原 `>= 80` / `>= 30`）下界 = `max(3, recorded×0.6)`；live 超过账本必须
`LOOMIES_TRAVERSAL_RECORD=1 swift test --package-path Packages/ClosetCore --filter TraversalCensus`。
窄门（`>= 3`）不动。撞门：账本 999、不存在的遍历根，都点名「遍历」（D216）。

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
| `docs/decisions.md` | 217 条 ADR；改任何行为前查关联决策 |
| `docs/DOC-SYNC.md` | **改文件前查 glob → 承诺**（DocSyncMapTests 守着） |
| `docs/DESIGN.md` | 产品真相；⚠️ 标注 = 实现与设计的已知偏差 |
| `docs/MVP-PLAN.md` | 里程碑退出门（✅/❌/⚠️ 标记约定见 D203） |
| `docs/DEVICE-ACCEPTANCE.md` | 真机验收清单（B1） |
| `docs/MARKET.md` §8 | 上线判定协议（预注册，禁改） |
| `docs/BODY-AVATAR-IMAGE-PROMPTS.md` | 出图 prompt 手册（C5） |
| `docs/MATTING-CORPUS.md` | 抠图语料约定（C6；没有图、没有评分器） |
| `.claude-state/requirements.md` | 三轮审计对账台账（历史） |

---

## 9. 用户 30 分钟行动包（agent 做不了，别让它硬做）

下面是**人**要做的。URL / 律师意见 / 出图 / push 都不要让 agent 编。

### 9.1 C1 · App Group（约 10 分钟，开发者后台）

未注册前 **不要** 取消 entitlements 注释——连 Debug 都签不过（D197 实测）。

1. Identifiers → App Groups → 新建 `group.com.pinglin.closet`
2. 新建 App ID `com.pinglin.closet.widget`，勾 App Groups，关联上一步
3. 已有 `com.pinglin.closet` 同样勾上并关联
4. 重发两张 App Store profile：App `Closet App Store TF2`；Widget `Loomies Widget App Store`（`project.yml` 按这个名字写死）
5. **做完 1–4 之后**，取消这两处注释（内容已写好）：
   - `app-shell/ClosetApp/ClosetApp.entitlements`
   - `app-shell/LoomiesWidget/LoomiesWidget.entitlements`
6. `cd app-shell && xcodegen generate` 再归档

完整说明：`app-shell/TESTFLIGHT.md`「App Group」。没做完 Widget 会一直显示 “Open Loomies to get today's look.”

### 9.2 C2 · ReleaseFacts 三件（先有托管再填）

仓里不编造域名。填这三行，`ReleaseReadiness.currentBlockers` 才会放行：

`Packages/ClosetCore/Sources/ClosetCore/PolicySite.swift` → `ReleaseFacts`

| 字段 | 现在 | 填什么 |
|---|---|---|
| `privacyPolicyURL` | `nil` | 托管后的 `preview/landing/privacy.html`（必须 https 绝对地址） |
| `supportURL` | `nil` | 托管后的 `preview/landing/support.html`（https；页已生成，不编造邮箱） |
| `supportContact` | `nil` | 人能回的邮箱或工单；填了之后重录 Support 页 |

三页都从 `ComplianceCopy` 生成：`privacy.html` / `terms.html` / `support.html`。
Support 页在没有收件方时只讲导出诊断，不教「发给某处」（D191/D217）。
托管：`ts-publish.sh` 或任何**公网**静态托管（tailnet :10029 审稿人打不开）。`http://` / `TBD` 过不了 `isUsableHTTPSURL`。

### 9.3 C3 · ASC 营养标签草稿（对照代码，不是法务意见）

出网面只有 `NetworkSurfaceCatalog` 两行。身体数据在独立本地域（D5/D170），照片不出去。

| ASC 项 | 草稿（提交前再对一遍代码） |
|---|---|
| 联系信息 | 城市名（打字搜城市 + 已存衣柜城市）→ Open-Meteo |
| 用户内容 | 扫到的条码 → Open Product/Beauty/Food Facts（标识一件你拥有的商品） |
| 健康与健身 | **不要勾**，除非律师在 9.5 改口。不接 HealthKit；围度只在本机 |
| 照片或视频 | 只在本机 Vision 抠图 / OCR；**不上传** |
| 使用数据 | 现在没 sink（C4）。接上之前不要申报「已采集」 |
| 跟踪 | 无 IDFA、无设备指纹（D10） |
| 年龄分级 | DESIGN 建议 12+，论证要自己写 |
| 截图 | 真机；Today / 衣橱格 / 试衣间 / 入库。别用模拟器液态玻璃当终稿 |
| 审核备注 | 身体数据仅本地；Widget 依赖 App Group（9.1）；条码会出网 |

### 9.4 C5 · 出图账本（93 张，人审，锁脸）

账本：`PhotorealInventoryQATests`。落盘后改断言，命名过白名单，严格 2:3。
prompt：`docs/BODY-AVATAR-IMAGE-PROMPTS.md` §10。**不要用生成器凑一张假身体。**

eastAsian 锁脸转角还缺 13 张（落盘后从 `knownPending` 删掉，并去掉 `BodyAvatarLayout` 的 eastAsian 豁免）：

```
photoreal_female_eastAsian_yaw045
photoreal_female_eastAsian_yaw090
photoreal_female_eastAsian_yaw135
photoreal_female_eastAsian_yaw180
photoreal_female_eastAsian_yaw225
photoreal_female_eastAsian_yaw270
photoreal_female_eastAsian_yaw315
photoreal_male_eastAsian_yaw045
photoreal_male_eastAsian_yaw090
photoreal_male_eastAsian_yaw135
photoreal_male_eastAsian_yaw225
photoreal_male_eastAsian_yaw270
photoreal_male_eastAsian_yaw315
```

shape 正面：`shapeFrontLedger` 现 **0/80**。名字 = `photoreal_{sex}_{phenotype}_{shape}_front`
（与 `BodyAvatarAsset.allPhotorealShapeFrontNames` 同源；`rectangle` 16 张可后补）：

```
photoreal_female_eastAsian_hourglass_front
photoreal_female_eastAsian_pear_front
photoreal_female_eastAsian_apple_front
photoreal_female_eastAsian_rectangle_front
photoreal_female_eastAsian_invertedTriangle_front
photoreal_female_southeastAsian_hourglass_front
photoreal_female_southeastAsian_pear_front
photoreal_female_southeastAsian_apple_front
photoreal_female_southeastAsian_rectangle_front
photoreal_female_southeastAsian_invertedTriangle_front
photoreal_female_southAsian_hourglass_front
photoreal_female_southAsian_pear_front
photoreal_female_southAsian_apple_front
photoreal_female_southAsian_rectangle_front
photoreal_female_southAsian_invertedTriangle_front
photoreal_female_european_hourglass_front
photoreal_female_european_pear_front
photoreal_female_european_apple_front
photoreal_female_european_rectangle_front
photoreal_female_european_invertedTriangle_front
photoreal_female_african_hourglass_front
photoreal_female_african_pear_front
photoreal_female_african_apple_front
photoreal_female_african_rectangle_front
photoreal_female_african_invertedTriangle_front
photoreal_female_latinx_hourglass_front
photoreal_female_latinx_pear_front
photoreal_female_latinx_apple_front
photoreal_female_latinx_rectangle_front
photoreal_female_latinx_invertedTriangle_front
photoreal_female_middleEastern_hourglass_front
photoreal_female_middleEastern_pear_front
photoreal_female_middleEastern_apple_front
photoreal_female_middleEastern_rectangle_front
photoreal_female_middleEastern_invertedTriangle_front
photoreal_female_indigenous_hourglass_front
photoreal_female_indigenous_pear_front
photoreal_female_indigenous_apple_front
photoreal_female_indigenous_rectangle_front
photoreal_female_indigenous_invertedTriangle_front
photoreal_male_eastAsian_hourglass_front
photoreal_male_eastAsian_pear_front
photoreal_male_eastAsian_apple_front
photoreal_male_eastAsian_rectangle_front
photoreal_male_eastAsian_invertedTriangle_front
photoreal_male_southeastAsian_hourglass_front
photoreal_male_southeastAsian_pear_front
photoreal_male_southeastAsian_apple_front
photoreal_male_southeastAsian_rectangle_front
photoreal_male_southeastAsian_invertedTriangle_front
photoreal_male_southAsian_hourglass_front
photoreal_male_southAsian_pear_front
photoreal_male_southAsian_apple_front
photoreal_male_southAsian_rectangle_front
photoreal_male_southAsian_invertedTriangle_front
photoreal_male_european_hourglass_front
photoreal_male_european_pear_front
photoreal_male_european_apple_front
photoreal_male_european_rectangle_front
photoreal_male_european_invertedTriangle_front
photoreal_male_african_hourglass_front
photoreal_male_african_pear_front
photoreal_male_african_apple_front
photoreal_male_african_rectangle_front
photoreal_male_african_invertedTriangle_front
photoreal_male_latinx_hourglass_front
photoreal_male_latinx_pear_front
photoreal_male_latinx_apple_front
photoreal_male_latinx_rectangle_front
photoreal_male_latinx_invertedTriangle_front
photoreal_male_middleEastern_hourglass_front
photoreal_male_middleEastern_pear_front
photoreal_male_middleEastern_apple_front
photoreal_male_middleEastern_rectangle_front
photoreal_male_middleEastern_invertedTriangle_front
photoreal_male_indigenous_hourglass_front
photoreal_male_indigenous_pear_front
photoreal_male_indigenous_apple_front
photoreal_male_indigenous_rectangle_front
photoreal_male_indigenous_invertedTriangle_front
```

### 9.5 C7 · 给律师的三问

工程侧已按「宁可严」做了，但分类口径 freeze 前要书面意见：

1. **身体围度算不算 App Store「健康与健身」？** 我们当尺码语境、不接 HealthKit、不进 CloudKit（防 5.1.3）。DESIGN §5 写「不按 Health 申报」。这个口径能不能提交？
2. **FashionCLIP / Marqo-FashionSigLIP 训练数据链**（Farfetch 等）商用是否干净？权重 MIT/Apache，数据许可未声明。过不了就不要启动 Core ML 转换（D7）。
3. **扩区**：现在只开 US。逐国开之前，GDPR / PIPL 等各要补什么？孩子档案已裁到 v2 + COPPA 同批（D2）。

### 9.6 C11 · 建 GitHub repo（不要让 agent push）

CI 已在 `.github/workflows/ci.yml`。仓库**没有 remote**。外发代码是你的决定。

```bash
# 在你确认可以公开/私有之后自己跑；agent 不跑 push
gh repo create <你的login>/cloth --private --source=. --remote=origin
git push -u origin main
```

首跑看 Actions「Show toolchain」：runner 必须有 Xcode 26，没有就按 `ci.yml` 头注释换镜像。

### 9.7 P1–P3 · 决策简报（你裁，agent 不替你选）

| # | 问题 | 现状锚点 |
|---|---|---|
| P1 | 体型两档「可辨差异 ≥5%」实测最大 3.6%。调大 preset（可能 uncanny）还是改标准？ | D202；`ShapeDistinctnessCriterionTests` 钉着现状；真机才看得出 |
| P2 | `OutfitScorer.reportedTightPenalty = 0.2` / 件。只降权「紧」、不排除。量纲夹在配色 ±0.3 与 60-30-10 的 0.1 之间 | D200；要真实穿着数据回看 |
| P3 | 买断 $9.99 / Plus $34.99 年是 D21 预注册值。R1 轻验证做不做 | D21 / MVP-PLAN P1；IAP 本身是 D 组 D2 |

### 9.8 其余 C，agent 只指到门口

- **C4 遥测 sink**：TelemetryDeck **类**（匿名聚合，无 IDFA）。不要让 agent 锁一家。接上后 `hasSink` 翻真，文案门会查「no analytics service」；sink 必须自己提供装机标识 + 时间戳（D201，App 故意不发）。
- **C6 抠图语料**：约定在 `docs/MATTING-CORPUS.md`。≥100 张人工 mask + 打 `VisionMattingService` 的评分器。没有图就不要先写永远绿的 scorer。
- **C8 / C9 / C10**：落地页后端、云端 AI Worker、USDZ 采购。没选型之前不要开工。
- **B 组**：`docs/DEVICE-ACCEPTANCE.md` 整册。§4 文案已按 D200 改过。
- **D 组**：明文延期。动工前先过那一行标的前置（D1 要 C9，D5 要 C7）。
