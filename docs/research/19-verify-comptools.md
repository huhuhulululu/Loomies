# 13 号线遗留核查：工具组三条关键断言的独立对抗核查（2026-07-22）

> 任务背景：`13-competitors-tools.md`（2026-07-21）因会话限额有 3 条关键断言未经独立核查，`MARKET.md` v1.0 §9 已标注。本报告以证伪立场逐条重查，全部走一手来源（iTunes Lookup / iTunes 付费榜 RSS / App Store 评论 RSS / App Store 网页版商品页 / MongoDB 官方文档 + Wayback / 竞品官方帮助中心与定价页），核查日 2026-07-22。
> 本报告为增量核查，不重复 13 号报告内容；判定口径：confirmed / refuted / uncertain。

---

## 0. 一页结论

| # | 断言 | 判定 | 一句话 |
|---|------|------|--------|
| ① | 工具组五家无一同时占据 2+ 差异化格位 | **confirmed（严格定义下）** | GetWardrobe 官方帮助中心逐项证实其全部为「记录级/过滤级/按人」半格实现；但它以半格触及 4 个格位，MARKET.md 表述需精确化 |
| ② | Stylebook 13 个月零更新仍居美区付费 Lifestyle 榜前列 | **confirmed（双源一手复现）** | 2026-07-22 复测：付费 Lifestyle 榜 **#2**（RSS + 商品页 badge 两源一致）；最新版本 10.1 = 2025-06-15，距今 13.2 个月 |
| ③ | Smart Closet 因 2025-09-30 MongoDB EOL 灾难性丢数据、口碑崩塌 | **confirmed（附两点精确化）** | MongoDB 官方文档证实 Device Sync/Device SDKs 于 2025-09-30 EOL 下线；评论灾难链与 2025 年 1.82 均分一手复现。注意：归因是强旁证非厂商确认；「崩塌」发生在书面评论与增长动能层，门面累计均分仍 4.4 |

三条全部 confirmed，13 号线核心结论无需回滚；两处表述建议精确化（见 §4）。

---

## 1. 断言②：Stylebook「13 个月零更新仍居付费 Lifestyle 榜前列」——confirmed

**证伪尝试**：榜位是日波动数据，13 号报告只测了一天（2026-07-21），可能恰逢峰值；且「零更新」依赖版本历史口径。

**一手证据（2026-07-22 复测，两个独立端点）**：
- iTunes 付费榜 RSS（`itunes.apple.com/us/rss/toppaidapplications/limit=200/genre=6012/json`）：Stylebook（id 335709058）**Lifestyle 付费榜 #2**；全类目付费榜（同端点无 genre）**#93**——与 13 号报告完全一致，连续两天可复现。
- App Store 网页版商品页（`apps.apple.com/us/app/stylebook/id335709058`，2026-07-22 抓取）：页面 Information 区 badge 原文 `Chart #2 Lifestyle`（链接指向 `charts/6012?chart=top-paid`）——**苹果自己渲染的榜位，与 RSS 交叉一致**。
- 版本口径：iTunes Lookup `version: 10.1, currentVersionReleaseDate: 2025-06-15T13:08:37Z`；商品页 What's New 区同样显示 `10.1 — 06/15/2025`。距 2026-07-22 为 **13.2 个月零更新**。
- 评分基线：8,703 条（4.68★），比 13 号报告的 8,701 +2 条/1 天——存量口碑仍在缓慢累积。

**次级差异（不影响断言）**：姊妹 App Stylebook Men 今日 Lifestyle 付费榜 **#55**（13 号报告记 #96）——中长尾榜位日波动大，引用时不应给单日精确名次，量级表述（前 100）即可。

**判定：confirmed**。修正表述建议：无需修正实质，可加注「榜位为日度快照，#2 已连续两日复现（2026-07-21/22）」。sourceTier: first-hand。

---

## 2. 断言③：Smart Closet「2025-09-30 MongoDB EOL 灾难性丢数据、口碑崩塌」——confirmed（附两点精确化）

**证伪尝试**：三个可疑点——(a) MongoDB EOL 是否真有其事、日期是否 2025-09-30；(b)「MongoDB 是元凶」是否只是用户猜测；(c)「口碑崩塌」是否夸大（App 门面评分仍 4.4★）。

### 2a. MongoDB EOL 事实：官方文档证实

- MongoDB 官方文档（`mongodb.com/docs/atlas/app-services/deprecation/`，Wayback 2025-05-22 快照）原文：
  > "As of September 2024, the following App Services are deprecated: Atlas Data API and HTTPS Endpoints / **Atlas Device SDKs**. These services will reach **end-of-life and be removed on September 30, 2025**."
  同页确认 **Device Sync** 在废弃清单内（"Device Sync, Data API, and HTTPS Endpoints are deprecated"）。
- 当前在线版同页（2026-07-22 抓取）横幅："Atlas App Services **has reached its end-of-life status** and is no longer actively supported by MongoDB."
- → 基础设施事件真实、日期精确吻合：**2025-09-30，Realm/Atlas Device Sync（含登录用 App Services）下线**。一手，高置信。

### 2b. 灾难链一手复现（评论 RSS 全量重拉，420 条去重，2017-02→2026-07）

- **年度均分独立复算**：2022:2.25(n=53) → 2023:2.65(n=17) → 2024:2.29(n=7) → **2025:1.82(n=28)** → 2026:2.20(n=5)——与 13 号报告逐年吻合（含 1.82 这个关键数）。
- **2025-10 锁死潮**：2025-10-07 起连续 12+ 条 1-2★，全部指向登录死亡/数据不可达，全部落在旧版 v3.7.1 上（时间与 9/30 EOL 精确衔接）。样例：
  - [2025-10-21|1★] "**MongoDB (the service that allows for cloud syncing data as well as signin) announced end-of-life support** for applications—and the developers did not warn a single person…"
  - [2025-11-19|5★(revised)] "The app's framework has reached its **End Of Life as of Sept. 30, 2025**. Emailed the developer about it but never received an answer."
  - [2025-10-19|1★] "I have lost everything; years of uploading garments…"；[2025-10-21|1★] "I have lost 100+ hours of work."
- **急救与部分恢复**：现行版本 3.8.3（2025-11-10 发布，iTunes Lookup），此后 **8+ 个月再无更新**；[2025-11-14|4★] "Finally able to log in… everything was saved"、[2025-11-19|5★] 恢复 vs [2025-12-01|1★]、[2026-02-04 口径] 付费备份数据永久丢失——「部分恢复、部分永损」两态并存。
- **增长归零独立复核**：Wayback 2024-09-18 商品页快照 `ratingCount: 4,328` → 今日 Lookup `4,344` = **22 个月 +16 条**，13 号报告数字精确复现。

### 2c. 两点精确化（不推翻，但引用时应带上）

1. **归因层级**：「MongoDB EOL 所致」来自用户诊断（两条评论点名）+ 时间/功能面精确吻合（登录+同步正是 Device Sync/App Services 所辖），**开发商 Rabbit Tech 从未公开确认**——smartcloset.me 官网今日全文 0 处提及事故。且根因严格说是**开发商在 2024-09 废弃公告后 12 个月无迁移作为**（2022-12 起已停更近 3 年），MongoDB EOL 只是引爆时点。引用时建议写「因后端依赖 MongoDB Device Sync 2025-09-30 EOL 且开发商未迁移」。
2. **「口碑崩塌」的口径**：崩塌发生在**书面评论层（2025 均分 1.82）与增长动能层（22 个月 +16 条评分）**；门面累计均分今日仍为 **4.41★/4,344**（累计口径稀释）。对我们的营销含义：普通用户在商店首屏看到的仍是 4.4★——「Smart Closet 已死」不能作为面向用户的对比话术，只能作为供给侧空位判断。

**判定：confirmed**。sourceTier: first-hand（MongoDB 文档 + 评论 RSS + Wayback + Lookup）。

---

## 3. 断言①：「工具组五家无一同时占据 2+ 差异化格位」——confirmed（严格定义下），表述需精确化

**证伪尝试**：唯一可能的反例是 GetWardrobe（13 号报告自评「单点最接近者」）。若其 Sizes Notebook（尺码维度）+ Occasions（场合）都算「占据」，断言即被推翻。故重点拉其官方帮助中心与定价页原文，逐格对质。

**一手证据（2026-07-22 抓取 help.getwardrobe.com/latest/features/ 全文 + getwardrobe.com/pricing + 五家 App Store 官方描述）**：

| 格位 | GetWardrobe 官方原文 | 定级 |
|------|---------------------|------|
| 尺码/维度 | "Sizes Notebook — **Record** body measurements and track how different brands and sizes fit you **for smarter shopping decisions**" | 记录级。文档通篇无「测量数据驱动推荐/合身判断/可视化」的任何表述 → **半格** |
| 场合推荐 | "Occasions — Create custom occasion tags (e.g., Work, Weekend, Formal) and **organize outfits by occasion for easy browsing and filtering**"；App Store 描述 "AI-curated outfits… filtered by weather, occasion, and mood" | 标签过滤级（含 AI 生成器的过滤参数），无场合档位、无日历联动 → **半格** |
| 多衣柜 | Family Wardrobe = 按 family member 建 profile / 按成员过滤（帮助中心 Filter 列表：family member, season, weight, status, size…）| 按人非按地点，无转移语义 → **半格** |
| 存放位置 | 帮助中心 "location" 共 7 处命中，**全部**指天气城市/行程地点（Weather Location / Temporary Location / trip location）| **零格**（复核成立） |
| 体型 | 帮助中心 "body shape" **0 命中**；Virtual Try-On (Credits) = "virtual model or your own body photo" | 13 号报告引 2021 年评论称有体型判定，现行官方文档已无此表述 → 降为**证据不足的残格** |

其余四家（今日官方描述交叉验证）：Stylebook 描述无 occasion/measurement/location 字段；Cladwell 仅 "Organize by season, work, or travel"（分组）；Pureple 过滤字段原文 "season, occasion, color, brand, size, price, and more"（**无 location**，13 号报告对基线的降级复核成立）；Smart Closet 描述无相关字段。五家近端更新（Pureple 6.0.21@2026-07-13 "bug fixes"、GetWardrobe 2026.06.3@2026-06-26）均无新增格位功能。

**判定：confirmed——在 13 号报告 §0 的严格定义下**（地点级多衣柜/存放位置字段/维度级尺码驱动功能/场合档位推荐/体型），无一家**完整**占据 ≥2 格。但 MARKET.md §4 的简写「无一家同时占据 2+ 差异化格位」在宽口径下有被挑战空间：**GetWardrobe 以半格形式触及 4 个格位**（记录级尺码+过滤级场合+按人多柜+照片试穿），是唯一的组合威胁。修正表述见 §4。sourceTier: first-hand。

**顺带增量**：GetWardrobe 官方定价页今日口径 **Premium $6.99/月 或 $49.99/年**（FAQ 原文）——13 号报告记录的「App Store 页 $4.99/mo·$34.99/yr 与官网不一致」中，官网侧已统一到高价档；App Store IAP 展示侧未复核（需实机），涨价方向坐实。

---

## 4. 对 MARKET.md v2.0 台账的修正建议

1. **§9 表格**：`research/13-competitors-tools.md` 行改为「**3/3 核查完成（19 号线补齐，全部 confirmed，2 处表述精确化）**」。
2. **§4 工具组整体**：原文「无一家同时占据 2+ 差异化格位（组合空白确认，⚠️ 本条未经独立核查）」→ 改为「**无一家完整占据 2+ 差异化格位（严格定义：地点级多衣柜/存放位置/维度驱动功能/场合档位推荐/体型）；GetWardrobe 以记录级/过滤级半格触及 4 个格位，是唯一组合威胁**（19 号线核查 confirmed）」。
3. **§2 H4 / §5 O**：「Smart Closet 因服务端 EOL 灾难性丢数据沦为僵尸」→ 建议加半句归因与口径精确化：「（MongoDB Device Sync 2025-09-30 EOL + 开发商 3 年停更未迁移；书面评论 2025 年均分 1.82、22 个月 +16 评分，但门面累计均分仍 4.4★——供给侧空位成立，不宜作面向用户的对比话术）」。
4. Stylebook 断言可加注「#2 已连续两日复现（07-21/07-22，RSS+商品页双源）」，去掉对 Stylebook Men 单日名次的引用。

## 5. 残留不确定（诚实声明）

- Pureple「自定义过滤器可否自建 location」、GetWardrobe App Store IAP 展示价、Stylebook "in storage" 状态的实机行为——均需上线对标时实机验证（13 号报告已列，本轮无新增证据）。
- GetWardrobe 体型判定：2021 评论与现行官方文档矛盾，按「现行不可证」处理。
- WebSearch 本会话预算耗尽，未能补充第三方媒体对 Smart Closet 事故的报道面；不影响三条判定（均已有一手证据闭环）。

## 6. 来源清单（全部 2026-07-22 抓取）

- iTunes Lookup：`itunes.apple.com/lookup?id=335709058,1140550878,656212466,628106373,1198057728&country=us`
- 付费榜 RSS：`itunes.apple.com/us/rss/toppaidapplications/limit=200/genre=6012/json`（Lifestyle）及无 genre 版（全类目）
- Stylebook 商品页（Chart #2 Lifestyle badge + 10.1@2025-06-15）：`apps.apple.com/us/app/stylebook/id335709058`
- Smart Closet 评论 RSS 10 页（420 条去重）：`itunes.apple.com/us/rss/customerreviews/page={1-10}/id=1198057728/sortby=mostrecent/json`
- MongoDB 官方废弃文档：`mongodb.com/docs/atlas/app-services/deprecation/`（现行页 + Wayback 2025-05-22 快照 `web.archive.org/web/20250522195457/...`）
- Smart Closet 商品页 Wayback 2024-09-18（ratingCount 4,328）：`web.archive.org/web/20240918010804/https://apps.apple.com/us/app/smart-closet-your-stylist/id1198057728`
- GetWardrobe 官方：`help.getwardrobe.com/latest/features/`、`getwardrobe.com/pricing`
- Smart Closet 官网（0 处事故说明）：`smartcloset.me`
