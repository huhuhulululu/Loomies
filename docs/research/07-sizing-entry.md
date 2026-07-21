# 07 · 衣服尺码与维度录入方案调研

> 调研日期：2026-07-21。面向女性职业/多场合数字衣橱 iOS App。
> 核心结论先行：**尺码标签（S/M/L、160/84A、US 6…）跨品牌不可比，只能作展示元数据；合身判断必须建立在「服装平铺实测维度 + 用户身体维度」之上**。自动化录入的现实路径是「洗标 OCR（设备端 Vision）为主 + 平铺拍照估测为进阶 + 条码反查为辅（低命中）」。

---

## 1. 尺码体系与对照关系

### 1.1 中国 GB/T 1335 号型制

- 现行标准 GB/T 1335.2-2008《服装号型 女子》（2009-08-01 实施），号型以**身高/净胸围（上装）或净腰围（下装）+ 体型代号**表示。`160/84A` = 身高 160cm、净胸围 84cm、A 体型。官方全文公开：[openstd.samr.gov.cn](https://openstd.samr.gov.cn/bzgk/gb/newGbInfo?hcno=220299CC07916ACAB86D71CB568BE36E)。
- 体型代号按**胸腰差**分档：Y（胸大腰细）> A（标准）> B（微胖）> C（胖）。女装 M ≈ 160/84A。来源：[百度百科·服装尺码标准](https://baike.baidu.com/item/%E6%9C%8D%E8%A3%85%E5%B0%BA%E7%A0%81%E6%A0%87%E5%87%86/12595313)、[澎湃科普](https://m.thepaper.cn/baijiahao_12790087)。
- 关键点：号型标的是**适穿人体尺寸**（净体），不是服装成衣尺寸——同为 160/84A 的两件衣服，成衣胸围可因放松量设计差 10cm+。

### 1.2 日本 JIS L4005

- JIS L4005:2001《成人女子用衣料のサイズ》：`9AR` = 9 号（バスト 83cm 为标准 9 号，号数全为奇数 3–31，每号 ±3cm）+ A 体型（Y=臀围小 4cm，AB=大 4cm，B=大 8cm）+ R 身高区分（R=158cm，P=150，PP=142，T=166）。9AR 基准：胸 83 / 腰 67 / 臀 91 / 身高 158。来源：[カケンテストセンター](https://www.kaken.or.jp/learn/detail/63)、[全日本婦人子供服工業組合連合会](https://www.jwca.or.jp/qa/size/)、[JIS 条文](https://kikakurui.com/l/L4005-2001-01.html)。

### 1.3 欧洲 EN 13402 / ISO 8559

- EN 13402 四部分（术语/主次维度/尺寸间隔/编码），核心思想：**用适穿人体尺寸（cm）+ 象形图标注**，取代品牌自定义数字码。EN 13402-1 已被 EN ISO 8559-1:2020 取代；EN ISO 8559-2:2025 为最新的尺码指示标准。来源：[Wikipedia·EN 13402](https://en.wikipedia.org/wiki/Joint_European_standard_for_size_labelling_of_clothes)、[iTeh 标准目录](https://standards.iteh.ai/catalog/standards/cen/10e10ff0-4f96-407a-b9c9-a0165d48a0c7/en-iso-8559-2-2025)、[ISO 8559-2](https://www.iso.org/standard/64075.html)。
- 美国**无政府强制标准**（ASTM D5585 为自愿性），英国同样品牌自定；「EU 36 = US 4 = UK 8」这类对照表全部是零售商自制近似，**不存在权威跨体系换算真相源**。

### 1.4 Vanity sizing 的量化证据（同码不同维度）

- **历史漂移**：Sears 目录中 1937 年 size 14 的胸围（32in）到 1967 年标为 size 8、2011 年标为 size 0；ASTM 标准中 size 12 的名义胸围从 34in（1958, CS 215-58）膨胀到 38.75in（2011, ASTM D5585-11e1）。来源：[Wikipedia·Vanity sizing](https://en.wikipedia.org/wiki/Vanity_sizing)。
- **跨品牌横向研究**：54 家美国零售商研究（Journal of Economic Behavior & Organization, 2017）发现中高价品牌尺码普遍虚标偏大、高奢品牌反而偏小、面向年轻女性的品牌偏小，男装童装几乎无 vanity sizing（[ScienceDirect](https://www.sciencedirect.com/science/article/abs/pii/S0167268117300045)）；Kinley 2003 实测 1000+ 条女裤，贵价品牌同名义码实际更小；Esquire 2010 实测男裤名义 36in 腰围实际 37–41in（4in 离散）；2011 英国抽查过半标签失实。
- **后果**：约 40% 的线上服装退货源于尺码问题（[Fibre2Fashion](https://www.fibre2fashion.com/industry-article/9438/vanity-sizing-in-women-s-fashion-does-size-matter)）。
- **对本 App 的含义**：尺码标签只能做「品牌语境内的名义值」，不可跨品牌比较、不可直接参与合身计算。

---

## 2. 平铺实测维度：二手平台行业范式

各平台均以**平铺测量（flat lay）**为通用语言。字段现状：

| 平台 | 结构化字段 | 测量字段惯例 |
|------|-----------|-------------|
| **Poshmark** | 尺码下拉（必填，美码体系） | 测量写描述区；社区规范：上装=胸宽(pit-to-pit，×2 报周长)+衣长(+袖长)，半裙=腰宽+裙长，裤=腰宽+内长(inseam)。casual 卖家最低集：上装 2 项、裤 2 项。来源：[Poshmark 官方博客](https://blog.poshmark.com/2014/09/25/posh-tip-how-to-measure-items-for-resale/)、[TheTailoredCo 指南](https://www.thetailoredco.com/how-to-measure-clothes-for-poshmark/) |
| **Vinted** | 尺码下拉（按目录静态，站内自动做 EU/UK/US 对照展示），**无结构化测量字段** | 测量写描述+实拍卷尺照；惯例：上装 pit-to-pit、裤腰+内长、裙肩至底摆。来源：[Vinted 帮助·Measurements](https://www.vinted.com/help/1108-measurements)、[Vinted 帮助·尺码表](https://www.vinted.com/help/505-size-guides-charts)、[卖家经验](https://medium.com/@ross.angus/everything-ive-learned-from-helping-to-run-a-vinted-account-for-a-year-65a3cff6558c) |
| **Mercari JP** | 尺码下拉（JIS 习惯码） | 官方「採寸ガイド」按品类给测点图：外套/衬衫/T恤（着丈·身幅·肩幅·袖丈），裤（ウエスト·股上·股下等），裙（丈），鞋、帽、包另有测点。来源：[メルカリ採寸ガイド](https://help.jp.mercari.com/guide/articles/520/)、[Mercari US Size Guide](https://www.mercari.com/us/help_center/product-info/size-guide/) |
| **eBay** | 尺码等 item specifics（服装类推荐非强制） | 测量入描述；2023-24 起 AI「magical listing」从照片预填颜色/尺码/款式等属性。来源：[eBay Innovation](https://innovation.ebayinc.com/stories/magical-listing-tool-harnesses-the-power-of-ai-to-make-selling-on-ebay-faster-easier-and-more-accurate/) |
| **闲鱼** | 无强制测量字段 | 2024 起「智能发布」：上传图片自动识别品牌等信息生成描述+定价参考。来源：[新浪科技](https://finance.sina.com.cn/tech/digi/2024-09-18/doc-incpptnw4791288.shtml)、[闲鱼 AI 技术解析](https://zhuanlan.zhihu.com/p/6035880766) |
| **多抓鱼** | 卖家零录入 | C2B2C 模式：平台昆山/天津工厂集中质检、消毒、测量、统一平铺拍摄后上架——测量由平台标准化完成而非卖家。来源：[界面新闻](https://www.jiemian.com/article/5882571.html)、[多抓鱼服饰交易规则](https://www.duozhuayu.com/support/clothing-trading-rules)、[昆山工厂探访](https://zhuanlan.zhihu.com/p/675019005) |

**通用品类→字段矩阵**（行业交集，可直接作 App 的 per-category schema）：

| 品类 | 核心字段（平铺 cm） | 可选 |
|------|---------------------|------|
| 上装（T恤/衬衫/毛衣/外套） | 胸宽(pit-to-pit)、衣长、肩宽、袖长 | 下摆宽、袖口宽 |
| 裤 | 腰宽、内长(inseam)、裤长 | 臀宽、前裆(股上)、脚口宽 |
| 半裙 | 腰宽、裙长 | 臀宽、下摆宽 |
| 连衣裙 | 胸宽、腰宽、肩至底摆长 | 肩宽、袖长、臀宽 |
| 鞋 | 内长 | 宽度 |

---

## 3. 自动化录入路径

### 3.1 洗标/吊牌 OCR（推荐主路径）

- **Vision `RecognizeTextRequest`**（iOS 18+ 新 Swift API）：设备端 OCR，支持精度档位、语言校正、**`customWords` 自定义词表**——把品牌名列表注入词表可显著提升品牌识别率。文档：[developer.apple.com/documentation/vision/recognizetextrequest](https://developer.apple.com/documentation/vision/recognizetextrequest)。
- **`RecognizeDocumentsRequest`**（WWDC25 新 API，iOS 26）：一次请求同时抽取**结构化文本（段落/表格/列表）+ 条码**，支持 26 种语言——洗标常见「多语言成分列表 + 尺码表格」正对口。Session：[Read documents using the Vision framework (WWDC25-272)](https://developer.apple.com/videos/play/wwdc2025/272/)。
- **VisionKit `DataScannerViewController`** 可做实时取景 Live Text 扫描（文本+条码同框）。
- 解析策略：品牌（customWords 词表匹配）→ 尺码 token（正则族：`\d{3}/\d{2}[YABC]`（GB/T）、`\d+A[RPT]?`（JIS）、`EU ?\d{2}`、`S|M|L|XL`、`US ?\d+`）→ 成分（`\d+% 棉/cotton/…`）。洗标弯曲、反光、多语言混排是主要工程难点；吊牌（平整印刷）识别率高于洗标。
- **产品先例**（证明可行性）：[Garma - Clothing Label Scanner](https://play.google.com/store/apps/details?id=com.stringcode.garma)（读成分/护理符号/品牌）、[Clear Fashion](https://apps.apple.com/us/app/clear-fashion-score-scan/id1468459532)（扫成分标签评分）、[FiberCheck](https://play.google.com/store/apps/details?id=com.codixus.fibercheck&hl=en_US)、[Size AI](https://apps.apple.com/us/app/size-ai-garment-measurement/id6752236057)（标签 1-2 秒抽品牌/尺码/成分/护理）。

### 3.2 条码/吊牌条码反查（辅路径，命中率有限）

- **GS1 Verified by GS1**：全球 GTIN 注册库，仅 6 个核心属性（品牌名、短描述、GPC 品类码、图片 URL、净含量、目标市场）——**无尺码/维度字段**，且需通过会员/API 接入。来源：[gs1.org/services/verified-by-gs1](https://www.gs1.org/services/verified-by-gs1)。
- 商用聚合库：[Barcode Lookup API](https://www.barcodelookup.com/api-documentation)（UPC/EAN/GTIN→名称/品牌/图片，付费）、[EAN-Search.org](https://www.ean-search.org/)（自称 12 亿 EAN）、[UPCitemdb]、[Scanbot lookup](https://scanbot.io/lookup-tool/)（5 亿+）。服装覆盖参差；同一款式不同尺码是不同 GTIN，反查可顺带拿到尺码，但**二手/在穿衣物通常已无吊牌，洗标上一般没有零售条码**——该路径只对「新购未拆吊牌」场景高价值。
- 中国市场可补充中国物品编码中心的商品条码数据（GDS），接入门槛类似。

### 3.3 拍照/LiDAR 估测服装维度（进阶路径，已有产品先例）

- **Stitch Fix（2016）**：平铺在带刻度标定板上俯拍，检测服装关键点 + 已知标定距离换算测量值——最早公开的工程范式。[技术博客](https://multithreaded.stitchfix.com/blog/2016/09/30/photo-based-clothing-measurement/)。
- **Tailored / Capture**：面向 reseller 的拍照测量 web app，用信用卡等参照物定标。[官网](https://www.thetailoredco.com/photo-based-clothing-measurements/)。
- **Size AI - Garment Measurement**（iOS，Polymath Collective）：平铺拍照自动出胸/腰/臀/内长/袖/肩/裆等，覆盖 90+ 品类；**宣称 LiDAR 机型 ~5mm、无 LiDAR ~9mm 精度**（iPhone 11+）；捆绑标签 OCR、条码、AI 商品图、平台化 listing 导出。[App Store](https://apps.apple.com/us/app/size-ai-garment-measurement/id6752236057)。⚠️ 精度为厂商自述，未独立验证。
- 学术先例：[Automatic Measurement of Garment Sizes Using Image Recognition](https://www.semanticscholar.org/paper/90a7000bcec8fbc77f3e71182c07c92cf13bf961)（关键点检测→测量换算）。
- **LiDAR 的角色**：平铺测量本质是 2D 问题，LiDAR 的增量价值主要是**免参照物的绝对尺度**（深度图直接给出像素-厘米换算）与更稳的平面拟合；ARKit sceneDepth / RoomPlan 级别的 3D 网格对「量衣服」是过度手段，对「量身体/试衣可视化」才是主战场（另见 LiDAR 专题调研）。通用 3D 扫描 App（[Polycam](https://apps.apple.com/us/app/polycam-3d-scanner-lidar-360/id1532482376)、[3D Scanner App](https://3dscannerapp.com/)、[KIRI Engine](https://www.kiriengine.app/features/lidar-scan)）可扫出服装形态但不直接输出裁片测量。

### 3.4 平台级先例：拍照自动建档

eBay magical listing（照片→预填颜色/尺码/款式/性别，2024 AI Breakthrough Award）与闲鱼智能发布（照片→品牌识别+描述生成+定价）证明「拍照→自动属性」在服装品类已规模化落地，但两者都**不做维度测量**。来源：[eBay](https://innovation.ebayinc.com/stories/ebays-magical-listing-tool-wins-ai-breakthrough-award-for-best-overall-generative-ai-solution/)、[闲鱼](https://www.ghxi.com/new2024091801.html)。

---

## 4. 品牌尺码表数据源

- **[SizeCharter](https://sizecharter.com/)**：聚合主流品牌官方尺码表，输入身体维度反查各品牌适穿码——**消费者网站，无公开 API，无可商用授权**。
- **[Sizely](https://www.size.ly/size-chart)**、**[SizeChart.com](https://www.sizechart.com/)**：同类聚合站，同样无 API。
- **GitHub / Kaggle**：未发现开源多品牌尺码表数据集；最接近的是 [Clothing Fit Dataset (ModCloth + RentTheRunway)](https://www.kaggle.com/datasets/rmisra/clothing-fit-dataset-for-size-recommendation)（19 万条**购买-合身反馈**记录，含身体特征与 fit 结果，适合训练 fit 模型，不含品牌尺码表本身）。
- 商业数据供应商（如 [Techsalerator Clothing Size Data](https://www.techsalerator.com/sub-data-categories/clothing-size-data)）存在但定价/质量不透明。
- **结论**：不存在「拿来即用、可商用」的品牌尺码表数据库。可行路线：自建种子库（目标用户高频品牌 Top50–100 的官网尺码表手工结构化，尺码表数值本身属事实数据，但注意抓取 ToS）+ 用户录入众包回填。

---

## 5. 合身度（fit）建模先例

| 方案 | 输入 | 方法 | 对本 App 借鉴 |
|------|------|------|--------------|
| **True Fit** | 用户自报「衣柜锚点」（哪个品牌哪个码合身）+ 基本信息，**不量体** | Fashion Genome：亿级购买/退货结果协同过滤，输出 5 分制 fit score + 推荐码 + 松紧描述 | 「锚点服装」思路可借用：让用户标记衣柜中最合身单品作为个人基准 |
| **Fit Analytics**（Snap 旗下） | 同上（问卷式 size advisor） | ML 尺码顾问，[官网](https://fitanalytics.com/) | 同上 |
| **Bold Metrics** | 少量输入推 **50+ 身体维度**「数字孪生」+ **每款服装的 spec/tech pack 数据** | Virtual Sizer API：身体维度 × 服装规格逐款匹配，[开发者文档](https://docs.boldmetrics.io/virtual-sizer) | **与本 App 架构同构**（身体维度+服装维度双边都有），验证了确定性匹配路线 |
| **Amazon Made for You**（2020） | 身高体重+2 张照片→virtual body double | 定制 T 恤，[CNBC](https://www.cnbc.com/2020/12/15/amazon-made-for-you-uses-virtual-body-double-to-create-custom-t-shirts.html) | 「照片→近似体型」的先例 |
| **Amazon Fit Insights**（2023-24，卖家侧） | 退货数据+评论 fit 反馈+尺码表 | LLM 聚合评论 + ML 检测尺码表缺陷，[EcommerceBytes](https://www.ecommercebytes.com/2023/12/17/amazon-hopes-fit-insights-tool-will-reduce-returns/) | 事后反馈闭环思路 |
| **学术** | 购买/退货记录 | Sembium et al. RecSys'17 潜变量「true size」（[PDF](https://cseweb.ucsd.edu/classes/fa17/cse291-b/reading/p243-sembium.pdf)）；Zalando 分层贝叶斯 RecSys'18（[ACM](https://dl.acm.org/doi/10.1145/3240323.3240388)）；Misra RecSys'18 fit 语义分解（即上述 Kaggle 数据集） | 电商系方法都依赖海量交易数据——**本 App 没有**，不可照搬 |
| **本 App 可行路线** | 身体净尺寸 + 服装平铺实测 | **确定性放松量（ease）模型**：服装周长（2×平铺宽）− 身体净围 = ease，按品类/版型设阈值带（如梭织衬衫胸围 ease 6–12cm 合身、<4cm 紧、>16cm oversize），输出可解释的松紧判断；用户穿着反馈（紧/合/松）逐件校准个人偏好偏移 | 冷启动零数据即可用、可解释、与 Bold Metrics 同路线 |

## 6. 竞品尺码字段现状

- **Stylebook**：条目字段含品牌/颜色/面料/价格（cost-per-wear）+ 尺码工具 + 自由备注；**无结构化平铺测量字段**。来源：[官方功能列表](https://www.stylebookapp.com/features.html)、[长期用户评测](https://www.cottoncashmerecathair.com/blog/2020/4/10/how-i-catalog-my-closet-and-track-what-i-wear-with-the-stylebook-app-review)。
- **Whering**：Category/Colour/Tags/Brand/**Size**/Price/Fabric/Care/状态（preloved 等），支持批量编辑与自定义品牌；无测量字段；另发布了独立「[AI Fashion Scanner](https://apps.apple.com/us/app/-/id6737750620)」App。来源：[Whering FAQ](https://whering.co.uk/faq/how-do-i-add-my-own-clothes)。
- **Indyx**：基础信息（品牌/尺码/品类/颜色）+ 「more info & **measurements**」区——竞品中唯一有测量区者（服务其转售场景）。来源：[用户实录](https://thisisnoelle.com/cataloguing-my-closet-with-indyx/)、[官方对比页](https://www.myindyx.com/versus/acloset-vs-stylebook)。
- **Acloset**：AI 自动去背+自动打品类/颜色标签，基础属性含尺码；无测量字段。来源：[Good On You 评测](https://goodonyou.eco/wardrobe-organising-apps/)。
- **空白点**：没有竞品做「尺码体系归一化（GB/T↔EU↔US）」「洗标 OCR 一键建档」「服装维度×身体维度 fit 判断」——三者都是本 App 的差异化机会。

---

## 7. 设计建议（录入方案）

1. **双层数据模型**：`nominal_size`（体系枚举 CN_GBT/EU/US/UK/JP/INTL + 原始标签字符串保真）与 `measurements`（品类化平铺实测 cm）分离；对照换算只做展示提示，永不参与 fit 计算。
2. **品类字段集**采用第 2 节矩阵（上装 4 核心 + 下装 5 + 裙 2-3 + 连衣裙 5），每字段带「实测/推断/未填」溯源标记。
3. **录入流水线**（渐进式，别一次要求全填）：拍洗标/吊牌 → 设备端 `RecognizeDocumentsRequest` 抽品牌（customWords 词表）/尺码（多体系正则）/成分 → 一屏人工确认；有吊牌条码顺手扫（GTIN 反查作 bonus）；测量字段默认留空，提供「平铺拍照引导 + 参照物（LiDAR 机型免参照物）」进阶入口。
4. **fit 引擎首版用确定性 ease 模型**（零数据冷启动、可解释），以用户「紧/合/松」反馈迭代个人化阈值；不做协同过滤（无交易数据）。
5. **尺码表不外购**：自建目标品牌种子库 + 用户众包；SizeCharter 类站点仅作人工参考。
