# 竞品实际付费证据（R1 验证方法④增量深挖）——2026-07-21

> **定位**：填补 11 号报告（1,484 评论基线）与 DEMAND-VALIDATION §2 未量化的一环——「下载 ≠ 付费」。本轮只挖**实际付费**这个 job 的证据：谁真掏钱、掏完满意还是后悔、买断还是订阅、以及这对 §2「合格访客付费承诺率 ≥2.5%」阈值意味着什么。
> **不重刷**：11 号 §5 已覆盖买断 vs 订阅的陈述性原声（Stylebook "one-off charge only" 等）。本轮增量点＝①硬采用量/付费量对比（iTunes lookup）②市场结构揭示性偏好（最大玩家不向用户收费）③付费后满意/后悔**按变现模式分层** ④对 2.5% 阈值的现实校准。
> **数据源**：iTunes 评论 RSS + iTunes lookup API（一手，2026-07-21 抓取，price/ratingCount/releaseDate）+ pullpush.io Reddit（本轮 429 严重限流，多数取不到，诚实标注）。引用带来源+星级+日期。

---

## 0. 结论速览

| 增量问题 | 本轮判定 | 一句话 |
|---|---|---|
| 这个 job 的付费意愿强度 | **窄且分模式**（买断真、订阅推荐器毒） | 付费几乎只发生在 **$4.99 买断**（Stylebook），且**订阅自主推荐器**（Cladwell＝项目押的机制）的付费口碑已崩 |
| 下载 vs 付费转化 | **付费是严苛的采用过滤器** | 买断金标准 16 年攒 8,701 评分；一个**免费**竞品 16 个月攒 10,783——免费采用速度约 **13×**；纯订阅推荐器（Cladwell）是老牌里体量**最小**（1,013 评分/9 年） |
| 市场结构信号（最强增量） | **最大/最有钱的玩家故意不向用户收费** | Alta（$11M VC）/ Whering（$7M+、1000 万用户）走**购物佣金/转售**变现；成熟资本判定「直接向用户收费」太薄，改押电商 |
| 买断 vs 订阅偏好 | **买断＝愉快付费，订阅＝信任赤字** | 买断后悔罕见且轻；订阅（Cladwell/Style DNA）付费评论被「乱扣费/退不掉/推荐不值」淹没；唯一被接受的订阅（Indyx）**要免费用满约 1 年才转化** |
| 对 §2 ≥2.5% 阈值 | **可守，但须用买断框架测；失败＝歧义而非证伪** | 该品类真实付费是**价值门控 + 高延迟**（Indyx ~1 年）；落地页定金测的是价值交付**前**的意向，2.5% 冷启达标是强信号，未达不能证伪需求 |

---

## 1. 硬数据：采用量 vs 付费量（iTunes lookup API，2026-07-21）

价格 + 评分总量 + 首发日期，是「下载 vs 付费」最硬的公开代理。关键在于**唯一一个买断上架的 App（Stylebook）里，每条评分≈一个付费者**（付费下载＝购买），因此它的评分总量是本品类「愿为此 job 掏钱」的**可核验地板**。

| App | 价格 | 评分总量 | 均分 | 首发 | 存续 | 解读 |
|---|---|---|---|---|---|---|
| **Stylebook** | **$4.99 买断** | **8,701** | 4.68 | 2009-10-29 | ~16 年 | **付费者代理天花板**：16 年攒 8,701 个「掏了钱还来评分」的人 |
| Alta | Free | 10,783 | 4.88 | 2025-03-13 | ~16 月 | **免费**，16 个月就超过买断金标准 16 年的累计 |
| Whering | Free | 10,756 | 4.67 | 2020-08-20 | ~6 年 | 免费，1000 万下载（WWD，11 号已核） |
| Style DNA | Free（订阅） | 7,368 | 4.29 | 2018-08-05 | ~8 年 | 订阅造型，口碑崩（见 §3.3） |
| Pureple | Free | 6,120 | 3.94 | 2013-04-05 | ~12 年 | — |
| Fits | Free | 4,707 | 4.61 | 2023-05-15 | ~3 年 | — |
| Acloset | Free（订阅） | 4,431 | 4.39 | 2021-03-12 | ~5 年 | 450 万注册 / 50 万 MAU（89% 不活跃，11 号已核） |
| Indyx | Free（订阅） | 1,445 | 4.78 | 2022-01-20 | ~4 年 | 订阅但被真心付费（见 §3.4） |
| **Cladwell** | **Free（订阅）** | **1,013** | **4.27** | 2017-03-15 | ~9 年 | **项目押的机制（自主订阅推荐器）＝老牌里体量最小、均分近最低** |
| GetWardrobe | Free | 754 | 4.29 | 2013-08-10 | ~12 年 | — |
| Doji | Free | 146 | 4.11 | 2025-05-06 | ~14 月 | 纯试穿，枯竭（11 号已核） |

**三条量化推论：**
1. **付费是残酷的采用过滤器**。买断金标准 Stylebook：8,701 评分 / 16 年 ≈ 544/年。免费的 Alta：10,783 / 1.3 年 ≈ 8,300/年——**每单位时间快约 13×**。同一个 job，收 $4.99 就把采用速度压到免费的 ~1/13。
2. **纯订阅自主推荐器没有跑出来**。Cladwell 是「每日推荐先驱」，9 年只 1,013 评分、均分 4.27（除 Pureple 外最低）。项目押注的正是这个机制形态，而它是老牌竞品里**footprint 最小、满意度最低**的一个。
3. **免费订阅制 App 的付费转化在此数据里不可见**，但可交叉推断：Acloset 450 万注册 / 50 万 MAU，即便按 freemium 慷慨的 2–5% MAU 付费转化，也仅 ~1–2.5 万付费者——对 450 万注册是**极薄的转化**（11 号「89% 注册不活跃」的付费面延伸）。

> 诚实边界：评分数≠下载数（评分/下载比通常 1–3%，因 App 而异），但**买断 App 的评分≈付费者**这一点使 Stylebook 的对比高保真；免费 App 的绝对付费转化 % 需 Sensor Tower 付费层，本轮不可得（见 §7）。

---

## 2. 市场结构揭示性偏好：最大玩家故意不向用户收费（最强增量）

**这是本轮最重要的新信号**，超出 11 号「陈述性买断偏好」的层次——它是**资本与产品的揭示性偏好**：

- **Alta（本品类最强新竞品，$11M VC，11 号已核）** 与 **Whering（1000 万用户、$7M+，WWD 已核）** 都**故意不向用户收订阅**，改走**购物佣金 / 二手转售**变现。两家最有钱、最大的玩家，都判定「直接向用户收费做这个 job」太薄，转而押注电商中介。这不是没想到收费，是**算过账后选择不收**。
- Alta 评论区**零条自发的「我愿意付费」**，取而代之的是对免费的惊叹与对「别家老推订阅」的反感：
  - *"How is this free?!"* — Alta，5★，2026-07-18
  - *"no premium or pay which is ABSOLUTELY AMAZING and no limit to clothing pieces"* — Alta，5★，2026-07-10
  - *"they don't constantly push a subscription on you like all the other apps do"* — Alta，5★，2026-07-19
  - *"Can't believe it's free 😍"* — Alta，5★，2026-07-18
- Whering 同构：
  - *"I didn't have to pay a subscription and it helps me organize"* — Whering，5★，2026-06-17
  - *"No ads or subscriptions necessary 10/10"* — Whering，5★，2026-05-20

**含义**：免费的头部玩家正在**主动把市场的付费预期训练到零**。任何在 2026 上市的**付费**产品，必须先翻越「Alta/Whering 都免费，我凭什么付你钱」这道墙——付费意愿不是在真空里测的，是在一个被免费补贴过的市场里测的。

---

## 3. 付费后满意 / 后悔——按变现模式分层（新颗粒度）

11 号把「买断 vs 订阅」当一个维度谈。本轮把**付费后情绪**按四种变现模式拆开，差异极大：

### 3.1 买断（Stylebook $4.99）＝愉快付费，后悔罕见且轻

- *"Best $5 I've ever spent"* — Stylebook，5★，2026-06-05
- *"SO worth the $5, if not much more"* — Stylebook，5★，2025-09-12
- *"This app is $5- but it's a one time payment but SO WORTH IT"* — Stylebook，5★，2025-11-21
- *"Not being a subscription service is also a major perk"* — Stylebook，5★，2026-02-14
- *"Best $$ I've ever spent"* — Stylebook，5★，2025-10-12

后悔面**存在但稀薄且温和**（无「乱扣费/退不掉」类愤怒，因为一次性）：
- *"I wasted my time. I don't need the app to do it all myself"* — Stylebook，1★，2026-01-16（后悔的是没用上，不是被骗钱）
- *"Unfortunately it seems that Apple doesn't allow refunds for this app"* — Stylebook，1★，2025-11-03（想退但金额小、非订阅纠纷）

### 3.2 订阅自主推荐器（Cladwell）＝**项目押的机制，付费口碑已崩**（最决定性）

Cladwell＝「自主 + 订阅 + 每日推荐」，与项目押注的机制**几乎同构**。它的付费评论是灾难：

- *"I've paid them AT LEAST $150 for this app subscription. That's crazy."* — Cladwell，2★，2025-02-01
- *"paying $8/month was ridiculous"* — Cladwell，2★，2025-02-01
- *"For $60 a year, there have been very little changes or improvements."* — Cladwell，3★，2025-01-05
- *"But not $60 a year good."* — Cladwell，3★，2025-07-29
- *"This app is an overall scam and I do not recommend anyone to get it!"* — Cladwell，2★，2026-01-02

**且付费的核心交付物——每日推荐本身——被判定不值订阅**：
- *"outfit suggestions… absolutely ridiculous"* — Cladwell，2★，2025-07-25

计费信任赤字（订阅特有）：
- *"Kept billing me after cancelling"*（2022 删号仍被扣数年）— Cladwell，1★，2025-10-05
- *"I have been trying to cancel for a year and they keep charging me."* — Cladwell，1★，2023-06-08
- *"Beware - they took my money and will not give me access to the app."* — Cladwell，1★，2026-06-21

> **这是本轮对 R1 机制之争最重的证据**：与项目押注最像的产品，其**付费**情绪是毒的——不仅骂价格，还骂「订阅买到的推荐不值」。§0 的「推荐器 vs 规划器」之争，在付费层再得一票**警告**。

### 3.3 订阅造型（Style DNA）＝订阅≈信任欺诈的代名词

近期评论几乎是订阅陷阱控诉合集，付费＝愤怒：
- *"They're charging me almost $30/month for a $5 monthly subscription. Never even downloaded the app."* — Style DNA，1★，2026-07-20
- *"I unsubscribed 6 months ago & you keep billing me"* — Style DNA，1★，2026-04-23
- *"Was charged almost $60 over three months despite deleting the app after 5 minutes."* — Style DNA，1★，2026-01-30
- *"I want to cancel and this app has no cancel"* — Style DNA，1★，2026-06-04

### 3.4 订阅但被真心付费（Indyx）＝唯一正面订阅信号，但**付费延迟约 1 年**

Indyx 是**唯一**订阅被由衷认可的案例，且揭示了付费的**时序**：

- *"It is the only app I pay for and it's totally worth it."* — Indyx，5★，2026-07-16
- *"After using the free version for about a year I switched to the paid one, and I have not regretted it!"* — Indyx，5★，2026-06-27
- *"I purchased the upgrade after a year of use; it does provide a much better app experience"* — Indyx，4★，2026-07-07
- 而付费的边界：*"I pay for the subscription to support the owners but the features aren't super compelling"* — Indyx，4★，2026-07-13（为情怀付，非为价值付）
- 付费墙怨言：*"the calendar function is essentially unusable for anyone without a paid membership"* — Indyx，1★，2026-07-07

> **关键时序含义**：本品类真正掏订阅费的人，**先免费用满约一年、价值被验证之后**才转化。付费是**价值门控 + 高延迟**的，不是落地页首触就发生的。

---

## 4. 买断 vs 订阅：增量证据（超出 11 号 §5）

11 号 §5 已列买断陈述性偏好。本轮**新增**的是**跨模式的付费后情绪对照**，把「偏好」升级为「揭示」：

| 变现模式 | 付费后情绪 | 代表证据 | 增量结论 |
|---|---|---|---|
| **买断 $4.99**（Stylebook） | 愉快、稳定、后悔轻 | "Best $5 I've ever spent"（2026-06） | 唯一**耐久的愉快付费**模型 |
| **订阅·自主推荐器**（Cladwell） | 毒：价格怒 + 推荐不值 + 计费不信任 | "$150… That's crazy"（2025-02）+ "suggestions absolutely ridiculous"（2025-07） | 项目押的机制，付费口碑最差 |
| **订阅·造型**（Style DNA） | 欺诈级：退不掉/乱扣费 | "keep billing me… never downloaded"（2026-07） | 订阅＝品类信任赤字放大器 |
| **订阅·被赚得**（Indyx） | 正面但**延迟 ~1 年** + 部分为情怀付 | "free version for about a year… then switched"（2026-06） | 订阅**可行但价值门控、慢** |
| **免费**（Alta/Whering） | 惊叹「怎么免费」，零付费意向 | "How is this free?!"（2026-07） | 头部把付费预期训练到 0 |

跨模式补充锚（11 号已有、本轮复核仍成立）：
- *"If it was a one time charge I would pay it, but I will not be paying for a subscription."* — Acloset，1★，2024-09-07（买断愿付 / 订阅拒付的最直白单条）
- *"I almost did a lifetime membership of $100 just to find out it can not even recommend outfits based on the correct weather."* — Acloset，2★，2026-05-12（**买断/lifetime 付费的前置条件＝试用期能验证推荐质量**）

---

## 5. 价格锚（增量锐化）

| 锚 | 数值 | 情绪 | 来源 |
|---|---|---|---|
| **愉快买断天花板** | **$4.99 一次性** | 耐久 5★，"best $5 I ever spent" | Stylebook 多条（2025-09 ~ 2026-06） |
| 订阅被接受的**唯一**条件 | 每日活跃 + 价值验证满 ~1 年 | 正面但少、部分为情怀付 | Indyx（2026-06/07） |
| 订阅反感线 | **$8/月即被骂** ridiculous | 怒 | Cladwell（2025-02） |
| 年费质疑线 | $60/年 "not worth" | 失望 | Cladwell（2025-01/07） |
| lifetime 犹豫线 | ~$100，**须先证明推荐质量** | 观望 | Acloset（2026-05） |
| 免费基线（新增） | $0（Alta/Whering 补贴） | 惊叹、零付费意向 | Alta/Whering（2026-05~07） |

**增量结论**：付费意愿的「甜点」是**买断 ~$5、最多到低两位数 lifetime**，且付费的**前置条件是价值可被快速验证**（Acloset "先证明能按正确天气推荐我才买 $100 lifetime"）。订阅在这个品类是**逆风**，除非做到 Indyx 那样的高频价值 + 长信任跑道。

---

## 6. 对 §2「付费承诺率 ≥2.5%」阈值的现实校准

DEMAND-VALIDATION §2 的北极星是**合格访客付费承诺率 ≥2.5%**（可退定金 / $15 终身预购）。本轮证据给出三条校准：

1. **阈值本身可守，但它测的是「价值交付前的意向」，而真实付费是「价值门控 + 高延迟」**。品类里真掏订阅费的人（Indyx）要**免费用满约 1 年**才转化。因此落地页冷启定金测到的，是被压缩到「交付前」的付费意向——**2.5% 冷启达标＝强信号**（它跑赢了品类真实的慢付费现实）；但**未达 2.5% ≠ 证伪需求**，可能只是该 job 天然付费晚，而非无人付。→ 建议把「付费承诺率」在决策规则里**从硬 KILL 判据降为强正向 tie-breaker**，与访谈/A-B 提升联判。

2. **必须用买断框架测，别用订阅框架**。本轮铁证：买断＝唯一耐久愉快付费（Stylebook $5），订阅自主推荐器＝付费口碑已崩（Cladwell）。若落地页用**订阅**做定金/预购，测出的低数字会因「品类订阅逆风」而**系统性低估真实需求**。§5.2 已建议「买断或诚实低价订阅二选一」——本轮把它**收敛为：预购测试锚定 $15–20 lifetime 买断**，与 Stylebook 愉快付费带对齐，让 2.5% 测的是「这个 job 值不值一次性掏钱」而非「你愿不愿再背一个订阅」。

3. **2.5% 要在「免费基线墙」前读**。Alta/Whering 免费且被赞爆，定金页文案必须让差异化价值（场合/日历推荐器）翻过「凭什么不用免费的」这道墙。换言之，**付费承诺率同时在测「差异化是否强到值得脱离免费锚」**——这与 §2「V1/V2 提升比」测的是同一枚硬币的两面：若付费承诺低 **且** V1/V2 提升 <1.2×，是「差异化不足以拉动付费」的双重证伪；若付费承诺低 **但** V1/V2 提升高，则更可能是「品类付费晚 + 框架/免费墙」压低了数字，需延长样本再判。

**一句话校准**：≥2.5% 是**合理的强信号线**，但应（a）用**买断框架**测、（b）读作**tie-breaker 而非硬 KILL**、（c）与 V1/V2 提升联判以区分「差异化不足」与「品类付费晚」。价格锚建议 **$15–20 一次性预购**，而非订阅定金。

---

## 7. 诚实声明与局限

1. **下载 vs 付费的绝对转化 %（Sensor Tower 付费层 / data.ai）本轮不可得**——付费数据在 paywall 后，WebSearch/exa 前几轮失效未重试。用**买断 App 评分≈付费者**（Stylebook）+ **免费/付费评分速度对比** + **Acloset 注册/MAU** 三角推断，方向高置信，绝对转化率为推断。
2. **Reddit「is X app worth paying」增量本轮基本取不到**：pullpush.io 全程 429 严重限流（curl 与 WebFetch 双路径均触发），且其覆盖止于 ~2025-05。唯一成功的一次检索（r/FFA "worth paying"）显示该短语在 FFA 几乎只用于**实体衣物**而非 App 付费——App 付费讨论在可及语料里本就稀薄。故 Reddit 侧仍沿用 11 号已抓取的买断原声（Stylebook "one-off charge only" 等），本轮**未新增** Reddit 付费原声，如实标注。
3. iTunes 评论 RSS 每 App 仅最近 ~150 条，且本轮与 11 号同为 2026-07-21 抓取——本报告的增量**不在新评论，而在按「付费/变现模式」重新抽取与量化**（付费后情绪分层 + lookup 硬数字），非重复 11 号的功能维度。
4. Alta/Whering 融资额（$11M / $7M+）与用户数（1000 万）沿用 11 号已核来源（WWD 等），本轮未重核。
5. 引用均带来源+星级+日期，高保真；经 WebFetch 摘要器规整的少量表述按方向性看待。

---

## 8. 来源

- iTunes lookup API（一手，2026-07-21）：`https://itunes.apple.com/lookup?id=<ids>&country=us`（price/userRatingCount/averageUserRating/releaseDate）
- iTunes 评论 RSS（一手，2026-07-21）：`https://itunes.apple.com/us/rss/customerreviews/page=1/id=<appId>/sortby=mostrecent/json`；appId：Stylebook 335709058、Cladwell 1140550878、Acloset 1542311809、Style DNA 1358319821、Indyx 1599179405、Alta 6481705400、Whering 1519461680
- pullpush.io Reddit（本轮多数 429，仅 r/FFA "worth paying" 一次成功，内容多为实体衣物付费，相关性低）
- 沿用 11 号已核：WWD（Whering 1000 万用户/$7M）、韩经（Acloset 450 万会员/50 万 MAU）、Alta $11M VC

---
---

# 【第二增量 · 2026-07-21】ICP 筛选分裂 + 推荐器 vs 规划器

> 上半篇（§0-§8）挖「实际付费」。本增量挖另两个未量化前瞻信号：
> ① **ICP vs 干扰项的可辨识分裂**（决定招募 screener 能否精准筛入 ICP、筛出干扰项）；
> ② **R1 决定性机制歧义**「算法替他们决定（推荐器） vs 帮他们自己规划的工具（规划器）」。
> 数据源：pullpush.io Reddit（r/femalefashionadvice、r/capsulewardrobe，本 session 6 组查询成功后 API 退化返回空，见末尾诚实声明）+ iTunes RSS（Indyx 1599179405、Alta 6481705400，各 ~150 条 = 约 300 条一手评论）。

## B1. 一句话结论

两群体可清晰分离，但边界不是「胶囊 vs 非胶囊」，而是「是否已用**做减法**把决策问题彻底消灭」。决定性机制答案强烈偏**规划器/副驾**：市场最被爱的 **Indyx 几乎没有自主日推荐器（纯手动策展+日历），却是口碑之王**；有自主推荐器的 **Alta，其「AI 自动配的」恰是差评首因，连五星粉丝都退回手动**。screener 应按行为标记（大衣橱/忘记拥有/重复购买/想显得得体）筛入 ICP，按「我穿制服/刻意精简/这对我不是问题」筛出干扰项。

## B2. ICP vs 干扰项：三分而非二分（关键精修）

原 §0 假设「做减法者 = 干扰项」。数据精修为**三分**——「胶囊人群」内部本身分裂：

**群体 A：真干扰项 —「做减法以消灭工具需求」**。制服/连衣裙/极端精简，自述问题已解决，不需也不会用 App。语言：`same thing every day` / `uniform` / `decision fatigue is not a thing` / `just put the dress on and go`。
- *"I wear the same set of jewelry every day to minimize decision fatigue."* — u/oxfordblue100，r/FFA，2024-11
- *"Decision fatigue is not a thing for me, getting dressed is a creative activity."* — u/No-Cold6085，r/FFA，2024-10
- *"I own a ton of dresses because I can just put the dress on and go, whereas whenever I need to pair two things... I dither for ages."* — u/boopbaboop，r/FFA，2024-01
- *"dresses reduce my decision fatigue."* — u/EmeraldEyesAlyssa，r/FFA，2024-07

**群体 B：App 化的策展者 —「做减法但配规划工具」**。身处 r/capsulewardrobe 却积极用衣橱 App——当**规划器**用（shop-my-closet / 日历排班 / cost-per-wear / 显得得体）。不是干扰项，是缩小版 ICP；naive「你用衣橱 App 吗」会把他们与 ICP 混淆，但机制诉求同样是规划器。
- 手动给每天上色标签 + 「显得得体」：*"since I've started using the app... making much better use of my wardrobe... It's definitely helping me look more put together."* — u/Elpeep（ACloset），r/capsulewardrobe，2025-04
- 夜里手动把明天整套（含鞋）排进 App 日历：*"this in when I start planning my outfit for tomorrow. I make the whole thing including the shoes then I pop it onto the calendar."* — u/Ecstatic-Battle-6463，2025-04

**群体 C：ICP 本体 —「衣橱大、忘记/用不上、想显得得体」**。App 采纳者语料由 C 主导。语言：`huge/big closet` / `forget what I own` / `too many clothes` / 满柜前的 `nothing to wear` / `look put together / elevate my style`。
- *"I own so many clothes, but... I often forget what I own and don't optimize the items I already own, which often results in me buying more clothes I don't need because I constantly feel like I have nothing to wear."* — Indyx 5★（**ICP 心声模板**：大衣橱+忘记+重复购买+满柜没得穿）
- *"I have major organizational issues and a huge closet... see the things shoved deep in drawers to be forgotten."* — Indyx 5★
- *"I have too many clothes in my closet. This app helps me to not feel so overwhelmed."* — Alta 5★
- ADHD object permanence（ICP 最锋利自我描述轴）：*"I will literally forget I own something if I don't see it all the time. Object permanence is still a struggle!"* — u/ProseNylund，r/FFA，2021-08；*"I've got adhd so my... object permanence is pretty bad, I often would buy fun weird pieces and then not use them."* — u/bubblegumdavid，2024-01
- 大衣橱确存在于这些 App：*"Some people have less than 100, some have over 1000."* — u/External-Ad-5813（Indyx），2025-04

**相对规模（方向性）**：泛时尚社区里群体 A 声量最大——r/FFA「decision fatigue」串前 14 条 top 评论几乎全走减法，近 0 求工具（→ naive 需求调研过采样干扰项）；但在**真正采纳衣橱 App 的揭示性转化者**里，ICP 语言压倒性主导。这正是 screener 必须按行为筛而非态度问卷筛的原因。

**正确排除信号（部分证实，偏"太麻烦/我已知道"而非"我不需要"）**：
- *"[closet apps] where you upload photos of every single item (thank goodness—I do NOT have time for that 😅)."* — u/byefelicia84，2025-04
- 拒绝 App + 自述「我已经知道我有什么」（= 无 object-permanence 痛 = 非 ICP）：*"I didn't like any of the wardrobe specific apps, so I'm trying to make my own in Obsidian... I don't care about statistics like how often I've worn an item, because I know what I wear regularly."* — u/girlenteringtheworld，2025-03

## B3. 推荐器 vs 规划器 —— 强烈偏规划器/副驾

**B3.1 最硬单证：Indyx（≈纯手动规划器）是口碑之王。** 动词清一色规划器动词（plan 几十次 / catalog / calendar / shop my closet / lay out）。核心价值是把**已自己决定好**的成套排进日历、早晨零思考——不是算法每早现配：
- *"assign [outfits] to days in the calendar so I don't have to do any thinking in the morning before work."* — Indyx 5★
- *"I get to online shop in my own closet each night to choose an outfit for the next day."* — Indyx 5★
- **反证铁证**：有用户把「自主推荐器」当**缺失功能许愿**——证明被爱的核心里根本没有它：*"potentially an AI stylist to sort through the closet and suggest outfits."* — Indyx 5★

**B3.2 Alta（有自主推荐器）——「AI 自动配」是差评首因，五星粉退回手动：**
- *"The outfits it puts together automatically don't work in real life... didn't make getting dressed any easier."* — Alta 3★
- *"most of the ai outfits it recommends are crazy and don't match."* — Alta 4★
- 主动退回手动：*"i honestly use it more to log outfits and see what i haven't worn than to generate new ones."* — Alta 4★

**B3.3 被爱的 AI = 用户播种/可改写的副驾**（= 「你选场合→我帮你配」）：
- *"I can choose the item I want to wear, like a pair of shoes, and it will design an entire outfit around the shoes."* — Alta 4★
- *"any suggestion Alta Daily makes can be easily restyled, and the App learns your preferences."* — Alta 5★
- 天气自主推荐再失手：*"Liked the idea of AI offering you outfits based on weather but the combos didn't really work."* — u/Fun-Satisfaction5748（Whering），2025-05

**B3.4 营销 tell**：被抓的 Kalyxa 推广号（u/Parth_Kalyxa，模板文案）主打的正是**推荐器**——*"the AI suggests outfits for you every morning based on the weather and the occasion... takes the decision-making out of getting dressed."*——而有机用户几乎无人这样夸。**「算法替你决定」是营销话术，「帮你自己规划」是真实留存价值。**

## B4. 对 screener 与验证的直接含义

**筛入 ICP（≥2 命中，行为优先）**：大衣橱 100+ 件 / 「因忘记买重过同类」/ 「out of sight out of mind」/ 想在职场显得 put-together / 满柜前仍「nothing to wear」。
**筛出干扰项（任一命中）**：「每天穿制服/同一套（有意）」/「刻意保持衣橱小」/「决定穿什么不是问题/已解决」/「我清楚我拥有的一切」/ 专挑连衣裙就为免搭配。

**机制路由题**（问卷/访谈，中立二选一）：「如果有个工具帮你，你更想它 (a) 直接告诉你每天穿什么，还是 (b) 帮你自己从你的衣服里搭好、排好？」——预期强偏 (b)；若反常偏 (a) 须回查。
**行为筛**：「你用过衣橱 App 吗？用来干嘛、坚持了吗？」——ICP 转化者描述 planning/cataloging/shop-my-closet；若描述「想让它自动决定、因 AI 太烂弃用」→ 吻合推荐器失败模式。

**对 A/B 落地页（方法②）预判**：本轮语料预测 **V2（规划器）胜出或不输 V1（推荐器）**。若 V1 显著打赢，是与竞品揭示性证据相反的强信号，须优先解释（可能是新鲜感非机制真需求）。本增量是 A/B 的**先验强化**，不替代它——真正裁决器仍是 V1/V2 提升比。

## B5. 量化速览

| 信号 | 量化 | 出处 |
|------|------|------|
| r/FFA decision-fatigue 串减法自救占比 | ~14/14 top 评论走减法，近 0 求工具 | pullpush 2023-2025 |
| App 采纳者主导语言 | Indyx+Alta ~300 条，五星几乎必含 plan/catalog/calendar/shop-my-closet；ICP forget/too many/huge closet 高频 | iTunes RSS 2026-07-21 |
| 推荐器机制差评聚集 | 「自动配不能用/AI 乱配」几乎全落在有自主推荐器的 Alta；无它的 Indyx 机制差评≈0 | 同上 |
| 反证铁证 | Indyx 用户把自主推荐器当缺失功能许愿 | Indyx 5★ |

## B6. 诚实声明（本增量）

pullpush 本 session 前 6 组查询成功后退化：`q=wardrobe&subreddit=femalefashionadvice` 返回 0 条（对高频词不可能），判为搜索后端限流/退化。AskWomenOver30「周日规划一周」未新抓，沿用基线 §0 的 5+ 条，相对规模为方向性非普查。App Store 五星有平台/水军美化倾向（Alta 马甲、Kalyxa 推广号本轮亦见）。推荐器 vs 规划器结论高一致（本轮 + 11 号 §1.2 三大执行失败 + Indyx 纯规划器口碑之王，三源互印），但为观察性揭示证据、非实验——最终裁决器是方法② A/B 的 V1/V2 提升比。

---
---

# 【第三增量 · 2026-07-21】推荐器 vs 规划器：扩样 Reddit 语料 + copilot 第三态 + A/B 校准

> 前两篇（§0-§8 付费证据、B1-B6 ICP 分裂）已用 Indyx/Alta 的 iTunes 数据给出「偏规划器」的判定。本增量**不重复**，只补三样它们没有的：① 一个**大得多的 Reddit 语料**直接量化「替我决定 vs 帮我规划」的相对频率（r/FFA「wardrobe app」主线程 100 条 + Cladwell/capsulewardrobe 83 条 + pick/plan my outfits 串）；② 一个被前两篇漏掉的**决定性第三态——copilot（我选/它补全）**，它才是真正的赢家形态；③ 对 §2 A/B 的**可执行文案校准**与社区选择偏差的**倍数下调**。
> 数据源：pullpush.io Reddit（本 session 冷却后成功取到 6 组，含 wardrobe-app/ffa 100 条、Cladwell/capsulewardrobe 83 条、Indyx/ffa 21 条、pick-my-outfits/ffa 18 条、plan-my-outfits/capsulewardrobe 20 条、tell-me-what-to-wear/ffa 50 条）+ iTunes RSS 750 条去重（关键词桶：control/planner 78 条、algorithm-learn/dumb 10 条）。引用带来源+日期。

## C1. 相对频率：规划/掌控语言 ~3-4:1 压过「替我决定」

把「用户描述理想解法」的语言按机制归类，规划器/掌控阵营在两个独立语料里都主导：

- **享受挑衣服、明确不想外包决策本身**（掌控为价值，非苦差）：
  - *"I enjoy picking my outfits and don't give a shit optimising productivity in my life."* — u/44morejumperspls，r/FFA，2021-10-08
  - *"The one thing getting me excited about the work week is picking my outfits."* — u/fusukeguinomi，r/FFA，2024-09-15
- **把「决策时点」前移而非把「决策」交出去**（周日/前夜自己排一周）：
  - *"I pick my outfits for the week every Sunday night. Full outfits, down to the jewelry and the shoes."* — u/87cotton，r/FFA，2017-06-27
  - *"I like not having to think about what to wear in the morning, so it's nice to have a schedule to fall back on... my preference for pre-planning things."* — u/coffee_for_dinner，r/FFA，2019-07-25
- **衣橱 App 被当 track/plan/inventory 用，DIY 规划工具并存**（未满足需求＝强掌控偏好）：
  - *"I prefer using **Canva. Google slides or PowerPoint**... a slide deck with one slide for each category, and then I copy and paste items onto other slides to make outfits."* — u/KingPrincessNova，r/FFA，2023-08-08
  - *"inventory all of your clothes, plan your outfits and see your cost per wear go down."* — u/jeweledbeanie，r/FFA，2024-05-12

对照「想要算法替我决定」——真实存在但**明显更少、且常自带小众限定**：
- *"You dont have to think of what to wear anymore — **if that is your thing because it certainly is mine.**"* — u/mlee001（Cladwell），r/capsulewardrobe，2020-10-06（"if that is your thing"＝作者自知是少数派）
- *"so helpful making an outfit as **an indecisive person**."* — Acloset 5★，2025-07-22
- episodic「替我决定」渴望多指向**真人造型师/社区**、发生在**人生低谷/过渡期**，非日推算法：*"I don't have the energy... just looking for someone to tell me what to wear"*（u/ac0380，r/FFA，2021-11-05，情绪低落）；*"someone tell me what to wear when I go back to my office"*（u/FancyGood7，r/FFA，2021-06-16，重返办公室）。

> 量化（方向性）：iTunes control/planner 桶 78 条 vs algorithm-learn/dumb 桶 10 条（后者全负面）；Reddit 两大线程里规划/掌控表述对「替我决定」表述约 **3-4:1**。两独立语料同向。

## C2. 弃用原声再证：自主日推「学不会/推得蠢」集中在 Cladwell + Acloset

问题③命中，且新增「爱 App 却弃推荐器」的决定性叙事——**推荐器是可切掉的负资产，追踪器才是留存核心**：

- *"Cladwell creates ridiculous outfit suggestions, and **the algorithm refuses to learn. Nothing you tell the app changes the nonsense it produces.**"* — Cladwell 1★，2026-03-12
- *"I still get the same clothes suggested almost every day. **Shouldn't the algorithm be smarter than that?**"* — Cladwell 2★，2021-12-29
- *"**I love Cladwell, but I don't use it for outfit recommendations, it's awful at that.** I've found it really helpful for understanding the items that work for me... tracking it helped me."* — u/plceswedontknow，r/capsulewardrobe，2023-12-24
- *"I think their **recommender system is really bad**."* — u/sennen_goroshi_，r/capsulewardrobe，2019-10-23
- *"The **outfit algorithm is a joke.** But it does sometimes give me ideas."* — u/lulubird6，r/capsulewardrobe，2022-01-16
- *"whatever AI they are using isn't helping put anything together that resembles a decent looking outfit... I'm not finding any creative value that **relieves me of the outfit conundrum**."* — u/Soft_Signature，r/capsulewardrobe，2025-05-09

## C3. 被前两篇漏掉的决定性第三态：copilot（我选，它补全）

问题的真答案不是「推荐器 vs 规划器」二元，而是三态——**赢家是 human-in-the-loop 的 copilot：用户保留选择权，App 做补全/建议/腿部工作。full-auto（autopilot）恰是被弃用的那一面**：

- **最清晰单证**（她爱「我选几件→AI 补全」，恨「给一件就自动成套」，直接因此退订）：
  *"I liked the **'make your own outfit' option in which I would pick a few items and AI would suggest what to add** to complete the look. This is no longer available. Only option is to pick one item and AI completes the outfit. **Dislike this. Will not renew.**"* — Acloset 2★，2025-10-12
- 推荐器只在用户**先自建候选集**后才被夸（last-mile 辅助，非自主驱动）：*"Now that I've got a decent capsule together **Cladwell does the rest**, and suggests items that I might be missing."* — u/missseesaw，r/capsulewardrobe，2020-03-10
- 甚至有人明确要**没有 AI**的工具：*"Does anyone know of an outfit organizer app that **doesn't use AI**? ... I have moral concerns."* — u/Dospunk，r/FFA，2024-09-17

**产品含义（跨 GO/PIVOT 都成立）**：默认 copilot（我选场合/主件/心情→在我自有衣橱内补全 + 按天气/日历硬过滤 + 防重复），把 full-auto 日推做成**可选开关**而非默认——这正是 V2 文案「You decide, it does the legwork」已编码的形态。

## C4. 对 §2 决策规则与 V1/V2 A/B 的先验含义（本轮净增）

1. **先验：V1/V2 提升比很可能 < 1.0**，几乎不可能自然到 GO 所需 ≥1.5×——把先验推向 **PIVOT 带**（真需求、错楔子）。**但这是先验，A/B 揭示性数据仍压过它，须实测**（与 §2「揭示性压过陈述性」一致）。
2. **可执行文案校准（新）**：当前 V1「One suggestion each morning, built from the clothes you already own」**已不是纯 autopilot**（"from the clothes you already own" 含掌控味），会与 V2 的差异被稀释、读不出决定性信号。若要真正隔离「推荐器 vs 规划器」这个自变量，V1 应更硬地测**纯自主日推**（如 "Open it and just wear what it picks"）；否则 A/B 的 lift 会失真。
3. **社区选择偏差 → 下调 Reddit 倾斜的绝对倍数（新）**：r/FFA、r/capsulewardrobe 天然聚集「享受挑衣服」的 hobbyist，会**高估**规划器阵营、**低估**急性决策疲劳/「替我决定」人群（后者更可能根本不泡时尚社区）。故 3-4:1 有一部分是社区自选伪影。但 App Store（更广人群）独立显示自主推荐器是 1-2★ 爆点——**方向稳健，倍数保守看**。
4. **推荐器不归零**：真实的急性决策疲劳小众存在（"indecisive person"、重返办公室、产后、体重变化）。若 V1 意外打赢，恰恰筛出这个高痛子群，值得单独定价/定位，而非否证 R1。

## C5. 诚实声明（第三增量）

pullpush 本 session 限流极重，14 条计划查询仅 6 条成功（冷却 90s 后单发才通）；「tell me what to wear」在 capsulewardrobe/AskWomenOver30、Stylebook 全文串未取到——**AskWomenOver30 的独立读数仍缺**，其信号靠 iTunes + 基线 11 号补位。pullpush 覆盖止于 ~2025-05，2025H2-2026 由 iTunes（至 2026-07）补位。频率倍数（3-4:1、78:10 桶）为关键词桶定性估计，非精确统计。本增量与 B1-B6 结论同向（偏规划器/copilot），但补了大样 Reddit 语料、copilot 第三态与 A/B 文案校准三处 B 未覆盖的净增值。最终裁决器仍是方法② 的 V1/V2 提升比。

---
---

# 【第四增量 · 2026-07-21】DIY-workaround 群体规模量化（未满足需求强度代理）

> 前三篇（§0-8 付费、B1-B6 ICP 分裂、C1-C5 推荐器/规划器语料）已把「偏规划器/copilot」论证得很扎实。本增量**不重复该机制论证**，只补一个前几轮未量化的独立信号：**已在为「每天穿什么」付出手动成本的 DIY-workaround 群体到底有多大**——用 Notion/表格/Pinterest 自建衣橱系统的人 + 周日/前夜手动摆一周穿搭的人。这批人是「未满足需求强度」最硬的揭示性代理（掏时间 > 嘴上说），且**他们自建什么＝第三类独立于 App 评论的机制证据**。
> 数据源：pullpush.io comment search（一手 curl，2026-07-21），词干化短语匹配 `q="a+b+c"`；14 条查询全部取回（冷却 120s + 20s 间隔规避限流）。**局限**：pullpush 数据止于 ~2025-05；每查询上限 100 条（触顶＝地板值）；本轮未跑 submission 帖级热度，热度以「去重独立线程数」代理。

## D1. 一句话结论

DIY 群体真实且**分裂成规模悬殊的两层**：**「手动提前规划穿搭」是主流大众行为**（`"plan my outfits"` 短语在 ~4 个月窗口即触顶 100 条 / **95 条独立线程 / 横跨 84 个不同 subreddit**），**「数字自建衣橱系统」（Notion/表格）是小而铁杆的 power-user 利基**（低两位数线程、跨越 5-7 年、围绕少数病毒模板自组织）。两层都指向同一机制答案——他们自建的是**规划器/追踪器**（日历预排、记住我有什么、别重复买），几乎无人自建「算法替我决定」的推荐器（唯一一条来自 r/ClaudeAI 的 LLM 极客）——为 C 篇的「偏规划器」再添**第三类独立证据**（DIY 制品 ≠ App 评论 ≠ 融资结构）。

## D2. 量化①：手动提前规划穿搭 —— 主流行为（强信号）

短语 `"plan my outfits"`（词干化，含 planned/planning）：

| 指标 | 数值 |
|---|---|
| 命中评论 / 独立线程 | 100（触顶，全 on-topic）/ **95** |
| 覆盖子版数 | **84 个不同 subreddit**（几乎每条一个不同社区）|
| 时间窗 | 2025-02 → 2025-05（**仅 ~4 个月即触顶 100**）|
| 明确「提前 / in advance / ahead of time」 | 14% |
| 「for the week / 一周量」 | 7% |
| 提到「先查天气」再规划 | 7% |
| 事件/旅行语境（Coachella/festival/cruise/wedding/conference/pack） | 38% |
| 日常/通勤/一周/早晨语境 | 44% |
| 神经多样性语境（autism/ADHD/AuDHD） | 9% |

**判读**：4 个月触顶、横跨 84 子版，说明「提前规划穿搭」是**跨人群的大众行为**（真实年量是此数的数倍）；它**事件驱动（38%）与日常routine（44%）并重**，神经多样性人群是高浓度子段（执行功能辅助）。canonical 原声（＝产品价值主张的手动版）：

- *"I usually **plan my outfits on Sunday night after checking the weather**. In the morning, I would like to just wake up, dress up, eat and leave for work."* — r/femalefashionadvice, 2025-04（**周日+天气+通勤，一句命中 hero**）
- *"I plan my outfits for work **on Sunday—all five hangars in my bathroom in order of the days to be worn**."* — r/neurodiversity, 2025-03
- *"I plan my outfits ahead of time and **set them out at the beginning of the week so I don't have to think about that in the AM**."* — r/FedEmployees, 2025-04
- *"I **always, always plan my outfits the night before**. Down to the jewelry, underwear, socks... it helps me look so much more put together."* — r/selfcare, 2025-04
- *"...articling at a law firm... almost an hour and a half each way... **planned my outfits out for the week**."* — r/LawBitchesWithTaste, 2025-04（高薪职业女性 ICP，长通勤）

## D3. 量化②：数字自建衣橱系统 —— 小而铁杆的 power-user 利基（真实但窄）

| 短语查询 | 命中/独立线程 | 时间跨度 | 备注 |
|---|---|---|---|
| `"notion closet"` | 15 / 11 | 2017–2024（7 年） | 集中 r/Notion + r/FFA，反复复制同一模板 |
| `"notion wardrobe"` | 8 / 7 | 2013–2025 | r/capsulewardrobe、r/RepLadies、r/techwearclothing |
| `"spreadsheet wardrobe"` | 5 / 4 | 2013–2023 | r/FFA「spreadsheet wardrobe」是十年老梗 |
| `"outfit spreadsheet"` | 38 / 36 | 2012–2025 | **~70% 污染**（Taylor Swift Eras Tour 粉丝追装表、DDLC/游戏 mod 表、Elite Dangerous "outfitting"）；真·个人衣橱表 ≈ 6-8 条 |
| `"pinterest board"`（衣橱语境） | 100 raw / 12 on-topic | 2025-05 | Pinterest 主做**灵感板**，非衣橱盘点 |
| `"airtable"` / `"notes app"`（衣橱语境） | 0 / ~4 on-topic | — | 衣橱用途几乎为零 |

**判读**：数字自建者是**低两位数线程、跨越 5-7 年**的窄利基，但**高度自组织**——同一个 Notion「Closet-Clothing-Tracker」模板与「Wardrobe-Organiser」模板在 r/FFA / r/capsulewardrobe / r/RepLadies / r/Notion 间反复复制，形成病毒式 DIY 制品。这批人正是「愿为这个 job 掏几小时」的最高意向人群。原声（他们建的是数据库+日历+盘点，不是推荐器）：

- *"it's basically **a database for planning outfits and a database for clothing you own with relations... to show the times worn, dates worn**... you can **preplan each outfit in the calendar view**."* — r/Notion, 2022-01（**有人手搓出了产品设想里的「日历预排穿搭」**）
- *"I basically used this... to **keep track of... what I have in my closet so I'm not buying something that has the same purpose. It also gives me an idea what's missing**."* — r/RepLadies, 2022-01（防重复购买＝基线 #1 JTBD）
- *"I do something like this **manually using a spreadsheet**. Wardrobe data can be so eye-opening..."* — r/femalefashionadvice, 2023-10
- 反例（自建推荐器，n=1，LLM 极客）：*"Planning my outfits. **I have an AI that knows all my clothes and looks up the weather and tells me what to wear**."* — r/ClaudeAI, 2025-05

**相对规模排序（衣橱用途）**：手动提前规划（主流，95 线程/4 月/84 子版）≫ Pinterest 灵感板（广泛但用于灵感非盘点）＞ Notion 衣橱库（铁杆利基 ~25 线程/多年）＞ Excel/Sheets 衣橱表（更极客/cost-per-wear 党）＞ Airtable/Notes（可忽略）。

## D4. DIY 系统的痛点 = 产品机会（从 DIY 手里抢用户的楔子）

| DIY 痛点 | 原声 | 产品机会 |
|---|---|---|
| **手动录入、无自动抠图/去背、有上传限制** | *"not having the **auto-cropping background tool** + outfit/ideas maker kinda sucks... I ran into the free version **5MB upload limit**"* — r/FFA, 2024-02 | 秒级拍照录入 + 自动去背（DIY 给不了）|
| **只是静态库、不会生成穿搭** | 同上：*"+ outfit/ideas maker kinda sucks"* | 自动组套/候选（用户仍拍板）|
| **坚持不下来 / 半途弃用** | *"I tried to track my wardrobe for a hot minute... but **I didn't stick to it**"* — r/xxfitness, 2020-01 | 低摩擦 + 每日回路即时回报 |
| **搭建门槛/学习曲线劝退** | *"I've been meaning to use the Notion app as an inventory catalogue, but **learning the keyboard shortcuts is slightly arduous, probably why I haven't started yet**"* — r/shoppingaddiction, 2021-02 | 开箱即用、零配置 |
| **工具碎片化（Notes+表格+Pinterest+Amazon 心愿单并用）** | *"Notes on my phone... Amazon wishlist... 'holes in my wardrobe' page on my wardrobe/outfit spreadsheet... Pinterest is where I put things..."* — r/FFA, 2017-09 | 一个 App 收敛盘点+灵感+缺件+计划 |

**楔子叙事（实锤迁移）**：给逃离 App（撞 100 件付费墙）而投奔 Notion 的人，提供 Notion 的免费/无限/数据自主 + 他们失去的自动录入 + 组套——*"i hit the 100item limit... i've been looking for a completely free way to organize clothes ever since and **just moved most of them to a Notion closet template today**"* — r/FFA, 2024-02。

## D5. 对 R1 判别的含义（接 §2 与 C4）

- **需求侧再加硬证**：有人愿为「每天穿什么」自建数据库、维护表格、周日摆一周衣服——揭示性（掏时间）而非陈述性偏好，把 §0「需求真实~80%」进一步坐实。
- **机制侧第三类证据继续偏规划器**：DIY 制品清一色规划/追踪器，几乎无自建推荐器——与 C 篇（App 评论）、B 篇（Indyx 纯规划器口碑之王）、市场结构三源互印。**支持 A/B 里 V2（规划器）不该输给 V1（推荐器）**；若 V1 大幅碾压反而与 DIY 证据冲突，需警惕新鲜感。
- **量级警示**：数字自建者虽是最高意向人群，但绝对盘子窄（低两位数/多年）；真正可规模化的是「手动提前规划」这层大众行为——产品要赢的是**把手动摆衣服/查天气这套零成本习惯换成更省事的数字规划器**，而非说服 power-user 换掉心爱的 Notion。
- **场合作为用户主动输入的楔子成立**：38% 手动规划是事件/旅行驱动、且是用户自己给出场合再规划——与基线「occasion 只在用户给出场合时被夸」一致；场合应做用户驱动的筛选/提示，非算法自主驱动。

## D6. 诚实声明（第四增量）

pullpush 覆盖止于 ~2025-05（本轮量化是该窗口地板值）；每查询上限 100（`"plan my outfits"` 触顶＝真实量被截断，95 线程/84 子版是保守下限）；未跑 submission 帖级热度（限流 + 输出时限），热度用去重独立线程数代理。短语召回有边界：`"outfit spreadsheet"` ~70% 粉丝/游戏污染（已人工剔除计数），`"pinterest board"`/`"notes app"` 多为非衣橱语境（on-topic 过滤后骤降）——引用均人工核对 on-topic。英文原声高保真（curl 原始 JSON，非摘要器），带子版+年月，permalink 以 `link_id`（t3_*）可追。样本含少量非美用户（AskUK/AskIreland 等），但主体子版以英美职业女性为主，与 ICP 大致吻合。本增量与前三篇结论同向（偏规划器），净增值＝DIY 群体的**规模量化**与**痛点→机会**映射，非重复机制论证。
