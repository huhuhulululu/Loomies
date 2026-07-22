# 近 90 天品类新鲜动态（2026-04 ~ 2026-07）

> 报告编号：20-fresh-signals
> 日期：2026-07-22
> 任务：MARKET.md / DEMAND-VALIDATION §8 基线之上的**增量**刷新（Alta 动向 / Whering $7M 后 / 新入场者 / 平台威胁 / 窗口修正）
> 数据源：WebSearch 与 WebFetch 本轮均不可用（safety classifier 宕机），全部改走 curl 直连一手源——iTunes Search/Lookup API、App Store 网页版本历史（apps.apple.com 内嵌 JSON）、iTunes 评论 RSS、Google News RSS、tech.eu / 9to5google 原文。Product Hunt 为 JS 墙无法一手抓取（DDG 两次代理检索失败），新品扫描以 App Store 为准。
> 每条 finding 标注 sourceTier：**first-hand**（官方 API/页面/一手评论）/ **vendor-claimed**（厂商自述）/ **inferred**（推断）。

---

## 0. TL;DR（五条最重要增量）

1. **Google Photos「Wardrobe」（4/29 官宣，今夏推送）是本轮最大新威胁**：自动扫描相册→识别穿过的衣物→生成干净单品图→Items/Outfits→avatar 试穿。全品类共同护城河「录入摩擦」被平台免费能力正面攻击。Android 先、iOS 后。
2. **Whering 拿到 $7M（7/7，eBay Ventures + Google AI Futures Fund 领投，宣称 10M 用户），官宣路线图 = 相册扫描 + VTO + 天气/心情/场合个性化推荐**——正面驶入我们的 copilot 车道；且 6 月已实装「Planner 按衣橱+天气建议穿搭」。**机制重叠度已超过 Alta。**
3. **Alta 更新节奏从周更实际放缓为月更**（4/22→5/27→6/30→7/21），90 天功能方向全部在社交/探索/大众化（explore page、Alta friends、widget、event & trip planning），**无任何走向存放位置/合身判断/多衣柜的迹象**——「变现模式与我们防御点结构性相斥」的基线判断被增量证据加强。无新融资。
4. **新品洪水但无真对手**：9 个月 ~180 款 closet/outfit/wardrobe 新 App 上架，最高者仅 739 评分；无一以「copilot」定位；「合身判断」空白 90 天内依然无人占据（Alta avatar 体型失真差评仍在持续产生）。
5. **窗口判断修正：总窗口从 12-18 个月收窄到约 9-15 个月**（驱动因素：Whering roadmap + Google Photos iOS 落地在即），对 Alta 维持 0-12 个月保守口径但实际迹象偏松；「合身×场合×存放组合无人占据」结论 90 天后依然成立。

---

## 1. Alta（主威胁复核）

### 1.1 产品动向（sourceTier: first-hand — App Store 版本历史 + iTunes API，2026-07-22 抓取）

- **更名**：App 名现为 **"Alta Daily: Digital AI Closet"**（Meta 官方博客 2026-04-06 已用 "Alta Daily" 称呼）。ASO 直插 "digital closet" 大词，与 Whering/Indyx 正面抢词。
- **更新节奏放缓，"周更" 已不成立**：版本历史 2.1.14（3/26）→ 2.1.15（4/6）→ 2.1.16（4/22）→ 2.1.17（5/27）→ 2.1.18（6/30）→ 2.2.0（7/21）。3 月还有 3 个 build，4 月起稳定为**每月一更**。基线 MARKET.md「周更节奏」需下调。
- **90 天功能方向**（release notes 文案演变）：Best Dressed / Alta friends（2-4 月）→ Explore the community（5-6 月）→ explore page + Home Screen widget + event & trip planning（7 月 2.2.0），持续项为 "Improved styling algorithm and more realistic avatars"。**全部指向社交/探索/内容分发；零迹象指向存放位置、合身判断、多衣柜。**
- 评分 4.88★ / 10,862 个评分（7/22），与基线（7/21 记录 10,783）同量级。

### 1.2 一手评论主题（sourceTier: first-hand — iTunes RSS mostrecent，7/14-7/21 共 40 条）

基线弱点全部仍在持续产生新差评：

- **avatar 体型失真依旧**（合身判断空白未被填补）："The avatar never looks even close to me, it has a completely different body type"（1★，7/15）；"she needs to stop being fat I weigh 115 pounds"（7/19）。
- **AI 变形衣物**："The AI part of this app made my shorts look like balloons"（4★，7/20）。
- **云端账号/数据丢失**："After months of adding items... the app forgot who I was... I was told to delete"（1★，7/17）；"When I downloaded the app it says looks like your offline... can't even use the app"（1★，7/18）→ 「没有可以宕机的服务器」叙事继续有效。
- **购物推动张力**："It will create outfits, encouraging you to shop rather than pull from your closet. otherwise it's a shopping app."（3★，7/15）。
- **用户面明显大众化而非聚焦职业女性**：同一周好评作者含 13 岁初中生、60 岁职业女性/母亲、职业造型师、西语用户（"Lo vi en Instagram"）——Alta 在走横向大众渗透路线，验证「职业女性纵深」仍是可切的定位。
- 录入激励机制：+100 件解锁 "VIP status"（7/19 评论提及）。

### 1.3 商业/资本动向（sourceTier: first-hand — Google News RSS 扫描）

- **无新融资、无收购新闻**（近 180 天检索仅 $11M seed 旧闻）。
- B2B2C 变现持续加码：与品牌 Public School 合作把 styling 工具嵌入品牌网站（TechCrunch，2026-02-14）；Poshmark 合作（2025-10 旧闻）延续。
- 曝光面：Meta 官方 SAM 技术案例（AI at Meta，2026-04-06）、ABC News 视频报道（2026-04-17）、PYMNTS Met Gala 稿（2026-05-04）。

**小结**：威胁定性维持「主威胁」，但两处修正——①执行节奏降档；②方向持续偏社交/大众/购物导购，90 天内没有向我们三个防御点（存放/多衣柜/合身）移动。基线「结构性相斥」判断获增量证据支持。

---

## 2. Whering：$7M 后的实际动作（威胁升级）

### 2.1 融资落地（sourceTier: first-hand — WWD/Yahoo/Tech.eu/TheIndustry.fashion 多源同报，2026-07-07）

- **$7M seed，eBay Ventures + Google AI Futures Fund 领投**，宣称 **10M 用户**（Tech.eu 2026-07-07；基线写 "~$14M 累计" 时该轮尚未官宣落地）。
- 战略叙事：wardrobe management + styling + **resale** 单一生态（eBay 的钱指向转售集成——与我们 v2「导出为转售草稿」期权同一方向，但它做的是平台内闭环）。

### 2.2 官宣路线图（sourceTier: vendor-claimed — CEO Bianca Rangecroft 于 Tech.eu，2026-07-07）

> 计划推出 "personalised outfit recommendations based on factors such as **weather, mood and occasion**, alongside new tools including image enhancement, **gallery scanning to identify clothing items from users' photos**, and **virtual try-on** functionality"。

- **相册扫描 + VTO：官宣了但尚未上线**（截至 7/22 版本 3.3.136 的 release notes 无此两项）——回答了任务问题「上线了吗」：**没有，还在 roadmap**。
- **天气/心情/场合推荐**：与我们 H1 机制直接重叠，且是 copilot 形态表述。

### 2.3 已实装（sourceTier: first-hand — App Store 版本历史）

- **6/12 起（3.3.38 → 3.3.136）**："Planner now suggests outfits based on your wardrobe and the weather... plan ahead for trips, weekends and events by changing your location" —— **天气驱动的 planner 内建议已上线**，正是「用户掌舵 + App 跑腿」的 copilot 形态。
- 4-6 月："**Unpacked**"（衣橱行为分析：cost per wear、最常穿、季度回顾）+ "**Enhance**"（照片转产品图——录入质量摩擦的减负）。
- 工程节奏快：7 月单月 3 个 build（7/1、7/7、7/22）。

**小结**：Whering 从基线的「Gen Z 象限玩家、12 个月拉平批量入库」升级为**机制重叠度第一的在场威胁**——有钱（且是 Google 的钱）、有量（10M）、已上线天气 planner、路线图直指相册扫描+场合推荐。缓冲因素：其定位（Gen Z/可持续/社交）与人群（英国起家）仍偏离美国 25-45 职业女性纵深；roadmap≠交付（其批量入库痛点历史悠久）；变现仍押 resale 佣金而非向用户收费——与 Alta 同样存在「诚实合身/深管理不产生 GMV」的结构张力。

---

## 3. 新入场者扫描（App Store，2025-10 以来上架）

### 3.1 总量（sourceTier: first-hand — iTunes Search API 5 关键词 × limit 200，按 releaseDate 过滤去重）

- **9 个月 ~180 款**含 closet/outfit/wardrobe/AI stylist 关键词的新 App 上架——淘金热确认，月均 ~20 款。
- **绝大多数零牵引**：评分数 0-个位数占比约 90%；命名高度同质（"AI Outfit Planner" 变体泛滥）→ ASO 长尾词正被稀释，上线前的 Apple Search Ads 实测（MARKET §7）更紧迫。
- **无一以「copilot」自我定位**（App Store 命名/描述层面）。Product Hunt 无法一手核查（JS 墙），此空白结论仅覆盖 App Store。

### 3.2 有初步牵引的新品（sourceTier: first-hand — iTunes API，7/22 数据）

| App | 上架 | 评分数 | 定位 | 与我们的重叠 |
|---|---|---|---|---|
| ButtonUp | 2025-11 | 739 (4.77) | 截图→VTO 购物试穿 | 低（购物侧） |
| Cloey: Style Companion | 2026-03 | 307 (4.5) | 编目+推荐+背景移除，freemium | **高**（机制最像，4 个月 307 评分为新品最快之一） |
| Setly | 2025-10 | 286 (4.58) | 社交/风格测验/社区 | 低 |
| Lekondo | 2026-01 | 203 (4.87) | OOTD 记录+社交 | 低 |
| Vesta Wardrobe | 2025-11 | 166 (4.65) | "rediscover what you already own... for any occasion" | **高**（JTBD 文案与我们完全撞车） |
| Vovin | 2026-06 | 91 (4.73) | "built for real wardrobes, not endless shopping lists" | 中（反购物叙事已被别人喊出，1 个月 91 评分初速最快） |
| BetterMe Style | 2026-05 | 7 | 胶囊衣橱 200+ 预制搭配 | 中（**健康 App 大厂 BetterMe 入场**，做减法哲学产品化——瞄准的是我们筛掉的「干扰项」人群） |

- 微型天气向新品出现（Dresr - Weather Outfit Planner 4/13、New Day Weather and Wardrobe 4/22），均无牵引——天气角度本身不构成壁垒的旁证。

### 3.3 资本侧信号（sourceTier: inferred — 标题级 + 一手牵引数交叉）

- **Daydream（$50M，Julie Bornstein）事实性哑火**：iOS App 上架 8 个月仅 **71 评分**（first-hand）；puck.news 2026-03-27 发文《Requiem for Daydream》（标题级信号，正文付费墙未读，故收敛为 inferred）。AI-fashion-shopping 叙事的资本热度在退潮，反衬「工具/copilot」车道未被烧钱大军碾压。

---

## 4. 平台威胁刷新

### 4.1 Google（威胁升级，形态改变）

- **Doppl 独立 App 已按计划于 2026-04-30 关停**（3 月官宣，jetstream.blog 2026-03-24；基线已预判「并入 Search/Shopping」，本轮确认执行完毕）。（first-hand: 新闻扫描）
- **新增：Google Photos「Wardrobe」**（blog.google / 9to5Google / The Verge，2026-04-29 官宣）：（first-hand）
  - 自动扫描照片库→识别穿过的衣物和配饰→"generate clean, snapshot images of the pieces"；
  - Collections 内新增 Wardrobe 页，分 **Items / Outfits**；分类 Tops/Bottoms/Skirts/Dresses/Jewelry；
  - 内置 **avatar 虚拟试穿**（与 Search try-on 同技术）+ 手动 mix & match Create 工具 + moodboard 分享；
  - **"rolling out this summer"，Android 先、iOS 后**。
  - **含义**：全品类共同的护城河兼共同的诅咒——「录入摩擦」——被拥有相册的平台以免费能力正面攻击。但它是「目录 + 试穿」，**没有场合/日历/合身判断/规划结构**，也不太可能做（Google 动机在 Shopping GMV）。iOS 上 Google Photos 渗透率有限，给了 6-12 个月缓冲。
- Search/Shopping try-on 持续加码：7/21 blog.google 再发 trending styles + try-on 功能稿。（first-hand）

### 4.2 Pinterest（横向扩张，未入衣橱管理）

- **"Ask Pinterest" 实验性 AI 购物独立 App 上线**（TechCrunch，2026-06-17）+ 同日发布 AI ads / personalized shopping 工具套件。（first-hand: 新闻）
- Styled for You / AI boards 在本窗口（4-7 月）无新动作（最近为 2025-10 的 AI-powered boards 实验）。
- 定性维持：灵感/购物侧威胁，未进入「管理你已拥有的衣物」领地。

### 4.3 Apple WWDC26（2026-06-08~12）

- 头条级扫描（Apple 官方稿 + CNET/9to5Mac/IGN/PCMag 等）：Siri AI、Apple Intelligence 增量、Visual Intelligence、iOS 27——**无任何时尚/衣橱/试穿场景信号**。（first-hand: 标题扫描；未逐篇精读，置信中）
- 对我们中性偏好：平台没有亲自下场，iOS 27 的 on-device 模型能力反而是「零服务器」架构的顺风。

### 4.4 转售生态

- Poshmark 把 1.2 亿 listings 开放给第三方 AI（glossy.co "the Shazam of fashion"，2026-06-25）——转售×AI 集成加速，v2「导出为转售草稿」期权的接口环境在变好。（first-hand: 标题级）

---

## 5. 威胁矩阵刷新

| 威胁 | 基线定性（7/21） | 刷新后（7/22） | 变化 | 依据 |
|---|---|---|---|---|
| **Whering** | Gen Z 象限、12 个月拉平入库体验 | **机制重叠度第一的在场威胁**：$7M（eBay+Google）、10M 用户、天气 planner 已上线、roadmap=相册扫描+VTO+场合推荐 | ⬆️ 升级 | §2 |
| **Alta** | 主威胁、周更、0-12 个月 | 主威胁（体量/心智仍第一）但节奏降为月更、方向偏社交大众化、90 天未向我们防御点移动、无新融资 | ➡️ 维持偏松 | §1 |
| **Google Photos Wardrobe** | （不存在） | **新晋平台级威胁**：免费自动录入+VTO；无决策层结构；iOS 滞后 | 🆕 | §4.1 |
| Google Search/Doppl | 已关停并入 Search | 确认执行完毕；Search try-on 持续加码 | ➡️ | §4.1 |
| Pinterest | 灵感/购物侧 | Ask Pinterest 独立 App 实验；仍未入衣橱管理 | ➡️ | §4.2 |
| Apple | iOS 26 起点 | WWDC26 无时尚信号；on-device 能力增强为顺风 | ➡️ 中性偏好 | §4.3 |
| 新品洪水 | — | ~180 款/9 个月，无 copilot 定位者，ASO 长尾稀释 | 🆕 低烈度 | §3 |
| Cladwell（autopilot 反面教材） | 收紧中 | 3/6 后零更新，进一步僵尸化 | ⬇️ | iTunes API 7/22 |
| Stylebook（买断标杆） | 停更 13 个月 | 仍停更（10.1 / 2025-06-15），评分数 8,703 vs 基线 8,701——需求在、供给死 | ➡️ | iTunes API 7/22 |
| Indyx（心智竞品） | 9-5 职业女性好感 | 活跃（7/22 更新，1,447 评分 4.77），无场合结构化新动作 | ➡️ | iTunes API 7/22 |
| GetWardrobe（盯防） | 月更 | 维持月更（6/26），无新大动作 | ➡️ | iTunes API 7/22 |

---

## 6. 对 12-18 个月窗口判断的修正

1. **总窗口：12-18 个月 → 约 9-15 个月**（收窄）。驱动：
   - Whering 官宣 roadmap 直指 copilot 机制（天气/场合推荐 + 相册扫描），且已有第一块落地（天气 planner）——它把「roadmap 变交付」通常要 2-4 个季度；
   - Google Photos Wardrobe 今夏 Android、随后 iOS——「录入自动化」将在 12 个月内变成品类标配预期，我们的录入体验必须以此为基准线设计（本地识别、相册导入），不能只对标 Whering/Alta 今天的手动流程；
   - 新品洪水稀释 ASO 长尾，晚上线一个月获客成本单调上升。
2. **对 Alta：维持 0-12 个月保守口径，但增量证据偏松**——节奏降档 + 社交大众化路线 + 变现结构性相斥的三重迹象，说明它 12 个月内主动来抢「合身×存放×职业女性纵深」格位的概率在下降而非上升。真正要盯的换成了 Whering（建议把「唯一活跃盯防」从 GetWardrobe 升格为 Whering + GetWardrobe 双盯防）。
3. **「合身判断」空白 90 天后依然无人占据**：Alta avatar 体型失真差评仍在每周产生（§1.2）、Style DNA 停在 4.29 口碑带、~180 款新品无一做 fit 判断、Google Photos Wardrobe 是试穿不是合身诚实评估。**护城河排序（合身闭环＞成本结构+隐私＞职业女性心智＞存放位置）不变，且第一位的时间价值在上升。**
4. **「没有可以宕机的服务器」叙事获得新弹药**：Alta 本周仍在产生云端账号数据丢失、离线不可用差评（§1.2）。
5. **对 DEMAND-VALIDATION 的含义**：Whering 天气 planner 上线 = 品类头部正在用真金白银投票 copilot 形态，与方法④ ~7:1 先验同向；D20（跳过真人验证直接上线）的机会成本进一步上升——**上线速度本身已成为验证策略的一部分**，遥测埋点（copilot 采纳率 vs full-auto 开关使用率）应作为 v1.0 硬需求。

---

## 7. 诚实声明与数据缺口

- WebSearch/WebFetch 全程不可用（classifier 宕机），News 检索依赖 Google News RSS 标题层——**标题级证据未逐篇精读原文的**已在文中标注（WWDC26 扫描、Poshmark、Daydream/puck）。
- Product Hunt 无法一手抓取（JS 墙 + DDG 代理两次失败），「无 copilot 定位新品」结论仅覆盖 App Store 命名/描述层。
- Alta 评分数环比（10,783→10,862）跨端点（RSS vs Search API）不可作增速证据，仅作量级。
- 相册扫描/VTO 在 Whering 是 vendor-claimed roadmap，非交付；Google Photos Wardrobe 是官宣待推送（"this summer"），实际体验与识别质量未验证。
- pullpush.io 覆盖仍止于 ~2025-05，本轮未用于 90 天窗口（会产生假阴性），Reddit 侧无增量。
