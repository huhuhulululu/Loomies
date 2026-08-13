# MVP 实施计划（MVP-PLAN.md）

> 版本：v0.1（2026-07-21）
> 依据：冻结的 `docs/DESIGN.md` v0.8 + `docs/MARKET.md` v1.0；6 子系统并行 build plan + 技术负责人综合 + critic 审查（**verdict: REJECT**，1 critical + 5 major——已在本文逐条应用/上升，见 §6）
> 状态：**规划稿**。§7 有 3 项需用户裁决才能定盘工期与范围。

---

## 0. 一句话

把冻结设计拆成 6 个可并行的 SPM package，用「fixture-first StoreProtocol」作解耦缝，5 个里程碑（M0-M4）交付 v1.0；**核心不确定性不在写代码，在端侧 ML 真机方差、CloudKit 生产 schema 单向门、以及需求侧仍未验证（R1）**。

## 1. 工期：诚实口径（critic 揪出的第一个问题）

规划 brief 的估算单位是**「1 名资深 iOS 工程师 + AI 辅助」**。按此单位诚实汇报：

| 口径 | 工期 | 说明 |
|------|------|------|
| **单人 + AI（brief 口径，主数字）** | **~228 person-day ≈ 10-11 个月** | 6 子系统 sizeDays 求和 27+52+36+47+26+40.5，扣除并行收益有限（单人无法并行）|
| 3 iOS + 0.5 后端 + 共享 QA（团队情景） | ~16-20 周墙钟（4-5 个月） | M1 生死线需 2 人拆流（抠图图形交互 vs OCR/打标/编排），否则拉到 24-26 周 |

> ⚠️ critic 原文：headline「16-20 周」**悄悄把估算单位从 1 人换成了 3-4 人**。真实决策依赖你的团队规模——这是 §7 待裁决项 P0。置信度 **medium-low**，不确定性全部来自下列 low 项，非乐观拍脑袋。

**低置信度来源（全部需真机/生产实测才能收敛）**：
- 端侧抠图真机方差：`VNGenerateForegroundInstanceMaskRequest` 对白/浅色/花纹衣物 + 杂乱背景易失手，≥90% 仅受控拍摄成立
- SAM2 Core ML 自集成：体积挤 ≤200MB 包体、ANE/量化时延、Background Assets 分发均未实测（已列砍项候选）
- CloudKit 生产 schema 不可回滚 + 双机最终一致性竞态复现
- 自托管真机流水线可靠性；WeatherKit / StoreKit 2 / App Attest 三个外部依赖各自的账号与验签门
- iOS 26 `RecognizeDocumentsRequest` 为新 API，护理「符号」是图形非文本，OCR 结构化抽取不可过度承诺

## 2. 里程碑（退出门已按 critic 硬化为可证伪）

> **标记约定（D203）**：每条退出门后面必须跟 ✅ **已过** / ❌ **未做** / ⚠️ **部分**，
> 并写清**证据**（哪个测试、哪个 ADR）或**为什么做不了**。
>
> ⚠️ 没有标记 ≠ 通过。M2/M3 此前**一个标记都没有**，读的人分不出「做了」和「没做」——
> 而实际上 M2 的两条早就过了（`FitEngineTests`、四条正确性各自的行为测试），
> 只是没人回来标。这是 `FEATURE-GAP.md` 那个病（D195）在计划文档上的复发：
> **决策文档过期比缺失更危险**。
>
> **改动某条门涉及的能力时，顺手核实那一行。**

| 里程碑 | 周期（团队情景） | 交付物 | 退出门（pass/fail） |
|--------|------|--------|---------|
| **M0 地基与契约冻结** | W1-3 | SwiftData 七实体 + VersionedSchema 单向门 + CloudKit 私有库骨架 + 身体维度本地-only 域隔离（DL-1/2/3）+ **AI 代理打标 schema 契约冻结** + **抠图基准语料冻结** | schema 过加法式单向门守卫测试 **✅ 已过**（D84：`SchemaGuardTests` + golden 指纹 `Fixtures/SchemaFingerprint-v1.txt`，破坏性变更硬失败已实证）；CloudKit 开发环境同步跑通 ❌ 未做（需真机/云端）；身体数据不进 CloudKit 的单测硬门绿 ⚠️ **部分**——D84 已锁「身体数据不落主库」（`configurationsCarryDomainSubschemas` + `bodyProfileRowsStayInLocalDomain`）；**D170 补齐了与同步开关无关的那半**：构造一个 `cloudKitDatabase: .private(…)` 的主域配置，断言身体档案仍不在其 schema 内（`BodyDataStaysLocalRegardlessOfSyncTests`，撞验可红）——即身体数据不同步靠的是**分区**而非「现在没开同步」。**仍未验证**：真开 CloudKit 后的端到端行为（需真机 + 云端容器；容器标识、entitlement、双机竞态均未测）；**≥100 张人工标注抠图基准语料入库**（solid/浅色/花纹/深色各档，供 M1 的 ≥90% 可证伪）|
| **M1 生死线端侧全链 + 激活漏斗** | W3-9 | 连拍/PHPicker 零权限批量导入（SI-1/2）+ 端侧抠图 + 拍摄引导 + 手修编辑器（SI-3/6）+ 三派生缩略图管线（SI-8）+ **onboarding 2-3 题 + 冷启动双路径空状态 + 预赋进度 + 里程碑兑现推荐**（critic critical：北极星驱动器，原计划漏了） | 抠图在 M0 基准语料上 ≥90%（**对固定语料**，非「感觉」）；单件端到端 <15 秒（真机计时）；出网 payload 身体字段隐私单测绿 ✅ **已过**（D171：`OutboundPayloadPrivacyTests` 录下真实出网 URL，判据取**查询参数白名单**而非禁词黑名单——新参数必须先过人眼；另查身体字段词。两种注入形态撞验可红）；**M1 末尾插一次百件网格性能 smoke**（不等 M3）✅ **已过**（D173：`PerformanceSmokeTests` 三条——网格排序取**相对比值**判据（与等量纯值排序比，>4× 即红，与机器速度无关）、百件冷天推荐 <3s、两年穿着统计 <1s；三条各撞一次真实回归验证可红：排序退回排模型 12.7×、推荐退回全物化 975s、统计退回逐件扫描 12.2s）|
| **M2 管理与推荐闭环** | W6-12 | 多衣柜 + 人物档案 + 存放位置树 + 单品转移（缺件语义）UI + 规则层推荐（候选硬过滤→组套→打分→1-3 套 + 理由）+ **最小合身标记（ease→紧/合/松）** | F4 四条正确性自动化用例全绿（天气仅日间时段/场合硬过滤/≥7 天防重复+状态感知/组合语法）✅ **已过**（D202 逐条核实：四条各有行为测试——`OutfitCompleterTests` / `CandidateFilterTests` / `SlotExhaustionFallbackTests` / `OutfitGrammarTests`；删任一套件都会掉测试计数）；ease 引擎单测 ✅ **已过**（`FitEngineTests` 9 条）；**FFIT 完整 9 类判定移 v1.x**（critic：仅最小合身标记进 v1.0，见 §6）——**这条是范围决定，不是待过的门**|
| **M3 集成硬化与合规** | W11-15 | FixtureStore→SwiftDataStore 集成收口（US-19）+ CloudKit 合并协议（UUID/revision/tombstone + 修复器 DL-7）+ 双机竞态套件（DL-8）+ 遥测/监控/隐私审计门 | §11.4 性能预算全过（百件 p95≥58fps + 冷启≤2s + 内存≤400MB，真机 Instruments）❌ **未做**（需真机；本机 load 常年 15+，自动化里的性能门只是灾难探测器，见 D185/D197/D198，已入 `DEVICE-ACCEPTANCE.md`）；CloudKit 双机竞态收敛无孤儿/双属 ❌ **未做**（需真机 + 云端容器）；隐私一致性审计门绿 ⚠️ **大部已过**——`ComplianceCopyTests` 是这道门的主体（运行时真实出网 host 对账、真打字内容对账、无背书承诺检查、有 sink 时不许说「什么都没发」），另有 `OutboundPayloadPrivacyTests`（D171 出网 payload 白名单）、`UserContentFields`（D165 遥测/PII 单一定义）、`BodyDataStaysLocalRegardlessOfSyncTests`（D170 分区而非开关）、`TelemetryVerdictContractTests`（D201 反向门：App 不得自发装机标识）。**仍缺的只有与 CloudKit 相关的那部分**——开了同步之后的一致性无法在本地验 |
| **M4 Beta 与发布** | W15-18 | TestFlight 两阶段 + 提审检查单 + US-only storefront + 法务文档托管 + phased release | 提审检查单逐条对账（隐私标签 vs §5 / PrivacyInfo.xcprivacy / 订阅取消路径）；phased release 崩溃率 + 同步失败率在阈值内；**首批 Beta 采集 R1 激活基准（7 天 40 件），门槛数字此时才有数据定**|

## 3. Xcode 工程结构（fixture-first 解耦）

单一瘦 App target + 按领域切分本地 SPM package，`StoreProtocol` 作并行开发的解耦缝：

```
ClosetApp.xcodeproj          瘦壳（App 入口/DI 组装/entitlements: CloudKit·WeatherKit·App Attest·Push）
Packages/
  ClosetModel      七实体 @Model + VersionedSchema + value-type DTO + StoreProtocol（核心缝，无 UI 无 CloudKit）
  ClosetSync       CloudKit 同步 + operation log + tombstone + 合并修复器 + 身体维度本地域隔离
  ScanIntake       capability 协议 + mock（治模拟器不可用）+ Vision 抠图 + SAM2 + OCR + 编排状态机
  RulesEngine      纯端侧推荐 + FFIT 纯函数 + ease 引擎 + 规则资产 JSON（禁 import SwiftData/UIKit）
  AIProxyClient    Worker 客户端 + App Attest attestation + 打标 schema + mock 代理
  DesignSystem     tokens + Liquid Glass 封装（GlassEffectContainer/concentric）
  Feature/*        WardrobeUI/RecommendUI/IntakeUI/CheckinUI/SearchUI/SettingsUI（只依赖 DesignSystem + StoreProtocol）
  AppCore          DI：FixtureStore 与 SwiftDataStore 两实现均 conform StoreProtocol，US-19 换缝
  TestSupport      fixtures + 快照 helper + payload 隐私断言 helper
Test targets:  UnitTests（模拟器）/ SnapshotTests（模拟器）/ DeviceRegressionTests（真机：Vision/SAM2/OCR + 双机 CloudKit）
worker/          Cloudflare Worker（TypeScript，wrangler + Durable Object 配额账本，独立 CI，Xcode 工程外）
```

**缝的价值**：UI 与 RulesEngine 全程对 `FixtureStore` 在模拟器迭代，US-19 一次性换 `SwiftDataStore`——这是 6 子系统真并行的架构前提，也让「Vision 真机-only」不拖慢非推理逻辑。

## 4. 关键路径与并行

- **关键路径**：DL-1（唯一硬前置）→ SI-0/3/6/9/10/11/12（入库生死线，52 person-day 是墙钟长 pole）→ US-19 集成收口 → DL-7/8 合并协议 → 性能门 → 发布
- **Day-1 可真并行**（靠契约/协议解耦）：AI Proxy（独立仓 + TS 工具链）、UI Shell（对 FixtureStore）、RulesEngine（吃 value-type DTO）——名义第二长的 UI Shell 几乎不占关键路径
- **压缩关键**：M1 入库必须 2 人拆流（抠图图形交互 / OCR·打标·编排状态机），否则整体 24-26 周

## 5. 砍项阶梯（工期超预算时按「伤北极星最小」顺序砍）

1. **SAM2 点选辅助抠图（SI-4，6d）**——已离主路径，未下载降级纯 Vision，砍了主链照跑，首选
2. StoreKit 2 权益绑定（AG-5，~3d）——若 v1.0 纯免费层则整块后置 v1.x（依赖 §7-P3 裁决）
3. 个人色彩 12 季型加权（~2.5d）——科学性争议 + 文案法务红线，去掉仍由场合/天气/体型主信号产出
4. Widget（2d）——拒权已有 App 内今日卡兜底，不伤激活漏斗
5. 全局查找降级为基础属性筛（~1-2d）——40 件规模语义检索价值低
6. 数据导出降 v1.x（~1.5d）——但 **CCPA「删除全部数据」是硬合规必留，只能砍导出不砍删除权**
7. 快照矩阵瘦身——无障碍是 §10.4 DoD 硬约束，只能瘦（关键页+极值档）不能砍

## 6. critic REJECT 的处置（逐条）

| # | critic 发现 | 处置 |
|---|------------|------|
| critical | 激活漏斗（北极星驱动器）无独立交付物 | **已应用**：onboarding + 冷启动双路径 + 预赋进度 + 里程碑兑现推荐纳入 M1 交付物 |
| major | 工期口径偷换（1 人 brief vs 3-4 人 headline） | **已应用**：§1 主数字改单人 ~228 person-day，团队情景作次要，团队规模上升为 P0 裁决 |
| major | FFIT 完整 9 类 + ease 作 v1.0 关键但被「四维度录满」门隐藏 | **已应用**：仅「最小合身标记（ease→紧/合/松）」进 v1.0，**FFIT 完整 9 类判定移 v1.x**（与 MARKET H3「合身判断优先」一致，且属加法演进） |
| major | 验收门不可证伪（抠图≥90% 无冻结基准） | **已应用**：M0 交付「≥100 张人工标注抠图基准语料」，M1 的 ≥90% 对固定语料判定 |
| major | v1.0 范围未砍最贵/最低激活的机器（多衣柜 + CloudKit 合并协议 DL-7/8） | **上升为 P2 裁决**——多衣柜是**用户硬需求不能砍**；但「并发多设备合并的精细度（DL-7/8 完整修复器）」可为 v1.0 降级（接受 LWW + 已知限制，MVP 多为单设备用户），此项触及硬需求的数据完整性，交你裁决 |
| minor×3 | 性能门全压 M3 / §10.6 全状态矩阵无 owner / 首启模型下载 + prompt 回归无 owner | **已应用**：M1 末插性能 smoke；§10.6 指定单一 owner 跨 RE+US；SI-4 决策提到 M0、打标 prompt 回归 harness 明确归属 |

## 7. 待用户裁决（本计划定盘的前置）

- **P0 团队规模与时间盒**：单人 ~10-11 个月 vs 3-4 人 4-5 个月——这决定里程碑周期是否成立，也决定要不要启用 §5 砍项阶梯。你的资源是？
- **P1 需求验证前置（R1）**：critic 强调整个计划押在「上线后才验证」的需求假设上，承诺 4-5 个月才见反馈。**强烈建议 M0 并行做一轮轻验证**（落地页/竞品社区访谈/可点原型），而非直接开工——你要先验证还是边建边验？
- **P2 CloudKit 合并精细度**：多衣柜保留（硬需求），但 v1.0 是否要完整的双机竞态合并修复器（DL-7/8，~14 天内链）？降级 = 接受并发多设备编辑的已知限制，省关键路径时间，多数 MVP 用户单设备可接受。
- **P3 v1.0 是否出售**：纯免费层（省 AG-5 StoreKit ~3d，200 件撞墙即降级无升级出口）vs v1.0 即上 Plus 订阅/买断。
- 次要：AI 代理 Cloudflare Worker vs Firebase AI Logic（§4.1 二选一，改选则 AG-3/4/5 重估）；WeatherKit「日间时段」窗口边界（几点到几点，卡推荐硬门#1 收口）。

---

## 附：子系统任务清单来源

完整 85 个任务（id/detail/sizeDays/deps/acceptance）见规划 workflow journal（`wf_b9383537-c0f`）；本文为综合视图。各子系统估算：数据层 27d(low) / 入库 52d(low) / 推荐 36d(medium) / UI 壳 47d(medium) / AI 代理 26d(medium) / 测试CI 40.5d(low)。
