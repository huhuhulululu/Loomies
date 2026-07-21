# 竞品深拆 B 组：社交/免费+服务型（Whering、Indyx、Acloset、Style DNA）

> 深挖轮报告（2026-07-21）。基线：`01-competitors.md`（广度扫描），本文只做增量与深度，不重复功能矩阵。
> 方法与证据纪律：WebSearch 预算耗尽、exa 不可用，本轮全部经 WebFetch 直取——iTunes Lookup API（一手平台数据：评分数/版本/日期）、iTunes 评论 RSS（一手用户原声，US 区最近 50-150 条/App）、官网（一手）、融资报道（二手媒体，创始人引语为一手引述）、Trustpilot（经 r.jina.ai 代理，一手评论低样本）。所有数据以 2026-07-21 抓取为准。

---

## 0. 四竞品规模速览（US App Store 一手数据，2026-07-21 iTunes Lookup）

| 指标 | Whering | Indyx | Acloset | Style DNA |
|---|---|---|---|---|
| 当前版本 | 3.3.54（2026-07-07） | 9.6.6（2026-07-08） | 6.28.1（2026-07-21） | 1.10.224（2026-06-29） |
| iOS 首发 | 2020-08-20 | 2022-01-20 | 2021-03-12 | 2018-08-05 |
| US 评分数 | 10,756 | 1,445 | 4,431 | 7,368 |
| US 均分 | **4.67** | **4.78**（四家最高） | 4.39 | 4.29（近期差评密集） |
| min iOS | 15.5 | **13.0** | 15.1 | 16.6 |
| 体积 | 194MB | 142MB | 117MB | 136MB |
| 宣称用户 | 10M+（融资稿） | 未公开 | 7M+（官网） | 3.2M 下载（2024-06） |
| 融资 | ~$14M 累计 | 未公开 | 未公开（Looko Inc.） | €3.4M pre-seed |

---

## 1. Whering（社交头部，刚拿 eBay/Google 战投）

### 1.1 版本节奏
评论 RSS 版本戳还原（一手）：3.2.89（2026-04 上旬）→ 3.2.116（4 月中-6 月初）→ 3.3.35（6-11）→ 3.3.38（6-12~6-29）→ 3.3.53（7-3）→ 3.3.54（7-7，融资官宣同日）。**约每 1-2 周一个 build**，大 minor（3.2→3.3）在 6 月初。7-7 版本 release notes：「Planner now suggests outfits based on your wardrobe and the weather」——天气+衣橱推荐是融资日主打功能。值得注意：有用户 6-14 抱怨「I saw you guys added an update with weather to style your clothes what happened? …I hope you bring it back!」→ 天气功能曾灰度上线又撤下，7 月正式回归（功能开关式发布）。

### 1.2 评论主题挖掘（US 区最近 150 条，2026-04~07，一手）
**结构性结论：iOS 近期口碑远好于基线印象**——150 条中约 90% 为 4-5 星，1-2 星仅 2 条。基线（01 报告）的「注册即崩、标签加载 5-15 分钟」主要来自 Google Play/旧版评论聚合，**iOS 端 2026 已明显修复**。当前主题：

- **组织/ADHD 疗愈叙事**（高频，独特资产）："I have ADHD and when it comes to doing laundry I get paralyzed… Weirdly this app helped."（5★，2026-07-11）；"Easy enough for my ADHD brain to use"（5★，2026-07-07）
- **免费慷慨是口碑核心**："No ads or subscriptions necessary 10/10"（5★，2026-05-20）；"there are SO many amazing free features on this app that you need pay for on others"（2026-07-11）
- **残留 bug**："sometimes I try to create a fit and it'll then create a blank page until I recreate it a few times"（4★，2026-07-16）；"a few things it needs… it is a little slow sometimes when loading stuff"（4★，2026-06-07）
- **AI/推荐质量投诉仍在**："Does not create outfits even after hours of me putting in clothes items"（1★，2026-05-10）；法语用户："les tenues que vous proposez c'est un peu aléatoire"（3★，2026-06-11）——Dress Me 仍是规则随机，"智能感"不足
- **照片质量**："the photos are never clean or straight"（4★，2026-06-28）；"darkens things even in good sunlight… background removal causes color distortion"（4★，2026-05-10）
- **高频功能请求**：dark mode、批量编辑（"click on multiple pieces then change info in bulk"，2026-07-13）、手动排序、日历同步、场合/心情筛选（"figure out an outfit based off occasion and mood"，2026-06-13——**恰是我们假设①的原生需求表达**）

### 1.3 定价拆解（App Store IAP 页，2026-07-21）
无传统订阅墙。IAP 结构 = **credits 消耗 + 打赏式 supporter 层**：10 credits $2.99 / 50 credits $7.99 / 100 credits $12.99（AI 增强类消耗）；Outfit Maker $4.99（一次性工具）；Supporter $0.99~$49.99 五档（core/basic/extra/speed/gold standard，本质捐赠）。基线记录的「免费 100 件上限 + £30/年」已不见于当前 US 商店与评论——**免费层实质无件数上限**（多条评论确认 free 可完整使用）。变现重心显然不在 C 端订阅，而在数据/recommerce（见 1.5）。

### 1.4 Onboarding（官网 5 步，2026-07-21）
①拍照/数据库搜索（宣称 100M+ 单品库）/零售商链接三路入库（自动抠图）→ ②可视化整理筛选 → ③AI 每日穿搭建议 → ④社交（好友衣橱/心愿单/moodboard）→ ⑤日历计划+打包+cost-per-wear。无强制 quiz、无付费墙卡点——与 Style DNA 形成两个极端。

### 1.5 融资后 roadmap 信号与战投含义（2026-07-07，$7M 种子，just-style/WWD）
- **资金投向**（一手引述融资稿）：①按心情/天气/场合的高级 AI 搭配建议；②把用户随手拍升级为零售级商品图；③**相册（camera roll）直接提取单品入库**；④**虚拟试穿**；⑤平台内转售（resale）扩展
- **eBay 战投逻辑**（eBay VP Alexis Hoopes）：打破时尚「buy, use, dispose」模式——**数字化衣橱 = recommerce 库存源**。Whering 衣橱数据可直接生成 eBay 挂单（品牌/成色/穿着次数俱全），这是 eBay 获取二手供给的上游卡位
- **Google AI Futures Fund 逻辑**：官方声明「AI-powered wardrobe that prioritises both personal style and the planet deeply resonates with us」；实质是**穿着行为数据**——CEO Bianca Rangecroft 原话："We have access to such a vast amount of data that hasn't existed before – not just what people buy, but what people actually wear."（2026-07-07）
- **组织现状**：London，**全球仅 19 人**（10M 用户/19 人 ≈ 53 万用户/人）；宣称影响力数据（二手，自报）：84% 用户穿衣频率提升、近 70% 减少快时尚购买
- **战略含义**：Whering 押注「数据 + 循环时尚佣金」而非订阅——**用户衣橱数据就是商业模式**。这与我们「身体数据永不出网 + on-device」的隐私叙事构成最锋利的对照（假设④的天然反面教材/营销靶子）

### 1.6 四假设对照
| 假设 | Whering 现状 | 威胁度 |
|---|---|---|
| ①职业女性多场合 | 无场合体系；用户自发要「occasion and mood」筛选；社区 Gen-Z 向、评论大量 teens | 低——定位错开 |
| ②身体维度→合身/可视化 | 无身体数据；VTO 在 roadmap（照片路线，融资款投向） | 中——12-18 月内照片 VTO 大概率上线 |
| ③存放位置/换季 | 无；最接近的是用户用穿搭日历找回丢在包里的衣服的故事 | 无 |
| ④不卡件数免费+隐私 | 免费无上限已做到（口碑核心）；**隐私是其结构性软肋**（数据变现模式） | 免费层不再差异化；隐私差异化增强 |

### 1.7 规模估算
10M+ 注册（自报，媒体转引未审计）；US iOS 评分 10.8k 条。以品类常见「评分数≈下载量 0.05%-0.5%」推 US iOS 下载 2M-20M 区间，与 10M 全球注册自洽（中置信）。MAU 未披露；19 人团队 + $14M 累计融资说明仍是精益运营，尚未证明大规模变现。

---

## 2. Indyx（免费无限量 + 人工服务，四家中口碑最好）

### 2.1 版本节奏
9.6.3（2026-06-20 前后）→ 9.6.4（6-30）→ 9.6.5（7-7）→ 9.6.6（7-8）——**周更节奏**。大版本号已到 9.x（2022 年发布至今），功能迭代速度快。7 月主推「Virtual Selfies」：把搭配叠加到用户真实照片上预览（release notes："your rushed 7am mirror moment becomes way less stressful"——**明确瞄准工作日早晨场景**）。

### 2.2 评论主题挖掘（US 区最近 50 条，2026-06-20~07-19，一手）
50 条中 5★≈42、4★≈5、1★=3。**四家中好评浓度最高、且用户画像与我们的目标用户高度重合**：

- **职业女性工作日场景反复出现**（我们假设①的最强需求侧证据）："I work a 9-5 M-F and I am no longer late to work figuring out what to wear"（5★，2026-07-19）；"My work week and weekend events begin and end with Indyx… on a workday when you're up at 5:30 am, checking the app for my OOTD is now one less thing"（5★，2026-06-23）；"assign them to days in the calendar so I don't have to do any thinking in the morning before work"（5★，2026-07-10）；"pulling me out of my midlife funk"（5★，2026-07-19）
- **设计口碑的具体构成**：①视觉美感（"elegant, intuitive… equal parts old-money, dark feminine, coquette"，2026-06-23；"beautiful, easy to use app"，2026-07-06——后者自 2008 年用 Photoshop 管理胶囊衣橱的重度用户认证「None have come close」）；②flat-lay 拼贴质感（"read like a pleasing, intentional flat lay"，theeliseedit 博客）；③无广告；④「Clueless 玩纸娃娃」情绪价值（"paper dolls every day but with my own closet"，2026-07-14）
- **付费转化由喜爱驱动而非墙逼**："I pay for the subscription to support the owners but the features aren't super compelling to justify the expense"（4★，2026-07-13）；"Within a day or two I immediately upgraded to Insider"（5★，2026-06-20）——**为爱付费/支持开发者心态**，与 Style DNA 的强制墙互为镜像
- **负面三条**：①**paywall creep 预警**："After the most recent update, the calendar function is essentially unusable for anyone without a paid membership… 'assign selfie' buttons getting in the way"（1★，2026-07-07）；②稳定性偶发："Downloaded but the opening screen simply stalls out"（1★，2026-06-30）；"Url import works once then also stops. Useless"（1★，2026-06-28）；③**大衣橱性能**："I have 250+ clothing items and 450+ outfits and digitally dragging a new item to my shoe section can be a chore (30+ seconds)"（4★，2026-07-07）
- **AI 反感信号**（其可持续消费用户群特质）："So good, wish there was less new ai features :/"（4★，2026-07-06）；"Great app, chill it w the AI"（4★，2026-07-02）——**该人群对生成式 AI 有道德性抵触**，AI 功能须低调实用而非营销卖点

### 2.3 定价拆解（官网 how-it-works + App Store IAP，2026-07-21）
- **软件层**：免费=无限件数字化+AI 抠图/打标+搭配板+日历+打包+基础 cost-per-wear；**Insider $12.99/月 或 $74.99/年**（进阶分析仪表盘、无限 outfit selfies、Lookbook 访问、resale 活动优先）。博客实测有黑五 $54/年促销（原价口径 ~$108，现官方 $74.99）
- **人工服务层**：**The Catalog 代客数字化：首 100 件 $295，超出 $2/件，仅限部分都市圈（zip code 校验）**；造型订阅 $15/月起；一次性造型 $110；Lookbook Mini $60（3 套）/ The Lookbook $150 起（10 套，用你自己的衣橱）

### 2.4 Onboarding
注册 → Style Quiz（App Store 描述确认）→ 三路入库：自拍（自动抠图+自动标签）/ **email 收据转发导入**（"forward your email receipts to Indyx… grabs the item information and imports your purchases directly"，theeliseedit）/ 代客服务。博客实测流程："laid out each item, snapped a quick photo, added details like category, colour, price & whether it was secondhand"（thejuliastyleedit，128 件建档）。无件数墙、无强制付费卡点。

### 2.5 人工服务单位经济与规模天花板（推断，中低置信）
- **The Catalog（$295/100 件）**：上门摄影 100 件约需 2.5-4 小时 + 通勤 + 后期打标（AI 辅助）。按美国大都市造型师/摄影助理 gig 时薪 $30-50 估，直接人力 $120-250/单 + 交通 + 复核 → **毛利率约 15%-50%，单均贡献 $50-170**——是服务业毛利而非软件毛利。天花板：受限 select metros + 单量线性依赖本地人力供给；即便月千单（乐观）年收入也仅 ~$3.5M。**结论：Catalog 是高端获客与品牌仪式感（"white glove"评论确有转化："The white glove service is also great"，2026-07-15），不是可规模化收入引擎**
- **造型订阅（$15/月起）/Lookbook（$60-150）**：真人造型师产出 10 套 look 约 2-4 小时（有数字衣橱加持效率高于传统造型），$150 单能给造型师留 $70-100 → 平台抽成 30-50%。类 Stitch Fix 人力模型：**边际成本不趋零，QC 与造型师供给是双瓶颈**。合理推断其软件（Insider）才是利润主体，人工服务是差异化与定价锚
- **规模现状**：US iOS 仅 1,445 评分（Whering 的 13%）→ 推断注册用户 10^5 量级（数十万，低置信）。无公开融资记录 → 大概率自筹/小天使，**增长慢但 NPS 极高的利基精品**

### 2.6 四假设对照
| 假设 | Indyx 现状 | 威胁度 |
|---|---|---|
| ①职业女性多场合 | **用户画像最重合**（评论满是 9-5 女性），但产品无场合结构（Collections 手动分组勉强替代）；styling 服务是人肉场合方案 | **中高——最直接的心智竞品**，若其加「occasion」维度即正面撞车 |
| ②身体维度→合身 | Virtual Selfies=照片叠加预览，无身体维度、无合身判断 | 低-中 |
| ③存放位置/换季 | 无 | 无 |
| ④不卡件数免费+隐私 | 免费无限件已是其口碑基石；无隐私叙事；paywall creep 苗头（日历事件） | 免费层不差异化；隐私可差异化 |

---

## 3. Acloset（韩国 Looko，全球化量最大但质粗）

### 3.1 版本节奏
官方公告页（一手）：6.0.0（2025-05-26）→ 6.28.1（2026-07-21），14 个月约 30 个版本，**月均 2-4 发**。关键节点：Beautify Pro（2025-09-11）、二手市场关停转向 AI 个性化推荐（2024-07-31）、**单张全身照生成 avatar 虚拟试穿（6.28，2026-07 主打）**。迭代激进但下文可见质量口碑跟不上速度。

### 3.2 评论主题挖掘（US 区最近 50 条，2025-11~2026-07，一手）
50 条两极分化明显（均分 4.39 为四家最低之一），**负面集中在「AI 全家桶质量」**：

- **AI 搭配质量差（最大主题）**："Today it's over 100 degrees and the outfit recommendations include jeans and a mid-weight field jacket"（1★，2026-07-04）；"recommends wool pants, long sleeve pullover sweaters AND cardigans [for 82°F]"（1★，2026-03-16）；"bright red sweats with a blue pink and yellow graphic tee and a sage green varsity jacket"（3★，2026-04-18）；"New AI assistant broke the recommendations I think"（1★，2026-01-28）；"since the supposed 'AI Upgrade' it's not good. The AI is LOL bad… a classic case of an over-engineered app"（3★「AI Slop」，2025-11-29）——**天气数据源都对不上（app 内两处温度不一致），推荐引擎被 AI 化改造反而退化**
- **AI 打标/抠图质量**："the image extraction doesn't really work at all if there's any other clothing item in the photo"（2★，2026-06-16）；"colors aren't really the same when you take a photo"（4★，2026-04-10）；"I'm having trouble getting a clean background removal with the free version… that's a deal breaker"（2★，2026-05-18）；Beautify 美化「takes all of the details out and leaves clothes looking like they belong on a cartoon character」（2025-11-29）；中文用户正面但暴露 credits 模型："美化后的衣服看起来很舒服……强迫症表示每件衣服都需要美化，额度不够用了"（4★，2025-11-22）
- **100 件免费墙引爆差评**（假设④直接证据）："I just spent two hours uploading clothes, and now it's telling me there's a max of 100 items or I have to pay???? I haven't even done my pants yet"（1★「ZERO STARS」，2026-07-17）
- **涨价反噬**："almost doubling the price of the subscription was greedy so I canceled"（2★，2025-11-22）
- **稳定性**："It crashes constantly, especially when loading new items"（3★，2026-07-03）；"Gets stuck on 90% analyzed"（3★，2026-01-03）
- **制服/职业场景的多柜需求**（假设①③旁证）：护士用户："it'd be a little ridiculous to match my scrub top to dress shoes… I suggest you make a feature that opts a closet in or out of the general outfit generation"（4★，2026-02-01）

### 3.3 定价拆解（App Store IAP，2026-07-21）
三档订阅 + 微交易 credits（beans）：Basic $3.99/月、$27.99/年；Premium $9.99/月、$59.99/年；**Expert $24.99/月、$147.99/年**（四家最贵档）；beans 100/$1.99 ~ 500/$9.99（AI 美化/试穿消耗）。免费层 100 件上限。另有用户提及 $100 终身会员（2026-05-12 评论）。**订阅+consumable 双轨吸血模型**，与其质量口碑不匹配是差评主源。

### 3.4 Onboarding
邮箱注册（被抱怨："Why is it an email only sign in?"，1★，2026-03-24）→ 拍照入库（AI 抠图+自动标签）/电商订单导入（Amazon/Zara/Shein）/单品库搜索 → 色彩分析+体型匹配（免费一次，评论："ive already found out my color analysis… for FREE"，2026-04-17）→ 天气+日程推荐流。CEO Ko Heasin 阐述的激活阈值（一手引述，hankyung 2026-02）："a whole new world opens up once you've added more than 50 items"——**50 件=其 aha moment 门槛**，侧证入库摩擦是全品类命门。

### 3.5 全球化程度与规模
- 官网（2026-07）：**7M+ 用户、90M+ 件衣物数字化、150+ 国、18 语言**；Google Play 38k+ 评论（Android 重心）、Editor's Pick 2023；韩媒（2026-02，基线）：累计会员 450 万、MAU 50 万口径——官网 7M 与韩媒 450 万差异应为时间差+口径差（下载 vs 注册），**MAU/注册比 ~11% 是重要参考系**
- US iOS 仅 4,431 评分：**全球量大但美国 iOS 渗透浅**，主力在 Android/新兴市场。18 语言本地化是真投入，但美区评论显示天气/尺码/场景本地化质量粗糙
- 公司：Looko Inc.，2020-06 创立，CEO Ko Heasin；入选韩国 Startup Leap Package、Google for Startups（政府/大厂扶持型，融资额未公开）

### 3.6 四假设对照
| 假设 | Acloset 现状 | 威胁度 |
|---|---|---|
| ①职业女性多场合 | 有场合概念但推荐质量差到成为差评源；护士要求把制服隔离出推荐——**多柜隔离需求它接不住** | 低——质量塌方给了空间 |
| ②身体维度→合身 | 2026-07 上线单照片 avatar VTO（照片路线）；色彩+剪影分析有 | 中——照片试穿已 ship，但无合身判断 |
| ③存放位置/换季 | 无 | 无 |
| ④不卡件数免费+隐私 | **100 件墙是其最大差评引爆点**；云端处理无隐私叙事 | 我们的免费层直接打其最痛处 |

---

## 4. Style DNA（订阅陷阱口碑崩塌样本）

### 4.1 版本节奏
1.9.208（2025-08）→ 1.9.211（2025-11）→ 1.10.212-218（2025-12~2026-04）→ 1.10.224（2026-06-29），**月更但 release notes 长期只写「Performance improvements and bug fixes」**——功能停滞、流量funnel 驱动的运营状态（对照：营销侧仍在 TikTok/IG 大量投放，评论多条「seeing this app all over social media」）。

### 4.2 评论主题挖掘 + 崩塌时间线（US 区最近 100 条，2025-08~2026-07，一手；Trustpilot 一手低样本）
**量化分布（100 条，本轮人工归类，估算口径）**：1-2 星 ≈ 53%；其中**计费/退订投诉 ≈ 27-29 条（占全部评论近三成、占负面评论过半）**；推荐/分析质量差 ≈ 20 条；稳定性/无法打开 ≈ 5 条。5 星 ≈ 45 条，几乎全部集中于**色彩分析单点价值**（"THE BEST COLOR ANALYSIS APP"）。

**崩塌时间线**：
- 2018-08：iOS 首发（工具形态）；2022：转型 AI stylist 重新增长
- 2024-06：TechCrunch 报道巅峰数据——3.2M 下载、300k 活跃、**70k 付费**、€3.4M pre-seed（Black River Ventures）、ChatGPT-4.0 驱动、150+ 联盟零售商
- **2024-10-21（Trustpilot 首条恶性投诉）**："it charges weekly and you just can't cancel it. There is not a chat option, no one to help"
- 2025 上半年（Trustpilot）：web funnel 定价钓鱼恶化——"Said it was only one pound to check your colors but took 7 pounds"（2025-06-26）；"Pretends to charge you $8 for a weeks trial but took £30 from my account"（2025-06-17）
- **2025-08 起 App Store 差评海啸**（每月多条）："my subscription has been canceled for months and they just keep charging me!"（2025-08-29）；"charging me for 4 months now without my consent… I did a trial through the app [but] it is not active [in Apple subscriptions]"（2025-09-01）；"Signed up for 1 year. Billing is $28.95 a month"（2025-08-25）
- 2026 持续："This doesn't show up in apple subscriptions for some reason"（2026-01-05）；"Charged $10 first month, then $28.95 for several months despite cancellation… App disappeared from subscription list but charges continued"（2026-05-30）；"KEPT CHARGING AFTER I CANCELLED. THEN WOULDN'T REFUND… citing dual-cancellation requirement"（2026-04-22）；最新（2026-07-20）仍是 1★「TOTAL SCAM」
- 现状：Trustpilot **2.0/5**（11 条，零官方回复）；App Store 均分从高位滑至 4.29 且近期页面 1 星密度极高

**机制拆解（教训核心）**：①**双轨计费**——web（Stripe 类）订阅绕开 Apple 订阅管理，用户在 iOS 设置里看不到、退不掉（"doesn't show up in apple subscriptions"），且客服只有 AI bot / 404（"Customer support returns 404 error"，2026-06-22）；②**价格阶梯钓鱼**——$1-10 引导价 → $28.95/月自动续；③**先付费后见货**——"Demands payment after sign-up before users can test AI functionality"（2026-06-07）；④退款拒付 + 「双重取消」话术。
**质量侧同步塌方**（付费憋单反噬）："AI model doesn't reflect actual body shape despite custom measurements"（2026-03-18）；53 岁用户："it suggested a $1200 crop top jacket… I showed a dozen generated outfits to an actual stylist. They said they would not dress their dog in those outfits. I once tried ChatGPT to do what this app says it does… it did a better job"（2★，2026-01-02）；"fundamentally flawed in advising fashion for an hourglass figure"（1★，2025-11-15）；"Generates outdated looks, frumpy as if for an 80 year old woman"（1★，2025-12-31）

### 4.3 定价拆解（App Store IAP，2026-07-21）
同名多价位 SKU 矩阵（A/B 测试痕迹）：月订 $7.99/$9.99/$19.99 三档并存；3 个月 $14.99/$19.99；年订 $19.99/$29.99/$39.99 三档并存；另卖一次性内容包（Palette and Body type guide $12.99、Advanced Color Palette $9.99——被抱怨「pay $10 for more features」二次收费）。**同一产品 9 个订阅 SKU + web 端另一套价格 = 定价体系本身就是漏斗实验场**，用户感知为欺诈。

### 4.4 Onboarding
单张自拍 → AI 判 12 季型色彩 + 体型/身高评估 → 风格 quiz → **付费墙（先付才出结果）** → 衣橱扫描（可选）。这是「先钩后墙」的教科书反例：色彩分析确有单点魔力（好评近半为它而来），但结果被扣为人质，配合 web 计费绕道，把一次性好奇流量烧成品牌负资产。

### 4.5 规模估算
巅峰（2024-06，二手）：3.2M 下载 / 300k 活跃 / 70k 付费（付费率 ~23% of active，异常高——funnel 强转化的另一面即退订投诉）。2026 现状：评分增速仍在（7.4k）但差评占比过半，增长质量恶化；开发商 AI Style by DNA S.L.（西班牙实体），仅支持英/德/意三语。**推断已进入「买量→收割→口碑折损→更依赖买量」的死循环**（中置信）。

### 4.6 四假设对照
| 假设 | Style DNA 现状 | 威胁度 |
|---|---|---|
| ①职业女性多场合 | 每日 5 套按场合建议存在但质量差（"frumpy"/年龄错位/气候错位——热带用户抱怨无气候适配） | 低 |
| ②身体维度→合身 | **唯一收集自定义身体测量的 B 组玩家，但执行失败**（"doesn't reflect actual body shape despite custom measurements"）——需求真实、执行空白的直接证据 | 低（反面验证了假设②的机会） |
| ③存放位置/换季 | 无 | 无 |
| ④不卡件数免费+隐私 | 完全反面：付费墙前置+双轨计费陷阱 | 其崩塌是我们定价叙事的活广告 |

---

## 5. 跨案横向结论（B 组增量洞察）

1. **免费无限件已成 B 组头部共识**：Whering（credits+打赏）、Indyx（免费无限+$12.99 Insider）均不卡件数且以此为口碑核心；仍卡 100 件的 Acloset 正被点名差评。→ 我们假设④的「不卡件数」**不再是差异化，而是入场券**；差异化重心应压到「on-device 隐私」上——恰逢 Whering 公开把「用户穿什么的数据」当融资卖点，隐私对立面从未如此清晰。
2. **「工作日早晨」已被 B 组识别为核心场景但无人结构化解决**：Indyx 的 Virtual Selfies 文案直指「rushed 7am mirror moment」，其五星评论全是 9-5 女性；Whering 用户自发索要 occasion 筛选；Acloset 接不住护士的制服隔离需求。**场合结构化（不只是标签，而是推荐引擎的硬约束）仍是空位**，且需求原声充分。
3. **照片路线试穿在 B 组全面铺开（2026-07 同月三家动作）**：Acloset 单照片 avatar VTO 已上线、Indyx Virtual Selfies 已上线、Whering VTO 在融资投向里。**但没有一家做身体维度→合身判断**；Style DNA 收了测量数据却做砸（用户原话可证）。假设②的窗口在「合身判断/尺码维度」，不在「视觉试穿」——视觉试穿 12 个月内会成为 B 组标配。
4. **AI 质量是口碑放大器也是粉碎机**：Acloset「AI Upgrade」把推荐搞退化（天气都对不上）直接制造 1 星潮；Indyx 用户明确要求「chill w the AI」。对 25-45 目标客群，**AI 要藏在结果里而不是挂在名字上**；天气数据一致性这类工程细节比模型能力更先决。
5. **订阅信任是品类系统性风险**：Style DNA 用双轨计费+价格阶梯在 18 个月内烧掉 8 年品牌；Acloset 翻倍涨价即遭退订。反面共识 → 计费必须 100% 走 Apple 订阅体系（可在设置一键退订）、先体验后付费、单一透明 SKU。
6. **规模≠质量**：US iOS 均分与规模倒序——Indyx（1.4k 评分/4.78）> Whering（10.8k/4.67）> Acloset（4.4k/4.39）≈ Style DNA（7.4k/4.29）。利基+精品设计（Indyx 路线）在本品类的留存与 NPS 回报被验证，与我们「职业女性利基切入」的路线同构。
7. **入库摩擦的量化锚点更新**：Acloset CEO 明示 50 件=aha 阈值；Indyx 用户 128 件建档记录；Acloset 用户「2 小时未传完上装」。MVP 的入库流程应以「首日 50 件、单件 <15 秒」为硬指标。

## 6. 关键来源
- Whering 融资：just-style（2026-07-07）https://www.just-style.com/news/whering-seed-funding-ai/ ；WWD（tollbit 墙，未直取）
- iTunes Lookup（2026-07-21 抓取）：id=1519461680 / 1599179405 / 1542311809 / 1358319821
- iTunes 评论 RSS（US，most recent，2026-07-21 抓取）：同上四 id，各 1-3 页
- App Store IAP：apps.apple.com 四 App 页面（2026-07-21）
- Indyx：https://www.myindyx.com/ 、https://www.myindyx.com/how-it-works 、theeliseedit.com 深评、thejuliastyleedit.substack.com 4 个月长测
- Acloset：https://www.acloset.app/ 、https://www.acloset.app/announcements 、hankyung plus（2026-02，CEO 引述）
- Style DNA：TechCrunch（2024-06-21）、Trustpilot styledna.ai（经 r.jina.ai 代理，2026-07-21，TrustScore 2.0/11 条）

> 置信说明：App Store 数据与评论原声为一手（高置信）；Indyx 单位经济、各家 MAU/注册推断为分析推断（中低置信，已标注）；Whering「免费无上限」结论来自 IAP 结构+评论交叉，上线前建议实机装四 App 复核付费墙与 onboarding 细节。
