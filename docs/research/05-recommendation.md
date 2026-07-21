# 穿搭推荐引擎公开方案调研（规则层 / ML 层 / LLM 层）

> 调研日期：2026-07-21。面向「女性 · 职业/多场合 · 数字衣橱 iOS App」的推荐引擎选型输入。
> 结论先行：公开方案收敛为**三层混合架构**——规则层做硬过滤与可解释打分（零数据即可用，天然解决冷启动）、embedding 层做兼容度检索与相似度（FashionCLIP 系）、LLM 层做编排/场合理解/自然语言解释（云端小模型为主，端侧 3B 只能做轻任务）。纯 LLM 或纯 ML 单层方案在私人衣橱场景均有明显短板。

---

## 1. 规则层

### 1.1 色彩搭配理论

**60-30-10 比例规则**：源自室内设计的经典配色比例，移植到穿搭——60% 主色（连衣裙/下装/套装）、30% 辅色（上衣/外套）、10% 点缀色（配饰/鞋/包）。多个造型师来源一致表述，可直接编码为「按单品面积占比分配色彩角色」的规则。
- https://insideoutstyleblog.com/2019/03/using-the-60-30-10-rule-to-create-fabulous-colour-combinations-in-your-outfits.html
- https://www.la-s.co.uk/blogs/journal/what-is-the-60-30-10-colour-rule

**色轮组合模式**（可直接算法化，HSL 色相角判断）：
- 邻近色（analogous，色相相邻 ≤60°）→ 和谐柔和；互补色（complementary，色相差 ~180°）→ 强对比；三角色（triadic，色相等距 120°）→ 平衡而醒目。
- 通用约束：整套 ≤3 个非中性色；黑白灰米驼牛仔蓝视为中性色，不计入配色数。
- https://www.masterclass.com/articles/how-to-match-clothes-using-the-color-wheel
- https://howtowearfashion.com/styling-tips/how-to-use-the-color-wheel-when-getting-dressed

### 1.2 个人色彩分析（四季型 → 12 季型 → 16 季型）

- 谱系：1920s Johannes Itten 的四季观察 → 1940s Suzanne Caygill 体系化 → **1980 年 Carole Jackson《Color Me Beautiful》普及四季型**（该书是行业事实起点）→ 12 季型在四季基础上加 Light/Deep/Soft/Bright/Warm/Cool 维度 → Sci\ART（Kathryn Kalisz，基于 Munsell 色彩系统的 hue/value/chroma 三轴）派生 12/16 季型。
  - https://en.wikipedia.org/wiki/Color_analysis
  - https://getthecolorkey.com/2023/05/18/a-brief-history-of-color-analysis/
  - https://colormebeautiful.com/blogs/colormenow/the-ultimate-guide-to-color-analysis
  - https://www.colorpaletteanalysis.com/learn/seasonal-color-analysis-chart/ （12 季型对照表）
  - https://www.shapecolourstyle.co.uk/seasonal-colour-analysis （16 季型）
- **科学性注意**：Wikipedia 与批评文章均指出该体系缺乏严格科学证据、依赖分析师主观判断；作为产品应定位为「风格偏好工具」而非科学诊断，避免绝对化文案。
  - https://en.wikipedia.org/wiki/Color_analysis
  - https://www.ellaray.com/post/6-Reasons-Why-The-Seasonal-Analysis-Is-Not-Based-On-Science
- 落地先例：Style DNA 用一张自拍 35 秒判定 12 季型之一并给出个人色板，作为后续单品匹配（color/shape/print/fabric 四维评分）的基础。https://apps.apple.com/us/app/style-dna-ai-color-analysis/id1358319821

### 1.3 场合 Dress Code 公开权威来源

- **分类学骨架**：西方着装规范的规范化分类是 formal（full dress）/ semi-formal（black tie 属此档）/ informal（= business wear，女装对应 pant suit / cocktail dress）/ casual 四档；「business casual」「smart casual」是 informal 与 casual 之间的现代细分。Wikipedia「Western dress codes」词条是最完整的一手分类来源。
  - https://en.wikipedia.org/wiki/Western_dress_codes （检索摘要来自其镜像 https://en-academic.com/dic.nsf/enwiki/3414158 ）
- **Business casual / business formal 操作性定义**（女装）：Indeed Career Guide 与大学 career center 指南是可引用的稳定来源——business casual = 及膝裙/西裤/衬衫/针织衫/乐福鞋等，排除牛仔短裤短裙；business formal = 套装/铅笔裙+西装外套/闭趾鞋。
  - https://www.indeed.com/career-advice/starting-new-job/business-casual
  - https://www.indeed.com/career-advice/starting-new-job/guide-to-business-attire
  - https://gardner-webb.edu/student-life/career-development/interviews/business-attire-guide/
  - https://resources.twc.edu/articles/what-should-i-wear-to-work （通勤全档位）
- 工程化建议：把场合建模为**枚举 + 每档白/黑名单（单品类别、面料、露肤度、鞋型）+ 正式度分值区间**；「约会/宴会」等社交场合复用 cocktail / semi-formal 档。

### 1.4 体型穿搭规则

- 主流五分类：hourglass / pear / apple / rectangle / inverted triangle，判定依据肩-腰-臀围比例（本 App 已采集身体维度数据，可直接由数值判定）。
- 核心启发式：**制造视觉平衡**——pear 上重下简（A 字裙盖臀、上身亮色/细节）；apple 提高腰线（empire 线、V 领拉长）；rectangle 造腰线（收腰/腰带/peplum）；inverted triangle 下身加量感；hourglass 顺应曲线强调腰线。
  - https://theconceptwardrobe.com/build-a-wardrobe/pear-body-shape （the concept wardrobe 系列是该领域最系统的免费资料）
  - https://theconceptwardrobe.com/build-a-wardrobe/hourglass-body-shape
  - https://www.adriannapapell.com/blogs/style-guide/how-to-dress-for-your-body-shape
- 注意：多来源强调这是 styling tool 而非 rule，产品文案避免 body-shaming 表述（「平衡/强调」而非「遮盖缺点」）。

---

## 2. ML 层（outfit compatibility）

### 2.1 Polyvore 系经典工作

- **Bi-LSTM（Han et al., ACM MM 2017）**：把 outfit 当作有序序列，双向 LSTM 预测下一单品；定义了沿用至今的三大评测任务：FITB（fill-in-the-blank 补全）、compatibility prediction、outfit generation。Polyvore 数据集 21,889 套 outfit 开源。
  - https://arxiv.org/abs/1707.05691 ｜ https://github.com/xthan/polyvore-dataset
- **Type-aware embeddings（Vasileva et al., ECCV 2018）**：按「类别对」学习子空间嵌入，区分 similarity 与 compatibility 两种关系——**「相似」≠「相配」是该领域根本建模前提**。
  - https://arxiv.org/abs/1803.09196

### 2.2 图模型

- **NGNN（Cui et al., WWW 2019）**：类别为节点建 Fashion Graph，outfit 为子图，node-wise 消息传递学整体兼容度。https://arxiv.org/abs/1902.08009
- GNN/超图后继与对比实验：https://arxiv.org/abs/2404.18040 （NGNN vs HGNN 复现）；个性化+兼容度双目标的层次图注意力网络（2025）：https://arxiv.org/pdf/2508.11105

### 2.3 Transformer 与个性化

- **OutfitTransformer（Amazon, WACV 2023）**：outfit 视为无序集合，self-attention + outfit token，Polyvore compatibility AUC 0.95，支持「部分 outfit + 目标描述 → 检索互补单品」，是**互补单品检索**的代表作。
  - https://arxiv.org/abs/2204.04812 ｜ https://openaccess.thecvf.com/content/WACV2023/papers/Sarkar_OutfitTransformer_Learning_Outfit_Representations_for_Fashion_Recommendation_WACV_2023_paper.pdf ｜ 改进实现 https://github.com/owj0421/outfit-transformer
- **History-aware Transformers（2024）**：双 transformer 堆叠（outfit 表示 + 历史序列），用购买/穿着历史个性化 outfit 预测——「基于穿着历史的个性化」的直接参考。https://arxiv.org/pdf/2407.00289
- 早期个性化：FashionNet（用户偏好+兼容度联合建模）https://arxiv.org/abs/1810.02443
- 领域综述：Computational Technologies for Fashion Recommendation: A Survey. https://arxiv.org/pdf/2306.03395

### 2.4 CLIP embedding 路线（对本 App 最可落地）

- **FashionCLIP**（patrickjohncyh）：fashion 域微调 CLIP，图文同空间，零样本分类/检索。https://github.com/patrickjohncyh/fashion-clip
- **Marqo-FashionCLIP / FashionSigLIP**：宣称对 FashionCLIP 2.0 评测指标 +57%，开源权重，可商用检索。https://github.com/marqo-ai/marqo-FashionCLIP ｜ https://huggingface.co/Marqo/marqo-fashionCLIP
- OpenFashionCLIP（ICIAP 2023，纯开源数据训练）：https://github.com/aimagelab/open-fashion-clip
- **Loom（arXiv 2605.09830, 2026-05）**：与本 App 场景高度同构的混合架构——FashionCLIP embedding 做 slot 约束 ANN 检索 + 六信号结构化打分（embedding 相似度/色彩和谐/正式度一致/场合一致/风格方向/套内多样性）；「场合」用 prose 描述编码为 CLIP 锚向量做 occasion prior；620 件目录上 3 套 outfit 生成 <5 秒，比随机基线得分 3.3×、违规率 -42%。**证明「检索+规则打分」混合在小衣橱上无需训练即可工作**。https://arxiv.org/abs/2605.09830
- 关键判断：Polyvore 系监督模型训练于「时尚编辑精选套装」分布，与私人衣橱（旧衣、基础款、少量单品）分布差异大；直接迁移效果存疑。CLIP embedding + 规则打分不需要标注衣橱数据，更适合冷启动与端上小库。

### 2.5 基于交互的偏好学习

- 竞品实践：Acloset 用「接受推荐 / 标记不喜欢」信号在线更新偏好（accept/reject 反馈环）。https://www.acloset.app/magazine/ai-fashion-recommendations-separating-smart-picks-from-impu/
- 结合 wear log（穿着打卡）可得隐式正样本：被反复穿的组合 = 高置信兼容+偏好样本，可做轻量重排序（如对候选打分加用户偏好项），无需重型协同过滤（单用户衣橱无跨用户矩阵）。

---

## 3. LLM 层

### 3.1 「衣橱 JSON → 搭配 JSON」prompt 模式

- **OpenAI Cookbook 官方范例（Clothing Matchmaker）**：GPT-4o mini 视觉分析单品图 → 输出结构化 JSON（items 标题数组含 style/color/gender、category 枚举、gender 枚举）→ text-embedding-3-large 嵌入 + 余弦相似度（阈值 0.6）检索候选 → 第二次 GPT-4o mini 调用做 guardrail（看两张图回答 `{"answer":"yes/no","reason":...}`）。这是**「视觉打标 → 检索 → LLM 校验」三段式**的官方参考实现。
  - https://developers.openai.com/cookbook/examples/how_to_combine_gpt4o_with_rag_outfit_assistant
- 社区实践（RAG + 衣橱库存喂给 LLM 出搭配）：https://medium.com/@Behavior2020/automating-your-wardrobe-with-openai-the-power-of-rag-and-streamlit-753331514c40 ｜ https://towardsdatascience.com/using-gpt-4-for-personal-styling/
- 已知失败模式：整个衣橱塞进对话上下文会**遗忘条目、编造不存在的单品**（长对话尤甚）——须用「检索预筛候选集 + 严格 schema 输出 + ID 白名单校验」规避。https://towardsdatascience.com/what-my-gpt-stylist-taught-me-about-prompting-better-inside-the-strange-behavior-of-llms/

### 3.2 扫描入库的视觉打标（VLM）

- 开源参考：wardrobe（tandpfun，853+ stars）——OpenAI Responses API 检测照片内全部衣物 + Images API 抠图出干净商品图，JSON 库本地存储。https://github.com/tandpfun/wardrobe
- 精度基准（Fashion Florence, arXiv 2605.09827）：微调 Florence-2 结构化抽取 category 94.6% / material 63.0%，对比 GPT-4o-mini 89.3% / 43.3%、Gemini 2.5 Flash 87.4%——**通用 VLM 打标 category 可用、material 明显不可靠，需允许用户改标签**。https://arxiv.org/pdf/2605.09827
- 商用 API 兜底：Ximilar Fashion Tagging。https://www.ximilar.com/services/fashion-tagging/

### 3.3 结构化输出可靠性

- OpenAI Structured Outputs（2024-08 起）：strict JSON schema 约束解码，官方评测 schema 遵循 100%。https://openai.com/index/introducing-structured-outputs-in-the-api/
- Apple Foundation Models 的 guided generation（@Generable 宏）同样是约束解码，结构正确性有保证（见 3.5）。
- 结论：**「搭配方案 JSON」的格式可靠性已是解决了的问题**，风险集中在内容层（引用不存在的 item id）——用「候选集内选择 + 客户端校验」闭环。

### 3.4 成本与延迟（2026-07）

- 小模型价位（每百万 tokens，输入/输出）：GPT-4o mini $0.15/$0.60；Gemini 2.5 Flash $0.15/$0.60（Flash-Lite 更低）；Claude Haiku 4.5 $1/$5。
  - https://benchlm.ai/llm-pricing ｜ https://intuitionlabs.ai/articles/ai-api-pricing-comparison-grok-gemini-openai-claude
- 量级估算：候选集预筛后（~30 件候选 × ~60 tokens/件 + 上下文 ≈ 3–4k tokens 输入、~1k 输出），单次推荐 **≈$0.001–0.01**；瓶颈是延迟而非成本——云端完整生成 2–8s，TTFT <1s 需流式或先出骨架再补理由。
  - https://redis.io/blog/streaming-llm-responses/ ｜ https://www.kunalganglani.com/blog/llm-api-latency-benchmarks-2026
- 入库打标是一次性成本（每件 1 次 VLM 调用，GPT-4o mini 图像约 $0.003/张量级，见 Cookbook 定价段）。

### 3.5 端侧 LLM 能否胜任

- Apple Foundation Models（iOS 26）：~3B 参数端侧模型，2-bit 量化跑在 Neural Engine；**上下文窗口固定 4096 tokens**（iOS 26.4 加了 contextSize/tokenCount API）；擅长摘要/抽取/短对话，官方明示不适合复杂推理。
  - https://machinelearning.apple.com/research/apple-foundation-models-2025-updates
  - https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window
  - https://arxiv.org/pdf/2507.13575 （技术报告）
- 判断：4096 tokens 放不下整个衣橱（200 件 × 60 tokens ≈ 12k）。端侧可胜任的子任务：**从 ≤20 件预筛候选中组套并生成一句理由、标签归一化、搭配命名**；场合理解/多约束编排/高质量解释仍需云端小模型。guided generation 保证端侧输出 JSON 结构正确。
  - https://www.createwithswift.com/exploring-the-foundation-models-framework/

---

## 4. 上下文信号

### 4.1 天气驱动

- 通用算法模式：温度 → 分层逻辑（阈值触发外套/压制厚重面料）、降水概率 → 防水过滤、UV → 防晒配饰、风速/湿度修正体感；再叠加用户「怕冷/怕热」个人偏置。
  - https://www.alibaba.com/product-insights/ai-powered-wardrobe-organizers-do-they-suggest-outfits-based-on-weather-forecasts-or-just-push-sponsored-brands.html （典型四层架构拆解）
  - 学术：Weather-to-Garment（weather-oriented clothing recommendation）https://www.researchgate.net/publication/319569282_Weather-to-garment_Weather-oriented_clothing_recommendation
  - 实践：Cladwell 每日按天气出 3 套；Whering W Pick 纳入当日天气；WeatherFit 专做天气穿搭。https://cladwell.com/app ｜ https://weatherfit.com/
- 工程要点：天气是**过滤器/权重项**而非生成器——先按温区给每件单品标「适穿温区」（入库时由面料+类别推断），推荐时硬过滤。

### 4.2 日历 / 场合驱动

- Acloset：天气 + 日历日程集成驱动每日搭配。https://www.acloset.app/
- Alta：自然语言场合 prompt（"What do I wear to the F1 Miami race?"）→ 实时造型建议。https://www.businessoffashion.com/news/technology/ai-personal-shopping-tool-alta-raises-11-million/
- Loom 的 occasion priors 提供了非 LLM 实现：场合 prose → CLIP 锚向量 → 差分亲和度打分。https://arxiv.org/abs/2605.09830
- iOS 落地：EventKit 读日历事件标题 → LLM/关键词映射到 dress code 枚举（1.3 节）→ 规则层换档。

### 4.3 重复穿着与衣物利用率（capsule wardrobe 方法论）

- **Project 333**（Courtney Carver）：33 件（含鞋与配饰，除内衣/家居/运动）穿 3 个月，季度轮换；复盘时未穿单品即淘汰候选——「利用率驱动断舍离」的成熟方法论。https://bemorewithless.com/my-project-333-challenge/
- **Cost-per-wear**：Stylebook 的核心统计（单价 ÷ 穿着次数、most/least worn、衣橱总值），是 wear-log 类 App 的标杆实现。https://www.stylebookapp.com/features.html ｜ https://www.stylebookapp.com/stories/maximize_wears.html
- 「20% 的衣服被穿 80% 的时间」流传甚广但**无严格学术出处**（多为 Pareto 原则的挪用与商业调查），产品引用需谨慎措辞。https://www.forbes.com/sites/oliviaobryon/2022/05/01/pareto-is-perfecting-the-20-of-clothing-women-actually-wear/
- 推荐引擎接入方式：wear log 驱动两个目标——①「冷落单品复活」（把低利用率单品组进新搭配）②重复度控制（近 N 天穿过的组合降权）。Cladwell 的 style profile（最常穿颜色/单品/衣橱利用率）是参考实现。https://thelaurieloo.com/blog/cladwell-review

---

## 5. 冷启动策略（衣橱条目很少时）

公开可查的策略组合（通用推荐系统 + 衣橱 App 实证）：

1. **规则层零数据兜底**：色彩/场合/体型/天气规则不依赖任何历史数据，条目再少也能给出「能穿且合规」的组合——规则层前置是衣橱 App 冷启动的结构性答案。
2. **Onboarding 风格问卷**（显式偏好采集）：Spotify 模式移植；注意问题过多导致流失，控制在 3–5 题（风格词/常用场合/怕冷怕热/禁忌色）。https://gopractice.io/product/how-to-solve-the-cold-start-problem-in-an-ml-recommendation-system/ ｜ https://www.freecodecamp.org/news/cold-start-problem-in-recommender-systems/
3. **预置 capsule 模板**：Cladwell 让用户从 30+ 预建 capsule 衣橱起步、再用实拍替换同类占位项——既解决空衣橱推荐无米之炊，又引导补拍入库。https://cladwell.com/app
4. **锚点单品补全（FITB 模式）**：条目少时改变交互——不做「全套推荐」而做「你今天想穿这件，我帮你配」，检索互补项（OutfitTransformer / Loom 的互补检索任务形态），少量单品即可工作。
5. **缺口购物建议**（可选变现）：衣橱不足以成套时提示缺口品类（Indyx/Style DNA/Alta 均有此机制），但需与「用好现有衣橱」的产品价值观权衡。
6. **渐进个性化**：上线即收 accept/reject 与 wear log，个性化层在数据足够前保持关闭（先规则+embedding，后加偏好重排）。https://baotramduong.medium.com/recommender-system-the-cold-start-problem-strategies-to-address-it-bddb177e723c

---

## 6. 竞品推荐机制对照（公开信息）

| 竞品 | 推荐机制 | 关键公开信息 | 来源 |
|---|---|---|---|
| **Whering**（英国） | Shuffle 随机 + 筛选（Dress Me）；W Pick（Beta）AI 生成、纳入天气、随点按迭代学习 | 主打可持续/复穿，从已有衣橱出发 | https://whering.co.uk/outfit-maker-apps ｜ https://stylewithingrace.com/whering-wardrobe-app-review/ |
| **Indyx**（美国） | **人工造型师**：订阅 The Feed（$25/月起，真人每周出搭配）、Lookbook（3/10 套） | 刻意不做算法推荐，人是卖点 | https://www.myindyx.com/how-it-works |
| **Stylebook**（老牌 iOS） | 无 AI 推荐；手动拼搭 + Outfit Shuffle + 日历计划 + cost-per-wear 统计 | 一次性买断，90+ 功能，数据统计最强 | https://www.stylebookapp.com/features.html |
| **Cladwell** | 每日按天气算法出 3 套；预建 capsule 模板冷启动；近年接入 ChatGPT 插件仿真人造型 | style profile 统计利用率 | https://cladwell.com/app ｜ https://thelaurieloo.com/blog/cladwell-review |
| **Acloset**（韩国 Looko） | ML 匹配（色彩理论+趋势+季节+场合）+ 个人色彩/体型诊断 + 天气&日历驱动每日推荐 + accept/reject 在线学习 | 与本 App 功能面最接近的竞品 | https://www.acloset.app/ ｜ https://play.google.com/store/apps/details?id=com.looko.acloset |
| **Style DNA** | 自拍 35 秒 → 12 季型色彩分析 → 个人色板 + 体型 → 单品四维匹配评分（color/shape/print/fabric）+ 生成式搭配 | 300 万用户；2024 TechCrunch 报道转向 GenAI | https://apps.apple.com/us/app/style-dna-ai-color-analysis/id1358319821 ｜ https://techcrunch.com/2024/06/21/style-dna-generative-ai-fashion-stylist-app |
| **Alta**（美国，2023 创立） | 十余个自训 fashion GenAI 模型 + transformer 推荐；场合 prompt 实时造型；真人感 avatar 试穿 | 2025 年 $11M 种子轮（Menlo/Aglaé） | https://fashionunited.com/news/business/alta-raises-11-million-in-seed-funding-for-ai-powered-personal-shopping-styling-app/2025061766632 |
| **中国区**（搭搭 / 爱搭衣橱 / Outfity） | AI 批量抠图入库 + 自动识别分类/颜色/季节/材质；按天气温度推 OOTD；AI 试衣 | 「搭搭」自称 200 万用户；标签含存放位置——与本 App 标签系统同构 | https://apps.apple.com/ai/app/id1616484963 ｜ https://apps.apple.com/cn/app/id6747186089 ｜ https://apps.apple.com/cn/app/id6745757612 |

格局判断：数据统计型（Stylebook）→ 规则+天气型（Cladwell/Whering）→ ML+诊断型（Acloset/Style DNA）→ LLM/GenAI 型（Alta，重资本）逐代演进；**真人造型师（Indyx）作为差异化路线存在**。「个人色彩+体型诊断+天气日历+衣橱推荐」的组合已被 Acloset/Style DNA 验证为可行产品形态。

---

## 7. 对本 App 的架构启示

1. **三层流水线**：候选生成（规则硬过滤：场合档位/温区/干净度）→ 兼容度打分（Marqo-FashionCLIP embedding 相似+互补 + Loom 式六信号规则打分）→ LLM 编排层（云端小模型，输入预筛候选 JSON，输出带 item id 引用与理由的搭配 JSON，strict schema + id 白名单校验）。
2. **入库打标**：VLM（GPT-4o mini 级）出 category/color/style 基本可靠，material 不可靠——打标结果必须可编辑；embedding 入库时一并计算存本地。
3. **个人色彩与体型作为打分项而非硬规则**：季型色板 → 色彩打分加权；身体维度 → 五分类体型 → 剪裁偏好加权；文案避免绝对化（科学性争议）。
4. **冷启动**：规则层 + 3–5 题问卷 + 「锚点单品补全」交互；衣橱 <N 件时不开全套推荐。
5. **上下文**：WeatherKit 温区过滤 + EventKit 日程 → dress code 档位；wear log 驱动 cost-per-wear 统计、冷落单品复活与近期重复降权——与「收藏搭配」「标签（存放位置/特殊需求）」共同构成个性化数据底座。
6. **端侧/云端分工**：Apple FM（3B/4096 tokens）只做候选内组套、标签归一、短理由生成；场合理解与高质量解释走云端 GPT-4o mini / Gemini Flash 级（单次 ≈$0.001–0.01，延迟 2–8s 需流式）。
