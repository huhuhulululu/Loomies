# 21 — 全品类定价基准归纳 + 我们的定价数字建议（2026-07-22）

> 任务：一手拉全品类当前定价 → 结合已有 WTP 证据 → 输出三档具体数字 + 价格实验设计 + StoreKit 价位附录。
> 数据源：iTunes Search API（一手，2026-07-22 当日抓取）+ App Store 产品页 IAP 区块（一手 WebFetch）+ 各家官网（一手/厂商自述）+ Apple Newsroom（一手）。本轮 WebSearch 预算耗尽（200/200），全程走 API + 官方页 WebFetch。
> 基线不重复：WTP 原声与红线见 `MARKET.md §6`、`18-method4-signal.md §8.3`、免费层与付费墙深拆见 `13-competitors-tools.md`。本文为**增量**：全品类当日价目 + 结构规律 + 具体数字裁决。
> 标注：〔first-hand〕官方页/API 一手抓取；〔vendor-claimed〕厂商营销自述；〔inferred〕推断。

---

## 1. 全品类定价基准表（一手，2026-07-22）

### 1.1 总表

| App（App ID） | 下载价 | 免费层边界 | 订阅·月 | 订阅·年 | 买断 | 试用 | 评分/量 | 最近更新 |
|---|---|---|---|---|---|---|---|---|
| **Stylebook** (335709058) | **$4.99 付费下载** | 无免费层（付费即全功能，不卡件数） | — | — | **$4.99**（下载价即买断，页面零 IAP） | 无 | 4.68★ / 8,703 | 2025-06-15（停更 13 个月） |
| **Indyx** (1599179405) | 免费 | **不限件数 + 不限 outfits**（官网明示 Unlimited items/outfits/packing/capsules） | $12.99 | $74.99 | — | 页面未标 | 4.77★ / 1,447 | 2026-07-22 |
| **Whering** (1519461680) | 免费 | 不限件数，核心全免 | 无订阅——credits 制：10/$2.99、50/$7.99、100/$12.99；Outfit Maker $4.99；Supporter 捐赠档 $0.99–$49.99 | — | — | — | 4.67★ / 10,777 | 2026-07-22 |
| **Acloset** (1542311809) | 免费 | **卡 100 件**（"free, for up to 100 items"） | Basic $3.99 / Premium $9.99 / Expert $24.99 | Basic $27.99 / Premium $59.99 / Expert $147.99 | — | 页面未标 | 4.40★ / 4,450 | 2026-07-22 |
| **Cladwell** (1140550878) | 免费 | 玻璃橱窗式：管衣橱+2 capsules+7 outfits（页面自述 freemium） | $7.99（另有季付 $21.99） | $59.99（官网话术 "less than $5 a month"） | — | 页面未标 | 4.27★ / 1,013 | 2026-03-06 |
| **GetWardrobe** (656212466) | 免费 | **卡 100 件**（items+outfits 合并计数，官网 FAQ "no credit card, no catch"） | $4.99 | **$34.99**（App Store IAP；官网另标 "$4.17/mo billed yearly · save 40%" ≈ $49.99/yr web 价，两轨价差在案） | — | 年付档有试用（官网） | 4.29★ / 754 | 2026-06-26 |
| **Pureple** (628106373) | 免费 | 不限件数，卡功能+广告（Style Me/日历/去广告/云同步在墙内） | $14.99；**周付 $6.99**（差评导火索） | $89.99 | 残留档 "Pro Version $14.99"（旧买断 SKU） | 年付 7 天 | 3.94★ / 6,120 | 2026-07-13 |
| **Alta** (6481705400) | 免费 | **全功能免费，页面零 IAP**（VC 补贴 + B2B2C 佣金变现） | — | — | — | — | 4.88★ / 10,862 | 2026-07-21 |

全表下载价/评分/更新日期来自 iTunes Search API（2026-07-22）〔first-hand〕；IAP 价目来自各 App Store 产品页 In-App Purchases 区块（2026-07-22 WebFetch）〔first-hand〕；免费层边界来自产品页描述或官网〔first-hand〕。

### 1.2 各家补充细节（一手，只记增量）

- **Stylebook**：页面文案自我锚定「for less than the price of a latte」〔first-hand〕。品类唯一在售现代买断，且停更 13 个月仍活——买断需求旺盛、供给真空（与 `13-competitors-tools.md` 付费榜 #93 互证）。
- **Indyx**：App Store IAP 仅两条：Monthly Membership $12.99 / Annual Membership $74.99〔first-hand〕。评论区出现「$9 subscription」字样（疑旧价或促销，未证实）〔inferred〕。官网另卖人工造型服务：Lookbook Mini 起 $60 / Lookbook 起 $150〔first-hand〕——订阅之外的第二变现层，解释了它敢把数字衣橱完全免费。
- **Whering**：无任何订阅 SKU。变现 = Style Pass credits（按次 AI）+ 捐赠型 Supporter 档（$0.99–$49.99，命名即「支持者」）〔first-hand〕。用户原声：「if y'all do have to start charging please only do it as a flat fee」（App Store 评论，2026 采集）〔first-hand〕——免费大盘用户的付费偏好也是一次性。
- **Acloset**：三档订阅 + beans 双轨（100 beans $1.99 起）〔first-hand〕。年付折扣率：Basic 42%、Premium 50%、Expert 51%。
- **Cladwell**：IAP 残留档混乱（同名 Cladwell Subscription $9.99/$59.99 多条、旧档 $2.99/$19.99 并存）〔first-hand〕——历史涨价轨迹直接晾在价目表上。
- **GetWardrobe**：AI credits 20/$4.99 → 1000/$89.99 五档；Stylist 档 $69.99/月、**$690/年**（B2B 造型师定价）〔first-hand〕。App Store 年付 $34.99 vs 官网 $49.99 两轨并存〔first-hand〕，是 Style DNA「同名多价」红线的轻度变体。
- **Pureple**：价目表 10 条 SKU 混乱并存（$34.99–$62.99 五档同名 Pureple Subscription）〔first-hand〕；`13-competitors-tools.md` 已记录其两年涨价 30-40% + $95.39 计费纠纷。
- **Alta**：页面零 IAP。评论原声「I'm surprised the features it has are all free right now」〔first-hand〕——用户自己都在等收费靴子落地。

---

## 2. 结构规律归纳（增量发现）

1. **年付 ≈ 月付流水的 48-63%（品类惯例 ~50-60%）**：Indyx 48%、Acloset Premium 50%、Pureple 50%、GetWardrobe 58%、Cladwell 63%〔first-hand 计算〕。定年价时先定月价再打对折是品类通行做法。
2. **年订阅带 $27.99–$89.99，主力档中位 $59.99；月订阅主力档中位 $9.99**〔first-hand〕。而 WTP 证据的现实带是 $30-50/年、$60/年已被质疑（MARKET §6）——**品类主流定价压在用户反感线上沿**，这正是差评里 34% 涉付费墙的价格侧解释。带内唯一玩家是 GetWardrobe $34.99。
3. **免费不限件数已是好评组的统一姿势**：Whering/Indyx/Alta（评分 4.67-4.88）全部不限件；卡 100 件的 Acloset/GetWardrobe（4.40/4.29）和玻璃橱窗的 Cladwell（4.27）整整低一个档位〔first-hand 相关性，非因果〕。
4. **买断供给真空实锤**：全品类在售买断仅 Stylebook $4.99（2009 年定价、停更 13 个月）+ Pureple 残留 Pro $14.99。$4.99-$14.99 之间没有任何活体现代买断供给，而买断偏好原声充分（MARKET §6、Whering 评论区 flat fee 请求）。
5. **credits 双轨是品类新流行病**：Whering/Acloset/GetWardrobe 三家全部引入按次 credits，与订阅并存——每家的价目表都因此变得难读（Acloset 10 条 SKU、GetWardrobe 9 条）。DESIGN §6「v1 无 credits」被基准表反向验证为清流。
6. **周付 SKU（$6.99-7.99/wk）只出现在口碑最差的两家**（Pureple 3.94★/Cladwell 4.27★），且是差评直接导火索（「6.99 A WEEK… That is insane」）。**永不做周付**。
7. **两大免费倾销者不向用户收钱**：Alta（VC 补贴）、Whering（credits+捐赠）。免费层对标对象是它们——我们的免费层必须完整跑通「录入+copilot 推荐」回路才站得住（MARKET §6 已定此原则）。
8. **同名多价/双轨价差仍在发生**：GetWardrobe IAP $34.99 vs 官网 $49.99；Cladwell/Pureple 同名 SKU 多价并存。每一例都对应可查的差评。我们 100% Apple IAP 单轨（DESIGN §6 已定）在品类里反而是差异化诚实。

---

## 3. 我们的三档具体数字建议

> WTP 证据锚（基线，不重复论证）：$4.99 买断=口碑金标准；$8/月=反感线；$60/年被质疑；$30-50/年=现实带；「一次性收费我就付、订阅不付」直接原声；≥2.5% 付费承诺阈值只在买断框架下可守（DEMAND-VALIDATION §8.3）。

### 3.1 数字总表

| 档位 | 建议数字 | 一句话理由 |
|---|---|---|
| **免费层** | 不限件数（永久承诺）+ 全部手动功能 + 导出/iCloud 备份 + AI 打标前 **200 件** + copilot LLM 补全 **2 次/日**（规则层每日推送不限） | 对标 Alta/Whering 免费倾销的最低站立线；200 件覆盖平均衣橱 166 件——让普通用户免费把全部衣橱打完标，付费墙不落在录入路径上（数据扣押感红线） |
| **买断 Core（一次性，本地功能永久）** | **$9.99**（上线价；phased 测 $14.99） | 买断真空带 $4.99-14.99 的中点；$4.99 是 15 年前的全 App 价、直接沿用会把三档锚死在地板上；$9.99 仍在「两杯拿铁」心理框架内，且为 Plus 年价留出 3.5× 锚距 |
| **Plus 订阅（AI 云端）** | **$4.99/月、$34.99/年**（年付=月流水 58%，"under $3/month" 框架；仅年付带 7 天免费试用） | 月价踩 $4.99 金标准数字、离 $8 反感线有 38% 安全垫；年价落 $30-50 带内、与带内唯一在位者 GetWardrobe 完全同价、比 Indyx（$74.99）便宜 53%、比品类中位（$59.99）低 42% |
| **买断→Plus 抵扣** | 买断用户专属年付 SKU **$24.99/年**（永久 -$10/年，本地 receipt 判断展示） | 兑现 DESIGN §6「按差价抵扣」承诺的最简 StoreKit 实现（订阅组内双 SKU 条件展示，无服务端）；消解「多重付费墙」解读 |

### 3.2 理由展开

**买断 $9.99（而非 $4.99 或 $14.99 起步）**
- $4.99 的问题：它是 Stylebook 2009 年定的**全 App**价格；我们的买断只是三档之一（免费层已含完整核心回路），照抄会（a）把 Plus 年价衬托成 7× 买断的失衡结构（b）放弃真空带内的定价权。
- $14.99 的问题：Pureple 残留 Pro 同价且口碑崩坏，有轻度负锚；上线即 3× 金标准，对「Best $5 I've ever spent」人群跳档过猛。放到 phase 2 用数据说话。
- $9.99 = 真空带中点、psychological sub-$10（App Store 价位 $10 以下 $0.10 步进、$10 以上跳 $0.50 步进，$9.99 是该区间最高标准位）、给「涨到 $14.99」留了不破 $15 的实验空间。
- 权益内容（对齐 DESIGN §6 矩阵）：高级统计 / fit 引擎 / RoomPlan 地图等**本地功能永久**。AI 云端不进买断（成本结构对齐，已定不重开）。

**Plus $4.99/月、$34.99/年（而非 $2.99/29.99 或 $5.99/39.99）**
- 月价 $4.99：品类月价带 $3.99-$14.99 的低位；美国用户对 $4.99 有品类专属好感（金标准数字迁移到月订阅仍在「拿铁」框架）；Cladwell 官网自己都在用「less than $5 a month」话术、GetWardrobe 用「$4.17/mo」话术——**$5/月是品类公认的心理天花板话术位**，我们直接把名义月价定在它下面。
- 年价 $34.99：58% 折扣率是品类惯例中位（GetWardrobe 同构）；折算 $2.92/月支持「under $3/month」营销框架；处于 $30-50 现实带下沿——刻意贴下沿，因为我们无服务器成本结构撑得起（免费层摊销 <$0.3/月/用户，Plus 重度用户估 ~$1/月〔inferred〕，$34.99×85%（Small Business Program）= 净 $29.7/年，毛利仍 >60%）。
- 不定 $2.99/$29.99：月 $2.99 会把年价压到 $20 区间，三档间距塌缩，且品类无此低锚、白让利；$29.99 留作 phase 2 降价选项而非起步价（涨价触发「Greedy」差评潮，降价没有——**起步宁高一档内、留降不留涨**……但 $39.99 起步又超出带中枢、直面 $60 被质疑的余震，不取）。
- 试用只挂年付（品类惯例：Pureple/GetWardrobe 均年付带试用）：月付无试用防「试用-退订」套利；**永不做周付**。

**免费层配额（copilot 2 次/日 + 打标 200 件）**
- copilot 补全是 PIVOT 后的核心机制，免费层必须让用户**每天真实感受到**核心价值——2 次/日 = 早晨出门场景 1 次 + 改主意 1 次，形成日习惯但重度使用（多场合/差旅打包连发）自然溢出到 Plus。取 DESIGN「1-2 次/日」的上限：品类免费倾销环境下，1 次/日不足以对抗 Alta 的全免费。
- 打标 200 件 > 平均衣橱 166 件：录入路径全程无墙（对比 Acloset/GetWardrobe 的 100 件墙 = 1★ 引爆器）；成本 ~$0.1-0.2/用户一次性（06-gap-3 口径），获客成本口径下可忽略。
- 「不限件数」文案与 200 件打标配额的关系必须一页说清：**件数永不限（存储承诺），AI 打标是算力配额**——存储与算力分开叙事，避免被读成变相 100 件墙。权益矩阵页照 DESIGN §6 执行。

### 3.3 三档锚定关系（消费者视角一屏读法）

```
免费        $0        完整衣橱 + 每天 2 次 AI 补全（不限件数，永久）
买断 Core   $9.99 一次  本地高级功能永久（统计/fit/地图）——「一杯月订阅的钱，永久」
Plus       $34.99/年   AI 全开（≈$2.92/月）——「一次真人造型 $60（Indyx Lookbook Mini 实价）> 全年 AI」
```
服务替代叙事有了品类内实价锚：Indyx 自家人工造型 Mini 档 $60 起〔first-hand〕，正好反衬我们全年 $34.99。

---

## 4. 上线后价格实验设计（phased，非同时 A/B）

> 硬约束（血案实证，MARKET §6）：同名多价/双轨计费 = Style DNA 崩塌路径；涨价触发「Greedy」差评潮。因此**禁止同时段不同用户不同价**（RevenueCat 式随机 paywall A/B 不做），只做**时间分段（phased）+ 全员祖父条款**。

### Phase 0（上线周 1-6）：$9.99 买断 + $4.99/$34.99 Plus
- 采集：paywall 曝光→购买 CVR（买断与 Plus 分开）、试用开启率、试用→付费转化、每千次安装收入（RPI）、退款率、差评中提价格的比例。
- 健康线（对齐 DEMAND-VALIDATION §2 的 2.5% 付费承诺阈值——注意该阈值在买断框架下测得）：
  - 买断 CVR ≥2.5%（对 paywall 曝光）→ 结构成立；
  - Plus 年付试用开启 ≥5%、试用转化 ≥40%（订阅业标准带）〔inferred〕；
  - 价格类差评占 1★ 比例 <5%、退款率 <2%。

### Phase 1（周 7-12）：单变量、单方向
- **若买断 CVR ≥4%**（明显过热=定价偏低）→ 新客调 **$14.99**（老客不动，价目页只有一个在售价）。观察 CVR×价格的收入曲线，取高者定稿。
- **若 Plus 年付 CVR <1.5% 且试用开启也弱** → 新客调 **$29.99/年**（降价无差评风险）。月价 $4.99 不动（它是心理锚，不是主收入位）。
- 一次只动一档一价；两档都要动时分两个 phase。

### Phase 2（周 13+）：结构微调而非价格微调
- 若买断占收入 >60% 且 Plus 转化持续弱 → 说明品类「订阅不付」倾向比预期更强，评估「买断 + AI 年票」话术重组（同价重述，不动数字）。
- 引导价格实验的年度节律：1 月（新年整理峰）/9 月（换季）做限时**入门定价**（intro offer，StoreKit 原生机制，不是改价），避免动基准价。

### 全程护栏
- 祖父条款：任何涨价对既有用户永久不生效（StoreKit 订阅 price increase 需用户同意的机制天然兜底，买断本无此问题）。
- 每次调价在价目页留一句 changelog 式说明（诚实是本品类的可营销差异化）。
- 触发回滚：价格类差评占比连续两周 >10% → 回滚上一价位。

---

## 5. 附：StoreKit 价位体系与美国心理价位惯例

### 5.1 现行价位体系（2023-03 起，取代旧 tier 制）
Apple Newsroom（2022-12-06）〔first-hand 引用〕：
- 「all developers will have the ability to select from **900 price points**」，「start as low as **$0.29** and, upon request, go up to **$10,000**」；
- 步进：「every **$0.10 up to $10**; every **$0.50 between $10 and $50**; etc.」；
- 支持非 .99 结尾：「rounded price endings (e.g., **X.00 or X.90**)」，官方点名「particularly useful for managing **bundles and annual plans**」。

### 5.2 旧 tier 对照（历史文献/竞品资料中仍常见此叫法）〔inferred，通行常识〕

| 旧 Tier | 美区价 | 本项目相关位 |
|---|---|---|
| Tier 1 | $0.99 | — |
| Tier 5 | $4.99 | Stylebook 买断位 / 我们 Plus 月价位 |
| Tier 10 | $9.99 | 我们买断位 |
| Tier 15 | $14.99 | 买断 phase 2 测试位 |
| （年付惯用非 tier 位） | $34.99 / $49.99 / $59.99 / $74.99 | 品类年价带实测四个聚集点〔first-hand〕 |

### 5.3 美国心理价位惯例（结合品类实测）
- **.99 charm pricing 仍是绝对主流**：本轮 8 家 30+ 条 SKU 全部 .99 结尾，无一例 .00/.95〔first-hand〕。年付也不例外——不必用 Apple 新开放的 .00 整数位。
- **$4.99 vs $5.99**：$5 以下属「impulse/拿铁」框架（Stylebook 文案原话 latte；Cladwell「less than $5 a month」；GetWardrobe「$4.17/mo」）——品类三家不约而同把话术压在 $5 线下，证明 $5 是本品类的认知阈值。$5.99 名义只贵 $1，但跨线后离 $8 反感线只剩 25% 缓冲。
- **$9.99 vs $10.99**：$10 是 App Store 步进跳档线（$0.10→$0.50）也是「单位数价格」心理线；$9.99 是买断的天然停泊位。
- **年付两位数框架**：$34.99 可说「under $3/month」、$49.99 只能说「about $4/month」——月折算话术差一个整档。品类内 GetWardrobe 官网正在用「$4.17/mo billed yearly」这套话术〔first-hand〕。
- **佣金口径**：Small Business Program（<$1M）佣金 15%〔vendor-claimed，Apple 公开政策〕：$34.99 净 ~$29.7、$9.99 净 ~$8.5——SOM 十万级 ARR 口径全程适用 15% 档。

---

## 6. 对 DESIGN §6 的回填清单

1. 价格锚点占位「买断 $4.99-14.99、订阅 $30-50/年」→ 落定具体数字：**买断 $9.99 / Plus $4.99/mo·$34.99/yr / 免费层打标 200 件 + copilot 2 次/日**（本文 §3）。
2. 「买断用户升 Plus 按差价抵扣」→ 落地为 owner 专属 $24.99/yr SKU（订阅组内条件展示，无服务端）。
3. 权益矩阵新增一行叙事约束：「件数=存储承诺永不限；AI 配额=算力，两者分开表述」。
4. v1 无 credits 决策获基准表反证（三家 credits 玩家价目表全部 9-10 条 SKU 混乱化）→ 维持。
5. 上线实验按本文 §4 phased 方案执行；DEMAND-VALIDATION §2 的 2.5% 阈值映射到买断 paywall CVR。

## 7. 诚实声明与缺口

- 本轮 WebSearch 配额耗尽，Indyx/Acloset 的试用期、Indyx Insider 免费边界细节未能三方核验（App Store 页与官网均未标）——标记为缺口，不影响数字建议（它们不是我们的价格锚）。
- GetWardrobe 官网「regular $49.99/yr」经 fetch 摘要器转述，原文未逐字核对〔inferred〕；但 IAP $34.99 为一手确凿，且 13 号报告独立记录过同一价差迹象，方向可信。
- 所有竞品价为 2026-07-22 美区快照；品类两年涨价 30-40% 的轨迹（Pureple 实证)意味着 6 个月后需重拉一次快照再定稿 phase 2。
- §3 数字建议为推断决策（一手基准 + 一手 WTP 原声 → 推理），非实验结果；最终裁决权在 §4 的上线遥测——这与 D20（跳过真人验证、靠上线后遥测）的既定路线一致。

## 8. 来源清单

| 来源 | 类型 | 日期 |
|---|---|---|
| iTunes Search API（8 App 价格/评分/更新日期） | first-hand | 2026-07-22 |
| App Store 产品页 ×8（IAP 价目、描述、评论引语） | first-hand | 2026-07-22 |
| getwardrobe.com（免费层/年付话术/试用） | first-hand | 2026-07-22 |
| myindyx.com（免费边界/造型服务价） | first-hand | 2026-07-22 |
| cladwell.com/pricing（"less than $5 a month"） | first-hand | 2026-07-22 |
| whering.co.uk（"Use Whering for free"） | first-hand | 2026-07-22 |
| Apple Newsroom 2022-12-06（900 价位/步进/结尾） | first-hand | 2026-07-22 取 |
| MARKET.md §6 / DEMAND-VALIDATION §8.3 / research/13 | 项目内基线 | 2026-07-21 |
