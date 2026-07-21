# 需求侧验证：四个差异化假设的真实需求强度（2026-07-21）

> **定位**：填补 R1「供给侧空白反推需求，需求侧未验证」的缺口（DESIGN.md §8-R1）。本轮只做需求侧增量，不重复 `01-competitors.md` 的功能矩阵。
> **方法与数据源**（按证据强度排序）：
> 1. **App Store 评论一手抓取**：经 Apple iTunes RSS 公开 JSON 接口抓取 11 个竞品各自最近 ~150 条美区评论（共 1,484 条，含日期/星级/全文），2026-07-21 抓取。这是本报告的主证据体。
> 2. **Reddit 原帖一手检索**：经 pullpush.io（Pushshift 后继）全文检索 r/femalefashionadvice、r/capsulewardrobe、r/AskWomenOver30、r/HomeOrganization 等版块的帖子与评论（覆盖至 2025-05 前后），并整线程拉取两个关键讨论串。
> 3. **官方一手数据**：Indyx《State of Our Wardrobes 2025》报告、iTunes Search API 的评分总量、Wikipedia、Shopify/Invesp 退货统计页。
> 4. **沿用 R1 已核对来源**：WWD（Whering 用户数）、韩经（Acloset MAU）等。
> **检索约束声明**：本 session WebSearch 配额耗尽、exa API key 失效、DuckDuckGo/Bing 反爬——无法做开放式网页发现。因此**创始人播客/访谈中的激活率与留存曲线未能获取**（假设④的运营数据部分改用替代证据：评论时间分布、MAU/注册比、评论原声中的弃用叙事）。涉及推断处已标注。

---

## 0. 结论速览

| # | 假设 | 证据强度 | 一句话判定 |
|---|------|---------|-----------|
| 1 | 场合日历驱动的每日搭配推荐 | **强**（需求真实，供给执行普遍差） | 「早晨决策疲劳」是社区高频词；每日推荐是竞品被爱的原因，也是被骂最狠的功能——**天气失配、场合失配、重复推荐**三大执行失败构成明确的质量门槛 |
| 2 | 存放位置/换季收纳管理 | **中**（行为普遍，显性 App 需求弱） | 美国用户换季收纳行为广泛存在（四季气候+小公寓+storage unit 文化），但**没有找到「用 App 记衣服在哪个箱子」的直接呼声**；Pureple 的 location 字段无人提及 |
| 3 | 体型可视化与合身判断 | **强**（张力明确） | 用户热爱 avatar 试穿概念，但**照片 avatar 的体型失真是差评首因**，且有「希望能输入身体测量数据」的直接原声——参数化体型路线正好踩在竞品的失败点上 |
| 4 | 录入摩擦致弃用 | **强**（一手实证扎实） | 「花 2-4 小时录入→撞付费墙/AI 拉胯→弃用」是跨竞品可复现的叙事模板；Cladwell/Pureple/Doji 评论速度已枯竭是弃用的行为学证据 |
| 5 | 付费意愿：买断 > 订阅 | **强** | Stylebook $4.99 买断被反复点名为购买理由；「一次性收费我就付，订阅我不付」的原声多次出现；Acloset 涨价与 Style DNA 订阅陷阱的口碑崩塌提供反面实证 |
| — | 附加发现：隐私叙事 | **反证（弱需求）** | 1,484 条评论中**几乎零条**主动提及隐私/数据安全——on-device 隐私不是本品类的获客钩子，只能作留存期信任资产 |

---

## 1. 假设①：场合日历驱动的每日搭配推荐 —— 评级：**强**

### 1.1 需求侧正面证据（Reddit 原声）

「决策疲劳（decision fatigue）」在目标社区是高频自发词汇，且用户已在用行为方案（胶囊衣橱/制服化/前夜规划）自救：

- *"On paper a capsule wardrobe sounds like the perfect solution to decision fatigue"* — r/femalefashionadvice，2024-01-18，308 赞 135 评论（https://www.reddit.com/r/femalefashionadvice/comments/19a1yc1/）
- *"I realized that maintaining my clothes and deciding what to wear aren't things that I want my brain occupied with... those people are 100% men."* — 「女性版 Steve Jobs 制服」讨论，r/femalefashionadvice，2021-07-18，680 赞 245 评论
- *"My main motivation for change is decision fatigue, never having appropriate things to wear"* — r/capsulewardrobe，2025-05-10
- *"How I get dressed has always been ritualistic... I plan all outfits (down to the underwear and socks) night before."* — r/AuDHDWomen，2025-05-19
- 职业场合得体焦虑单独成帖：*"Workwear - Women in Politics ... it seems there is no real 'dress code' for women"* — r/femalefashionadvice，2021-06-08，411 赞

**「忘记自己有什么」是本品类第一 JTBD**：1,484 条评论中 19 条自发使用 "forget what I own / remember what I have" 表述（Cladwell 5 条、Alta 5 条）。代表原声：
- *"my memory for what I own is TERRIBLE"*（r/FFA，2025-04-02）
- *"I have adhd and object permanence is a real issue. But this app helps me remember what I have in my closet so I don't buy multiples"*（Cladwell 评论，2022-04-26，5★）

### 1.2 每日推荐功能的实际口碑（App Store 一手）

**被爱的时候**（证明需求存在）：
- *"I never wake up and think 'I have nothing to wear' anymore"* — Cladwell，2021-09-07，5★
- *"Factors in your local weather and occupation or social schedule when suggesting outfits"* — Alta，2026-07-17，5★（60 岁职业女性）
- *"choosing an outfit is no longer a problem for me. My style is sooo elevated now."* — Alta，2026-07-13，5★
- *"I'm either running too behind to put thought into my outfits and/or I'm struggling to envision how I should style something"* — Alta，2026-07-15，5★（时尚从业者）

**被骂的时候**（三大执行失败 = 本产品的质量门槛）：

| 失败模式 | 原声（出处/日期/星级） |
|---------|----------------------|
| **天气失配**（最高频差评主因） | Cladwell 2025-07-29 3★：*"It's high of 97 degrees F today and Cladwell recommended black jeans with a black tee"*；Cladwell 2025-07-22 2★：天气数据卡死在 65/55 导致夏天推毛衣，**用户因此退订**；Acloset 2026-07-04 1★：*"over 100 degrees and the outfit recommendations include jeans and a mid-weight field jacket"*；Acloset 2026-03-16 1★：82°F 推羊毛裤+开衫，因为算法把睡眠时段低温计入日均温；Acloset 2026-05-12 2★：App 内两处天气数据互相矛盾 |
| **场合失配** | Cladwell 2023-03-08 3★：*"recommendations didn't put together my running shoes and little black dress"*（用户明确要求按 athletic/lounge/office 分场合推荐）；Alta 2026-07-11 3★：*"The accessories it adds don't feel right for the occasions suggested"* |
| **重复推荐/不认「已穿过」** | Cladwell 2021-12-29 2★：*"If I just said I wore this sweater today, why are you suggesting it as an outfit for tomorrow?"*；Cladwell 2026-02-23 3★：免费 2 套/天 + 重复本周已穿；Alta 2026-07-14 5★ 也主动要 shuffle 防重复 |
| **组合非法**（缺服装常识约束） | Cladwell 2026-02-18 3★：*"A leather jacket with an open front blazer and no pants? An outfit with TWO blazers?"*；Cladwell 2026-06-27：把内衣当下装推；Alta 2026-07-11 3★：*"a navy top and black shoes... didn't make getting dressed any easier"* |

### 1.3 反面/边界证据

- **行为替代方案分流**：社区主流自救路径是「减少衣服」（胶囊/制服化/Project 333），其逻辑是*少即是解*——对这批用户，App 是次优解。*"I sold/donated 60% of my clothes and it actually feels like I have more to wear now... significantly reduced my stress"*（r/FFA 2025-04-05）。
- **DIY 工具分流**：Google Slides、Notion、Pinterest 自建衣橱库的用户不少（FFA「which wardrobe app in 2025」串，2025-03-26 起）；一位用户因 Polyvore 被 SSENSE 一夜关停而*"vowed never to entrust my closet to an app again"*（2025-04-07）——**数据可导出/可迁移是信任前提**。
- Cladwell 免费 1-2 套/天的钩子有效但双刃：*"it's annoying when it reuses clothes I've already worn that week and that's hard to avoid if I only get two outfits a day"*（2026-02-23）。

### 1.4 对 MVP 的含义

- **做**：每日推荐是正确的核心回路，但发布门槛 = ①天气数据准确（用户所在地实时，区分日间时段——Acloset 把夜间低温算进去被骂上 1★）②场合硬过滤（本产品 F4 的场合标签+温区硬过滤设计正好命中）③7 天不重复窗口 + 已穿/在洗状态感知（本产品 Item 状态机设计命中）④服装语法约束（不能两件 blazer、不能缺下装）。
- **信心注脚**：竞品的失败全部是执行层而非需求层——没有一条差评说「我不需要每日推荐」，全部在骂「推得不对」。

---

## 2. 假设②：存放位置/换季收纳管理 —— 评级：**中**

### 2.1 换季收纳是美国真实且普遍的行为（正面证据）

- *"I live in a tiny studio apartment and don't have space for like 6 different coats... **all my off-season clothes are stored off site** so I need to wait for a day that winter is 100% over to do **the big switcheroo**."* — r/femalefashionadvice，2025-03-16（新英格兰）
- *"I do seasonal swap-outs because I live in a place with 4 seasons"* — r/capsulewardrobe，2024-09-09
- *"I keep out of season clothes in the basement. I've got two tubs of clothes, a tub for shoes... I just did my seasonal swap last week"* — r/FFA，2020-04-30
- *"I have a **storage unit** for the time being because I live in a smaller space and this weekend I went and got two bins of all shoes"* — r/capsulewardrobe，2024-12-23
- 收纳与决策疲劳被用户自发关联：*"It is easier to have less available at all times from a laundry, **storage** and decision fatigue standpoint"*（r/capsulewardrobe，2025-05-18）；*"If you have space to put away things that aren't in the right season it can streamline the look of your closet, reduce decision fatigue"*（2025-04-08）
- 竞品「虚拟收纳」功能确有使用：Cladwell 用户把 storage 功能当组织手段用（2024-09-27 4★ 把它当分组 workaround；2021-11-05 5★ *"placing items in storage are all incredibly easy"*；2021-04-26 *"put wrong-size outfits in virtual storage"*）；GetWardrobe 2026-05-02 5★：*"I used to dread the seasonal closet swap... everything is done in less than 10 minutes"*（注意：GetWardrobe 近期五星评论语言模式高度雷同，疑似激励/水军评论，降权处理）。
- **文化热度**：The Home Edit——Netflix《Get Organized with The Home Edit》两季（2020-09、2022-04），客户含 Reese Witherspoon/Khloé Kardashian 等，2023 年被 Hello Sunshine 收购（https://en.wikipedia.org/wiki/Get_Organized_with_The_Home_Edit）——收纳可视化在美国是成熟的大众文化审美。

### 2.2 反面证据（为什么只给「中」）

- **没有找到「想用 App 记录衣服存放在哪」的直接美国原声**：pullpush 多组检索（"storage unit"、"seasonal swap"、"in a bin somewhere"、r/HomeOrganization）都只命中收纳行为本身，无一条抱怨「不记得哪件在哪个箱子」并求工具。
- **Pureple 是欧美唯一有 location 字段的竞品，其最近 150 条评论零条提及该字段**——供给存在但无人因它而爱（Pureple 差评集中在广告/崩溃/付费墙）。
- 中文市场验证（搭搭/尽简，R1）依托的是**小户型+强制换季**的居住结构；美国有 walk-in closet 的住宅占比高，痛感被住房条件稀释（多位 r/FFA 用户描述大 walk-in + 4 个挂杆臂的自有储物空间，2025-04-09）。

### 2.3 对 MVP 的含义

- **降级为次级功能，不作首屏卖点**：把 StorageLocation 树保留在数据模型（成本已沉没在设计中），但 UX 上定位为「换季 swap 助手 + 缺件提示」的支撑层——即推荐引擎在推被收进换季箱的衣服时给出「在 xx 箱」提示，这比独立的「收纳管理」入口更贴近实际行为。
- 营销措辞用美国用户自己的语言：**"seasonal swap" / "the big switcheroo"**，而不是「存放位置管理」。
- 真正的强需求邻接点是**多地/多柜**（两地生活、大学生寒暑假、储物单元）——本产品的多衣柜分层架构在美国的对应场景是 storage unit 与两地生活，可在 v1.x 讲这个故事。

---

## 3. 假设③：体型可视化与合身判断 —— 评级：**强**

### 3.1 用户想要「在自己身上看效果」（需求真实）

- *"I literally photoshop my head on clothes when online shopping to see what fits me since it's so hard to judge a piece on a model"* — Doji，2025-12-01，5★（需求存在的极端证据：用户手工 P 图自救）
- *"The ability to try clothes on literally your body and see how they will look is incredible!! It has changed the way I look at my clothes"* — Alta，2026-07-13，5★
- *"the app is like playing Barbie in real life!"* — Alta，2026-07-15，5★
- *"I love to see how outfits may look on me before hand without requiring me to actually try them on"* — Alta，2026-07-15，5★
- 退货背景数据：2025 年美国线上销售退货率约 **19.3%**（Shopify 汇编，2025，https://www.shopify.com/blog/ecommerce-returns）；服装/鞋类因「fit and sizing are hard to judge from a product page」高于均值；**近 2/3 消费者承认 bracketing（多尺码下单退回）等行为**（同上）。Invesp 汇编：线上整体退货率约 30% vs 实体店 8.89%（https://www.invespcro.com/blog/ecommerce-product-return-rate-statistics/，年份未标注）。（注：「fit 占服装退货原因的确切百分比」本轮未能从可核验来源获得，遗留待查。）

### 3.2 照片 avatar 的体型失真是差评首因（竞品失败点 = 本产品支点）

**Doji（纯照片 avatar 试穿，$14M 融资）最近 34 条评论中 12 条负评几乎全部指向体型失真**：
- *"**The avatar makes you skinny so it defeats the purpose** of 'trying' clothes on. **I thought it would have a feature where you could put your measurements, height and...**"* — 2025-12-01，2★（**直接点名想要身体维度输入——本产品假设②的最强单条原声**）
- *"making a taller, skinny version of myself doesn't help me understand how the clothes will fit"* — 2025-11-01，3★
- *"The body my avatar has is clearly not mine, it's a model who is taller and much thinner than I am. The clothing also isn't really being 'tried on'"* — 2025-07-12，2★
- *"The avatars are all tall and skinny, not inclusive... doesn't do a good job of dressing people who are regular or plus sized"* — 2025-05-16，1★
- *"This app gives me pictures that look like a 6'5" shredded model. I am 5'10" and fat."* — 2025-06-28，1★

**Alta（衣橱+avatar 合体，本品类最强竞品）同样被体型准确性拖累**：
- *"I hate the avatar... I weigh 115 pounds on 5 foot one and if you look at my avatar, she looks like she's at least 175 pounds... **with all this effort, I want my avatar to look like me**"* — 2026-07-19（评 5★ 但正文是抱怨）
- *"The avatar never looks even close to me, it has a completely different body type... I'll give the app a pair of low rise, flared pants, and it makes them high waisted leggings!!"* — 2026-07-15，1★（**版型渲染错误 = 合身可视化失败**）
- *"I wish my avatar would align more with my actual physical proportions as demonstrated in photos"*；*"difficult to get the avatar to look less 'uncanny valley'"* — 2026-07-08，5★
- *"the proportions are off"* — 2026-07-11，3★

**身体变化场景是高价值人群**（与 25-45 职业女性画像强重叠）：
- *"Two years ago had kidney transplant... 30 lb weight gain from anti rejection meds... I had to buy all new clothes and have different body type. Your app helps me dress as I am uncomfortable with my new 'larger' size"* — Alta，2026-07-17，5★
- *"body fluctuations as your metabolism changes... as I grow a baby... I'll probably lose weight with breastfeeding"* — r/capsulewardrobe，2025-05-07
- *"I recently had to replace my entire wardrobe after a major weight loss. Stylebook has helped me see what I actually own"* — Stylebook，2026-02-14，5★

### 3.3 反面/边界证据

- **纯试穿产品粘性存疑**：Doji 上架 14 个月只累计 34 条美区评论、2026 年月均 1 条——「试穿新鲜感」自身不构成留存（与 R1 判断一致：护城河在衣橱数据）。
- **纯分析产品口碑崩塌**：Style DNA（自拍→色彩/体型分析）最近 100 条评论 72 条 1★，主因订阅陷阱+建议泛泛（*"Generates outdated looks, frumpy as if for an 80 year old woman"*，2025-12-31）——**体型「分析结论」没有可视化和衣橱落地就是玩具**。
- 「用户是想要美化还是想要真实」存在张力：Doji 用户骂「把我画瘦没意义」，但也有人享受美化——本产品选「真实合身判断」路线时要接受它反爽感的一面（呈现方式需谨慎，避免身材焦虑触发）。

### 3.4 对 MVP 的含义

- 竞品失败模式恰好论证了本产品「**身体维度数据（非照片）→ 参数化体型**」的差异化：确定性、可解释、可由用户校正，且天然规避照片 avatar 的「不像我」uncanny valley 问题。
- 但注意用户实际语言是「**want my avatar to look like me**」——参数化体型的呈现若过于抽象（人台/线框），可能同时失去照片派的情感联结。MVP 应主打「**合身判断**（这条裙子在你的腰臀比上会紧）」而非「看起来像我」，把期望锚定在功能价值。
- 版型渲染错误（低腰裤画成高腰 legging）说明**单品属性→着装形态的正确性**比渲染保真度更重要——本产品的 Fashionpedia 属性 schema + 实测尺寸字段是对的投入方向。

---

## 4. 假设④a：录入摩擦是第一弃用点 —— 评级：**强**

### 4.1 「数小时录入」是跨竞品普遍事实（一手原声）

- Acloset 2026-07-17 1★：*"I just spent **two hours** uploading clothes, and now it's telling me there's a max of 100 items or I have to pay???"*
- Acloset 2024-11-09 1★：*"After **3 hours** of inputting clothes, it says you have to pay monthly to add more **and keep your clothes**"*
- Pureple 2023-08-06 1★：*"me and my friend spent **four hours** taking pictures of our clothes and loading them in for nothing"*
- Fits 2026-03-05 3★：*"I spent **hours** uploading all my closet to the app because I was hoping for a smart AI function. Ugh nope."*
- Alta 2026-07-20：*"spent **an hour** manually adding every top, bottom, belt, dress and shoe I own. The app would glitch and black out often... I wouldn't go through the effort again"*（后改口 5★）
- Alta 2026-07-08 5★：*"After **a couple hour** initial time investment to catalogue the clothes I own..."*
- Cladwell 2026-04-05 5★：*"One night I **locked in** and uploaded my entire closet"*；Cladwell 2025-12-28：*"you spend an HOUR or even TWO taking pictures of all your clothes and... it will only give you two outfit ideas"*
- 即使最忠诚用户也确认摩擦：Indyx 2026-04-23 5★：*"Was it time consuming adding all my items? yes! Is it totally worth it? Hell, yes!!"*；Indyx 2026-06-23 5★：*"I will admit it's a bit of a pain to add your wardrobe **so I've added enough for seasonal capsules**"*（→ 用户自发用「先录一个季节」降低门槛，MVP 引导可借鉴）
- Reddit 侧共识表述：*"The wardrobe apps are a hassle to get started with but once you have your wardrobe digitized they're a real game changer"* — r/capsulewardrobe，2025-04-05

### 4.2 弃用节点的行为学证据（评论时间分布，2026-07-21 抓取）

各 App「最近 150 条评论」覆盖的时间跨度（越短=评论流越活跃）：

| App | 最近150条跨度 | 2026 年至今条数 | 解读 |
|---|---|---|---|
| **Alta** | 2026-06-11 → 07-20（**40 天**） | 150 | 爆发期；总评分量 10,783（上线约一年）已超 Stylebook 15 年累计（8,701） |
| Indyx | 2026-04-07 → 07-19（3.5 月） | 150 | 稳健增长 |
| Whering | 2026-04-06 → 07-19（3.5 月） | 150 | 活跃（1★ 仅 1 条，存在评论引导嫌疑） |
| Fits | 2024-11 → 2026-07 | 67 | 中速，Gen-Z 社交向 |
| Acloset | 2024-08 → 2026-07 | 40 | 中速下行，付费墙差评密集 |
| Stylebook | 2024-10 → 2026-07 | 27 | 老牌稳态 |
| Doji | 2025-05 → 2026-07（14 月共 34 条） | 7 | **枯竭**——纯试穿无留存 |
| Cladwell | 2021-04 → 2026-06（**5 年**共 150 条） | 7 | **枯竭**——每日推荐先驱已失速 |
| Pureple | 2022-04 → 2026-05（4 年） | 7 | 枯竭 |
| Style DNA | 2025-05 → 2026-01 | 10 | 口碑崩塌后评论流中断（72/100 为 1★） |

**运营数据替代证据**（因创始人访谈不可得）：
- Acloset：累计会员 450 万 vs MAU 50 万 ≈ **89% 注册用户不活跃**（韩经 2026-02，R1 已核）——注册→留存的斗损巨大。
- Indyx 报告间接给出录入规模：*"tens of thousands of closets"* 与 *"over 10 million digitized items"*（https://www.myindyx.com/blog/the-state-of-our-wardrobes-is-concerning，2025-04 发布）；**平均衣橱 166 件**、年新增中位数 59 件、25% 全年零穿、平均单件仅穿 10 次。→ 完整录入 166 件 × 即使 30 秒/件 ≈ 83 分钟，**「一次锁定几小时」是不可回避的物理量**；59 件/年的持续新增意味着录入不是一次性成本而是常态流。
- Whering 1,000 万用户（WWD 2026-07-07，R1 已核）但其差评集中在录入/编辑性能（R1：标签编辑加载 5-15 分钟）。

### 4.3 摩擦的复合放大器：录入沉没成本 × 付费墙 × 数据扣押

弃用叙事的完整模板不是单纯「录入累」，而是「**录入几小时 → 撞 100 件付费墙/AI 拉胯 → 感觉被骗 → 1★ + 卸载**」：
- *"They're banking that you'll spend hours loading your wardrobe in and then raise the price continuously. Scammy :("* — Acloset，2024-09-16，1★
- *"you have to pay monthly to add more **and keep your clothes**"* — Acloset，2024-11-09（付费墙扣押已录入数据）
- Polyvore 关停创伤（§1.3）说明数据所有权焦虑真实存在。

### 4.4 对 MVP 的含义

- 录入体验的验收标准应量化为：**首次会话 ≤10 秒/件、支持批量、90% 字段 AI 预填仅需确认**（与 R1 结论一致，本轮获得需求侧确证）。
- 引导策略采纳用户自发行为：「先录本季 30-50 件」而非全量（Indyx 用户原声），首日即可跑通推荐回路。
- **绝不做「录入后才发现的件数付费墙」**——这是本品类最高频 1★ 触发器（下节）。
- 提供导出（CSV/照片包）：Polyvore 教训 + Stylebook 用户主动要 CSV 导入导出（2025-08-17）。

---

## 5. 假设④b + 付费意愿：不卡件数免费层与买断偏好 —— 评级：**强**

### 5.1 「订阅 → 差评」的因果在本品类反复上演

- **Acloset 涨价/加墙实录**：*"Price Hike Was Insane and Greedy... almost doubling the price of the subscription was greedy so I canceled"*（2025-11-22，2★）；*"Moved over to making you pay monthly/yearly when it used to be free. Greedy!"*（2025-02-12，1★）；*"They have now started to limit the free version to only 100 pieces which is so annoying"*（2024-12-20，1★）
- **Style DNA 订阅陷阱后果**：最近 100 条评论 72 条 1★——*"Impossible to cancel... doesn't show up in apple subscriptions"*（2026-01-05）；*"Not only does it charge $30 for subscription but it will make you pay $10 for more features"*（2025-12-28）
- **Cladwell 计费黑历史**：*"My 'free for life' account from 3 years ago is suddenly asking me for $5/mo. That's how you treat your initial word-of-mouth users?"*（2022-01-28，1★）；*"I have contacted Cladwell support several times over the past few YEARS... they keep charging me"*（2025-10-05，1★）；$8/月被长期用户评为 *"ridiculous"*（2025-02-01）；$60/年被评 *"not $60 a year good"*（2025-07-29）
- 连免费最慷慨的 Indyx 也开始被抓包：*"After the most recent update, the calendar function is essentially unusable for anyone without a paid membership"*（2026-07-07，1★）

### 5.2 买断偏好的直接原声（价格锚点）

- *"**If it was a one time charge I would pay it, but I will not be paying for a subscription.**"* — Acloset，2024-09-07，1★（本假设最直接的单条证据）
- *"I wish I could just pay once for more space"* — Acloset，2024-11-09
- *"It's $5- but it's a one time payment but SO WORTH IT"* — Stylebook，2025-11-21，5★；*"Best $5 I've ever spent"* — 2026-06-05，5★；*"SO worth the $5... tried another that I liked but had a monthly cost rather than a 1 time payment. Stylebook is absolutely a steal."* — 2025-09-12，5★；*"Not being a subscription service is also a major perk"* — 2026-02-14，5★
- Reddit 同构：*"Stylebook is the one... no subscription fees or charges for extra features"*（r/capsulewardrobe，2024-12-18）；*"Some of the free apps try to get you to pay a monthly subscription for more features. Stylebook doesn't."*（2024-10-11）；*"Had to start all over again since finding out Acloset now has subscription charges - Stylebook... it's a one-off charge only"*（2024-04-29）；SimpleCloset lifetime $10-15 被当卖点转述（2024-05-02）
- 订阅被接受的稀有条件（天花板参考）：Cladwell 忠诚用户 *"For me this is well worth paying a very small amount monthly"*（2021-09-07）——前提是每天都用+数据可信。Acloset 用户犹豫在 **$100 lifetime**：*"I almost did a lifetime membership of $100 just to find out it cannot even recommend outfits based on the correct weather"*（2026-05-12，2★）→ **付费的前置条件是推荐质量可被验证，试用期必须能证明天气/场合正确性**。
- **Alta 的免费是 VC 补贴型倾销**（$11M 融资 + 购物佣金路线，R1），拉高了免费预期基线：*"There are no subscription fees or limits on the app"*（r/FFA，2025-04-29）。付费产品在 2026 与之同台，免费层必须在核心回路（录入+推荐）上无残缺。

### 5.3 价格结构结论

| 锚点 | 数值 | 来源 |
|---|---|---|
| 买断心理锚 | $4.99（口碑金标准） | Stylebook 评论/Reddit 反复引用 |
| lifetime 犹豫线 | ~$100 | Acloset 2026-05-12 |
| 订阅反感线 | $8/月即被长期用户骂贵 | Cladwell 2025-02-01 |
| 年费质疑线 | $60/年 "not worth" | Cladwell 2025-07-29 |
| 免费件数红线 | 100 件上限=差评引爆器（平均衣橱 166 件，100 件必然撞墙） | Acloset 多条 + Indyx 报告 |

---

## 6. 附加发现（未在假设清单内但影响定位）

1. **隐私是反证**：1,484 条评论中检索 privacy/my data/creepy 仅命中 4 条，且全部与隐私诉求无关（网络报错、AI 抵触等）。Reddit 讨论中也未见对衣橱/身体数据上云的担忧。→ **on-device 隐私不构成获客钩子**，但可作为①身体维度采集时降低阻力的信任设计（采集弹窗文案）②against-AI 情绪的接应点（见下）。
2. **反 AI 情绪正在品类内出现**：*"AI is horrible for the environment and wasting gallons of water to get dressed is wild"*（Cladwell 2025-08-16，4★）；*"AI slopification continues :("*（Indyx 2026-05-19，1★，因 AI 生成营销图卸载）；Acloset 2025-11-29 3★ *"AI Slop"*。→「端侧计算/确定性算法优先」可以包装成**克制的 AI**叙事，接住这批用户。
3. **水军污染是行业常态 → 信任是稀缺品**：r/FFA 用户当场揭穿 Alta 马甲号（2025-03-29：*"Your very first reddit comment... almost all your comments mention Alta"*）；Velra/Verla 试穿 App 在 FFA 批量刷模板评论（2025-04-11 多条）。真实社区对 astroturfing 高度敏感，冷启动营销切忌复制此路径。
4. **桌面端是被忽视的高频请求**：*"i am so upset that none of these apps have a good desktop interface!!"*（r/FFA 2025-04-02）；Stylebook 用户要 CSV 批量导入（2025-08-17）。→ iOS-only MVP 可接受，但录入场景的 iPad/Mac（Catalyst/同构）值得进 roadmap。
5. **洗涤状态跟踪无人做**：*"I want to track number of wears since I last washed each item so I can stop feeling anxious that something is too dirty to wear... I haven't been able to find that feature in any apps"*（r/FFA 2025-03-27）→ 本产品 Item 状态机（在洗/干洗中）已覆盖，是低成本差异点，可显性化。
6. **趋势时间窗**：Alta 40 天 150 评论、一年 10,783 评分的爆发证明品类正处主流化拐点（Google 搜索词 *"app like Cher's closet in Clueless"* 成为自然流量入口，Alta 2026-07-11 评论、GMA 电视曝光 2026-07-06 评论）。窗口红利与竞争压力并存。

---

## 7. 对 MVP 优先级的综合含义

| 优先级 | 结论 | 依据 |
|---|---|---|
| **P0（生死线）** | 录入 ≤10 秒/件 + 「先录本季」引导 + 永不卡件数 + 数据可导出 | §4：摩擦×付费墙×数据扣押是弃用模板；平均 166 件/年增 59 件 |
| **P0（生死线）** | 每日推荐的四条正确性验收：天气实时准确（日间时段）、场合硬过滤、≥7 天防重复+状态感知、服装语法合法 | §1.2：竞品全部死在执行层，无人质疑需求本身 |
| **P1（差异化）** | 合身判断先于「像我」：参数化体型输出「这件在你身上的松紧」结论，避免照片 avatar 的失真陷阱；呈现避免身材焦虑 | §3：Doji/Alta 失真差评 + 「想输入测量数据」直接原声 |
| **P2（支撑层）** | 存放位置降为推荐回路的支撑功能（换季箱提示、swap 助手），不作首屏卖点；营销词用 "seasonal swap" | §2：行为普遍但显性工具需求弱，Pureple location 字段无人在意 |
| **定价** | 免费层完整跑通核心回路；付费点放在增值（多衣柜/体型可视化/历史统计），买断或诚实低价订阅二选一；试用期必须足以验证推荐质量 | §5：$4.99 锚、$8/月反感线、"一次性收费我就付" |
| **叙事** | 隐私不进获客文案，改讲「克制的 AI/无广告/数据属于你」；冷启动严禁水军 | §6.1-6.3 |

---

## 8. 证据局限与遗留问题

1. **创始人访谈/播客的激活率、留存曲线未获取**（搜索通道受限），用评论速度、MAU/注册比、弃用叙事替代——方向可信但缺精确漏斗数值。遗留：后续可定向抓 Whering（Bianca Rangecroft）与 Indyx 创始人访谈。
2. **「fit 占服装退货原因的百分比」**未从可核验来源获得（仅获整体退货率 19.3%/2025 与 bracketing 2/3），引用时避免使用具体 fit 占比数字。
3. pullpush 对 2025-06 之后的 Reddit 覆盖不完整（检索结果止步 2025-05 前后），2025H2-2026 的 Reddit 情绪由 App Store 评论补位。
4. App Store RSS 每 App 仅可得最近 ~150 条，时间跨度即活跃度的推断对低量 App（Doji 34 条）置信更高，对高量 App 只反映近期状态。
5. GetWardrobe/Whering 近期五星评论存在引导/水军嫌疑（语言模板化、1★ 占比异常低），相关正面证据已降权。

## 9. 来源清单（关键）

- App Store 评论 RSS（一手，2026-07-21 抓取）：`https://itunes.apple.com/us/rss/customerreviews/page={1-3}/id={appId}/sortby=mostrecent/json`，appId：Alta 6481705400、Indyx 1599179405、Whering 1519461680、Acloset 1542311809、Cladwell 1140550878、Stylebook 335709058、Pureple 628106373、GetWardrobe 656212466、Style DNA 1358319821、Doji 6737292650、Fits 6447482321
- iTunes Search API 评分总量（一手，2026-07-21）：`https://itunes.apple.com/search?term=...&entity=software`
- Reddit（pullpush.io 检索，一手原帖）：关键线程 r/FFA 1jjtgyt（wardrobe app 2025）、1jnjmwq（closet size）、19a1yc1（capsule/decision fatigue）、omqrqj（女性制服）、1jbtokf（换季收纳）等，正文中逐条附 permalink
- Indyx State of Our Wardrobes 2025：https://www.myindyx.com/blog/the-state-of-our-wardrobes-is-concerning
- Shopify 退货统计（2025）：https://www.shopify.com/blog/ecommerce-returns ；Invesp：https://www.invespcro.com/blog/ecommerce-product-return-rate-statistics/
- The Home Edit：https://en.wikipedia.org/wiki/Get_Organized_with_The_Home_Edit
- 沿用 R1 已核：WWD（Whering $7M/1000 万用户，2026-07-07）、韩经（Acloset 450 万会员/50 万 MAU，2026-02）
