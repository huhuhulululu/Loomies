# 调研 04：身体维度数据 → 近似体型 → 着装可视化

> 调研日期：2026-07-21。背景：面向女性/职业多场合的 iOS 数字衣橱 App，需从少量身体维度（身高体重胸腰臀等）生成近似体型并做着装可视化。

---

## 1. 参数化人体模型（SMPL 家族）

### 1.1 模型概览

| 模型 | 特点 | 学术下载 |
|------|------|---------|
| SMPL | 6890 顶点 + 10~300 shape betas，事实标准 | https://smpl.is.tue.mpg.de/ |
| SMPL-X | SMPL + 手（MANO）+ 脸表情，10475 顶点 | https://smpl-x.is.tue.mpg.de/ |
| STAR | SMPL 改进版（稀疏局部化 blendshape，参数量小） | https://star.is.tue.mpg.de/ |

### 1.2 从少量维度回归体型参数（betas）的路径

- **SHAPY（CVPR 2022，MPI 官方）**：其 **A2S（Attributes-to-Shape）** 模型显式支持「身高 + 体重 + 胸/腰/臀围（可加语言属性词）→ SMPL-X betas」，也有反向 S2A。是学术界最正式的「维度→betas」实现。License：非商用科研；商用需联系 ps-licensing@tue.mpg.de。
  https://github.com/muelea/shapy
- **SMPL-Anthropometry（DavidBoja）**：**正向**测量库——给定 betas 输出 16 项标准围度/长度（胸腰臀、身高、臂长腿长等），MIT 许可（但依赖需另行下载的 SMPL/SMPL-X 模型文件）。可用于自建逆向回归：SMPL 测量值对 betas 近似线性，采样 betas→测量值后做最小二乘/岭回归求逆即可（社区常见做法）。
  https://github.com/DavidBoja/SMPL-Anthropometry
- **body-measurement-to-smpl-beta**：直接演示「常见身体测量 → SMPL-X betas」的小型开源项目（质量一般，可作参考实现）。
  https://github.com/tharuneshwar-s/body-measurement-to-smpl-beta
- **FlexiSMPL**：23 项人体测量滑杆实时驱动 SMPL 形状的交互框架。 https://taneemishere.github.io/flexismpl/
- **pose-independent-anthropometry（ECCV24 wksp）**：从稀疏数据做姿态无关人体测量。 https://github.com/DavidBoja/pose-independent-anthropometry
- **Meshcapade Me API（商用正路）**：REST API，支持从**测量值**、图片、视频、扫描创建 SMPL avatar，官方称胸腰臀精度 1–3cm；商用许可随 Premium 订阅解锁。
  https://medium.com/meshcapade/streamline-avatar-creation-with-meshcapade-me-api-from-one-image-to-an-accurate-avatar-in-seconds-b8ca4f15b9a8 ；C# SDK：https://github.com/tryAGI/Meshcapade

### 1.3 许可证（商用红线）⚠️

- **SMPL / SMPL-X / STAR 模型文件默认许可均为「仅限非商业科研/教育/艺术」**，明文禁止并入商业产品或商业服务：
  - SMPL: https://smpl.is.tue.mpg.de/modellicense.html
  - SMPL-X: https://smpl-x.is.tue.mpg.de/modellicense.html （另禁色情/军事/监控用途）
  - STAR: https://star.is.tue.mpg.de/license.html
- **商用唯一渠道是 Meshcapade（MPI 独家商业授权方）**，sales@meshcapade.com；商用授权含 SMPL+H / SMPL-X / STAR 全部成人变体。 https://meshcapade.com/infopages/licensing.html ；https://github.com/Meshcapade/wiki/blob/main/wiki/SMPL.md
- 周边仓库许可各异：SMPL-Anthropometry 代码 MIT，但**代码 MIT ≠ 模型文件可商用**；SHAPY 非商用。上架 App Store 属商用，**任何内嵌 SMPL 家族模型文件的方案都必须先拿 Meshcapade 商业授权**（或改用其 API，把模型留在云端由其托管授权）。

---

## 2. 商用 body scanning / 虚拟形象 SDK

### 2.1 3DLOOK（美国，公开定价）

两条产品线，按扫描量订阅（https://3dlook.ai/pricing/ ，2026-07 查证）：

| 产品 | 档位 | 价格 | 额度 |
|------|------|------|------|
| Mobile Tailor（量体） | Basic | $499/月 | 100 scans/月，80+ 测量项、CSV 导出、3D 模型导出、网页 widget |
| | Premium | $999/月 | 500 scans/月，+widget 定制/通知/模板 |
| | Enterprise | 定制 | 500+，API + 专属支持 |
| FitXpress（体成分） | Starter | $1,000/月 | 500 scans/月，BMI/体脂等 |
| | Pro | $1,500/月 | 1,000 scans/月，+3D 进度跟踪 |
| | Personalized | 定制 | SDK 多语言、专属支持 |

两张照片（正/侧）出 80+ 测量项；主打 B2B 服装电商 fit 场景。

### 2.2 Bodygram（日本，B2B 报价制）

- 平台：正面+侧面照片 + 身高体重年龄性别，<1 分钟出 **3D avatar + 至多 35 项 ISO 8559 兼容测量**。 https://www.bodygram.com/en/platform
- 开发者产品：Body2Fit（widget/headless SDK/API）、Body Scanner（widget/API）、Estimation API；旧文档站 developers.bodygram.com 已标记 deprecated，迁往 docs.bodygram.com。 https://developers.bodygram.com/
- **定价不公开**，B2B contact-sales 模式。

### 2.3 其他

- **Meshcapade**：见 1.2，既是 SMPL 授权方又提供 avatar API，是「维度→3D 体型」最顺的商用一站式。
- **Mirrorsize GetMeasured** 等同类量体 API 存在（https://www.mirrorsize.com/ms-getmeasured-body-measurement ），格局类似：照片量体、B2B 报价。
- 共同点：按扫描量计费、面向服装电商退货率场景；对**只需「近似体型可视化」而非毫米级量体**的本 App，采购这类 SDK 性价比低。

---

## 3. 体型分类学：可计算判定规则

### 3.1 权威出处：FFIT（Female Figure Identification Technique）

- 原始体系：Simmons, Istook & Devarajan (2004)，NC State 开发的 3D 扫描体型分类软件，9 类：Hourglass、Top/Bottom Hourglass、Spoon、Rectangle、Diamond、Oval、Triangle、Inverted Triangle（JTATM Vol.4 No.1, part I & II）。
- 数学公式化：Lee, Istook, Nam & Park (2007)，SizeUSA/SizeKorea 对比研究给出可执行公式。 https://doi.org/10.1108/09556220710819555
- 完整公式表转引自 Sokolowski & Bettencourt (2020) 3DBODY.TECH 论文（含 plus-size 修正），**已逐页核对 PDF 原文**： https://proc.3dbody.tech/papers/2020/2022sokolowski.pdf （DOI 10.15221/20.22）

**原始 FFIT 公式（单位英寸；bust=胸围, waist=腰围, hip=臀围, high hip=上臀围）：**

| 体型 | 判定条件（按顺序判定） |
|------|------|
| Hourglass 沙漏 | (bust−hip) ≤ 1 且 (hip−bust) < 3.6，且 [(bust−waist) ≥ 9 或 (hip−waist) ≥ 10] |
| Bottom Hourglass 下沙漏 | (hip−bust) ≥ 3.6 且 (hip−bust) < 10，且 (hip−waist) ≥ 9，且 (high hip/waist) < 1.193 |
| Top Hourglass 上沙漏 | (bust−hip) > 1 且 (bust−hip) < 10，且 (bust−waist) ≥ 9 |
| Spoon 勺形 | (hip−bust) > 2，且 (hip−waist) ≥ 7，且 (high hip/waist) ≥ 1.193 |
| Triangle 三角（梨） | (hip−bust) ≥ 3.6，且 (hip−waist) < 9 |
| Inverted Triangle 倒三角 | (bust−hip) ≥ 3.6，且 (bust−waist) < 9 |
| Rectangle 矩形 | (hip−bust) < 3.6 且 (bust−hip) < 3.6，且 (bust−waist) < 9 且 (hip−waist) < 10 |

**Plus-size 修正公式（Sokolowski & Bettencourt 2020, Table 9）**——原公式隐含「腰总小于胸臀」假设，大码体型会被误分类；修正为：

| 体型 | 修正条件 |
|------|------|
| Hourglass / Bottom / Top Hourglass / Spoon | 不变 |
| Triangle | (hip−bust) ≥ 3.6，且 [0 ≤ (hip−waist) < 9，或 (bust−waist) < 0 且 (hip−waist) ≥ 0] |
| Inverted Triangle | (bust−hip) ≥ 3.6，且 (bust−waist) < 9，且 (hip−waist) ≥ 0 |
| Rectangle | (hip−bust) < 3.6 且 (bust−hip) < 3.6，且 0 ≤ (bust−waist) < 9 且 0 ≤ (hip−waist) < 10 |
| Diamond 菱形 | (hip−waist) < 0 且 (bust−waist) < 0 |
| Oval 椭圆（苹果） | (hip−waist) < 0 且 (bust−waist) ≥ 0 |

判定输入只需 **胸围、腰围、臀围、上臀围** 四项（Diamond/Oval 用差值符号判定，不再需要腹围）。大众 5 类与 FFIT 映射：梨形≈Triangle/Spoon/Bottom Hourglass；苹果≈Oval/Diamond；其余同名。消费级计算器（如 https://www.omnicalculator.com/health/body-shape ，引 Lee 2007）也采用同源规则，可作交叉验证。

### 3.2 各体型穿搭扬长避短（行业共识 + 学术补充）

学术侧：Kostogryz (2026, European Journal of Interdisciplinary Issues 3(1):99-112) 把各体型的修正策略归因于视错觉机制（Helmholtz、Müller-Lyer、格式塔分组），并提出「保真度（authenticity）」评估维度—— https://www.eujini.org.pl/index.php/journal/article/view/81 。具体条目主要来自造型行业共识（the concept wardrobe、Adrianna Papell 等风格指南；无单一权威标准，规则引擎应设计为可配置）：

| 体型 | 扬长 | 避短 |
|------|------|------|
| 沙漏 | 强调腰线：wrap 裙、腰带、高腰、修身剪裁 | oversize 直筒掩盖腰线 |
| 梨形（Triangle/Spoon） | 视线上移：结构化/亮色上装、船领、off-shoulder、A 字裙、深色下装 | 紧身下装、低腰裤、下半身亮色大印花 |
| 苹果（Oval/Diamond） | V 领拉长、empire 高腰线、wrap、垂坠面料、露腿 | 腰部堆积装饰、紧身中段、高领+硬挺厚面料 |
| 矩形 | 制造曲线：peplum、腰带收腰、分层、印花增体积 | 无腰身直筒连衣裙 |
| 倒三角 | 弱化肩部：V 领/U 领、A 字裙、阔腿裤、下装亮色 | 垫肩、一字肩、肩部荷叶边等细节 |

来源示例：https://theconceptwardrobe.com/build-a-wardrobe/apple-body-shape ；https://www.adriannapapell.com/blogs/style-guide/how-to-dress-for-your-body-shape

---

## 4. 呈现层级对比（成本 / 效果 / 算力 / 隐私）

| 层级 | 代表 | 实现成本 | 效果 | 算力 | 隐私风险 |
|------|------|---------|------|------|---------|
| ① 2D 平铺拼贴 | Stylebook、Indyx（人工/AI 抠图 + 网格拼贴） | 极低（iOS 16+ VisionKit 抠图端上免费） | 表达「搭配构成」，不表达「上身效果」 | 零 | 零（无身体数据） |
| ② 分层纸娃娃 | croquis 底图 + 服装分层贴放 | 低-中：按体型分类做 5–9 款 croquis 模板，衣服图带锚点缩放 | 示意级「上身效果」，风格化可控 | 零（纯本地渲染） | 低（只需维度数字，本地） |
| ③ 3D avatar 换装 | SMPL avatar + 3D 服装 | 高：SMPL 商用授权 + **每件衣服需 3D 资产**（用户任意衣服 2D→3D 仍是未解难题）+ 布料模拟 | 体型还原真实，但服装覆盖率是死穴 | 端上可渲染（RealityKit），模拟吃性能 | 中（3D 体型数据） |
| ④ AI 生成式试穿 | TryOnDiffusion 系、Doji、Google Doppl/Vertex VTO、FASHN | 中（调 API）/ 极高（自训） | 最真实（垂坠、褶皱、光影） | 云 GPU；API $0.02–0.08/图 | **最高**：全身照上传云端 |

### ④ 生成式试穿的关键事实

- **TryOnDiffusion**（Google, CVPR 2023, Parallel-UNet）未开源官方权重；生态见 https://github.com/minar09/awesome-virtual-try-on
- **Google Vertex AI Virtual Try-On**：模型 `virtual-try-on-001` 已 **GA（2026-01-20）**，输入人像+服装图（PNG/JPEG ≤10MB），单次最多 4 图，含 SynthID 水印；配额 50 req/min。 https://docs.cloud.google.com/vertex-ai/generative-ai/docs/models/imagen/virtual-try-on-preview-08-04
- **Google Doppl**：Google Labs 实验 App（2025-06-26 上线，美区 iOS/Android），上传全身照试穿任意截图衣服并生成动态视频；2025-12 起仅需自拍。 https://blog.google/innovation-and-ai/models-and-research/google-labs/doppl/ ；https://techcrunch.com/2025/12/11/googles-ai-try-on-feature-for-clothes-now-works-with-just-a-selfie/
- **Doji**：2025-05 上线即获 Thrive 领投 $14M 种子轮，自研扩散模型、selfie+全身照建 avatar，invite-only，80+ 国。 https://techcrunch.com/2025/05/15/doji-raises-14m-to-make-virtual-try-ons-fun-through-ai-avatars
- **商用 API 价格锚点**：FASHN $0.075/图（量大 <$0.04），864×1296。 https://help.fashn.ai/plans-and-pricing/api-pricing ；https://fashn.ai/blog/pricing-update-for-developer-api
- **开源模型许可陷阱**：IDM-VTON、CatVTON、OOTDiffusion、StableVITON、VITON-HD 等主流开源 VTON 多为 **CC BY-NC（禁商用）**；例外 **Leffa（MIT）**。CatVTON 可在 <8GB VRAM 跑 1024×768（约 35s/图）；自托管对标 API 吞吐需 24GB GPU，云成本约 $200–700/月。 https://fashn.ai/blog/comparing-the-top-4-open-source-virtual-try-on-viton-models ；https://fitroom.app/blog/open-source-vton-models-vs-managed-apis/ ；https://github.com/yisol/IDM-VTON
- 数字衣橱竞品现状：Stylebook/Indyx 停留在①；Acloset/Aesty 已加 AI 试穿（④）作付费点。 https://www.myindyx.com/versus/indyx-vs-stylebook ；https://www.nouva.app/blog/best-wardrobe-apps-2026-comparison

---

## 5. 身体数据的隐私合规（App Store）

### 5.1 App Store 审核指南 5.1.3（Health and Health Research）

https://developer.apple.com/app-store/review/guidelines/#health-and-health-research 要点：

- 健康/健身/医学研究语境收集的数据（HealthKit、Clinical Health Records、Motion & Fitness 等）**不得用于广告、营销或其他 use-based data mining**；
- 不得向 HealthKit 写入虚假数据；**不得把个人健康信息存入 iCloud**；
- 涉及健康测量的**准确性声明必须能证明方法学**，否则被拒（如仅凭传感器测血压类 App 直接禁止）。

### 5.2 是否触及「健康数据」类目？

- 隐私标签（App Privacy Details）中 **Health** 的定义：「健康与医疗数据，包括但不限于 HealthKit API……**或任何其他用户提供的健康或医疗数据**」。 https://developer.apple.com/app-store/app-privacy-details/
- **判断**：胸腰臀等维度**仅用于服装尺码/体型可视化**时，属边界灰区——不是医疗数据，但「用户提供的身体数据」定义宽泛。实务上：(a) **不接 HealthKit** 就不自动落入 5.1.3 的 API 触发面（HealthKit 本身有 height/bodyMass/waistCircumference 类型，接入即触发义务，见 https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/waistcircumference ）；(b) 隐私标签保守申报（Health & Fitness 或 Other Data Types），并确保**不用于广告/不共享第三方**；(c) 若日后加体重跟踪/健康趋势功能，即明确进入健康类目监管。
- 全身照片（若做 AI 试穿）按 **User Content › Photos** 申报；上传云端处理必须在 UI 明示并给出保留/删除策略。
- GDPR 参考：身体测量数据只有在「用于唯一识别自然人」时才构成 Art. 9 特殊类别生物识别数据（Art. 4(14)）；尺码用途通常不构成，但全身照+人脸涉及肖像，出海欧盟需 DPIA 评估（https://eur-lex.europa.eu/eli/reg/2016/679/oj ）。

### 5.3 隐私风险梯度（对应第 4 节层级）

维度数字本地存（②）≈ 零风险 → 3D 体型参数本地（③）低风险 → 全身照上传云端生成（④）高风险：需隐私标签申报、数据出境评估、供应商 DPA、明示同意与删除机制。

---

## 6. 对本 App 的落地建议（摘要）

1. **MVP 走「②分层纸娃娃 + FFIT 判定」**：四项围度（胸/腰/臀/上臀）本地判 9 类（大众化展示可折叠为 5 类），选对应 croquis 模板 + 按身高体重微调轮廓，零云端、零授权费、隐私最优。
2. **FFIT 公式直接实现为纯函数**（英寸阈值 1 / 3.6 / 9 / 10 / 2 / 7 / 1.193），采用 2020 plus-size 修正版以覆盖大码用户（目标人群女性、体型多样，原版会把大腹围误判为矩形/倒三角）。
3. **穿搭规则引擎按「体型×单品属性」二维表建模**，规则可配置可解释（附「为什么推荐」），避免硬编码单一流派。
4. **3D 路线若启用，选 Meshcapade API 而非自嵌 SMPL**：绕开模型文件商用授权+维度→betas 自研两个坑；但 3D 服装资产覆盖率是死穴，不建议作为衣橱主视图。
5. **AI 试穿作为后期付费增值**：接 FASHN（$0.075/图）或 Vertex `virtual-try-on-001`（已 GA）；禁用 CC BY-NC 开源模型于商用；全身照功能上线前先完成隐私标签、明示同意与删除链路。
6. **合规姿势**：不接 HealthKit、维度数据只存本地（或端到端加密同步）、不用于广告、隐私标签保守申报——即可把审核风险压到最低。

---
🟡 **置信度** 🟡: 82% — FFIT 公式逐页核对论文 PDF 原文、定价/许可来自官网一手页面；SHAPY/开源 VTON 许可与 GPU 数字来自 GitHub 与厂商博客交叉引用未逐仓核验；Apple「身体维度是否必然算 Health 数据」为基于官方定义的推断，无判例级来源。
