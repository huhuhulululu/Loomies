# 08 — Apple LiDAR / 3D 扫描可行性边界调研

> 调研日期：2026-07-21。面向本 App（数字衣橱 + 搭配推荐 + 体型可视化 + 存放位置标注）评估 LiDAR/3D 扫描在各层的正/负收益。
> 结论先行：**LiDAR 扫衣服建 3D 模型 = 负收益（官方与研究界双重否定）；RoomPlan 衣柜空间数字化 = 有限正收益（Pro 机型渐进增强）；身体测量不需要 LiDAR（2-photo AI 是行业主流且精度不落下风）。**

---

## 1. 硬件与 API 事实

### 1.1 深度图分辨率与帧率

- **ARKit `sceneDepth`（ARFrame.sceneDepth / ARDepthData）实际输出 256×192**，最高 60 Hz，由 LiDAR 稀疏点 + RGB 图像经 ML 插值融合生成；**分辨率不可配置**。
  - 来源（Apple 工程师在开发者论坛的答复与实测）：https://developer.apple.com/forums/thread/695771 ；https://developer.apple.com/forums/thread/712943
  - 实测解读：https://www.it-jim.com/blog/iphones-12-pro-lidar-how-to-get-and-interpret-data/
- 对比：AVFoundation `AVCaptureDeviceTypeBuiltInLiDARDepthCamera` 流式深度为 320×240 @30fps（帧率更低、分辨率略高）。来源同上论坛帖。
- 含义：**LiDAR 原始点阵极稀疏（约 576 个真实测距点级别，深度图靠插值）**，任何"精细几何"都是 RGB 推断，不是激光实测。

### 1.2 有效距离与精度

- 官方标称：**测距"最远 5 米"**（Apple Newsroom，2020-03 iPad Pro 发布稿）：https://www.apple.com/newsroom/2020/03/apple-unveils-new-ipad-pro-with-lidar-scanner-and-trackpad-support-in-ipados/
- 学术评测（iPhone 12 Pro，Nature Scientific Reports 2021）：**边长 >10 cm 的物体绝对精度约 ±1 cm**；大场景精度降至 ±10 cm 量级；超过 5 m 质量急剧下降：https://www.nature.com/articles/s41598-021-01763-9
- 室内制图对比地面激光扫描仪（TLS）：厘米级一致性，建筑测绘够用：https://www.tandfonline.com/doi/full/10.1080/16874048.2024.2408839
- 医学/人体应用综述指出：**iPhone LiDAR 空间分辨率低，只能捕获粗糙表面几何，完全无法表现高频细节**（如面料纹理、褶皱）：https://link.springer.com/article/10.1186/s12938-025-01480-8

### 1.3 配备 LiDAR 的机型清单（截至 2026-07）

**iPhone（全部为 Pro/Pro Max，共 6 代 12 款）**：12 Pro / 12 Pro Max / 13 Pro / 13 Pro Max / 14 Pro / 14 Pro Max / 15 Pro / 15 Pro Max / 16 Pro / 16 Pro Max / 17 Pro / 17 Pro Max。
**标准版、Plus、mini、SE、16e、Air 一律没有 LiDAR。**

- Apple 官方机型说明（iOS 27 支持文档"Models with a LiDAR Scanner"）：https://support.apple.com/en-kg/guide/iphone/aside/iphc07537a89/26/ios/27
- 汇总清单（2026）：https://www.simplywise.com/blog/which-iphones-have-lidar/

**iPad**：2020-03 起的**所有 iPad Pro**（11" 第 2 代+ / 12.9" 第 4 代+ / M4 11" & 13"）。非 Pro iPad 无。

- https://en.wikipedia.org/wiki/IPad_Pro_(M4) ；https://support.apple.com/en-us/108043

### 1.4 非 Pro 机型市场占比（LiDAR 覆盖率的现实）

- CIRP 数据（美国，2025 Q1）：iPhone 16 Pro + Pro Max 合计仅占 iPhone 销量 **38%**（上代同期 15 Pro 系为 45%）：https://9to5mac.com/2025/04/23/iphone-16-pro-is-the-surprise-loser-in-apples-recent-sales/
- iPhone 17 系发布初期 Pro 占比一度冲到 72%（新机早期抢购偏 Pro，非稳态；且仅指 17 系内部占比）：https://finance.biggo.com/news/202604111021_Apple-iPhone-17-Pro-Max-Q4-2025-Sales-Leader
- **存量角度**：活跃 iPhone 中还包括大量 11/12/13/14/15/16 标准版、SE、16e、Air——存量 LiDAR 覆盖率显著低于新机销售占比。
- **结论：任何核心功能都不能以 LiDAR 为前置条件**，只能作 `isSupported` 检测下的渐进增强；本 App 目标用户（女性、职业场景）机型分布没有证据偏向 Pro。

---

## 2. Object Capture（RealityKit Photogrammetry）

### 2.1 官方对被摄对象的要求

Apple 官方文档《Capturing photographs for RealityKit Object Capture》明确：

- 选择**静态、拍摄过程中不会弯曲或形变**的物体；**"soft, articulated, or bendable" 物体会破坏特征点匹配**——衣物正是柔性形变物，属官方排除项。
- 避免**高反光、透明、半透明、单色无纹理、某一维度极薄**的物体——丝绸/缎面/雪纺/纯色针织全部踩雷。
- 建议 ≥100 张照片、相邻帧重叠 ≥70%。
- 来源：https://developer.apple.com/documentation/realitykit/capturing-photographs-for-realitykit-object-capture ；WWDC21《Create 3D models with Object Capture》：https://developer.apple.com/videos/play/wwdc2021/10076/

### 2.2 iOS 端上重建能力

- **iOS 17（WWDC23 session 10191）起支持全流程端上重建**；设备要求：**LiDAR + A14 及以上芯片**（Apple 官方示例工程现要求 iOS 18+，因 WWDC24 增加了 area mode）。
  - https://developer.apple.com/documentation/realitykit/scanning-objects-using-object-capture
  - WWDC23：https://wwdcnotes.com/documentation/wwdc23-10191-meet-object-capture-for-ios/
  - WWDC24 area mode：https://developer.apple.com/videos/play/wwdc2024/10107/
- 端上重建耗时**数分钟/件**，细节等级低于 Mac 端；运行时用 `ObjectCaptureSession.isSupported` 检测。
- 第三方实测的局限汇总（反光、无纹理、细薄结构失败）：https://www.mappedin.com/resources/blog/apple-object-capture-limits/

### 2.3 对衣物的适用性判定

**不适合**。衣物同时命中官方排除清单的三项：柔性形变、常见反光/半透面料、薄片结构。挂着扫会晃、平铺扫是"薄片"、穿着扫是人体+衣物耦合。工业界甚至有专利靠**给衣服充气使其刚性化**再扫描（US10436575），侧面印证直接扫描不可行：https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/10436575

**适合的例外**：鞋、包、首饰、腰带扣等**刚性配饰**可用 Object Capture 出高质量 USDZ——若未来做配饰 3D 展示可考虑，但属加分项非核心。

---

## 3. 3D 衣物数字化：研究与产品先例

### 3.1 学界现状（2024-2026）

| 方案 | 输入 | 输出 | 移动端可行性 |
|---|---|---|---|
| Gaussian Garments（ETH，3DV 2025） | **多机位视频（studio 采集台）** | 仿真就绪衣物 + GNN 动力学 | ✗ 需多相机阵列 |
| Dress-1-to-3（2025） | 单张照片 | 仿真就绪 3D 套装（扩散先验+可微物理） | ✗ 服务端重 GPU |
| Garment3DGen（Meta） | 单图/文本 + 模板网格 | 仿真就绪衣物网格 | ✗ H100 上约 5 分钟 |
| GarmentDreamer / Image2Garment（2025-26） | 文本/单图生成 | 3DGS/网格 | ✗ 研究级 |
| Deep Fashion3D（数据集/基准） | — | 单图重建基准 | — |

- Gaussian Garments：https://arxiv.org/abs/2409.08189 （代码：https://github.com/eth-ait/Gaussian-Garments/ ）
- Dress-1-to-3：https://arxiv.org/pdf/2502.03449 ；Garment3DGen：https://arxiv.org/html/2403.18816
- 领域论文汇总：https://github.com/Shanthika/Awesome-3D-Garments

**判定**：真实衣物的高保真 3D 数字化要么依赖 studio 多机位，要么是服务端重 GPU 的**生成式**管线（从单图"猜"出 3D，而非扫描）；**手机端"扫一扫得到可用 3D 衣物"在 2026 年仍无成熟方案**。若远期要 3D 衣物，正确路线是"单图生成式 + 云端"，与 LiDAR 无关。

### 3.2 商业产品先例

头部数字衣橱产品 **Indyx、Whering、Acloset 全部采用 2D 照片 + AI 抠图 + 自动打标**，无一使用 3D 扫描：

- Indyx（AI 背景移除 + 品牌/类目/颜色/存放位置筛选）：https://www.myindyx.com/
- 行业对比：https://www.myindyx.com/blog/the-best-wardrobe-apps

虚拟试穿方向（Google Doppl 等）也走**2D 图像生成式**路线而非 3D 扫描。行业已用脚投票。

---

## 4. LiDAR / TrueDepth 用于身体测量

### 4.1 商业 SDK 的实际技术路线

- **3DLOOK**：2 张照片（正+侧）→ 80+ 项测量，声称 96-97% 精度、95%+ 可重复性，**不要求 LiDAR**：https://3dlook.ai/content-hub/3dlook-turns-two-photos-structured-body-data/
- **Bodygram**：2 张照片 + 身高体重年龄 → 24 项测量（训练数据含 3D 全身扫描 + ISO 8559-1 人工测量），声称对比专业裁缝达 ~99%，**不要求 LiDAR**：https://www.bodygram.com/en/platform ；https://techcrunch.com/2018/07/02/original-stitchs-new-bodygram-will-measure-your-body
- 两家的精度数字均为厂商自述（营销口径），但技术路线选择本身是事实：**主流商业体测 SDK 都选了纯照片 + AI，而非 LiDAR**。

### 4.2 LiDAR 直扫人体的学术数据

- iPhone 12 Pro LiDAR 人体测量研究：**身高误差 0.55%，臀围 3.84%，腰围 6.90%**（腰围 70 cm 即 ±4.8 cm，做尺码推荐不够用）：https://www.researchgate.net/publication/358080588_Human_body_measurement_with_the_iPhone_12_Pro_LiDAR_scanner
- 2025 系统综述（智能手机/平板 3D 扫描人体测量）：可靠性因部位与 App 而异，深度硬件（TrueDepth/LiDAR）优于单目单摄，但 LiDAR 分辨率低只能取粗轮廓：https://link.springer.com/article/10.1186/s12938-025-01480-8
- LiDAR 手持扫描仪人体部位测量的初步验证（PMC）：https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10820714/

**判定**：LiDAR 直扫的围度误差（~7%）**不优于** 2-photo AI 方案的声称精度（3-4% 量级），却把可用人群砍到 Pro 机型。体型数据获取应走：**手动录入（必备）+ 可选 2-photo AI 测量（全机型可用）**。TrueDepth（前摄，所有 Face ID 机型都有）可作面部/近距离补充，但对全身围度无成熟优势。

---

## 5. RoomPlan：衣柜空间数字化

### 5.1 能力边界（官方核实）

- **系统要求：iOS/iPadOS 16.0+，必须 LiDAR 机型**（Mac Catalyst 仅能处理数据不能采集）：https://developer.apple.com/documentation/roomplan
- **可识别对象类目（`CapturedRoom.Object.Category`，16 类，iOS 16.0+，经 Apple 文档逐项核实）**：bathtub / bed / chair / dishwasher / fireplace / oven / refrigerator / sink / sofa / stairs / **storage** / stove / table / television / toilet / washerDryer：https://developer.apple.com/documentation/roomplan/capturedroom/object/category-swift.enum
  - **衣柜/储物柜/橱柜归入 `storage` 类**，无更细分的"wardrobe"类目。
- **输出**：参数化数据（墙/门/窗/开口 + 对象的类型、位置、**尺寸包围盒**），可导出 **USDZ**（多种 `USDExportOptions`），`CapturedRoom` 遵循 Codable 可序列化为 JSON；iOS 17 起 `CapturedStructure` 支持多房间合并：https://developer.apple.com/documentation/roomplan ；WWDC22：https://developer.apple.com/videos/play/wwdc2022/10127/ ；WWDC23 增强：https://developer.apple.com/videos/play/wwdc2023/10192/
- **已知短板**：识别的是**外包围盒不是精细几何**；镜面/玻璃（衣柜常见镜面门）造成空洞；开放式衣架/置物架这类非封闭家具识别不稳定：https://www.it-jim.com/blog/roomplan-framework-by-apple/

### 5.2 用于「衣柜空间数字化 + 存放位置可视化」的可行性

- **可行到"柜级"**：扫一次卧室 → 得到房间轮廓 + 每个 storage 对象的位置与外尺寸 → 渲染 2D/3D 户型图，把"这件衣服在主卧左侧衣柜"可视化。参数化 JSON 便于叠加自定义标注。
- **不可行到"格位级"**：RoomPlan 不识别柜内隔层/抽屉/挂杆——柜内结构必须用户手动定义（如"衣柜 A → 上层/挂区/抽屉 2"的逻辑格位树），这恰好用标签系统就能实现，**与 LiDAR 无关**。
- 机型门槛：Pro-only。**存放位置功能的主路径必须是纯手动标签**（位置字段 + 可选照片），RoomPlan 仅作 Pro 用户的可视化增强皮肤。

---

## 6. 结论：LiDAR 的正/负收益分层

| 层 | 判定 | 理由 |
|---|---|---|
| 衣物入库（扫衣服→3D 模型） | **负收益，不做** | Object Capture 官方排除柔性物；LiDAR 分辨率无法表现面料细节；学界无移动端方案；头部竞品全走 2D 照片 |
| 衣物入库（2D 照片+抠图+AI 打标） | **正收益，主路径** | 行业标准做法，全机型可用（VisionKit `ImageAnalysisInteraction` / Vision 人像分割即可端上抠图） |
| 身体测量 | **负收益，不用 LiDAR** | LiDAR 直扫围度误差 ~7% 不优于 2-photo AI（声称 3-4%）；砍掉非 Pro 用户 |
| 体型可视化 | 与 LiDAR 无关 | 手输维度 + 参数化 avatar；可选接 2-photo 测量 SDK |
| 尺码/维度录入 | 与 LiDAR 无关 | 品牌+尺码字段 + 吊牌拍照 OCR（Vision 文本识别）+ 可选平铺关键测量（胸宽/衣长，用参照物照片估算） |
| 衣柜空间数字化 | **有限正收益，Pro-only 渐进增强** | RoomPlan storage 类目 + 尺寸 + USDZ，做"衣柜地图"皮肤；主路径仍是手动位置标签 |
| 刚性配饰 3D 展示（鞋/包/饰品） | 可选正收益（远期） | Object Capture 恰好擅长刚性小物；iOS 17+/LiDAR+A14 端上重建数分钟/件 |

**一句话**：LiDAR 在本 App 里唯一站得住的位置是 **RoomPlan 衣柜空间可视化（Pro 机型增强项）**；衣物与身体两条核心数据管线都应是**纯摄像头 + AI** 路线，保证全机型可用。
