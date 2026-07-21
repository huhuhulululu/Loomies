# iOS 原生技术栈调研（截至 2026-07）

> 调研日期：2026-07-21。背景：面向女性/多场合的数字衣橱 App（扫描入库、搭配推荐与收藏、标签系统、体型近似与着装可视化）。
> 时间坐标：iOS 26 已发布近一年（2025-09）；WWDC 2026（6 月）已发布 iOS 27 开发者 beta，公测版 2026-07-13 上线，正式版预计 2026-09-14 前后随 iPhone 18 Pro 发布（[Forbes](https://www.forbes.com/sites/davidphelan/2026/07/13/apple-ios-27-release-date-when-you-can-install-iphones-new-software---public-beta-near/)、[9to5Mac](https://9to5mac.com/2026/07/02/ios-27-public-beta-release-date-when-you-can-install-the-new-iphone-update/)、[MacRumors](https://www.macrumors.com/2026/07/12/ios-27-public-beta-release-date-timing/)）。

---

## 1. 扫描入库（主体抠图 + 连拍相机）

### 1.1 VisionKit 主体抠图（带 UI 交互）
- **iOS 16** 引入 subject lifting 用户交互（`ImageAnalysisInteraction`，`.automatic` 含主体抠图/Live Text/数据检测）；**iOS 17** 新增 `.imageSubject` 交互类型（只要抠图、不要文本交互）和**程序化 API**：`ImageAnalysisInteraction.Subject`（`subjects`、`highlightedSubjects`、`image(for:)`）可直接拿到抠出的主体图像。来源：[WWDC23 Session 10176](https://developer.apple.com/videos/play/wwdc2023/10176/)、[Subject 文档](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/subject)。
- 设备要求：Live Text/分析类能力需 **A12 Bionic 及以上**（[WWDC 资料](https://developer.apple.com/videos/play/wwdc2023/10176/)）。

### 1.2 Vision 前景实例分割（无 UI、批量管线首选）
- `VNGenerateForegroundInstanceMaskRequest`：**iOS 17+ / macOS 14+**，类无关（class-agnostic）前景实例软掩膜，正是 Photos 长按抠图的同款能力；输出与原图同分辨率的 soft mask，可生成带 alpha 的抠图。来源：[Apple 文档](https://developer.apple.com/documentation/vision/vngenerateforegroundinstancemaskrequest)、[Create with Swift 教程](https://www.createwithswift.com/removing-image-background-using-the-vision-framework/)。
- **iOS 18** 起有新 Swift 并发风格 API `GenerateForegroundInstanceMaskRequest`（[文档](https://developer.apple.com/documentation/vision/generateforegroundinstancemaskrequest)）。
- ⚠️ 该请求**不支持 CPU、模拟器不可用**（"Could not create inference context"），需真机 GPU/ANE（[开发者论坛](https://developer.apple.com/forums/thread/764948)）——影响测试策略。

### 1.3 连拍批量入库相机
- 基础：`AVCapturePhotoOutput`。**iOS 17** 一组"快拍"特性直接服务连续拍摄场景：
  - **Zero Shutter Lag**（`isZeroShutterLagEnabled`，支持机型默认开）消除快门延迟（[文档](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/iszeroshutterlagsupported)）；
  - **Responsive Capture**（`isResponsiveCaptureEnabled`）让上一张还在处理时即可拍下一张；
  - **Fast Capture Prioritization**：检测到快速连拍时自动把质量从 quality 降到 balanced，保证节奏；
  - **Deferred Photo Processing**：把重处理推迟到拍摄间隙。来源：[iOS 17/18 相机 API 综述](https://zoewave.medium.com/ios-18-17-new-camera-apis-645f7a1e54e8)、[QualityPrioritization 文档](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/qualityprioritization)。
- WWDC26 有高分辨率拍摄新 session（[WWDC26 304](https://developer.apple.com/videos/play/wwdc2026/304/)），属增强非必需。
- 结论：**「取景连拍 → 队列后台跑前景分割 → 逐件确认」的批量入库流水线在 iOS 17+ 完全原生可行**。

## 2. 识别与分类

### 2.1 Vision 内置分类
- `VNClassifyImageRequest`（iOS 13+）：内置通用 taxonomy 共 **1303 个类别**；iOS 18 起有 Swift 并发新 API `ClassifyImageRequest`。来源：[Create with Swift](https://www.createwithswift.com/classifying-image-content-with-the-vision-framework/)、[WWDC24 Vision Swift API 解读](https://medium.com/kkdaytech/ios-vision-framework-x-wwdc-24-discover-swift-enhancements-in-the-vision-framework-session-755509180ca8)。
- 判断：通用 taxonomy 可辨"clothing/dress/coat"级粗类，但**细粒度服装属性（袖型、领型、面料、正式度）不在内置能力内**→ 需自定义模型或 LLM 视觉。分类请求同样不支持模拟器。

### 2.2 Core ML + coremltools（部署第三方模型）
- **coremltools 9.0**（2025-11-10）：Python 3.13、**PyTorch 2.7 / ExecuTorch 0.5**、新增 iOS26/macOS26 部署目标、int8 输入输出、模型 state 读写；8.x 已有 stateful models、`torch.export` 转换（beta）、4-bit 量化/3-bit palettization/blockwise 量化。来源：[GitHub Releases](https://github.com/apple/coremltools/releases)。
- 工具链健康、活跃维护。部署开源服装识别模型（如 fashion attribute 模型）转 Core ML 路线可行。
- **WWDC 2026 新变量：Core AI framework**——Core ML 的"官方后继"，两者共存：Apple 定位 Core ML 继续服务经典 ML，**Core AI 服务神经网络/transformer**（AOT 编译、专用 Instruments、Python 转换工具，支持 3B 视觉模型到 70B 推理 LLM，量化/palettization）。来源：[InfoQ](https://www.infoq.com/news/2026/06/apple-core-ai-wwdc/)、[AppleInsider](https://appleinsider.com/articles/26/03/01/wwdc-2026-to-introduce-core-ai-as-replacement-for-core-ml)、[Apple ML What's New](https://developer.apple.com/machine-learning/whats-new/)。属 iOS 27 世代，中期可迁移，不影响当前选型。

### 2.3 Create ML 自训
- Create ML app（macOS）训练图像分类器成熟（[官方教程](https://developer.apple.com/documentation/createml/creating-an-image-classifier-model)）；**Create ML framework iOS 15+ 支持设备端训练**（图像分类、风格迁移等，保数据隐私）（[WWDC21 10037](https://developer.apple.com/videos/play/wwdc2021/10037/)、[Create ML 主页](https://developer.apple.com/machine-learning/create-ml)）。
- 判断：用几百张标注图自训「衣物类目/颜色」小分类器可行且成本低；细粒度属性建议「内置分类粗筛 + FM 视觉（iOS 27）或自训模型精标 + 用户确认」三层兜底。

## 3. Apple Intelligence / Foundation Models framework（端侧 LLM）

### 3.1 iOS 26 基线（当前可用）
- **Foundation Models framework：iOS 26 / macOS 26 / iPadOS 26 / visionOS 26 起**，Swift API 直连 Apple Intelligence 端侧 **~3B 参数模型**。核心能力：**guided generation（`@Generable` 宏 → 约束解码直接产出 Swift 结构体，结构化输出原生支持）**、tool calling、streaming、`LanguageModelSession` 多轮上下文。全端侧、数据不出设备。来源：[WWDC25 286](https://developer.apple.com/videos/play/wwdc2025/286/)、[WWDC25 301](https://developer.apple.com/videos/play/wwdc2025/301/)、[Apple ML Research 2025](https://machinelearning.apple.com/research/apple-foundation-models-2025-updates)。
- **上下文窗口固定 4096 tokens**（输入+输出共享），超限抛 `exceededContextWindowSize`；iOS 26.4 增加了查询上下文大小与 token 计数 API。来源：[TN3193 官方技术笔记](https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window)、[论坛](https://developer.apple.com/forums/thread/790736)。
- **可用性检查**：`SystemLanguageModel.availability` 三种不可用原因——`deviceNotEligible`（永久，隐藏功能）/ `appleIntelligenceNotEnabled`（引导开启）/ `modelNotReady`（重试）。来源：[fallback 实践](https://dev.to/arshtechpro/how-to-fall-back-gracefully-when-apple-intelligence-isnt-available-48j)、[AppCoda](https://www.appcoda.com/foundation-models/)。
- **硬件门槛 = Apple Intelligence 门槛：iPhone 15 Pro / 15 Pro Max、iPhone 16 全系及之后（A17 Pro+，≥8GB RAM）**；支持语言含**简体/繁体中文**、英、日、韩等 16+ 种。来源：[Apple Support 121115](https://support.apple.com/en-us/121115)、[Apple Newsroom 2026-06](https://www.apple.com/newsroom/2026/06/apple-intelligence-brings-powerful-ai-capabilities-into-everyday-experiences/)。
- 判断：**搭配推荐理由生成、标签/场合文本理解、结构化搭配输出（@Generable）在 iOS 26 即可落地**；但 4096 token 限制意味着"衣橱全量塞 prompt"不可行——需先用规则/检索筛出候选单品再交给模型。

### 3.2 iOS 27 增量（2026-09 正式发布）
来源：[WWDC26 241 "What's new in the Foundation Models framework"](https://developer.apple.com/videos/play/wwdc2026/241/)、[MacRumors SOTU](https://www.macrumors.com/2026/06/09/apple-outlines-major-ai-and-developer-tool-updates/)、[byteiota](https://byteiota.com/apple-foundation-models-wwdc-2026-multimodal-python-sdk/)、[DEV](https://dev.to/arshtechpro/wwdc-2026-apple-just-opened-the-foundation-models-framework-to-any-llm-provider-5ejn)：
- **端侧模型图像输入（vision）**：接受 UIImage/CGImage/CVPixelBuffer/文件 URL，任意尺寸比例。⚠️ 图像能力需新一代模型（AFM 3 Core Advanced，20B 稀疏 MoE、每次激活 1-4B），**仅 iPhone 15 Pro 及以上等高端硬件**；旧设备维持纯文本。
- **`PrivateCloudComputeLanguageModel`**：PCC 云端模型，**32k token 上下文**、`reasoningLevel` 推理档位、免鉴权免 API key；**首次下载量 <200 万的开发者免费**。
- **`LanguageModel` protocol**：本地/云端/第三方（Claude、Gemini）模型统一接口，`LanguageModelSession` 代码不变换模型。
- 其他：Dynamic Profiles（多 agent）、系统工具（OCRTool/BarcodeReaderTool/Spotlight 本地 RAG）、Evaluations framework、usage token 用量上报、框架开源 + Linux/Python SDK。
- 判断：**「拍照→LLM 直接理解衣物属性」路线在 iOS 27 世代打开**；PCC 免费额度让"云端补强"（长上下文搭配规划）零成本可用。但都不应做成硬依赖。

## 4. 数据层

### 4.1 SwiftData vs Core Data
- SwiftData 最低 iOS 17。**iOS 26 修复关键缺陷后达到"生产可用"**：模型继承、Codable 属性上的 predicate、history fetch 排序等（[mjtsai 汇总 WWDC25](https://mjtsai.com/blog/2025/06/19/swiftdata-and-core-data-at-wwdc25/)、[FractalDev 2026 指南](https://fractal-dev.com/blog/ios-databases)）。绿地 SwiftUI 项目默认 SwiftData + CloudKit 私有库同步。
- 仍存短板：**CloudKit 仅私有数据库同步，不支持 shared/public database**（多人共享衣橱需 Core Data `NSPersistentCloudKitContainer` sharing 或自建服务）；iOS 26.0/26.1 曾有同步回归（重复记录、不刷新），26.x 小版本已修（[论坛](https://developer.apple.com/forums/thread/811675)）。
- SwiftData+CloudKit 既有约束沿袭 Core Data mirroring：属性需 optional 或带默认值、不支持 unique 约束（[Medium 实践](https://medium.com/@jakir/sync-swiftdata-with-icloud-using-cloudkit-34764a46ba54)）。

### 4.2 大量衣物图片的存储
- 推荐：模型二进制属性标 `@Attribute(.externalStorage)`——框架把大 blob 存到 store 旁独立文件，DB 保持轻量；CloudKit 侧**自动镜像为 CKAsset**（字段 >1MB 记录上限时自动转 asset）。Apple 官方口径：**让框架管理图片存储与同步，勿手动管文件路径**（手动方案在 App 更新/多设备同步时不稳定）。来源：[官方论坛 Best Practices](https://developer.apple.com/forums/thread/803646)、[externalStorage 讨论](https://developer.apple.com/forums/thread/748267)。
- 实践补充：原图（抠图后 PNG/HEIC）走 externalStorage；**列表缩略图单独存小尺寸版本**避免滚动时反复解码大图；抠图 mask 不必持久化（可由原图重算）。

## 5. 体型（近似体型 + 着装可视化）

- **ARKit body tracking**：`ARBodyTrackingConfiguration`（iOS 13+，A12+，后置摄像头）实时 3D 骨架（[文档](https://developer.apple.com/documentation/arkit/arbodytrackingconfiguration)）。能力边界：输出**姿态骨架而非身体围度**；对照 VICON 的研究显示关节角度精度有限、下肢运动时误差增大（[MDPI 评测](https://www.mdpi.com/2076-3417/12/10/4806)）。⚠️ iOS 26.0 存在 LiDAR 机型 `ARBodyAnchor` 不检测的回归 bug（[FB15128723](https://developer.apple.com/forums/thread/804899)）。
- **TrueDepth**：前置结构光 3 万点，**近距离小范围**高精度（面部扫描 vs CBCT 平均偏差 0.387mm；适合脸/半身，不适合全身）（[LAAN 案例](https://labs.laan.com/casestudies/truedepth-3d-scanning-case-study)、[NCBI 研究](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11592646/)、[MyFit](https://myfit-solutions.com/en/blog/truedepth-camera/)）。
- **LiDAR 全身**：iPhone 12 Pro LiDAR 人体测量研究：>10cm 物体绝对精度约 **±1cm**（[ResearchGate](https://www.researchgate.net/publication/358080588_Human_body_measurement_with_the_iPhone_12_Pro_LiDAR_scanner)）；商业 App（3D Measure Me 等）走"引导扫描→80+ 围度→avatar"路线（[App Store](https://apps.apple.com/us/app/3d-measure-me-body-scanner/id1582395826)）。
- 判断：**Apple 无"身体围度测量"原生 API**。本 App 的「根据用户身体维度数据生成近似体型」应走：**用户手输维度（胸/腰/臀/身高等）→ 参数化人体模型（SMPL 类形变体）→ SceneKit/RealityKit 渲染**；AR 扫描估维度作 P2 增强（精度 ±1cm 级、流程摩擦大）。着装可视化用 2D 分层贴装（抠图衣物叠加在体型剪影上）比 3D 试穿现实得多——3D 布料模拟无原生支持。

## 6. 环境信号

- **WeatherKit**：iOS 16+（Swift API），其他平台 REST。**Apple Developer Program 会员含 50 万次/月调用**，超量可订阅扩容；需付费开发者账号 + App ID + key。**署名义务**：展示天气数据必须显示  Weather 商标及数据源法律链接（`WeatherAttribution` API 提供素材）。来源：[Get Started](https://developers.apple.com/weatherkit/get-started/)、[REST API 文档](https://developer.apple.com/documentation/weatherkitrestapi)、[署名要求](https://developer.apple.com/weatherkit/data-source-attribution/)。
- **EventKit**：iOS 17 权限重构——`requestFullAccessToEvents`（读+写）/ write-only / `EKEventEditViewController`（免权限写入）；旧 `requestAccessToEntityType` 弃用。**读日历做"场合识别"需 full access** + 明确用途文案。来源：[WWDC23 示例](https://github.com/gromb57/ios-wwdc23__AccessingCalendarUsingEventKitAndEventKitUI)、[Create with Swift](https://www.createwithswift.com/creating-and-saving-calendar-events/)、[expo issue（弃用记录）](https://github.com/expo/expo/issues/24343)。
- 判断：「明天有面试 + 降温」→ 推荐更正式/保暖搭配的信号链完全原生可得，成本仅为权限申请与署名合规。

## 7. 功能 → 所需 API → 最低 iOS 版本矩阵

| 功能 | 所需 API | 最低 iOS | 备注 |
|---|---|---|---|
| 主体抠图（交互确认 UI） | VisionKit `ImageAnalysisInteraction` `.imageSubject` | 16（UI）/ **17**（程序化取 subject 图） | A12+ |
| 主体抠图（后台批量管线） | Vision `VNGenerateForegroundInstanceMaskRequest` | **17**（新 Swift API 需 18） | 模拟器不可用 |
| 连拍批量入库 | `AVCapturePhotoOutput` + zero shutter lag / responsive capture / fast prioritization / deferred processing | **17**（基础拍摄更低） | 支持机型逐特性检测 |
| 内置图像分类（粗类） | `VNClassifyImageRequest` / `ClassifyImageRequest` | 13 / 18 | 1303 类通用 taxonomy |
| 自定义分类模型部署 | Core ML（coremltools 9 转换） | 名义 11+，实际取决于模型 op，现代模型建议 **17+** | iOS 27 世代可评估 Core AI |
| 设备端个性化训练 | Create ML framework | 15 | 可选 |
| 搭配推荐理由 / 结构化输出（文本） | Foundation Models `LanguageModelSession` + `@Generable` + tool calling | **26** | 硬件 iPhone 15 Pro+；4096 token；中文支持 |
| 衣物照片直接 LLM 理解（图像输入） | Foundation Models image input | **27** | 仅 AFM 3 Core Advanced 硬件（iPhone 15 Pro+ 一档） |
| 云端长上下文推荐 | `PrivateCloudComputeLanguageModel`（32k、免费额度） | **27** 世代 | <200 万下载免费 |
| 衣橱/搭配/标签数据层 | SwiftData（+ CloudKit 私有库同步） | 17（**26 才生产成熟**） | 无共享/公共库 |
| 衣物图片存储 | `@Attribute(.externalStorage)` → CKAsset | 17 | 缩略图自行分离 |
| 体型骨架/AR | `ARBodyTrackingConfiguration` | 13（A12+） | 无围度输出；26.0 有回归 bug |
| 近距离深度（脸/半身） | TrueDepth（`AVDepthData`/ARFaceTracking） | 硬件 TrueDepth 机型 | 不适合全身 |
| 天气信号 | WeatherKit | 16 | 付费开发者账号 + 署名 |
| 日历场合信号 | EventKit `requestFullAccessToEvents` | 17（新权限 API） | 权限文案必填 |

## 8. 最低支持版本建议

**建议：最低 iOS 26，Apple Intelligence 能力按 `SystemLanguageModel.availability` 优雅降级；iOS 27 图像输入/PCC 作条件增强（`#available(iOS 27, *)`）。**

理由：
1. 本 App 的差异化核心（搭配推荐 + 理由生成 + 结构化输出）落在 Foundation Models，**framework 地板就是 iOS 26**；若 min 设 17 只是把同一批「iOS 26 且 15 Pro+」用户之外的人从"系统旧"换成"系统新但没 AI"，AI 功能覆盖面不变，却要背 17~25 五代系统的适配债。
2. 新 App 实际上架窗口在 2026 底~2027 初：届时 iOS 26 已发布 >1 年（历史采用率约 70-80%），且 iOS 27 正式版已出——min 26 并不激进。
3. SwiftData 在 iOS 26 才修完继承/predicate 等关键缺陷（见 §4.1），min 26 可直接享受成熟形态，避免 17 时代的坑。
4. 必须接受的现实：**系统版本 ≠ AI 硬件**。iOS 26 覆盖 iPhone 11+ 一大批无 Apple Intelligence 的设备（非 Pro 的 15 及更早），因此**推荐引擎必须双轨**：规则/检索引擎兜底（颜色协调、场合匹配、冷暖），FM 在可用设备上叠加生成理由与个性化——这是架构级决定，不是可选项。

---

## 附：关键风险与坑

- 抠图/分类/FM 均**不可在模拟器验证** → 真机测试基线。
- FM 4096 token：衣橱候选集须先剪枝再进 prompt；用 iOS 26.4 token 计数 API 预算。
- SwiftData+CloudKit：属性 optional/默认值约束在建模期就要遵守，后补代价高；共享衣橱（闺蜜互看）当前原生无解，列为远期并预留数据导出路径。
- WeatherKit 需要付费开发者账号（本来就要）+ 商标署名进设置页。
- ARKit body tracking 在 iOS 26.0 的 ARBodyAnchor 回归提醒我们：体型功能别押注单一 AR API。

---
🟡 **置信度** 🟡: 82% — 核心版本断言（FM=iOS 26、mask=iOS 17、图像输入=iOS 27、SwiftData 成熟度）均有官方 session/文档或多源交叉印证；iOS 27 细节（AFM 3 硬件分档、PCC 免费条款细则）来自 WWDC26 二手转述且 beta 期可能微调，建议开发前对照 9 月正式发布说明复核。
