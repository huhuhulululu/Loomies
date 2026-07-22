# 红队报告：主动搜寻 copilot 先验（D19）的反证 —— 2026-07-22

> **定位**：D20 已裁决跳过真人验证，本报告是上线前最后的市场依据之一。任务不是巩固 D19（copilot 机制 PIVOT），而是**攻击它**：把「方法④ ~7:1 偏规划器」的结论按五条线拆开找反证。与 18 号报告（方法④四个增量）不重复，所有数据为本轮新抓或新分解。
> **数据源**：iTunes 评论 RSS（一手，2026-07-22 抓取：Alta 666 条去重 / Cladwell 560 条去重——均约为 18 号报告样本的 2-4 倍，Cladwell 覆盖 2017-2026 全史）+ iTunes lookup + pullpush.io Reddit（7 组成功 / 2 组失败）+ WebFetch 官方页与财务页。WebSearch 本 session 预算耗尽（200/200），未能使用。
> **引用规范**：评论引用带星级+日期；Reddit 引用带子版+年月。sourceTier 标注：first-hand（一手抓取）/ vendor-claimed（厂商或公司自述）/ inferred（推断）。

---

## 0. 红队结论速览

| # | 攻击目标 | 红队判定 | 一句话 |
|---|---------|---------|--------|
| 1 | 「Alta 4.88★ 证明 autopilot 成功」 | **不成立，但发现更危险的东西** | Alta 是「autopilot 营销钩子 × copilot/编目产品体」：666 条评论中真·autopilot 之爱仅 ~1%，编目/规划/试穿/购物占压倒多数——但它的**官网主推纯 autopilot 框架**且获客最快。**钩子与机制可以分离**，这直接威胁 §2 把 V1/V2 A/B 当机制裁决器的判读规则 |
| 2 | 「Stitch Fix $2B 证明外包穿衣决策有大市场」 | **部分成立，需求真、job 不同、经济学死** | 峰值 $2.10B（FY2021）→ $1.27B（FY2025），但衰退主因是执行/单位经济/战略摇摆（Freestyle 自助化转向反而失败），不是「委托决策」需求消失——留下的客户人均消费还在涨。它外包的是**买什么**（购物策展），不是**今早穿什么**；且它保留廉价 veto（寄5退N）。委托段规模锚 ≈ 峰值 ~4M 活跃客户 |
| 3 | 「autopilot 忠诚用户可忽略」 | **不可忽略，但小且结构性难触达** | Cladwell 全史正评中 ~6-7% 是真·每日推荐之爱（产后妈妈/黑暗清晨/自述 indecisive/低意愿男性）；ADHD 决策瘫痪极真实但 workaround 几乎全是减法/前夜准备，0 条自发要算法决定；纯委托欲流向**信任的人**（伴侣/妈妈/Dom）而非 app；「处方式穿搭日历」付费小生意（Outfit Formulas）实存。子群 ≈ ICP 的个位数%~10%（inferred），且与「先录入 166 件」的产品架构自相矛盾 |
| 4 | 「7:1 是机制天平的量化证据」 | **该倍数不可用**（方向仍立） | Cladwell 237 条 1-2★ 分解：**63% 提扣费/订阅/价格，纯机制差评仅 9%**；负评高峰（2019-21）与免费→$50/年 同步。7:1 差评率差有相当部分在测「订阅愤怒 + 时代/幸存者 + 评论者自选择」，不是「替我决定 vs 帮我规划」的偏好比。方向性结论（naive autopilot 高危）因三源同向仍成立，但倍数应从论证里退役 |
| 5 | 「copilot 先验的错误条件」 | 见 §5 | 机制层敞口低-中；**营销钩子层与 A/B 判读层敞口高**——V1/V2 lift 测的是广告钩子不是产品机制，须改判读规则；full-auto 建议做成默认 copilot 之上的 opt-in 开关（工程 ~10-20%），真裁决器改为上线遥测的 wear-as-is 率 |

---

## 1. Q1：Alta 细拆——4.88★ 到底是谁的功劳

### 1.1 官方如何框架化（vendor-claimed，2026-07-22 抓取）

**官网（altadaily.com）主推的是纯 autopilot 叙事**：headline "Your personal AI stylist that truly gets you"，日推荐描述为 "Personalized daily outfit recommendations based on your closet and weather"——页面上**没有**任何用户掌舵元素的表述。

**App Store 描述则暴露了三层推荐面**（排在功能列表第一位）：
1. **每日推送**（autopilot 面）："Get daily outfit suggestions based on the weather and your schedule."
2. **场合 prompt 生成**（用户给场景）："Generate outfits for any event, from 'date night in Paris' to 'work conference in Vegas'"
3. **单品锚定生成**（用户给主件）："Want to wear that specific jacket? Ask Alta to generate outfits with it."

加上评论区证实的 restyle（"any suggestion Alta Daily makes can be easily restyled"，18 号报告 B3.3）与 closet mode 开关（1★ 2026-07-18 提及 "I tried toggling closet mode"——即可切换「只用我的衣橱 vs 混入购物推荐」），**三分之二的推荐面是用户掌舵的**。产品结构 = autopilot 表皮 + copilot 骨架。

### 1.2 用量真相：666 条评论的主题分解（first-hand）

对 590 条 5★ 做正则主题分桶（多标签，人工抽查校正）：

| 5★ 主题 | 占比 |
|---|---|
| 规划/日历/打包/旅行 | **24%** |
| 购物/wishlist/品牌 | 24% |
| avatar/虚拟试穿 | 22% |
| 从自有衣服出新搭配灵感 | 16% |
| 决策疲劳缓解（泛） | 12% |
| 数字化看清衣橱 | 11% |
| 免费惊叹 | 10% |
| **每日推送这个 autopilot 功能本身** | **8%** |

**真·autopilot 之爱**（"替我决定"语言：picks out my outfits for me / tells me what to wear / outsource / don't have to think）：正则命中 7/626 条 4-5★（1%），逐条人工读后**站得住的只有 ~3 条**：

- *"It picks out my outfits for me and it's great!"* —— 5★，2026-05-06
- *"I suffer from decision fatigue and am always looking for ways to outsource decisions I shouldn't be agonizing over, like deciding what to wear. Alta is exactly what I needed... I was previously using ChatGPT to help me organize my closet and suggest outfits, but that was so much more cumbersome."* —— 5★，2026-01-28（注意：她此前的 workaround 是 ChatGPT——委托欲真实存在）
- *"Busy HR director + mom of two here... now it gives me daily outfit picks that consider my clothes, the weather, and my schedule... without me having to decide"* —— 5★，2025-08-30（⚠️ 模板化人设开头 + 全功能点名，**疑似马甲**；11 号报告已录得 Alta astroturf 前科，本条按打折看待）

同期差评仍在打自动组合的质量与商业污染（first-hand）：
- *"The outfits it puts together automatically don't work in real life. For example a navy top and black shoes."* —— 3★，2026-07-11
- *"It only made outfits with one piece of my clothing and the rest was stuff that they wanted me to buy"* —— 1★，2026-07-12（B2B2C 变现直接污染推荐——印证 MARKET.md「结构性相斥」判断）
- *"I ask for it to make different outfits and it gives me the same outfit... constantly"* —— 3★，2026-06-24

### 1.3 红队判定

**「Alta 证明 autopilot 成功了」不成立**：它的满意度来自编目/规划/试穿/免费，autopilot 功能在自家 5★ 里只占 8% 声量、真爱 ~1%，且差评仍集中打自动组合。18 号报告的细化（「执行正确 + 用户掌舵框架的日推荐器能活」）方向无误。

**但红队发现了一个更危险的东西**：Alta 的**获客面**（官网、品类最快采用速度：16 个月 10.8K 评分）用的是纯 autopilot 叙事（"Your personal AI stylist"），**产品面**却是 copilot。即：**autopilot 当钩子卖、copilot 当产品交付，两者可以并存且都成立**。这对 D19 的直接威胁不在机制选择（copilot 对），而在：
1. **营销层**——如果我们的 hero 忠实于 copilot（"You decide, it does the legwork"），可能在广告点击上输给竞品的 "never think about what to wear" 式钩子；
2. **A/B 判读层**——DEMAND-VALIDATION §2 把 V1/V2 lift 当「推荐器 vs 规划器」的最终裁决器，但 Alta 证明**落地页转化测的是钩子的广告效力，不是用户想要的产品机制**。V1 赢 ≠ 该做 autopilot 产品；V2 赢 ≠ autopilot 钩子没有获客价值。详见 §5。

---

## 2. Q2:Stitch Fix——「外包穿衣决策」市场的兴衰解剖

### 2.1 硬数字（vendor-claimed，经 stockanalysis.com + Wikipedia 两源，2026-07-22 抓取）

| 财年 | 营收 | 同比 | 净利 |
|---|---|---|---|
| FY2021 | **$2,101M（峰值）** | +22.8% | -$8.9M |
| FY2022 | $2,018M | -4.0% | -$181.6M |
| FY2023 | $1,593M | -21.1% | -$150.3M |
| FY2024 | $1,337M | -16.0% | -$118.9M |
| FY2025 | $1,267M | -5.3% | -$28.8M |

- 活跃客户：峰值 ~3-4.2M（FY2021-22；两源口径不一致——Wikipedia 摘要给 "3+ million"，公司财报口径记忆中为 ~4.2M，**本轮未能一手核实精确峰值**，按区间引用）→ 2.31M（2025-12，-5.2% yoy）。
- **关键反转信号**：Q4 FY2025 营收 $342.1M **+7.3% yoy（重回增长）**，单客年收入 $559 **+5.3%**——留下来的客户更少但花得更多。

### 2.2 衰退原因归因（三类证据）

**(a) 官方/媒体叙事（vendor-claimed）**：疫情电商拉动退潮 + 电商行业整体减速；2020 裁 1,400 人、2022 裁 15%、2023 再裁 20%；CEO 四换（Lake→Spaulding 2021→Lake 回归 2023→Baer 2023）；2024 起「rationalize, build, grow」三阶段重整 + AI 工具（StyleFile、Vision）。

**(b) 用户churn原声（first-hand，r/stitchfix via pullpush）——全部指向执行与性价比，无一条指向「我其实想自己挑」**：
- *"They don't listen to my notes at all. I have been keeping maybe 1 thing every 3rd box so it's not worth it."* —— 2024-04
- *"a NEW stylist also ignored my 'no plastic' request... I refuse to keep paying 'styling fees' to illiterate or AI generated stylists"* —— 2024-12
- *"Sometimes the quality is bad or I get boring ugly T shirts I could buy anywhere for less money."* —— 2025-05

**(c) 战略反证（最有说服力）**：2021-22 的 Freestyle 转向（让用户**自助直购**，即从「替你决定」走向「你自己挑」）恰是 Spaulding 时代最大败笔——没有拉回增长，反而稀释了核心定位，Lake 回归后才重新聚焦 styling 核心并在 FY2025 末企稳。**Stitch Fix 往 copilot/自助方向转反而失败了**——这是对「委托决策无市场」最直接的反驳。

### 2.3 忠诚者画像（first-hand）——委托购物决策的真需求人群

- *"I had large uterine fibroids and needed longer loose fitting tops... I hate shopping and this helps so much."* —— r/stitchfix，2025-05
- *"I'm petite and hate shopping... overall I think it's worth it."* —— 2025-04（用了 5 年+）
- *"Plus size, hate shopping and such bad self loathing, I don't keep up with fashion"* —— 2024-09
- *"I hate shopping, I hate trying things on in dressing rooms, and I'm too busy to spend hours driving around"* —— 2024-10
- 有人把账算得很明白：*"ugh I hate shopping. I want someone else to put time and thought into what will look good on me... WHAT OMG WHY DOES IT COST MORE"* —— 2025-02（讽刺不愿付溢价的人——忠诚者**知道自己在为决策外包付费**）

### 2.4 与 copilot 先验矛盾吗？——红队裁定

**不构成直接矛盾，但给出三个必须吸收的修正**：

1. **Job 不同**：Stitch Fix 外包的是**购物决策**（何物入柜，低频高客单、身材羞耻高发场景），不是**每日穿搭决策**（何物出柜，高频零成本）。$2.1B 证明的是前者。前者痛在「逛店试衣的身体羞耻 + 时间」，后者痛在「早晨的执行功能」——重叠但不同税。
2. **「掏钱请人决定」的段规模是百万级**：峰值 ~4M 活跃客户（含男性，美国）≈ 目标人群（44M 美国 25-44 女性）的个位数百分比量级。**大到能撑 $2B 营收、小到撑不起 40% 毛利下的获客成本**——这正是它衰退的单位经济学根源（styling 费 $20、高退货、高churn）。对我们：委托段真实存在，但按 Stitch Fix 的教训，它**churn 高、服务成本高**。
3. **veto 结构**：Stitch Fix 从来不是纯 autopilot——寄 5 件、用户留 veto（全退只损 $20）。加上 Cladwell 的「每日 3 选 1 + reset」、Alta 的 restyle：**市场上从未有过成功的无 veto 穿搭 autopilot**。成功的委托产品都是「重决策外包 + 廉价否决权」。这与其说反驳 copilot 先验，不如说把它精确化：**争的不是 auto vs manual，是 veto 放在哪、多便宜**。

---

## 3. Q3：autopilot 忠诚用户——画像与规模

### 3.1 Cladwell 全史正评细读（first-hand，560 条覆盖 2017-2026）

18 号报告只引了 Cladwell 的差评。本轮抓到它 9 年全史 210 条 4-5★，**手工细读**（正则粗筛 3 条，宽网+人工复核后校正为 ~12-15 条，占正评 6-7%）真·每日推荐之爱：

- *"I don't even find myself scrolling to pass on the first suggested outfit. **I open the app and get dressed. Done.**"* —— 5★，2019-03-19
- *"when I wake up in the morning, I don't have motivation to find something. With this, I open the app and an outfit is there... **I grab what it tells me and I get dressed and go. It's perfect.**"* —— 5★，2019-01-13
- *"I open the app. **Boom! Layers, pants, and shoes, all picked out for me.** I find this especially helpful when I wake up and it's still dark outside!"* —— 5★，2017-03-24
- *"As a **stay at home mom with a 7 week old newborn and 2 toddlers**... Now I feel put together in all the beautiful and stylish clothes I already own **without having to put much thought into it**"* —— 5★，2019-03-17（**产后画像实锤**）
- *"My daughter downloaded this app [for me]... I normally didn't put any thought into what I wear... grab whatever is at the front of the closet"* —— 5★，2019-03-29（低意愿男性）
- *"Great for helping **indecisive people like me** get dressed quickly"* —— 4★，2018-07-08
- *"helpful making an outfit as **an indecisive person**"* —— Acloset 5★，2025-07（18 号已录，同画像）

**画像收敛**：产后/新生儿期、黑暗清晨通勤、自述 indecisive、低装扮意愿者（含男性）、身体形象受挫（Stitch Fix 侧：plus-size/petite/body dysmorphia/术后）、结构偏好者（*"I liked being told what to wear, what time to do things and where to be"* —— r/ADHD 2025-02，军队语境）。

**注意结构细节**：这些人爱的 Cladwell 形态是「每日 **3 套**候选 + 一键 reset」（多条评论证实），Alta 是「每日推送 + restyle」——**连忠诚 autopilot 用户实际消费的也是带廉价 veto 的轻 copilot**，纯「一套、不给选」的产品市场上不存在。

### 3.2 ADHD 人群：痛最尖、但 workaround 语料反向（first-hand，r/ADHD 100 条 2025 评论）

决策瘫痪严重程度远超一般想象：
- *"I've actually **flunked classes in college**... just because I couldn't decide what to wear and would just curl up into a ball of anxiety"* —— 2025-04
- *"I froze, completely. **I didn't go to work or even call in to work.** ...deciding what to wear to work was the trigger."* —— 2025-04
- *"I will cry if I have to make the final decision."* —— 2025-03

但他们**自发采用的解法**在 100 条样本里几乎全是：uniform/减法（*"Everyday has a specific shirt/pants"*、*"6 pairs of my favorite black joggers"*、*"mostly black and gray so I don't have to think"*）、前夜准备、照片相册翻查（*"take pics... with my outfits then scroll that album when idk what to wear"*）、spreadsheet（甚至自发算 cost-per-wear）、配偶提示。**0 条自发想要「app 替我决定」**。
红队解读要诚实两面：(a) 这继续支持 copilot 先验——最痛的人也在要「结构」而非「代理」；(b) 但**不能排除潜在需求**——他们可能不知道这类 app 存在，且「被告知」的接受度有原声（军队条）。ADHD 是**潜在可转化、非显性索求**的 autopilot 子群。

### 3.3 纯委托欲的真实流向：信任的人，不是算法（first-hand）

pullpush 全史检索 *"picks my outfits for me"*：**10 条**，构成：BDSM/DDlg 权力交换 3 条、伴侣 2 条（*"I love when my SO picks my outfits for me"*、*"My boyfriend actually picks my outfits for me... like I'm a giant Barbie doll... It eases my [mind]"* —— r/AskWomen 2019-01，**此条是 ICP 邻近画像：'I have soooo many clothes and I hate them all'**）、妈妈 2 条、BPD 委托闺蜜 1 条（*"I appoint a friend as my fashion advisor... it has really removed the guess work"* —— 2024-12）。
*"app that tells me what to wear"* 全史：**3 条**（1 条质疑、1 条 fetish 语境、1 条真需求：*"I'm still waiting on an app that tells me what to wear based on the given temperature, wind, likelihood of rain... **Now that, my friends, I would buy.**"* —— r/Futurology）。
**判读**：日常穿搭的委托欲存在，但压倒性地投向**有信任关系的人**；对算法的自发索求在可及语料里接近零（天气实用主义框架是唯一例外——恰是 H1 的正确性门）。

### 3.4 付费先例：「处方式穿搭日历」小生意带（vendor-claimed）

- **Outfit Formulas**（原 Get Your Pretty On）：向 35-55 女性卖**每月穿搭处方日历**+购物清单+AI 助手（ALI），订阅制+7 天试用。承诺语言就是纯 autopilot："know **exactly what to wear every day**"；会员原声："**I know what I'm wearing before I even get out of bed.**" 有 4 年+老会员、活跃 FB 社群；无公开规模数字（历史访谈称七位数营收，inferred）。
- **Frump Fighters**：面向妈妈的穿搭日历（r/workingmoms 2024-07 原声：*"I was thinking of buying it to **take the decision fatigue out of getting dressed**"*）；品牌已改名/转向（域名 301 到 nowthaticando.com）。
- 相邻证据：r/workingmoms 的决策疲劳语料里，**外包被歌颂**（保洁、Home Chef "**to relieve decision fatigue about what to make for dinners**"）——「花钱消灭决策」是该人群的显性生活策略，衣橱只是其中一项。
- 注意结构：这类产品**不要求录入自有衣橱**（卖通用胶囊+购物清单），装机成本为零——它们服务的正是「不愿先付出录入成本」的委托段。

### 3.5 规模判断（inferred，诚实区间）

综合四个锚：Stitch Fix 峰值 ~4M（购物委托、含男性）；Cladwell 正评 6-7% / Alta 正评 ~1% 的真·autopilot 之爱；Reddit 自发索求近零；处方日历生意 = 小生意量级。
**「愿意让算法每天替自己决定穿什么」的子群 ≈ ICP（25-45 职业女性）的个位数 %，上限口径 ~10%**；其中还要再砍一刀：**该子群与「先录 166 件衣服」的产品架构自相矛盾**（时间穷/低意愿正是他们的定义特征），能走完我们 onboarding 的 autopilot 爱好者会更少。这就是为什么 Outfit Formulas 卖通用处方而不卖数字衣橱。

---

## 4. Q4：7:1 的方法学审计——哪些偏差实锤了

### 4.1 变现模式混杂（**最大实锤**，first-hand 新分解）

Cladwell 全史 237 条 1-2★ 多标签分解：

| 差评类别 | 占比 |
|---|---|
| **扣费/订阅/退订/价格** | **63%** |
| 推荐质量（机制）任意提及 | 36% |
| 崩溃/bug/数据丢失 | 33% |
| **纯机制差评（不含扣费与 bug）** | **仅 9%** |
| 纯商业差评（完全不提机制） | 43% |

且负评时间高度集中于 2019-2021（63+40 条/年 vs 2017 年 9 条），与**免费→$50/年**的变现转向同步（5★ 老用户原声：*"Used to LOVE now just like... About going from free to $50/year when there haven't been any major upgrades in 2+ years"* —— 2020-10-20）。
**结论**：18 号报告的「自主推荐器组差评率 ~51% vs 规划器组 ~7%」中，自主推荐器组恰好全是**订阅制**（Cladwell/Acloset/Style DNA 系），规划器组恰好是**买断/免费/慢订阅**（Stylebook $4.99/Whering 免费/Indyx 免费一年后转化）。**7:1 的相当部分在测「订阅愤怒」而非「机制憎恨」**——两个变量完全共线，无法从该数据里分离。

### 4.2 其余偏差核查

| 质疑 | 裁定 | 依据 |
|---|---|---|
| 评论者自选择（爱掌控者更爱写评论） | **实锤** | 评论是双峰分布（Cladwell 146 条 1★ + 111 条 5★，中段薄）——只有愤怒者与狂喜者发声；且「录入全衣橱还写长评」者结构性偏 hobbyist/掌控派。**真 autopilot 目标人群（时间穷、低意愿）系统性缺席于所有已用语料**：不写评论、不泡 r/FFA、可能根本不装要录入的 app。他们在哪？在 r/workingmoms 买 Outfit Formulas、在 Stitch Fix 的账单里 |
| r/FFA 过采样掌控派 | 实锤（18 号 C4 已自认，本轮补位仍不完全） | 本轮 ADHD/workingmoms/stitchfix 语料部分对冲，但仍全是 Reddit 用户（偏文字型、偏自助型人群）|
| 幸存者偏差（活下来的都是规划器，故规划器好评多是果非因） | **部分实锤** | Stylebook 16% 差评率来自「停更 13 个月仍留守的买断用户」——幸存忠诚样本；Cladwell 的衰败与其说证明机制死刑，不如说证明「naive 算法 × 订阅制 × 小团队执行」的组合死刑。但注意：**为何活下来的全是规划器**本身仍是信号——五家自主推荐器无一家跑通，不能全用幸存者偏差消解 |
| 7:1 是差评率之比，不是偏好之比 | **实锤（口径警告）** | 它测「做坏的 autopilot 有多惹人恨」，不测「做好的 autopilot 有多少人爱」。Alta（执行较好+带 veto+免费）4.88★ 即活反例。**禁止把 7:1 读成「想要规划器的人是想要推荐器的 7 倍」**——后者的真实比例本轮所有语料都无法给出，只能说自发索求语料里规划语言显著占优（C1 的 3-4:1 同样受上述全部偏差影响）|

### 4.3 修正后的诚实读数

**方向存活，倍数退役**：「naive autopilot × 订阅」是实证毒组合（三源同向：评论/DIY 制品/融资结构，不依赖 7:1 单一数字）；但 7:1 与 51%-vs-7% **不应再被引用为机制偏好的量化天平**。对 DEMAND-VALIDATION §8.1 的口径应降级为：「差评率差显示自主推荐器组风险显著更高，量级受变现模式/时代/自选择混杂，不可作偏好比例解读」。

---

## 5. Q5：诚实结论——copilot 先验何时会错，D19 敞口多大

### 5.1 copilot 先验在什么条件下会错

1. **把机制结论误用到营销层**（最现实的错法）：Alta 证明 autopilot 钩子（"Your personal AI stylist"）+ copilot 产品可以同时成立且获客最快。若因 D19 连 hero 文案都恪守 copilot 语言，可能在广告转化上输给竞品的「不用再想穿什么」式钩子。**先验管产品机制，不管广告钩子**。
2. **执行质量跨过门槛时**：全部差评证据打的是 naive 算法（天气错/重复/非法组合）。若四条正确性验收（MARKET.md §2-H1）全过 + veto 一键便宜，每日 full-auto 推送本身无罪——Cladwell 忠诚者爱的正是这个形态（3 选 1 + reset）。**先验禁止的是「无 veto 的 naive autopilot 当默认」，不禁止「高质量 full-auto 当可选面」**。
3. **若目标人群扩到纯委托段**（产后/ADHD 急性期/身体形象受挫/时间穷）：这个段真实存在（§3），copilot 先验对他们不成立——但他们同样不会完成 166 件录入。**服务该段的产品形态是 Outfit Formulas/Stitch Fix（零录入、通用处方/实物寄送），与数字衣橱 app 架构互斥**。故 copilot 先验对**本产品**是条件性稳健的：录入门槛已经把用户自选择成掌控派。
4. **若上线遥测显示 wear-as-is 率意外高**：见 5.3——这是唯一能真正证伪先验的数据。

### 5.2 D19 风险敞口分层

| 层 | 敞口 | 理由 |
|---|---|---|
| 产品机制层（copilot 默认 + 候选过滤/语法/打分保留） | **低-中** | 三源同向 + 本轮红队攻击后方向仍立 + 录入门槛自选择效应加固；ClosetCore 双形态可复用，切换成本低 |
| 营销钩子层 | **中-高** | 若 hero/广告拘泥 copilot 语言，可能丢获客；autopilot 钩子的广告效力有 Alta 实证 |
| A/B 判读层（§2 决策规则） | **高** | V1/V2 lift 实际测的是**钩子的广告效力**，不是**用户要的产品机制**——两者已被 Alta 证明可分离。按现行规则，V1 大胜会被误读为「该做 autopilot 产品」（其实只说明钩子强）；V2 大胜会被误读为「autopilot 钩子无价值」。**建议给 §2 加注：A/B 裁决 hero 钩子与获客文案；机制裁决权移交上线遥测** |
| 忠诚委托子群错失层 | 低-中 | 个位数%~10% 子群（产后/ADHD/indecisive），若产品完全无 full-auto 面则错失；对策见 5.3，成本低 |

### 5.3 full-auto 该占产品多大比重（可执行建议）

- **产品面**：默认 copilot（你选场合/主件 → 它补全 + 硬过滤），**full-auto 做成一等公民的 opt-in 开关**：「每日一推」推送（含今日天气/日程），卡片直接可穿、但**必须带一键 veto（restyle/换一套/我自己选）**——市场上所有活着的委托产品（Stitch Fix 退货、Cladwell 3 选 1、Alta restyle）都长这样。工程投入占比 ~10-20%（ClosetCore 推荐管线已建，增量主要是推送与开关 UI）。
- **营销面**：钩子允许比机制更「auto」——「打开就有今天的搭配」类语言可用（Alta 已验证其获客效力），但落点必须诚实展示 veto 与掌舵（避免 Kalyxa 式马甲话术反噬，r/FFA 会揭穿）。
- **真裁决器（取代 A/B 的机制判读职能）**：上线遥测三个数——①每日推送**未编辑采纳率**（wear-as-is）②restyle/换一套率 ③提前规划（日历预排）使用率。若 wear-as-is 持续 > ~30%（拍脑袋起点，上线后校准），说明 autopilot 子群比先验大，加大 full-auto 投入；若 <10%，先验确认，推送降级为规划提醒。**这是 D20（跳过真人验证）之后唯一能证伪 D19 的机制级数据**。
- **ADHD 子群钩子**（零成本增量）：文案里显性化 object permanence / 执行功能语言（18 号 §8.4 已识别为最锋利自我描述轴），入口仍是 copilot——「帮你看见你拥有的」对该人群同时命中痛点与非污名化。

---

## 6. 诚实声明与局限

1. **WebSearch 本 session 预算耗尽（200/200），一次未能使用**；Stitch Fix 财务靠 stockanalysis.com + Wikipedia 两源 WebFetch 交叉，营收数字两源一致（高置信）；**活跃客户峰值口径（3M+ vs ~4.2M）两源不一致且未能一手核实**，正文按区间引用。
2. pullpush 覆盖止于 ~2025-05；9 组查询 7 成功 2 失败（"picks out my outfits"、"pick my outfits for me" 两变体因限流未取回）——**「自发索求近零」的结论基于 3 个成功变体（"app that tells me what to wear" 3 条 / "picks my outfits for me" 10 条 / "decide for me" 衣着相关 7 条），召回边界真实存在，强度按中等看待**。
3. iTunes RSS 单 App 上限 ~500 条（本轮 Alta 666 / Cladwell 560 为 recent+helpful 双排序去重合并）；Alta 语料已知有 astroturf 污染（本轮又见 1 条疑似，已标注打折）；正则分桶存在漏检，关键结论（Cladwell autopilot 忠诚 3→12-15 条、占比 6-7%）经**随机抽样+人工细读校正**，非纯正则输出。
4. Cladwell 差评分解为多标签正则（63%/36%/33%/9%），类别边界有模糊地带（如「订阅买到的推荐不值」同时命中两类），但「纯机制仅 9%」为保守口径（排除任何商业/bug 共现），方向稳健。
5. Outfit Formulas 规模（七位数营收）来自历史访谈记忆，未能本轮核实，标 inferred；其余厂商数字均标 vendor-claimed。
6. 本报告与 11/18 号报告的分工：它们证明了「偏 copilot」的方向；本报告证明该方向**在本产品架构内**经受住了反证攻击，但**量化倍数（7:1）与 A/B 判读规则（§2）两处需要修正**——这两条修正是本轮最重要的净增量。

## 7. 来源

- iTunes 评论 RSS（一手，2026-07-22）：Alta 6481705400、Cladwell 1140550878，各 page 1-10 mostrecent + page 1-5 mosthelpful，去重后 666/560 条
- iTunes lookup API（一手，2026-07-22）：App 描述/评分/价格
- pullpush.io（一手，2026-07-22）：comment search——"app that tells me what to wear"、"picks my outfits for me"、"decide for me"、r/ADHD "what to wear"（100 条）、r/workingmoms "decision fatigue"（100 条）、r/stitchfix "hate shopping"（56 条）/"styling fee"（100 条）
- WebFetch（2026-07-22）：altadaily.com（官方框架）、outfitformulas.com（处方日历产品）、frumpfighters.com（301 → nowthaticando.com）、en.wikipedia.org/wiki/Stitch_Fix、stockanalysis.com/stocks/sfix/financials/
- 基线引用：docs/MARKET.md、docs/DEMAND-VALIDATION.md §0/§2/§8、docs/research/18-method4-signal.md（B3.3 Alta restyle 原声、C1 3-4:1、§8.1 差评率）
