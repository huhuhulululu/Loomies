# 竞品深拆 A 组——工具型：Stylebook / Cladwell / GetWardrobe / Pureple / Smart Closet（2026-07-21）

> 深挖轮报告。基线 = `01-competitors.md`（首轮广度扫描），本文只做增量与深度，不重复功能矩阵。
> **方法与证据分级**：
> - 一手：iTunes Lookup API（版本/评分/价格，2026-07-21 实测）；App Store 页面内嵌版本历史 JSON（每 App 25 条）；App Store 官方 RSS 评论流（每 App 162-500 条带日期原文，去重后统计）；iTunes 付费榜 RSS（当日排名）；Google Play 商店页安装量区间；官网/帮助中心；Wayback Machine 历史快照（历史定价/评分数）。
> - 二手：Indyx 竞品博客（注意其厂商立场）、个人博客评测。
> - 所有评论引用格式：`[日期|星级|版本]`，原文英文保留。
> - 局限：WebSearch 预算耗尽 + Appfigures/Sensor Tower 付费墙，**无第三方下载/收入绝对值估算**；改用当日付费榜排名、评分增量、Play 安装区间三个一手代理指标，并标注推断置信。

---

## 0. 一页结论（增量要点）

| | Stylebook | Cladwell | GetWardrobe | Pureple | Smart Closet |
|---|---|---|---|---|---|
| 近 12 个月更新次数 | **0** | 2（全 bug fix） | **15**（~1.3/月，多为功能） | 16（15 次仅写 "bug fixes"） | 3（灾后急救，集中在 3 天内） |
| 活跃度判定 | 蛰伏但商业健康 | 半停滞 | 高速迭代 | 高频低质 | 灾后弃养 |
| 商业信号 | **美区付费 Lifestyle 榜 #2**（2026-07-21） | 用户盘萎缩 | 自称 3M 用户，美区实际渗透小 | Android 1M+，涨价激进 | 增长归零（22 个月 +16 条评分） |
| 近期评分趋势（US 书面评论均分） | 2025:3.95 → 2026:4.52 | 2025:2.60 / 2026:3.00 | 2026 全 5★（**疑似刷评**） | 2024:2.50 / 2026:2.29 | 2025:**1.82** |
| 定价方向 | $4.99 买断不变 | $7.99/mo·$59.99/yr | 订阅 + **AI credits 按次** + $690/yr 造型师位 | 两年涨价 30-40%，周付 $6.99 | 转 $2.99 买断 + $0.99/mo 同步订阅 |

四个差异化假设在 A 组的总对照见 §6。核心结论：**没有任何一家同时具备「多衣柜（地点级）+ 存放位置 + 维度级尺码 + 场合档位推荐 + 体型」中的两项以上**；单点最接近者是 GetWardrobe（身体维度记录 + occasion 标签），但记录不驱动推荐、不做可视化。

---

## 1. Stylebook（left brain / right brain, LLC；iOS 独占；$4.99 买断）

### 1.1 版本节奏（一手：App Store 版本历史 JSON，2026-07-21 抓取）

| 日期 | 版本 | 内容 |
|---|---|---|
| 2025-06-15 | 10.1 | 深色模式、归档项排除统计、双指缩放恢复、批量 bugfix |
| 2025-03-19 | 10.0.2 | 崩溃修复、cost-per-wear 响应性 |
| 2025-03-10/12 | 10.0/10.0.1 | **“30+ new features” 大版本**：iCloud 同步、AI 抠图/AI 生成商品图、归档、批量导入 |
| 2023-12-23 | 8.3 | 性能优化（与 10.0 间隔 15 个月） |
| 2021-01-03 | 8.2 | 机型适配（与 8.3 间隔 35 个月） |

- **近 12 个月（2025-07-21→2026-07-21）更新次数：0**。最后一次更新距今 13 个月。
- 历史模式 = 「多年蛰伏 + 大版本爆发」：2009 年上线以来 25 个版本，2021-2024 近乎停摆，2025-03 一次性还清十年技术债（sync/AI 抠图/暗色模式）。
- 商业上蛰伏≠死亡：**2026-07-21 实测美区付费 Lifestyle 榜 #2、全类目付费榜 #93**（iTunes 官方 RSS）；姊妹 App「Stylebook Men」同榜 #96。一手、高置信。

### 1.2 评论主题随时间（一手：RSS 评论 500 条，2020-10→2026-07）

书面评论年度均分：2021:3.93 → 2022:4.13 → 2023:3.68 → 2024:4.10 → **2025:3.95（v10 阵痛）→ 2026:4.52（恢复）**。

**好评主题（稳定贯穿）**：超长期忠诚（10 年+ 用户密度极高）、$4.99 买断、打包清单、cost-per-wear/统计、日历防撞衫、客服响应快、无社交无广告的隐私感。
- [2026-07-20|5★] “I bought this app about 10 years ago… still religiously log all the new clothes I get and what I wear everyday.”
- [2026-02-14|5★] “Fulfills my long held desire for the dream closet software from the film Clueless. **Not being a subscription service is also a major perk.**”
- [2026-05-07|5★] “I started tracking my outfits **700 days ago** on Stylebook and haven’t missed a day!”
- [2026-06-25|5★] “When I had trouble syncing, I contacted Support and Bill responded within a half-hour.”
- [2025-11-25|5★] “I love how it’s private, no one sees your sets or items but you.”

**差评主题（分阶段演变）**：
- v10 前（→2025-03）：无云同步/换机丢数据、手动抠图费时。[2024-11-01|1★] “rather than smoothly sharing I get repeated error messages”；[2025-01-06|5★但焦虑] “I worry that if my phone ever dies I’ll lose all of my hard work.”
- **v10 阵痛期（2025-03→2025-10）**：同步产生重复项/丢项 [2025-04-07|4★] “after performing a Sync function, I now have 2 of every item”；[2025-03-13|3★] “Not all of my items synced”。AI 自动抠图不可关 [2025-04-03|1★] “You can’t even opt out of the AI auto cropping”；编辑窗口在 iPad 上过小 [2025-08-06|2★] “The advanced editing window is tiny”。同步提示扰民 [2025-03-21|1★] “I am never going to sync to the cloud. I do not need a tip every time I open the app.”
- 长期结构性抱怨：录入全手动（[2025-03-01|1★] “It’s extremely manual… the app doesn’t do anything to import that [brand/price]”）、无 Web/桌面端（[2025-07-23|5★] “Need online web interface please!!!!”）、性别化类目且男版单独收费（[2025-11-03|1★] “Wrong app for Men. Look for ‘Stylebook Men’ instead.”）。

### 1.3 定价与付费墙

- **$4.99 一次性买断，零 IAP**（App Store 页面无 In-App Purchases 区块；iTunes Lookup price=$4.99）。付费墙唯一位置 = 下载前。男版 Stylebook Men 独立再收 $4.99（差评点）。
- 转化机制 = 口碑/媒体（Vogue、WSJ 报道）+ 付费榜位自循环。无试用、无订阅、无广告。

### 1.4 Onboarding（二手：cottoncashmerecathair 深评 + 一手评论佐证）

- 流程：下载（已付费）→ 无注册、无问卷 → 直接进空衣橱 → 逐件入库（相机 AI 抠图 / 相册 / 网页链接 clip / “Import Wardrobe Basics” beta / AI 生成商品图）→ 手动建 look。
- **问题数：0；到首个价值时刻的步骤 = 建完最小衣橱**，用户自报耗时数小时到数天：[2026-01-06|5★] “it took me 12 hours to get all my clothes added”；[2025-12-18|5★] “Loading your individual pieces is a pain in the butt, but it’s totally worth it once you’re done.”
- 模式总结：零引导、高摩擦、高沉没成本 → 高留存。适合动机强的整理型用户，天然过滤轻用户。

### 1.5 四假设对照

| 假设 | 判定 | 证据 |
|---|---|---|
| 多衣柜 | **无** | 单 closet + 自定义分类；男女分 App 各自收费 |
| 存放位置 | **半吊子** | 仅 available/in storage/unavailable 三态 status；[2025-04-01|4★] 抱怨 “it doesn’t count ‘available’, ‘in storage’… as all being available”；[2024-11-09|5★] 用户确实用它管仓储衣物——需求存在、字段太浅 |
| 尺码/维度深度 | **无** | size 为普通文本字段；用户在求更基础的 purchase date 字段 [2026-05-24] |
| 场合驱动推荐 | **无** | 只有随机 shuffle；[2025-11-23|1★] “I thought this was suppose to help you style outfits and it doesnt”；[2026-06-10|5★] “Switch ai feature needs fine tuning… puts some weird stuff together” |
| 体型 | **无** | — |

### 1.6 规模估算

- 一手代理：US 评分 8,701（4.68★），2024-07（Wayback：7,775）→ 2026-07 **+926 条/24 个月**；付费 Lifestyle 榜 #2。
- 无可靠第三方下载/收入估算（Appfigures 404、Sensor Tower 付费墙）。基于「全类目付费榜 #93」的量级推断：美区日付费下载应在数百级、年流水七位数下限（**推断，低-中置信，仅供量级参考**）。

---

## 2. Cladwell（Cladwell, Inc；胶囊衣橱 + 天气推荐）

### 2.1 版本节奏

| 日期 | 版本 | 内容 |
|---|---|---|
| 2026-03-06 | 5.12.4 | bug fixes + iOS 26 适配 |
| 2026-02-10 | 5.12.3 | bug fixes |
| 2025-05-21 | 5.12.0 | item 类目/类型可编辑（回应差评） |
| 2025-04-15 | 5.11.0 | **AI 拍照批量入库自动分类**（"Snap some photos… AI will automatically categorize"） |
| 2024-12-05 | 5.10.0 | pinch-to-zoom 等杂项 |

- **近 12 个月更新：2 次，均为 bug fix**；近 24 个月唯一实质功能 = AI 入库（2025-04）。2023 年的 Ask Cladwell（ChatGPT）后再无方向级更新。
- 用户感知同步：[2024-09-01|2★] “Seems like developer gave up on any updates”；[2025-01-05|3★] “For $60 a year, there have been very little changes or improvements”；[2025-07-29|3★] “it seemed like they rebranded to be a tool for personal stylists, not the individual regular person.”

### 2.2 评论主题随时间（RSS 450 条，2018-10→2026-06）

书面评论量崩塌：2021:83 → 2022:31 → 2024:14 → 2025:15 → 2026H1:7；均分长期 2.4-3.3（工具组最低区间之一）。

- **订阅取消陷阱（贯穿 4 年未解，最高频差评）**：[2023-04-24|1★] “Have contacted multiple times… Don’t subscribe or you get caught in months of charges”；[2023-06-08|1★] “trying to cancel for a year and they keep charging me”；[2025-10-05|1★] “I deleted my account and cancelled my subscription through my Apple ID back in 2022. They have continued charging me monthly”；[2026-06-21|1★] “they took my money and will not give me access… I’ve sent 4 emails now.”
- **AI 分类错误且不可纠正**：[2025-04-19|3★] “I uploaded an image of a dress and it keeps categorizing it as a skirt over and over. No way to change it”；[2025-07-25|2★] “it put one of my T-shirts in the layers section, and I cannot move it into the top section.”（5.12.0 后部分可改）
- **天气推荐失灵**：[2025-07-22|2★] “The weather feature… has been stuck at 65H/55L every day… It is currently 95H and 77L where I live”；[2023-03-08|3★] “recommend sandals and shorts when it’s 30 degrees.”
- **推荐不学习/组合荒谬**：[2026-03-12|1★] “Cladwell creates ridiculous outfit suggestions, and the algorithm refuses to learn”；[2025-05-29|3★] “It always recommends the same 2-3 shoes for every single outfit.”
- 好评主线：capsule 理念带来的消费克制与整理感。[2025-10-18|5★] “It’s made me less materialistic when it comes to my closet”；[2026-03-25|5★] “I use the chat to help me pack for trips and make outfits for special occasions.”

### 2.3 定价与付费墙

- 现行 IAP（App Store 页，2026-07-21）：**Monthly Subscription $7.99 / Annual Subscription $59.99**；另存历史 SKU（Cladwell Monthly $2.99、Cladwell Annual $19.99、Quarterly $21.99、Weekly Membership $7.99、$9.99 档）——多次调价的地质层。
- 官网 pricing 页（2026-07-21 抓取）只写 “Get recommendations and better style for less than $5 a month”（= $59.99 年付折算），不显示具体价格；35+ 免费 capsule 模板作获客钩子。
- 免费层边界（二手：Indyx 博客 2025/2026 口径）：每天 1 套记录 + 1 套天气算法推荐 + Ask Cladwell 5 条/月；解锁全部（无限 outfit、mini-capsules、50 条/月 AI）需订阅；$49/月真人造型师档已从官网撤下（仅存二手记载）。
- 付费墙位置：核心「每日多套推荐 + 统计 + 分组」全部在墙内，免费层是玻璃橱窗式体验。

### 2.4 Onboarding（二手：Indyx 博客实测 + 一手评论佐证）

- **独特路线：不从拍照开始**。“The Cladwell app heavily encourages you to select from one of over thirty pre-built ‘capsule wardrobes’, and your Cladwell wardrobe is automatically populated with these generic items.”（Indyx 博客）→ 分钟级到达首个推荐，但推荐基于**通用假衣橱**，替换成真衣服靠后续逐件补拍。
- 需注册账号，且注册流程本身是历史差评点：[2023-03-03|1★] 密码创建死循环；[2024-10-22|1★] “Tried to sign up through my email and received notice that an unknown error occurred.”
- 问题数：capsule 选择 + 基本信息（少量）；**到首个价值时刻 ≈ 3-5 分钟（业内最快），但价值真实性打折**——这是「快但假」路线的代表样本。

### 2.5 四假设对照

| 假设 | 判定 | 证据 |
|---|---|---|
| 多衣柜 | **无**（capsule=分组非衣柜） | mini-capsules 按 season/work/travel 分组；[2024-09-27|4★] 用户靠把衣服移进 “storage” hack 分组，“it’s just a mess” |
| 存放位置 | **无** | 同上，用户用 storage 状态自救 |
| 尺码/维度 | **无** | 无尺码/测量字段的任何证据 |
| 场合驱动推荐 | **半吊子** | 每日推荐仅天气驱动；capsule 可按 work/travel 建组间接实现；用户明确要场合分类：[2023-03-08|3★] “I wish I could assign a category to each outfit like athletic, lounge, or office so that the recommendations…” |
| 体型 | **无** | — |

### 2.6 规模估算

- Google Play（一手，2026-07-21）：**100K+ 安装，513 条评论**——工具组 Android 最小盘。
- US iOS 评分 1,013（4.27★）；Wayback 2024-08：837 → **+176 条/23 个月**。
- 无收入估算；2018 年后无融资新闻。综合判定：存量维持型业务，用户盘萎缩（书面评论量 5 年缩水 90%+）。

---

## 3. GetWardrobe（Outfit Makers LLC；四端同步；订阅 + AI credits）

### 3.1 版本节奏（工具组最活跃）

近 12 个月 **15 次更新（~1.3 次/月）**，且功能密度高：

| 日期 | 版本 | 关键内容 |
|---|---|---|
| 2026-06-10/15/26 | 2026.06.x | 修复 + item 级 cost-per-wear + 天气过滤改进 |
| 2026-05-30 | 2026.05.1 | **隐私重定位**：“The app’s been reworked around your privacy. Nothing in it tracks you for ads or hands data to advertisers. Crash and usage diagnostics are optional, off by default” |
| 2026-04-10 | 2026.03.1 | 天气→穿搭建议强化 |
| 2026-02-12 | 2026.01.1 | **AI Outfit Generator（10-30 套/次）+ 虚拟 avatar + 全局搜索（离线可用）** |
| 2025-11-27 | 2025.11.1 | **Virtual Try-On** 上线 |
| 2025-10-15 | 2025.10.1 | AI 商品图增强 + 自动裁切 |
| 2025-08-05 | 2025.07.1 | 统计表重构（可排序 CPW/%worn） |

方向解读：2025Q4-2026 押注 AI 生成（generator/try-on/图片增强）+ 隐私叙事——**隐私卖点已被其抢先占用**（2026-05-30 release note 原文），与本产品假设 ④ 直接相关。

### 3.2 评论主题随时间 + **可信度警报**

- 年度均分：2021:3.55 → 2023:4.53 → **2026:5.00（n=44，零差评）**。
- **警报：2026 年美区 44 条评论全部 5★，且高度模板化**——每条标题即功能名（“Virtual Try-On” “Family Wardrobe” “Client Invites” “Auto Tagging”），正文为完美营销体（如 [2026-07-13|5★] “Postpartum body changes left me unsure what still fit or flattered me, and that’s where this app’s virtual try-on came handy”；[2026-07-05|5★] “As a minimalist who owns 37 carefully chosen pieces…”），以每周 2-3 条的稳定频率出现。**判定为疑似激励/代写评论（中-高置信）**，其 4.29★ 均分与「口碑良好」结论均需降级处理。
- 模板流中夹杂的真实信号反而是差评方向：[2026-02-20|5★但正文负面] “It’s not really user friendly anymore… items are larger which makes moving things around harder. It also seems as if it’s moving slower.”
- 历史真实主题：2023 前广告轰炸（[2023-01-23|1★] “ads every 10 seconds”；[2023-04-04|3★，俄语] “При КАЖДОМ переходе… вылезает реклама”——2023 评论中俄语占比高，印证其用户盘源于俄语区）；订阅逼付（[2023-01-07|2★] “free trial… only 7 days and then it automatically charges”）；抠图不准（2021-12 开发者回复承认需按教程拍摄）。
- 基线报告中的抱怨（抠图不准/更新变卡/标签删除不可恢复）在 justuseapp 口径仍成立，本轮无新增反例。

### 3.3 定价与付费墙（一手：官网 pricing 页 + App Store IAP，2026-07-21）

三层货币化，工具组最复杂：
1. **免费层**：100 件 + 全平台（iOS/Android/macOS/Web）+ AI Generator Starter（10 套/次，不限次数）+ AI Studio 不限 + 天气日历 + 社区，无需信用卡。FAQ：“Is the free tier really free? Yes. No credit card, no trial period, no catch.”
2. **Premium**：解锁无限件数、Family Wardrobe、打包清单、归档/批量编辑/高级过滤、统计。官网：**$49.99/年（折 $4.17/月，标 −40%）**；App Store 页却写 “$4.99/month or $34.99/year”，**两处价格不一致**（疑似正在涨价或分渠道定价，上线对标前需实机复核）。年付含试用。
3. **AI Credits（按次消耗，独立于订阅，人人可买）**：20/$4.99、60/$9.99、150/$19.99、500/$59.99、1000/$89.99；消耗场景 = Virtual Try-On、Generator Standard(20)/Pro(30) 模型、照片增强。
4. **Stylist Mode**：$69.99/月或 **$690/年**，≤10 客户，客户自动获得 Premium——B2B2C 变现位。

付费墙位置：第 101 件物品（最经典卡点）+ 家庭衣柜 + 统计；AI 深功能移到 credits（免费层也能付费用）→ 「订阅管容量、credits 管算力」的解耦结构，值得研究但复杂度高。

### 3.4 Onboarding

- 免费无卡直入；自动打标（“Snap a photo — AI details everything: category, color, season, fabric… so cataloguing takes seconds, not minutes”，App Store 描述）；帮助中心有完整 digitize 指南。
- 无强制问卷证据；到首个价值时刻 = 录入若干件后跑 Starter Generator（10 套/次免费）。四端同步使桌面批量录入可行（[2026-01-18|5★模板化] 亦主打此点）。

### 3.5 四假设对照（工具组中单点最接近者）

| 假设 | 判定 | 证据 |
|---|---|---|
| 多衣柜 | **半吊子（按人不按地点）** | Family Wardrobe（Premium）：“profiles for family members and anyone you style, filtered per member”（官网 pricing）；帮助中心确认按 family member 过滤/批量分配。无「地点/柜」维度，无转移语义 |
| 存放位置 | **无** | 帮助中心全文 “location” 仅指天气城市与行程地点；无 storage 字段 |
| 尺码/维度 | **有（记录级）** | 帮助中心：“**Sizes Notebook — Record body measurements and track how different brands and sizes fit you** for smarter shopping decisions”；精选评论 [2021-12|5★] “I can input my measurements, sizes for specific brands, **tells me my body shape**”。但测量数据不驱动推荐、不做合身判断、不做可视化 |
| 场合驱动推荐 | **半吊子（标签过滤级）** | 帮助中心：“Occasions — Create custom occasion tags (e.g., Work, Weekend, Formal) and organize outfits by occasion”；AI Generator “filtered by weather, occasion, and mood”。已是工具组最强，但无场合档位×日历联动 |
| 体型 | **半吊子** | body shape 判定存在（评论证据）；Try-On 可用 “virtual model or your own body photo”（credits），非参数化体型可视化 |

### 3.6 规模估算

- 自报（官网 2026-07）：“Trusted by 3 Million People”“3M+ Users worldwide”“39+ Countries”——**自报口径、累计注册，低置信**。
- 一手代理：Google Play **1M+ 安装、4.86K 评论**；US iOS 评分仅 **754**（2024-10 Wayback：618，**21 个月 +136**）→ 美国市场实际渗透很小，与其宣称规模的落差显著（历史盘在俄语区，官网四语含俄语）。

---

## 4. Pureple（ICECLIP LLC；免费 + 广告 + 激进订阅）

### 4.1 版本节奏

近 12 个月 **16 次更新，其中 15 次 release notes 仅写 “bug fixes”**（一行）；唯一功能版本 = 6.0.6（2025-09-03）“virtual try-on”。此前 5.9.9（2025-01-28）“AI feature opened for all users”。高频发版 ≠ 产品演进——工程节奏活跃但产品方向停滞，且同期口碑继续恶化（见下）。

### 4.2 评论主题随时间（RSS 500 条，2020-02→2026-05）

书面评论量与分数双降：2021:198（2.43）→ 2023:53（2.58）→ 2024:26（2.50）→ 2025:15（3.33）→ 2026:7（2.29）。

- **广告密度（第一主题，贯穿 4 年）**：[2023-12-12|1★] “You get an ad every 5 second”；[2024-01-06|3★] “embarrassingly long, nonskipable ad, after I enter every single item”；[2025-09-06|3★] “Now it’s constant ads every time you click”；[2025-10-21|3★] 全屏广告关不掉。
- **付费墙后移（信任破坏的教科书案例）**：日历原免费、2025 秋移入 Pro——[2025-11-07|1★] “I mostly used it for the calendar feature. But now they are making the calendar feature apart of the pro version and making you pay **6.99 A WEEK**… That is insane for what this app is.”；Style Me 需看广告或付费 [2024-07-31|1★] “spent around an hour taking pictures… just to click ‘Style Me’ and be met with ‘Upgrade to Pro to continue.’”
- **定价愤怒**：[2025-09-05|2★] “$6.99 a week is an insane ask”；[2024-06-03|2★] “Now they want you to pay 70 bucks a year”。
- **计费纠纷**：[2026-03-19|1★] “Pureple illegally paid for a subscription of **$95.39** for year (WHEN THEY HAVE $6 AND SOME CHANGE SUBSCRIPTION)… Apple will not refund my money and Pureple is ignoring my request.”
- **疑似冒名刷评指控（2026 新信号）**：[2026-05-26|1★] “**This app wrote a fake review with my name.** I didn’t even know I had this app.”；同日另一条 “Someone broke into my email and left a review for this app. Very suspicious.”
- 稳定的产品级差评：上传慢/图片丢失（[2024-09-07|1★] “I take pictures… then next thing I know it’s just black or empty squares”）、sync 让已删项复活（[2024-09-11|2★] “Hitting ‘Sync All Data’ is like a death wish”）、拍照方向翻转（2023-11-21、2025-07-28 两年未修）、推荐随机感（[2024-10-14|3★] “as if the app is just spinning a wheel”；[2024-11-21|3★] “it paired my nice heels with a hoodie??”）。
- 好评主线（少量）：社区互相搭配、AI 打包：[2026-01-19|5★] “I used AI to create outfits for my recent vacation… helped me not overpack, for once!”

### 4.3 定价与付费墙（含两年涨价轨迹，一手对比）

| 时点 | Weekly | Monthly | Yearly | 来源 |
|---|---|---|---|---|
| 2024-08（Wayback App Store 描述） | $4.99 | $9.99 | $69.99 | 一手历史快照 |
| 2026-07（现行 App Store 描述） | **$6.99** | **$14.99** | **$89.99**（7 天试用） | 一手 |

**两年全线涨价 30-40%**，同时把日历从免费层移入 Pro。IAP 列表另见残留档：AI Style Advisor+ $39.99、Pro Version $14.99、Annual Storage $9.99、Pureple Subscription $34.99-$62.99 多档、“Monthly renewals are charged at USD$3.99” 旧文案——定价体系混乱是计费纠纷（$95.39 投诉）的土壤。
付费墙位置：打开 App 即订阅推销（[2025-01-01|4★] “Once you first open the app it’ll ask you to pay for a monthly subscription”）→ 录入免费但插广告 → Style Me/日历/去广告/云同步在墙内。

### 4.4 Onboarding

- 打开即订阅弹窗（可关）→ 逐件拍照/相册（自动分类，号称 “Fastest Virtual Closet Creation”）→ Style Me 触发广告或付费墙。
- 问题数少，但**到首个价值时刻被商业化拦截**是其 onboarding 的定义性特征：[2023-09-09|1★] “took hours taking pictures… you have to pay money for it to actually find outfits that match.”
- 批量上传易崩（基线已录：40+ 张崩溃），本轮评论续证上传慢/丢图。

### 4.5 四假设对照

| 假设 | 判定 | 证据 |
|---|---|---|
| 多衣柜 | **无** | 无任何多衣柜/多 profile 证据 |
| 存放位置 | **半吊子→存疑（基线口径需降级）** | 2024-08 与 2026-07 两版官方描述的过滤字段均为 “season, occasion, color, brand, size, price, and more”——**均无 location**。基线的 location/availability 字段说法源自 justuseapp 转载旧文案；现行更可能是「自定义过滤器可自建 location」（[2024-02-11|3★] “You can make custom filters too”）。上线对标前需实机验证 |
| 尺码/维度 | **无** | size 仅为过滤字段 |
| 场合驱动推荐 | **半吊子** | occasion 过滤字段 + “AI Style Suggestions: Endless outfit ideas… for any occasion”（描述）；无场合档位、无日历联动；实际推荐被评为随机 |
| 体型 | **无** | try-on 是通用模特（“see it on a model using AI”，描述原文），与用户体型无关 |

### 4.6 规模估算

- Google Play（一手）：**1M+ 安装、3.98K 评论**。US iOS 评分 6,120（3.94★）；Wayback 2024-08：5,946 → **+174 条/23 个月**，美区增长近停滞。
- 无收入估算。判定：老用户盘吃存量 + 广告/涨价双向收割，处于口碑-收入死亡螺旋早期。

---

## 5. Smart Closet（Rabbit Tech Inc；灾难样本）

### 5.1 版本节奏与「MongoDB EOL 灾难」时间线（本轮最重要的增量发现）

| 日期 | 事件 | 证据 |
|---|---|---|
| 2022-12-11 | v3.7.1 后**停更近 3 年** | 版本历史 |
| **2025-09-30** | 后端框架 EOL（用户点名 **MongoDB**（Realm/Atlas Device Sync）停服），登录+同步全断 | [2025-11-19|5★] “The app’s framework has reached its End Of Life as of Sept. 30, 2025”；[2025-10-21|1★] “**MongoDB (the service that allows for cloud syncing data as well as signin) announced end-of-life support**—and the developers did not warn a single person that this would mean all app data would become inaccessible” |
| 2025-10 全月 | 用户被锁/丢数据潮（本轮抓到至少 14 条 1★） | [2025-10-19|1★] “I have lost everything; years of uploading garments… RUN. Run fast and run far”；[2025-10-21|1★] “I have lost 100+ hours of work”；[2025-10-14|1★] “I paid for pro specifically to be able to download my backed up data… feel scammed” |
| 2025-11-07/08/10 | 3 天连发 3 版急救（修 Google/FB/Apple 登录、改备份、**新增同设备多账号多 closet**） | 版本历史 3.8.1-3.8.3 |
| 2025-11 中下旬 | 部分用户恢复 | [2025-11-14|4★] “Finally able to log in with my Apple account & everything was saved”；[2025-11-19|5★] “REVISED — Tried to log in last night & was able to access my closet” |
| 2025-12→2026 | 部分用户永久丢失 + 客服失联继续 | [2025-12-01|1★] “I previously paid to have my data backed up, yet none of it is loading back”；[2026-02-04|1★] “2 years of collecting images… gone in an update. The company won’t even answer emails” |
| 2025-11-10 后 | 再次停更至今（8 个月） | 版本历史 |

且这不是首次：**2022-12 v3.7 更新同样大规模清空数据并砍掉日历**（[2022-12-08|1★] “WHERE ARE ALL MY CLOTHES?? Yall updated the app and completely WIPED everything”；[2022-12-09|1★] “Calendar feature now gone”）。付费备份不可用是贯穿性主题（[2022-07-04|1★] “I paid $9.99 to back up everything… everything is gone”）。

### 5.2 评论主题随时间

均分：2022:2.25 → 2023:2.65 → **2025:1.82（n=28）** → 2026:2.20。主题排序：数据丢失/登录死亡 >> 客服零响应（[2022-02-18|1★] “emailed… several times… not once received a reply” → [2026-03-09|1★] “There is no longer customer service support”）> 隐私担忧（[2026-03-10|1★] “smart closet needs too much of our personal identifiers and so today I switched to a more privacy forward option”）> 功能退化（[2026-07-12|3★] 建 look 时类目过滤失效至今未修）。
好评残留：品牌库/网页导入（[2026-05-04|5★] “Love the google search feature for importing images”）、统计与 cost-per-wear、规则化随机 look。
中文用户对照差评（2023-05-04|1★）：“论收费比不上尽简衣橱，甚至没有免费的搭搭好用……强烈推荐用搭搭”——与基线「中文产品在收纳维度更强」互证。

### 5.3 定价与付费墙

- **2025-11 复活后转付费下载 $2.99**（iTunes Lookup formattedPrice，2026-07-21；基线时代为免费）+ Pro 订阅 **$0.99/月或 $9.99/年**（Auto Backup & Sync；IAP 列表另见 $3.99 档）。
- 付费墙位置：单机功能基本全免（买断价内），唯一订阅点 = 云备份/多设备同步——恰是其两次灾难的功能，付费信任已破产。
- 分级 17+、类目 Shopping：变现结构偏联盟导购（品牌库导流）。

### 5.4 Onboarding

- 首启需登录（Google/FB/Apple）以启用同步——**登录即灾难引爆点**（FB 登录坏了一年+：[2024-06-07] “Anyone who logged in with a Facebook account cannot use the app!”）。
- 快速起步路径 = 从数千品牌库选现成商品图入库（免拍照）或拍照一键抠图；无问卷。到首个价值时刻（建 look/随机生成）在单机路径上较快，但账号/同步故障随时清零。

### 5.5 四假设对照

| 假设 | 判定 | 证据 |
|---|---|---|
| 多衣柜 | **半吊子（账号 hack）** | 3.8.1（2025-11-07）：“Now you can create and manage **multiple closets with different accounts** on the same device — available for every user”——靠切换账号实现，无跨柜检索/转移语义 |
| 存放位置 | **无（曾被用户自造后毁掉）** | [2022-12-24|2★] “I used to have a customized status tag to group cloth by **where I storage them**. The new update just entirely wiped it” |
| 尺码/维度 | **无** | 类目/颜色/品牌/价格/季节字段而已；[2024-07-19|3★] 连鞋型细分都缺 |
| 场合驱动推荐 | **无** | 仅自定义规则随机 look（[2022-09-08|1★] “the ‘rule’ outfit adding makes no sense”） |
| 体型 | **无** | — |

### 5.6 规模估算

- Google Play（一手）：**1M+ 安装、6.18K 评论**（历史积累）。US iOS 评分 4,344；Wayback 2024-09：4,328 → **22 个月仅 +16 条**——美区增长归零。
- 判定：历史 1M+ 盘子的僵尸资产，现金流靠 $2.99 买断长尾。

---

## 6. 四个差异化假设 × 五竞品总对照

| 假设 | Stylebook | Cladwell | GetWardrobe | Pureple | Smart Closet |
|---|---|---|---|---|---|
| ① 多衣柜（地点级隔离 + 搭配不跨柜） | 无 | 无（capsule=分组） | **半吊子**（Family=按人 profile，Premium） | 无 | 半吊子（多账号 hack，2025-11 新增） |
| ② 存放位置字段深度 | 半吊子（in storage 单一状态） | 无 | 无 | 存疑（官方描述两版均无 location；或可自定义过滤器自建） | 无（用户自造 tag 曾被更新毁掉） |
| ③ 尺码/维度字段深度 | 无（文本 size） | 无 | **有-记录级**（Sizes Notebook：身体维度 + 各品牌尺码 + 体型判定），不驱动任何功能 | 无 | 无 |
| ④ 场合驱动推荐 | 无（随机 shuffle） | 半吊子（天气日推 + work/travel capsule） | **半吊子-最强**（occasion 自定义标签 + AI generator 按 weather/occasion/mood 过滤） | 半吊子（occasion 过滤 + “for any occasion” 话术，实际随机） | 无 |
| 体型功能（假设②配套） | 无 | 无 | 半吊子（判型不可视化；try-on 可上传本人照片，credits 计费） | 无（通用模特试穿） | 无 |
| 免费层是否卡件数 | 不卡（买断） | 不卡件数、卡功能 | **卡 100 件** | 不卡、卡功能+广告 | 不卡（买断 $2.99） |
| on-device/隐私叙事 | 隐性（无社交被好评） | 无 | **2026-05 起显性主打**（no ad tracking、诊断默认关；但仍是云账号架构） | 无（广告 SDK 重） | 反面教材（隐私差评 + 数据灾难） |

**结论**：四假设的完整组合在工具组仍然无人占据；假设 ④ 的隐私叙事已被 GetWardrobe 抢跑营销话术（2026-05-30），但其架构仍是云账号 + 行为数据可选上报，「数据根本不在开发商服务器上」的 CloudKit 私有库路线仍是空位。假设 ② 的「存放位置」在五家中最好的实现只是一个状态枚举——树形位置 + 换季批量移位无人做过。

---

## 7. 跨竞品增量洞察（供市场决策）

1. **更新频率与商业健康完全解耦**：Stylebook 13 个月零更新仍居付费榜 #2；Pureple 月更但口碑继续崩。工具品类的护城河 = 用户数据资产沉没成本 + 信任，不是迭代速度。对我们：MVP 不必追功能军备，但**信任面（数据安全/定价诚实）一票否决**。
2. **数据信任是品类第一生死线（本轮最强证据链）**：Smart Closet 两次数据灾难（2022-12 自毁、2025-09 MongoDB EOL 他杀）直接把 1M+ 盘子打成僵尸；Stylebook v10 同步阵痛也立刻反映在 2025 年均分（3.95）。付费备份失效（Smart Closet/Pureple）是最高烈度差评。→ 本产品「无自建后端、数据在用户 iCloud」既是成本优势更是可营销的结构性信任优势，应显性表达为「我们没有可以宕机的服务器」。
3. **付费墙演化的品类共性 = 越收越紧，且每次收紧都被评论精确记录**：Pureple 两年涨价 30-40% + 日历入墙；GetWardrobe 引入 credits 按次收费 + 官网年费从 $34.99 → $49.99 迹象；Cladwell 维持 $59.99/yr 但免费层是玻璃橱窗。周付 SKU（$6.99-7.99/wk）成为品类新惯例且是差评导火索。→ 免费层边界必须一次定对，**任何「先免费后入墙」的功能回收都会产生带日期的永久差评**。
4. **评论生态已被污染，评分不可比**：GetWardrobe 2026 年 44 条全 5★模板文案（疑似代写）；Pureple 被用户指控冒名发评。竞品对标与 ASO 决策必须下钻评论文本而非均分；同时说明真实差评（尤其数据/计费类）的信任权重在放大。
5. **「首个价值时刻」的两条已验证路线及其中间空位**：Cladwell「预置模板 3 分钟但假衣橱」（推荐脱离真实衣物成为其核心差评）vs Stylebook「全手动 12 小时但高留存」。**AI 批量真衣橱、30 分钟内到首个真实推荐**的中间路线在工具组无人做到——直接支撑 F1（扫描入库）作为生死线功能的优先级。
6. **GetWardrobe 是 A 组唯一需要持续盯防的活体**：四端 + 月更 + Sizes Notebook + occasion 过滤 + 隐私话术 + stylist B2B2C，几乎每条都踩在我们假设的邻格；但其美区渗透小（754 评分）、执行浅（测量不驱动推荐）、100 件卡点在身——正面差异化打法清晰：维度数据要「用起来」（fit 判断/体型可视化）而非「记下来」，免费层不卡件数直击其最大卡点。

---

## 8. 来源清单（关键）

**一手**
- iTunes Lookup API（5 App 元数据，2026-07-21）：`https://itunes.apple.com/lookup?id={335709058,1140550878,656212466,628106373,1198057728}&country=us`
- App Store 页面内嵌版本历史（各 25 条，2026-07-21 抓取）：`https://apps.apple.com/us/app/id{各ID}`
- App Store 官方 RSS 评论流（带日期原文）：`https://itunes.apple.com/us/rss/customerreviews/page={1-10}/id={各ID}/sortby=mostrecent/json`
- 美区付费榜 RSS（2026-07-21）：`https://itunes.apple.com/us/rss/toppaidapplications/limit=200/genre=6012/json`（Stylebook #2）；全类目同端点（#93）
- Google Play 商店页（安装区间，2026-07-21）：`com.app.pureple`（1M+）、`com.cladwell`（100K+）、`com.ThreeBoots`=GetWardrobe（1M+）、`com.rkk.closet`=Smart Closet（1M+）
- GetWardrobe 官网/定价/帮助中心：https://getwardrobe.com/ 、https://getwardrobe.com/pricing 、https://help.getwardrobe.com/latest/features/
- Cladwell 官网：https://cladwell.com/ 、https://cladwell.com/pricing
- Smart Closet 官网：https://smartcloset.me/ ；Stylebook 官网：https://stylebookapp.com/
- Wayback Machine：Pureple App Store 2024-08-07（历史定价 $4.99/$9.99/$69.99、评分 5,946）；Stylebook 2024-07-29（7,775）；Cladwell 2024-08-07（837）；Smart Closet 2024-09-18（4,328）；GetWardrobe 2024-10-04（618，含 2021-12 身体维度评论及开发者回复）；getwardrobe.com 2024-09-04

**二手**
- Indyx 竞品博客（Cladwell onboarding/免费层、Stylebook/Pureple 评价；厂商立场）：https://www.myindyx.com/blog/the-best-wardrobe-apps
- Stylebook 深度评测（onboarding 流程）：https://www.cottoncashmerecathair.com/blog/2020/4/10/how-i-catalog-my-closet-and-track-what-i-wear-with-the-stylebook-app-review

**已知缺口**：Appfigures/Sensor Tower/Apptopia 下载与收入绝对值不可得（付费墙；Wayback 无存档）；Pureple 存放位置字段、GetWardrobe 体型判定现状需实机验证；WebSearch 预算耗尽未覆盖 YouTube onboarding 视频逐帧还原。
