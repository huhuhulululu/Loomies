# 竞品深拆 C 组：AI 新贵与平台威胁（Alta / Doji / Google Doppl / FitCheck / 新入场者）

> 调研日期：2026-07-21。本文为深挖轮，只做 `01-competitors.md` 首轮基线之后的**增量与深度**，不重复功能矩阵。
> 检索方法说明：本轮 WebSearch 配额耗尽、Exa key 失效，改用 WebFetch 直抓 DuckDuckGo/Bing 检索页 + App Store/官网/TechCrunch 一手页面；justuseapp/appshunter 反爬 403，Alta 负面原声采样受限（见 1.3 置信标注）。

---

## 0. 本轮最重要的三个变化（相对首轮基线）

1. **Google Doppl 已死**：2026-03-23 宣布、2026-04-30 停止运行并下架，用户数据不可再访问；试穿技术并入 Google Search/Shopping（"Try on you"）。平台以独立 App 形态进军「衣橱/试穿」的实验**失败退场**（一手：Google 官方支持页）。
2. **Alta 是收敛度最高的直接威胁**：已从「AI 购物造型师」全面长成「免费数字衣橱 + 场合造型」——官网 tagline 直接写 "digital closet for **date nights, interviews, trips**"，与我们「职业女性多场合」叙事正面重叠；App Store 4.9★/11K 评分、周更节奏、TIME 2025 最佳发明特别提名、四起品牌合作（Poshmark/Altuzarra/Public School/CFDA）。
3. **照片 avatar 路线的信任裂缝被用户原声证实**（Doji）："makes everyone skinnier"、"doesn't even look like me"——为我们「身体维度驱动的诚实体型可视化」假设提供了反面论据。

---

## 1. Alta（Flagship AI, Inc.）——头号收敛者

### 1.1 定位与商业模式
- 官网定位（2026-07-21 检索）："your AI stylist and digital closet for **date nights, interviews, trips**, and more — built around the **clothes you already own**"。重心已明确落在**自有衣橱**而非纯购物。来源：https://www.altadaily.com/
- App Store 完整功能面（2026-07-21，一手）：拍照/**电商邮件收据导入**/数据库选衣入库、AI 抠图+自动打标签、cost-per-wear 与穿着频率统计、按**天气+日程**的每日推荐、指定单品生成搭配、event/trip 造型、多城市行程打包清单（可分享链接）、衣橱 gap 分析、wishlist 降价提醒、avatar 虚拟试穿、web 版。来源：https://apps.apple.com/us/app/alta-daily-digital-ai-closet/id6481705400
- **变现＝免费软件 + 商业侧收入**：App 免费且当前 App Store 未列任何 IAP；收入侧押品牌/电商合作——
  - 2025-10-16 Poshmark 合作（二手单品与自有衣橱混搭试穿）；
  - 2025-12-02 Altuzarra 假日 campaign（品牌顾客用 Alta avatar 试穿假日 look）；
  - 2026-02-14 Public School：品牌商品页嵌入 "Style with Alta" 图标——**B2B2C 试穿 widget 路线**；
  - 2025-04-08 CFDA 官方合作。来源：https://www.altadaily.com/blog/press
- **对我们楔子的渗透判定：已渗透**。衣橱管理深度（收据导入/CPW/场合/打包）不再是它的短板；它与我们仅剩的差异见 §6。

### 1.2 融资与团队增量
- 截至 2026-07-21，**未见 Series A 公告**：TechCrunch 站内检索仅 2025-06-16 的 $11M 种子轮一条（Menlo Ventures 领投，Karlie Kloss、Jasmine Tookes、Meredith Koop〔米歇尔·奥巴马造型师〕等跟投）。来源：https://techcrunch.com/2025/06/16/alta-raises-11m-to-bring-clueless-fashion-tech-to-life-with-all-star-investors/
- 荣誉：2025-10-09 入选 **TIME Best Inventions 2025**（special mention）。来源：https://www.altadaily.com/blog/press
- 产品节奏：v2.2.0，What's New 自述 "**New features every week!** … Improved styling algorithm and more realistic avatars"（2026-07-21 抓取时更新于「17 分钟前」）——迭代速度极快。

### 1.3 用户口碑（avatar：偏「惊艳」侧；留存信号真实）
- 4.9★/**11K** 评分（一个月内检索缓存还是 9.6K，仍在快速增长），Lifestyle 类 #84。
- 正面原声（App Store，一手）：
  - "I work from home…this app FINALLY is getting me out of it"（BunAlert, 2026-03-03）——WFH 职业女性场景直接命中；
  - "This app helps me stay organized with what I've worn"（Saphira34568, 2025-09-10）；
  - "I love this app…it helps so much"，同时**担忧未来收费**（big dinkle dour, 2026-04-21）。
- ⚠️ 置信标注：justuseapp/appshunter 均 403，负面原声未能系统采样；4.9★ 高分下差评占比小，但「avatar 真实度」在其更新日志里被反复强调（"more realistic avatars"），说明仍是用户抱怨点。第三方评测（Klodsy 2026-01-08）称 Alta「无虚拟试穿、只有每日推荐」与官方页矛盾——二手评测源对 Alta 的描述普遍滞后，采信官方/App Store。

---

## 2. Doji（Doji Labs, Inc.）——高融资、低牵引，未向衣橱渗透

### 2.1 现状（2026-07-21，一手 App Store）
- 4.1★/仅 **146** 个评分（上架 ~14 个月、$14M 融资背景下极低）；Shopping 类；v1.0.85 高频小版本修 bug；免费、未列 IAP。
- 功能：自拍生成 AI likeness、试穿设计师品牌与任意商品链接、tastemaker/品牌风格 feed、**浏览器扩展**（在任意时尚网站上试穿）、wishlist、社交分享、导购。**无任何衣橱管理**（描述通篇未提 closet/wardrobe）。来源：https://apps.apple.com/us/app/doji-try-on-designer-fashion/id6737292650
- 2026 年**零新闻**：TechCrunch 站内检索最后一条仍是 2025-05-15 融资稿；通用检索已被「Doji K线形态」淹没。官网新增 careers 页但无团队/规模披露。来源：https://techcrunch.com/2025/05/15/doji-raises-14m-to-make-virtual-try-ons-fun-through-ai-avatars/ 、https://www.doji.com

### 2.2 试穿质量的真实用户评价（恐怖谷证据，App Store 原声）
- "The concept is interesting. But once I tried the app **the avatar doesn't even look like me**"（TNRO08, 2025-09-14）
- "I love the concept…avatar doesn't really look accurate, **it seems to make everyone skinnier**"（SFMurderino, 2025-09-26）——体型失真直接打击信任，正是「合身判断」需求的反面教材。
- "difficulties with miniskirts…**turn into long skirts**"（doll faced diva, 2025-06-27）——服装保真度问题。
- 正面："Doji is pure brilliance…so useful in pasting product links"（macsnack_, 2025-10-21）。
- **判定：尝鲜即弃形态**。分享驱动的社交新鲜感未转化为规模留存（146 评分是硬证据）；对我们的楔子（日常衣橱管理）无渗透迹象，威胁降级。

---

## 3. Google：Doppl 关停，试穿变成搜索基础设施

### 3.1 Doppl 完整时间线（扩张→转向→关停）
| 时间 | 事件 | 来源 |
|---|---|---|
| 2025-06 | 美国上线（iOS/Android，Google Labs 实验品） | 基线 + https://jetstream.blog/en/google-doppl-shut-down-end-of-april-2026/ |
| 2025-10-08 | 扩展更多国家 + 支持鞋类试穿 | https://techcrunch.com/2025/10/08/googles-virtual-try-on-shopping-tool-expands-to-more-countries-now-lets-you-try-on-shoes/ （基线）|
| 2025-12 | 加入 TikTok 式 **shoppable AI discovery feed**（向导购转向） | https://www.mobilemarketingreads.com/doppl/ |
| 2026-03-23 | 宣布关停 | https://jetstream.blog/en/google-doppl-shut-down-end-of-april-2026/ |
| 2026-04-30 | 停止运行、双商店下架、用户数据不可访问 | **一手**：https://support.google.com/labs/answer/16537062 |

- 规模旁证（二手、低置信）：Android 端 AppBrain 仅录得 "10,000+ downloads"。来源：https://www.appbrain.com/app/doppl/com.google.android.apps.labs.glam
- 官方口径：实验目的已达成，「virtual try-on will continue across Google Search and Shopping」。来源：https://x.com/GoogleLabs/status/2036188820128071786

### 3.2 主线：试穿并入 Search/Shopping + 代理式购物
- **"Try on you"**：google.com/shopping/tryon——上传照片生成 "a digital version of yourself"，在商品列表/图片结果里直接试穿（Doppl 遗产的归宿）。来源：https://www.google.com/shopping/tryon?udm=28
- I/O 2026（2026-05）：AI Mode 购物体验（"inspiring visuals, virtual try-ons, and agentic checkout"）+ **Universal Commerce Protocol / Agent Payments Protocol / Universal Cart** 三件套。来源：https://mashable.com/article/google-io-2026-agentic-shopping-google-search 、https://blog.google/innovation-and-ai/technology/ai/google-io-2026-all-our-announcements/ 、https://thinkwithgoogle.com/next/v2/article/search-and-video/google-shopping-ai-mode-virtual-try-on-update/
- 2026-07-14：Google Images 改版为 Pinterest 式发现流（时尚发现流量入口再强化）。来源：https://techcrunch.com/2026/07/14/google-images-gets-a-pinterest-like-redesign-focused-on-discovery/
- **判定**：Google 明确放弃「独立衣橱/试穿 App」形态，**不与我们争日常衣橱管理**；但把照片级试穿做成了**免费基础设施**——任何以「生成式照片试穿」为卖点的独立 App 均被釜底抽薪。护城河结论与基线一致且更强：**在衣橱数据与日常粘性，不在试穿像素**。

---

## 4. FitCheck 现象与 2025-2026 新入场者扫描

### 4.1 "FitCheck" 不是一家公司，是一个关键词集群（重要市场信号）
检索发现至少 8 个同名产品（fitcheckaiapp.com / fitcheckai.app / tryfitcheck.com / getfitcheck.ai / fitcheck.day / 两个 iOS App / 多个安卓 App），无一有规模、无一有融资记录：
- **AI Outfit Maker: FitCheck**（Rule 25 Apps LLC）：2025-11-12 上架，仅 1 个评分；$3.99-4.99/周、$29.99-39.99/年。功能：相册/购物链接入库 + 试穿 + 搭配规划。来源：https://apps.apple.com/us/app/ai-outfit-maker-fitcheck/id6752269346
- **FitCheck AI - Outfit Planner**（JM INNOVATIONS LTD）：2026-03-05 上架，3.9★/9 评分；**credit 制付费**（5 次 $1.99 → 200 次 $69.99，另 $34.99/年）。功能却相当全：扫描建可搜索衣橱、AI 识别品牌/类别/颜色/尺码、真衣上模特试穿、天气推荐、日历、**带行李限重的打包工具**、桌面 widget。差评原声："App does not follow rules, will be taking legal action."（TruthLegal, 2026-04-26）。来源：https://apps.apple.com/us/app/fitcheck-ai-outfit-planner/id6758739428
- **信号解读**：①「衣橱扫描+试穿+天气+打包+widget」的功能清单已被 AI wrapper 模板化，1-2 人团队即可拼出——**功能表不再是护城河**；②App Store 时尚类目关键词污染严重，ASO 要避开可蹭词根；③credit 制/高周费付费墙泛滥，反衬诚实定价的稀缺性。

### 4.2 值得留意的新面孔
- **Layered**（独立开发者 Vadim Drobinin，iOS，2026 年春上线，Product Hunt 当日 #7/140 票）：**用自拍/生活照反推建衣橱**（明确针对 "photograph items one by one against a white background" 的录入痛点）、旅行胶囊（按目的地+行李限制）、CPW、次日穿搭 widget；免费 5 次交互后付费墙。**录入摩擦创新的方向标**。来源：https://www.producthunt.com/products/layered-2
- **Gensmo**（Serendipity One Inc.，iOS+Android）："your first fashion AI agent"——试穿 + 整套搭配 + 购物整合；自称 **750k+ 下载、4.7★**（公司口径），AppBrain 录得 Android 100k+。购物代理路线，不做衣橱深度。来源：https://gensmo.com 、https://www.appbrain.com（检索页快照）
- **OpenWardrobe**（LolaAI 对话式衣橱）、**Klodsy**（自称试穿质量业界领先）、**Combyne**（社交搭配）、closetapp.ai、aiwardrobe.co、Nouva、Looqs、fits-app、minniie、selionai、beautyai、outfitmaker.ai（€7.99-14.99/月）等——2026 年「best AI wardrobe app」SEO 内容战激烈，各家互写评测带私货，二手评测可信度低。来源示例：https://klodsy.com/blog/best-ai-stylist-apps-2026-comparison/ （2026-01-08）、https://outfitmaker.ai/blog/best-ai-wardrobe-apps-in-2026-honest-comparison （2026-03-31）
- **Haze Couture**（Cruxnd Haze, Inc.）：定位与我们假设②几乎同构——「body scan → 你体型的 AI mannequin，precision sizing based on actual measurements」，但 2024-05 上架后 2024-06 即停更，仅 2 个评分，订阅栏杆高至 $199.99。**概念有人试过、执行与获客双双失败**——空白仍在，但需引以为戒（体型扫描的冷启动成本）。来源：https://apps.apple.com/us/app/haze-couture/id6759711912
- 基线更新：Acloset 官网现称 **7M users**（基线 2026-02 韩媒口径为累计会员 450 万；公司自报口径，未经核实）。来源：https://www.acloset.app

---

## 5. 平台风险专项

### 5.1 Apple：无 sherlocking 信号（截至 2026-07-21）
- 专利/收购/招聘三条线均未检出时尚方向：近期大动作是 ~$20 亿收购以色列**音频** AI 公司 Q.ai（与时尚无关）；Patently Apple 近期时尚/试穿相关专利未见。来源：https://techcrunch.com/（Q.ai 报道，检索页快照）
- iOS 26 **Visual Intelligence**：截图/屏幕内容 → 识别商品并跳转购买——是**购物漏斗**能力，不是衣橱管理，也未内建试穿。来源：https://www.macrumors.com/guide/ios-26-visual-intelligence/ 、https://appleinsider.com/articles/25/06/10/visual-intelligence-in-ios-26-makes-screenshots-useful-not-just-saved
- **机会面**：Apple Intelligence/on-device Foundation Models 是我们「on-device 隐私」差异化的顺风（Stylebook 10 已用其做 AI 生成商品图，见基线）；Apple 更可能以 API 赋能第三方而非自做衣橱 App。
- 监控点：每年 WWDC（6 月）；若 Apple 在 Wallet/Shopping 或 Vision Pro Persona 方向出现「身体测量→服装」专利再升级评估。

### 5.2 Pinterest：距离衣橱管理一步之遥（当前最需盯的平台）
- **2025-10-27 官宣 "Styled for you"**：把用户**收藏的 fashion Pins** AI 拼贴成整套 outfit，可逐件点击换款；配套 "Boards made for you"（编辑+AI 混合策展板，含每周穿搭灵感与可购商品）；美国+加拿大数月内灰度。CEO Bill Ready 明确目标：成为 "**AI-enabled shopping assistant**"。来源：https://techcrunch.com/2025/10/27/pinterest-experiments-with-new-ai-powered-personalized-boards/ 、https://www.techbuzz.ai/articles/pinterest-s-ai-upgrade-transforms-boards-into-outfit-generators
- 同时在做 AI 内容标注与「减少 AI pin」控制（用户对 AI slop 反弹的对冲）。
- **边界判定**：素材是「收藏的商品图」（aspirational），**不是用户自有衣橱**（owned）——尚未跨入我们的楔子。**升级触发器：一旦 Pinterest 允许上传自己衣服照片进 Styled for you，其分发能力（月活 5 亿级）将构成 C 组最大威胁**。当前未见此计划。
- 周边信号：Depop 2025-09-24 上线 Pinterest 风格拼贴造型工具（二手电商也在抢造型入口）。来源：https://techcrunch.com/2025/09/24/depop-launches-a-fashion-collaging-tool-to-style-pinterest-worthy-outfits/

### 5.3 Meta/Instagram：纯商业漏斗，无衣橱迹象
- 2026-03-25（Shoptalk）：在 Instagram/Facebook 测试生成式 AI 购物工具（商品信息增强）。来源：https://techcrunch.com/2026/03/25/meta-turns-to-ai-to-make-shopping-easier-on-instagram-and-facebook/
- 传闻级（二手）：内部代号 **"Hatch"** 的 Instagram 内 AI 购物代理，目标 2026 年底。来源：https://futurefactors.ai/meta-instagram-ai-shopping-agents-affiliate-reels-2026/
- 2026 世界杯营销含「virtual jersey try-ons」（噱头级）。来源：https://news9live.com/technology/tech-news/meta-launches-fifa-world-cup-2026-features-on-instagram-whatsapp-and-facebook-2979445
- 判定：与 Google 同向——购物代理与试穿彩蛋，不碰「自有衣橱」。

---

## 6. 威胁矩阵：谁在收敛到我们的定位，时间窗多长

> 我们的定位：美国职业女性(25-45)多场合数字衣橱——扫描入库 / 场合+天气搭配 / **身体维度合身与体型可视化** / **存放位置与换季** / 多衣柜分层 / 不卡件数免费 + on-device 隐私。

| 玩家 | 收敛度 | 已重叠 | 仍缺（=我们的活口） | 时间窗判断 |
|---|---|---|---|---|
| **Alta** | ★★★★★ | 自有衣橱、场合叙事(interviews/trips)、天气+日程推荐、打包、CPW、收据导入、avatar 试穿、免费 | **身体维度合身判断**（其 avatar 走照片写实路线）、**存放位置/换季**、**多衣柜分层**、on-device 隐私（云端+品牌数据合作天然冲突）、变现依赖导购→与「只穿已有衣服」用户利益错位 | **0-12 个月**。周更节奏 + $11M + 品牌侧收入压力可能随时补场合/职业深度；但其商业模式（导购佣金）使「纯衣橱深度」优先级存疑 |
| **Google（Search/Shopping try-on）** | ★★☆☆☆ | 免费照片试穿基础设施、代理式购物 | 全部衣橱管理维度（已明确退出 App 形态） | 不进入楔子；但**永久性商品化了照片试穿**——把试穿当卖点的窗口已关闭 |
| **Pinterest** | ★★★☆☆ | AI 整套搭配、逐件替换、购物助手战略 | 自有衣橱 ingestion、场合/天气、合身、任何管理功能 | **12-24 个月**；触发器=开放自有衣物上传。需按季监控 |
| **Meta/Instagram** | ★☆☆☆☆ | AI 购物代理（Hatch，传闻） | 全部 | 24 个月+，非直接威胁 |
| **Apple** | ★☆☆☆☆ | Visual Intelligence 购物漏斗 | 全部；无专利/收购/招聘信号 | 24 个月+；每年 WWDC 复查。当前更像**赋能者**（on-device 模型） |
| **Doji** | ★☆☆☆☆ | 照片 avatar 试穿 | 全部衣橱维度；且增长停滞（146 评分） | 无近期威胁；若转型衣橱再评估 |
| **indie 潮（FitCheck 集群/Layered/Gensmo/Klodsy…）** | ★★☆☆☆ | 功能清单全面模板化（扫描/试穿/天气/打包/widget） | 规模、留存、信任、深度（合身/存放均无人做） | 持续背景噪音：拉高获客成本、压低付费意愿、污染关键词 |

**总判断**：C 组没有人同时做「体型维度合身 + 存放/换季 + 多衣柜」——这三点仍是空白；但「多场合叙事」「免费慷慨」「试穿」三张牌已被 Alta/Google 打掉差异性。竞争窗口主要由 Alta 的路线选择决定：它每周都在发版，我们的差异点必须是它**商业模式上不愿做**的（隐私 on-device 与导购收入冲突、存放/换季不产生 GMV），而不仅是它**还没做**的。

---

## 7. 对四个差异化假设的冲击评估

| 假设 | 冲击 | 结论 |
|---|---|---|
| ① 职业女性多场合 | Alta tagline 已含 interviews/trips；但其场景仍偏「时尚爱好者+购物」，无职业女装规则深度（着装规范/会议级别/差旅行程联动） | **叙事不再独有，深度仍可赢**——需把「场合」做成规则引擎+日历集成，而非标签 |
| ② 身体维度合身+体型可视化 | 无人做成：Doji 照片 avatar「把人变瘦」遭差评；Haze Couture 尝试身体扫描已死；Google 走照片 digital self | **空白确认且被反向验证**——「诚实的参数化体型 + 合身判断」恰好是照片路线的信任解药；避免与像素写实军备赛 |
| ③ 存放位置/换季收纳 | C 组零玩家触碰（不产生购物 GMV，AI 新贵无动机做） | **空白维持**，且结构性安全（与导购模式利益相斥） |
| ④ 不卡件数免费 + on-device 隐私 | Alta 全免费已把「慷慨免费」变成 AI 新贵默认（免费≠差异化）；indie 潮 credit 墙泛滥；on-device 无人占位 | **免费层降级为及格线；隐私 on-device 仍独有**——变现设计不能依赖「免费更大方」，要靠隐私订阅/合身高级功能 |

---

## 8. 来源清单（关键）

**一手**
- Alta App Store：https://apps.apple.com/us/app/alta-daily-digital-ai-closet/id6481705400 （2026-07-21 抓取）
- Alta 官网/press：https://www.altadaily.com/ 、https://www.altadaily.com/blog/press
- Doji App Store：https://apps.apple.com/us/app/doji-try-on-designer-fashion/id6737292650 （2026-07-21 抓取）
- Doji 官网：https://www.doji.com
- Google Doppl 关停支持页：https://support.google.com/labs/answer/16537062 ；Google Labs 官推：https://x.com/GoogleLabs/status/2036188820128071786
- Google Try on you：https://www.google.com/shopping/tryon?udm=28 ；I/O 2026 官方汇总：https://blog.google/innovation-and-ai/technology/ai/google-io-2026-all-our-announcements/
- FitCheck 两 App：https://apps.apple.com/us/app/ai-outfit-maker-fitcheck/id6752269346 、https://apps.apple.com/us/app/fitcheck-ai-outfit-planner/id6758739428
- Haze Couture：https://apps.apple.com/us/app/haze-couture/id6759711912
- Layered（Product Hunt）：https://www.producthunt.com/products/layered-2
- Gensmo：https://gensmo.com

**二手（媒体/聚合）**
- TechCrunch：Alta 融资（2025-06-16）、Doji 融资（2025-05-15）、Pinterest Styled for you（2025-10-27）、Depop 拼贴（2025-09-24）、Meta AI 购物（2026-03-25）、Google Images 改版（2026-07-14）
- Doppl 时间线：https://jetstream.blog/en/google-doppl-shut-down-end-of-april-2026/ 、https://www.mobilemarketingreads.com/doppl/ 、https://www.appbrain.com/app/doppl/com.google.android.apps.labs.glam （下载量，低置信）
- I/O 2026 购物协议：https://mashable.com/article/google-io-2026-agentic-shopping-google-search
- Pinterest 深度：https://www.techbuzz.ai/articles/pinterest-s-ai-upgrade-transforms-boards-into-outfit-generators
- Meta Hatch（传闻级）：https://futurefactors.ai/meta-instagram-ai-shopping-agents-affiliate-reels-2026/
- iOS 26 Visual Intelligence：https://www.macrumors.com/guide/ios-26-visual-intelligence/ 、https://appleinsider.com/articles/25/06/10/visual-intelligence-in-ios-26-makes-screenshots-useful-not-just-saved
- 2026 评测生态（互相带私货，低置信）：https://klodsy.com/blog/best-ai-stylist-apps-2026-comparison/ 、https://outfitmaker.ai/blog/best-ai-wardrobe-apps-in-2026-honest-comparison

> 置信说明：App Store 数据为 2026-07-21 实抓（高置信）；下载量/用户数若为公司自报或 AppBrain 桶状计数已标注（低-中置信）；Alta 负面原声因聚合站反爬未能系统采样（中置信缺口）；Meta "Hatch" 为单源传闻（低置信）。
