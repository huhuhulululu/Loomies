# 开源项目 / 模型 / 数据集调研（数字衣橱 iOS App）

> 调研日期：2026-07-21。星标数与维护状态来自 GitHub API 实时查询，许可证均核对过 LICENSE 文件或模型卡。
> 产品背景：面向女性多场合需求的 iOS App —— 扫描衣服入库、搭配推荐与收藏、标签系统、按身体维度生成近似体型做着装可视化。

---

## 1. 开源衣橱/穿搭 App

| 项目 | 技术栈 | Stars | 许可证 | 维护状态 | 可用性结论 |
|---|---|---|---|---|---|
| [Anyesh/wardrowbe](https://github.com/Anyesh/wardrowbe) | Next.js + FastAPI + Postgres，自托管 | 535 | MIT ✅ | **极活跃**（2026-07-21 仍有提交），有 [App Store iOS 客户端](https://apps.apple.com/us/app/wardrowbe/id6759947671) | **最佳全栈参考**：AI 打标走任意 OpenAI 兼容 API（默认 Ollama + gemma3 视觉模型），含天气/场合推荐、穿着记录。架构与 prompt 设计可直接借鉴 |
| [tandpfun/wardrobe](https://github.com/tandpfun/wardrobe) | gpt-image 提取/标准化衣物图 | 1271 | MIT ✅ | 活跃（2026-07-16） | 思路参考：用**生成模型**（gpt-image）把随手拍变成标准化商品图，替代传统抠图，效果好但每张有 API 成本 |
| [Lazztech/Libre-Closet](https://github.com/lazztech/libre-closet) | TypeScript PWA，Docker 自托管 | 289 | **AGPL-3.0** ⚠️ | 活跃（2026-07-17） | AGPL 不可闭源集成，仅作功能/数据模型参考 |
| [zebangeth/ai-closet](https://github.com/zebangeth/ai-closet) | React Native + Expo（iOS/Android） | 283 | MIT ✅ | 半停滞（2025-11 最后提交） | 移动端参考：AI 背景去除 + 自动分类的移动端交互流可借鉴 |
| [OpenWardrobe/app](https://github.com/OpenWardrobe/app) | Flutter + Supabase | 31 | MIT | 停滞（2025-02 起无提交） | 参考价值低 |
| [bahaaTuffaha/Project-ClosetArchive](https://github.com/bahaaTuffaha/Project-ClosetArchive) | React Native | 36 | MIT | 活跃（2026-07-19） | 小体量，穿着记录/防重复穿思路可参考 |

**Swift/iOS 原生**：GitHub 搜索 `wardrobe language:swift` 最高仅个位数 star（[mixnmatch](https://github.com/mrezkys/mixnmatch) 9★ WWDC 学生作品无许可证、[CapOotd](https://github.com/whdtx111/CapOotd) 4★ MIT、[ClosetAI](https://github.com/Ligoml/ClosetAI) 4★ 无许可证、[Project333_iOS](https://github.com/yewei600/Project333_iOS) 2017 年弃更）。

**结论**：**不存在可二次开发的成熟 Swift 开源衣橱 App，iOS 原生层需自研**；可复用的是 wardrowbe（后端/AI 打标流水线，MIT）与 ai-closet（移动端 UX，MIT）的设计与代码片段。

---

## 2. 服装图像处理

### 2.1 背景去除 / 分割

| 方案 | 来源 | Stars/热度 | 许可证 | 端侧可行性 | 结论 |
|---|---|---|---|---|---|
| **Apple Vision 主体提取**（iOS 17+ `VNGenerateForegroundInstanceMaskRequest`） | [Apple 官方文档](https://developer.apple.com/documentation/vision/vngenerateforegroundinstancemaskrequest)、[实现教程](https://www.createwithswift.com/removing-image-background-using-the-vision-framework/) | 系统内置 | 系统 API ✅ | **纯端侧、零依赖、免费** | **扫衣入库抠图首选**。对平铺/悬挂单件衣物效果好，离线、隐私友好、零成本 |
| [rembg](https://github.com/danielgatis/rembg) | danielgatis | 23,934 | MIT ✅（默认 u2net 权重 Apache-2.0） | Python/ONNX，定位服务端 | 服务端批处理/兜底通道；一行代码，模型可切换 birefnet |
| [BiRefNet](https://github.com/ZhengPeng7/BiRefNet) | ZhengPeng7，CAAI AIR'24 | 3,914 | **MIT（代码+官方权重均 MIT）** ✅（[HF 模型](https://huggingface.co/ZhengPeng7/BiRefNet) 69.6 万月下载） | 社区已验证同架构可转 Core ML：[RMBG-2-CoreML](https://huggingface.co/VincentGOURBIN/RMBG-2-CoreML)（INT8 233MB、ANE 兼容、1024²）；另有 [ONNX 版](https://huggingface.co/onnx-community/BiRefNet-ONNX)（deform_conv2d 需等价替换） | 抠图质量 SOTA。⚠️ 注意：RMBG-2.0 权重属 BRIA **非商用**，商用须用 ZhengPeng7 官方 MIT 权重自行转换（含 BiRefNet_lite 轻量版） |
| [SAM2](https://github.com/facebookresearch/sam2) | Meta | 19,568 | Apache-2.0 ✅ | **Apple 官方已发 Core ML 版**：[apple/coreml-sam2.1-tiny/small/…](https://huggingface.co/apple/coreml-sam2.1-small) | 点选式交互分割（用户点一下衣服即选中）端侧可用，适合多件衣物同框拆分 |
| [U-2-Net](https://github.com/xuebinqin/U-2-Net) | xuebinqin | 9,815 | Apache-2.0 ✅ | 有大量 Core ML/ONNX 移植先例 | 停更（2024-06），已被 BiRefNet 超越，仅作轻量备选 |
| [levindabhi/cloth-segmentation](https://github.com/levindabhi/cloth-segmentation)（U2-Net 服装 3 分类） | levindabhi | 673 | 代码 MIT；⚠️ 训练数据 iMaterialist 许可不明 | ONNX 可转 | 上/下/全身三类分割，可用但数据来源许可灰色 |
| [mattmdjaga/segformer_b2_clothes](https://huggingface.co/mattmdjaga/segformer_b2_clothes)（人身 18 类解析） | HF，502 likes，16.6 万月下载 | — | ⚠️ **NVIDIA SegFormer 许可 = 非商用**（模型卡明确指向 [NVlabs LICENSE](https://github.com/NVlabs/SegFormer/blob/master/LICENSE)） | 可转 Core ML 但许可不允许 | **商用不可直接用**（HF 上最流行的服装解析模型，许可是坑）。[sayeed99/segformer-b3-fashion](https://huggingface.co/sayeed99/segformer-b3-fashion) 同属 SegFormer 架构，同样受限 |
| [SCHP 人体解析](https://github.com/GoGoDuck912/Self-Correction-Human-Parsing) | GoGoDuck912 | 1,241 | 代码 MIT；⚠️ LIP 训练数据非商用 | — | 仅研究/内部实验用 |

**结论**：许可安全的商用抠图/分割栈 = **iOS 17 Vision 端侧抠图（主）+ SAM2 点选拆分（辅）+ 服务端 rembg/BiRefNet-MIT（兜底）**。避开 SegFormer 系服装解析模型。

### 2.2 类目与属性识别（数据集）

| 数据集 | 规模 | 许可证 | 结论 |
|---|---|---|---|
| [DeepFashion](https://mmlab.ie.cuhk.edu.hk/projects/DeepFashion.html)（CUHK） | 80 万图 | ⚠️ **仅限非商用研究**（需签 Release Agreement） | 商业产品**不可用**于训练 |
| [DeepFashion2](https://github.com/switchablenorms/DeepFashion2) | 49.1 万图 / 13 类 | ⚠️ **仅限非商用研究**（[官方 issue 确认](https://github.com/switchablenorms/DeepFashion2/issues/3)，需机构邮箱签协议） | 同上，**不可商用** |
| [Fashionpedia](https://fashionpedia.github.io/home/) | 4.8 万图 / 46 类目 + 294 属性，分割级标注 | **标注与本体 CC BY 4.0 ✅**（[官方 Terms](https://fashionpedia.github.io/home/data_license.html)；图片版权自负）；[HF 镜像](https://huggingface.co/datasets/detection-datasets/fashionpedia) cc-by-4.0 | **唯一可商用微调的服装类目/属性数据集**，且属性体系（领型/袖型/材质等）正好支撑本 App 标签系统 |

**务实路径**：类目/属性识别可完全不训模型 —— 用 **FashionCLIP zero-shot 分类**（把类目/属性写成文本 prompt 算相似度）或 **VLM API 打标**（wardrowbe 即此路线，gemma3/GPT-4o 级视觉模型直接输出 JSON 标签），冷启动最快；量大后再用 Fashionpedia 微调小模型降本。

### 2.3 服装向量表征（Embedding）

| 模型 | 来源 | 许可证 | 热度 | 端侧可行性 | 结论 |
|---|---|---|---|---|---|
| [FashionCLIP 2.0](https://github.com/patrickjohncyh/fashion-clip) | patrickjohncyh，528★ | **MIT ✅**（[HF](https://huggingface.co/patrickjohncyh/fashion-clip) 285 万月下载） | 极高 | ViT-B/32 架构；CLIP 跑 iPhone 已被 [Queryable](https://github.com/mazzzystar/Queryable)（2,969★，MIT，Core ML 版 CLIP 全端侧图搜）验证可行 | 可商用、可端侧。80 万 Farfetch 商品图训练，服装域检索/零样本分类主力 |
| [Marqo-FashionCLIP / FashionSigLIP](https://github.com/marqo-ai/marqo-FashionCLIP) | Marqo，140★ | **Apache-2.0 ✅**（[HF](https://huggingface.co/Marqo/marqo-fashionSigLIP) 44.7 万月下载） | 高 | ViT-B-16-SigLIP，OpenCLIP 加载，coremltools 可转 | 官方 benchmark 文本检索指标较 FashionCLIP **+57%**（[博客](https://www.marqo.ai/blog/search-model-for-fashion)），**embedding 首选**；训练侧 2024-09 后无更新但即用即取 |
| [Apple MobileCLIP](https://github.com/apple/ml-mobileclip) | Apple，1,589★ | 代码 MIT，⚠️ **权重 apple-amlr = 仅限研究、可撤销**（[LICENSE](https://huggingface.co/apple/MobileCLIP2-B/blob/main/LICENSE)） | — | 专为端侧设计 | **权重不可商用**，放弃；端侧需求用 FashionCLIP 自转 Core ML |

**结论**：**Marqo-FashionSigLIP（服务端检索/推荐）+ FashionCLIP 转 Core ML（如需端侧离线搜索）**，两者均可商用。

---

## 3. 搭配兼容性（Outfit Compatibility）

| 资源 | 类型 | 许可证 | 状态 | 结论 |
|---|---|---|---|---|
| [mvasil/polyvore-outfits](https://huggingface.co/datasets/mvasil/polyvore-outfits)（UIUC，ECCV'18） | 数据集：68,306 套搭配 / 261,058 单品，含类目与文本 | HF 卡标 **CC BY 4.0**（写明允许商用，需署名）；⚠️ 图片系 Polyvore 网站历史抓取，图片本身版权灰色 —— 建议只用于**训练/评测**，不在产品内分发图片 | 静态（2018 数据） | 搭配兼容性训练的事实标准数据集 |
| [xthan/polyvore-dataset](https://github.com/xthan/polyvore-dataset)（Maryland 版） | 数据集：21,889 套 | 未明示（研究惯例） | 静态 | 备选，规模小 |
| [mvasil/fashion-compatibility](https://github.com/mvasil/fashion-compatibility) | Type-aware embedding 训练代码 | BSD-3-Clause ✅ | 167★，经典但老（PyTorch 旧版） | 方法参考 |
| [outfit-transformer](https://github.com/owj0421/outfit-transformer)（现 bigohofone/） | Outfit Transformer 复现：兼容性打分 CP + 填空 FITB + 互补检索，提供预训练 checkpoint | MIT ✅ | 79★，活跃（2025-12） | **最实用起点**：直接在 Polyvore 上训好，可服务端部署打分 |

**结论**：推荐架构 = **Marqo-FashionSigLIP 向量 + 轻量兼容性头（outfit-transformer 或自训 MLP，Polyvore 训练）+ 规则层（场合/色彩/用户标签过滤）**。兼容性打分模型很小，服务端 CPU/低配 GPU 即可，甚至可蒸馏转 Core ML 端侧跑；MVP 期可先用 LLM + 规则冷启动。

---

## 4. 虚拟试穿（VTON）

综合评测参考：[FASHN 四大开源 VTON 对比](https://fashn.ai/blog/comparing-the-top-4-open-source-virtual-try-on-viton-models)（质量排名 CatVTON > IDM-VTON > OOTDiffusion > StableVITON）。

| 模型 | Stars | 许可证 | 维护 | 算力/效果 | 结论 |
|---|---|---|---|---|---|
| [CatVTON](https://github.com/Zheng-Chong/CatVTON)（ICLR'25） | 1,795 | ⚠️ **CC BY-NC-SA 4.0**（代码+权重+demo 全部非商用） | 2025-12 仍有提交 | **<8GB VRAM @1024×768，~11s/张**，899M 参数，开源里综合最佳 | 效果/成本最优，但商用需另行授权 |
| [IDM-VTON](https://github.com/yisol/IDM-VTON)（ECCV'24） | 5,112 | ⚠️ CC BY-NC-SA 4.0（[README 明示](https://github.com/yisol/IDM-VTON)） | 2025-03 后停滞 | **>18GB VRAM**（[issue #94](https://github.com/yisol/IDM-VTON/issues/94)），~17s/张，质地/花纹还原最佳；自动 mask 仅支持上装 | 非商用；算力要求高 |
| [OOTDiffusion](https://github.com/levihsu/OOTDiffusion) | 6,564 | ⚠️ CC BY-NC-SA 4.0（LICENSE 文件核实） | **停更**（2024-05） | ~110s/张，下装支持差，demo 长期报错 | 不推荐 |
| [StableVITON](https://github.com/rlawjdghek/StableVITON)（CVPR'24） | 1,262 | ⚠️ CC BY-NC-SA 4.0 | 过时 | 已被后来者全面超越 | 不推荐 |
| [Leffa](https://github.com/franciszzj/Leffa) | 1,665 | 代码与 [HF 权重均标 MIT](https://huggingface.co/franciszzj/Leffa) ✅，⚠️ 但训练数据 VITON-HD（[CC BY-NC 4.0](https://github.com/shadow2496/VITON-HD)）/DressCode 均非商用 → 权重商用属法律灰色地带 | 2025-09 后停滞 | 质量与 IDM-VTON 相当，需服务端 GPU | 名义上唯一 MIT 的高质量 VTON，商用需自行评估数据链风险 |
| [FitDiT](https://github.com/BoyuanJiang/FitDiT) | 626 | ⚠️ 非商用（NOASSERTION，README 标研究用途） | 2025-02 停滞 | DiT 架构，质量好 | 非商用 |

**硬结论**：
1. **端侧 VTON 完全不可行**（扩散模型需 8~24GB VRAM），必须服务端 GPU 或第三方 API。
2. **全部主流开源 VTON 均非商用**（CC BY-NC-SA）；Leffa 权重虽 MIT 但训练数据非商用。商用三条路：向作者购买授权、用商业 API（[FASHN](https://fashn.ai)、Kling、Google Vertex AI try-on 等）、或视 Leffa 数据链风险自担后自部署。
3. **对本 App**：MVP 的「着装可视化」不必上 VTON —— 用抠好图的**2D 分层拼贴**（人台/体型剪影 + 衣物图层）即可满足"近似体型 + 搭配预览"；VTON 作为后期付费增值功能走商业 API 按次计费。

### 4.1 体型生成（身体维度 → 近似体型）

- [SMPL/SMPL-X](https://smpl.is.tue.mpg.de/modellicense.html)（Max Planck）：3D 参数化人体标准模型，从围度/身高回归体型成熟。⚠️ **研究免费，商用必须经 [Meshcapade](https://meshcapade.com/smpl/) 付费授权**。
- 规避路径：App 内用**自绘参数化 2D 体型剪影**（按胸/腰/臀/身高插值的矢量形状）做着装可视化，完全避开 SMPL 许可，且更符合"近似体型"的产品定位；后期需要 3D 再谈 Meshcapade 授权。

---

## 5. 总体选型建议（按许可与算力收敛）

| 环节 | 推荐方案 | 部署 | 许可 |
|---|---|---|---|
| 扫衣抠图 | iOS 17 Vision 主体提取；复杂图 SAM2 点选辅助 | 端侧 | 系统 API / Apache-2.0 ✅ |
| 抠图兜底 | rembg + BiRefNet 官方 MIT 权重 | 服务端 | MIT ✅ |
| 类目/属性打标 | VLM API 或 FashionCLIP zero-shot；量大后 Fashionpedia 微调 | 服务端 | MIT / CC BY 4.0 ✅ |
| 向量表征 | Marqo-FashionSigLIP（服务端）；FashionCLIP→Core ML（端侧检索） | 双端 | Apache-2.0 / MIT ✅ |
| 搭配兼容性 | outfit-transformer（Polyvore 训练）+ 规则层 | 服务端（模型极小） | MIT / CC BY 4.0 ✅ |
| 着装可视化 | MVP：2D 分层拼贴 + 参数化体型剪影；进阶：商业 VTON API | 端侧 / API | 自研 ✅ |
| 禁用清单 | DeepFashion/DeepFashion2 训练、segformer_b2_clothes、MobileCLIP 权重、四大 VTON 自部署商用、SMPL 未授权商用 | — | ⚠️ 非商用 |

---

🟡 **置信度** 🟡: 82% — 星标/许可证/维护时间均经 GitHub API 与 HF API/LICENSE 文件实时核验；Polyvore HF 卡的 CC BY 4.0 与 Leffa 权重 MIT 属平台自标，法律效力未经律师核验；VTON 算力数字来自官方 README 与社区 issue，未实测。
