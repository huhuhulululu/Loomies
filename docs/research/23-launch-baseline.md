# 23 — 上线后验证基准（launch baseline）

> 日期：2026-07-22 ｜ 任务：为 D20「跳过真人验证、靠上线后遥测验证」提供判定基准线，把 DESIGN §11.8 的「数字门槛待定」变成可判 pass/fail 的具体数字
> 数据渠道声明：本轮 WebSearch 预算耗尽（200/200）、exa API key 失效（与 18 号报告同状况）——增量证据来自 **WebFetch 直取 + DuckDuckGo HTML 检索 + iTunes Search API（一手）**。通用基准全部为厂商聚合口径（vendor-claimed），各家 cohort 定义不一，**只能当量级锚，不能当精确线**。
> 增量声明：不重复 MARKET.md / DEMAND-VALIDATION §8 已有结论（40 件阈值、Acloset 11% MAU/注册、免费采用 13×、$25 CAC 假设等仅作引用锚点）。

---

## 0. TL;DR — §11.8 判定门槛速查表（本报告核心交付，详见 §5）

| 指标（§11.8 / MARKET §7） | GO（达标） | 观察区 | FAIL（警报） | 依据 |
|---|---|---|---|---|
| **7 天 40 件激活率**（北极星激活） | ≥20% | 10–20% | <10% → F1 入库生死线复审 | 激活率中位 25%/均值 34%（Plotline）打折：重录入负担 |
| 下载→入库 3 件（漏斗第一关） | ≥40% | 25–40% | <25% | onboarding 完成 ~34% 锚（低摩擦目标应超均值） |
| **D1 留存** | ≥30% | 20–30% | <20% | 全类目中位 25%、强线 30–40%（UXCam 聚合 2026） |
| **D7 留存** | ≥12% | 8–12% | <8% | 中位 8%、强线 10–15% |
| **D30 留存（全体 cohort）** | ≥8% | 4–8% | <4% | 中位 4%、强线 5–8%；e-comm 8.7% 为可比上界 |
| **D30 留存（激活层 ≥40 件）** | ≥30% | 15–30% | <15% → **copilot 机制证伪警报** | 无公开基准；由 40 件阈值论点自洽推导（inferred） |
| 推荐采纳率（推送→接受/打卡） | ≥25%（暂定） | 15–25% | 换一套率 >60% = naive autopilot 警报 | 无公开基准，前 4 周收分布校准（inferred） |
| 周均打卡（active 用户） | ≥2 次/周（暂定） | 1–2 | <1 | 无公开基准，前 4 周收分布校准（inferred） |
| 买断转化（安装→付费） | ≥2.5%（沿用 DEMAND-VALIDATION §2，买断框架下测） | 1–2.5% | <1% | 方法④：付费意愿几乎只在 $4.99 买断存在 |
| CAC 护栏 | CPI ≤$5、$/激活用户 ≤$25 | — | 超线即停投 | US 平均 CPI $5.28、Meta CPI $1–5；20% 激活率 × $5 = $25 |

**读数顺序（诊断矩阵）**：先看激活率再读留存——激活差+留存差 = 修入库漏斗（F1）；激活好+激活层留存差 = **机制问题**（copilot 推荐不成立，最严重信号）；激活好+留存好+付费差 = 免费墙问题（Alta/Whering 训练出的零付费预期，18 号报告）。

⚠️ **Beta cohort 校正**：TestFlight 招募的 N≥50 是高动机人群，各线应显著跑赢上表（建议按 1.5–2× 读）；上表门槛适用于**上架后 organic 自然量 cohort**。付费 UA cohort 留存通常低于 organic，若投 Meta 测试需分开读数。

---

## 1. 通用留存基准（D1/D7/D30）

### 1.1 全类目聚合（vendor-claimed）

UXCam《Mobile App Retention Benchmarks (2026)》聚合 AppsFlyer State of App Marketing 2025、Adjust Mobile App Trends 2026、data.ai State of Mobile 2026（fetch 2026-07-22）：

| 口径 | D1 | D7 | D30 |
|---|---|---|---|
| **中位数** | 25% | 8% | 4% |
| **强者线（75 分位）** | 30–40% | 10–15% | 5–8% |

交叉验证（Plotline，引 AppsFlyer/Adjust，2024-12 发布，fetch 2026-07-22）：Adjust 口径「双平台 30 天留存整体约 6%」；iOS D30 留存近年上升、Android 同期下降 16%——**iOS-only 是留存顺风**。

### 1.2 分类目（无 lifestyle 单列，取最近邻）

Plotline 分类目表（D1 / D30）：E-commerce 33.7% / 8.7%；Fintech 30.3% / 11.6%；Social 26.3% / 3.9%；Health & Fitness 20.0–20.2% / 2.78–4%；Dating 29.6% / 5.1%。另一口径（Adjust 2025，经 Wellness Zenith 转引）：Health D1 27% → D30 8%；AppsFlyer 口径 Health D30 仅 3.5%。

**判读**：衣橱管理 = 工具 × 习惯型，最近邻是 Health & Fitness（习惯养成，D30 中位 3–4%）与 E-commerce（高频打开，D30 8.7% 是品类可及上界）。同一类目不同报告差 2 倍（Health D30 3.5% vs 8%）——再次证明门槛只能设区间不能设点。sourceTier：vendor-claimed。

### 1.3 激活与 onboarding

- 激活率（新用户完成核心价值动作）：**均值 34%、中位 25%**（Plotline 2024，survey 口径，fetch 2026-07-22）。
- onboarding 完成率：约 **34%**（Norvik Tech 转引研究）；高摩擦流程 drop-off 区间 **21–72%**（SetGreet）。均为弱源快照（DDG snippet），sourceTier：vendor-claimed 偏低置信。
- 对我们的含义：40 件录入是**远重于普通 onboarding 的激活动作**，直接套 25–34% 会虚高——故 §0 把 GO 线打折到 20%，并在漏斗前段（3 件）用 ≥40% 把「愿不愿意开始」和「能不能到 40 件」拆开归因。

## 2. 衣橱品类特有基准（已有 + 本轮增量）

| 数据点 | 数值 | 来源/状态 |
|---|---|---|
| Whering 40 件留存阈值 | ≥40 件后留存「指数级」变好 | 已有（16 号，创始人自述，单源未审计） |
| Acloset 注册→MAU | ~11%（450 万注册/50 万 MAU，即 ~89% 不活跃） | 已有（12/14 号，公司口径） |
| Style DNA 下载→活跃 | ~9.4%（3.2M 下载/300k 活跃，2024-06 巅峰期） | 已有（14 号，TechCrunch 转引） |
| 免费 vs 买断采用速度 | ~13×（Alta 16 月 10,783 评分 vs Stylebook 16 年 8,701） | 已有（18 号） |
| **【新·一手】Alta 评分增速** | **+79 条/天**（10,783→10,862，2026-07-21→07-22，iTunes API）；年化 ~29k 条 | first-hand（单日 delta，噪声大，方向可信） |
| **【新·一手】Whering 评分增速** | +21 条/天（10,756→10,777，同窗口）；**Alta 增速 ≈ 3.8× Whering，且总量已反超**（10,862 vs 10,777） | first-hand |
| 【新·一手】其他增速 | Fits +8/天；Stylebook +2/天（僵尸增速）；Pureple 0；Essembl +67（两快照口径可能不同，存疑） | first-hand |
| 【新】品类公开留存数据 = **零** | 检索 Whering/Alta/Indyx 留存/下载公开数据无果（DDG 两次专项检索空手） | inferred（缺席本身是信息：无人敢晒留存） |

**判读**：①品类内「注册→活跃」公开锚只有 ~9–11%（Acloset/Style DNA），与全类目 D30 中位 4% 量级自洽——衣橱 App 并不比大盘更能留人，**留存必须靠激活分层做出来**；②Alta 增速一手确认「最大威胁」判断（MARKET §4）仍在加速兑现，对 Alta 的 0–12 个月窗口读数偏紧不偏松。

## 3. Meta 广告成本基准（US，获客预算用）

| 指标 | 数值 | 来源（fetch 2026-07-22） | tier |
|---|---|---|---|
| US Meta CPM（Traffic 目标） | **$10–15**（均值区间） | Affect Group，Q1 2026（截至 2026-03-26，自有盘面 90% 权重） | vendor-claimed |
| US Meta CPM（Reach/Sales 目标） | $9–14 / $14–25 | 同上 | vendor-claimed |
| Meta 全局 CPC / CPM / CPL | $0.87 / $16.06 / $18.75（2025-11） | Shopify blog（2025-11-30） | vendor-claimed |
| Apparel 行业 Traffic CPC / CTR | **$1.07 / 1.14%**（2023-02–2024-04） | WordStream/LocaliQ 行业基准 | vendor-claimed |
| Meta CPI（App Install） | **$1–5** 常态，竞争类目 $10+ | WASK 工具页 | vendor-claimed |
| US 全渠道平均 CPI | **$5.28**（2024，全球最贵市场） | Linkrunner 基准工具 | vendor-claimed |
| Apple Search Ads 均值 | **CPT $2.25 / CPA $3.76** / TTR 9.7% / CR 66.2%（2025 年数据，2026-02 发布） | SplitMetrics | vendor-claimed |
| 25–45 女性 lifestyle 定向溢价 | 公开数据**不存在**按性别×年龄的 CPM 单列；fashion/女性购物人群常识性溢价 +20–50% | — | inferred |

**账（决定获客策略的一手推演）**：CPM $12.5 × CTR 1.14% → CPC ~$1.1（与 LocaliQ $1.07 互证）；商店页转化按 25–35% → **CPI ≈ $3–4.5**（落在 WASK $1–5 与 US 均值 $5.28 之间，三源自洽）。按 §0 的 20% 激活率 GO 线：**$/激活用户 ≈ $16–23**，恰在既有 $25 CAC 假设内——护栏自洽。
**但回本测算是残酷的**：2.5% 安装→付费 × $4.99 买断 = **$0.12/安装收入** vs CPI $3–4.5 → 付费 UA 单位经济 **~25–40× 不回本**；即便 $40/年订阅 × 2.5% 也只有 $1/安装。⇒ **Meta 广告在本品类只能当信号测试预算（$500–1k 测创意/文案/人群），不是规模获客渠道**——16 号报告的 organic 优先排序（整理师渠道/Reddit/earned media）从「建议」升级为**结构必然**。ASA 长尾词（CPT $2.25 均值，长尾更低）是唯一可能接近回本的付费位，与 MARKET §7「上线前 ASA 实测长尾词」衔接。

## 4. ASO 快照刷新（iTunes Search API 一手，us store，2026-07-22）

> 对照基线：16 号报告同 API 快照（2026-07-21，仅 'outfit planner'/'digital closet' 两词）；本轮**新增 'wardrobe app'** 覆盖。API 为相关性排序，是 App Store 搜索排名的代理而非精确名次。

**'digital closet' 前 6**：Whering(4.67/10,777) → **Alta(4.88/10,862)** → SimpleCloset(4.70/739) → Indyx(4.77/1,447) → Fits(4.61/4,715) → Clozzie(4.64/134)
**'outfit planner' 前 6**：Whering → Fits → Combyne(4.76/**86,861**) → Alta → Pureple(3.94/6,120) → Indyx
**'wardrobe app' 前 6**【新】：Whering → Fits → Indyx → Alta → Wardrobe Fashion(75) → Stylebook($4.99/8,703)

与 07-21 快照相比的变化与判读：
1. **格局 24 小时无位移**——头部占位序稳定，16 号「大词正面位无望、ASO 做防守」判读维持不变。
2. **'wardrobe app' 同样被四巨头（Whering/Fits/Indyx/Alta）锁死前四**——三大词全部无正面空位，长尾组合词（work outfit planner / closet inventory / capsule wardrobe planner）仍是唯一 ASO 入口。
3. **Fits（德国，L. & J. Henne UG）在三词中两词占 #2**，4,715 评分——16 号仅注意其与美国同名产品混同风险，本轮确认其 ASO 占位强度被低估，建议列入盯防名单（月更观察）。
4. Stylebook 停更持续（2025-06-15，13+ 个月）仍在 'wardrobe app' 前 6 + $4.99 买断——「买断供给真空」窗口继续敞开。
5. Combyne 86.8k 评分提示 'outfit planner' 词下混入社交搭配玩法的巨型玩家，该词商业意图最杂、转化预期应最低。

## 5. §11.8 门槛建议的推导逻辑（对 §0 表的注解）

1. **为什么 D30 全体 GO 线设 8% 而不是 4%**：4% 只是全类目中位（=平庸）；我们的论点是「激活分层制造留存」，若全体 cohort 只做到中位，说明激活漏斗没有兑现设计（F1 生死线 + 40 件钩子）。8% = 强者线上沿 = e-comm 类可及上界，是「值得继续投入」的证据强度。
2. **激活层 D30 ≥30% 是真正的机制裁决线**（本报告最重要的一条）：40 件阈值论点（16 号）+ copilot 先验（18 号 ~7:1）合起来的可证伪表述是——「到达 40 件的用户会因每日 copilot 推荐持续回访」。若激活用户 D30 <15%，说明**录入沉没成本留不住人、推荐也留不住人**，PIVOT 后的核心机制被上线数据证伪，触发 needs_replan 级复审；15–30% 说明钩子弱但方向在；≥30%（约中位数的 7 倍）才配得上「指数级变好」的原始断言。此线无公开基准，纯推导（inferred），但它把创始人自述变成了可判命题。
3. **推荐采纳率与周打卡暂不设硬门**：全网无公开基准；设「暂定线 + 前 4 周收分布再校准」比拍数字诚实。唯一提前可定的是**反向警报**：「换一套」率 >60% = naive autopilot 病灶重现（方法④差评主因），优先级高于采纳率绝对值。
4. **付费 2.5% 沿用而非新设**：18 号已论证该线只在买断框架下可守，且要在「Alta/Whering 免费墙」背景下读——付费转化差 + 留存好 ≠ 失败，可能只是免费锚太强，此时看 §0 诊断矩阵走变现结构复审而非产品复审。
5. **所有留存线按 organic cohort 定义**：付费 UA 与 TestFlight cohort 必须分层读数（§0 警告），混读会让门槛同时虚高和虚低。

## 6. 来源清单

- UXCam《Mobile App Retention Benchmarks (2026)》（聚合 AppsFlyer 2025 / Adjust 2026 / data.ai 2026），fetch 2026-07-22
- Plotline《Retention rates by industry》（引 AppsFlyer/Adjust）2024-12；《Activation rates》2024-12，fetch 2026-07-22
- Adjust 2025 口径（Wellness Zenith 转引，DDG snippet）；SetGreet / Norvik（onboarding，DDG snippet，低置信）
- Affect Group《US Meta CPM Q1 2026》（2026-03-26 截止）；Shopify《Facebook Ads Cost》2025-11-30；WordStream/LocaliQ FB 行业基准（2023-02–2024-04）；WASK CPI 工具页；Linkrunner CPI 基准（2024）；SplitMetrics《Apple Search Ads Cost》（2025 数据，2026-02 发布）——均 fetch 2026-07-22
- iTunes Search API（us store，entity=software，'digital closet'/'outfit planner'/'wardrobe app'，2026-07-22）——一手；对照 16/18 号 2026-07-21 快照
- 检索失败记录：businessofapps.com 403、adjust.com 429×2、uxcam onboarding 404、Whering/Alta/Indyx 公开留存数据专项检索无结果

---
🟡 **置信度** 🟡: 72% — ASO 快照与竞品增速为一手（高置信）；通用留存/广告基准为多源厂商聚合、同类目跨报告差 2 倍，只能当量级锚（中置信）；激活层 D30≥30% 等机制线为逻辑推导无公开基准（已标 inferred）；建议上线 4 周后用自有遥测分布回校准所有暂定线
