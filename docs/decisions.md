# 决策日志（只追加不修改）

> 每条：日期 / 决策 / 依据 / 状态。设计详情见 DESIGN.md 对应章节，调研依据见 docs/research/。

## D1 [2026-07-21] 首发美国区 + min iOS 26 + en-US/英制优先
用户裁决（原 R3/R4）。国区合规链后置（预案 `research/06-gap-1.md`）。

## D2 [2026-07-21] 孩子档案砍出 MVP，v2 携完整 COPPA 合规再上
用户裁决（原 R9），采纳 AI 建议。儿童数据合规预案保留于 DESIGN §5。

## D3 [2026-07-21] 数据模型四条派生语义确认，模型冻结
用户裁决（原 R10）：Person 拆层 / 单品转移不共属 / 天气按衣柜所在地 / 搭配不跨柜但检索跨柜。
冻结例外：加法式 schema 演进不算破冻（DESIGN §11.1）。

## D4 [2026-07-21] 三个建议功能簇保留 + 买断档加上
用户裁决（原 R11 + 买断）：个人色彩（v1.0 加权/可选录入）、统计簇与差旅打包（v1.x）；
买断 = 本地功能永久，AI 走订阅；权益矩阵见 DESIGN §6（v0.7 一页化）。

## D5 [2026-07-21] 身体维度改默认仅本地存储域（不进 CloudKit）
来源：Codex 独立审计发现「Health 定性 × iCloud 存储」口径互斥（5.1.3 禁止个人健康信息存 iCloud）。
代价：体型档案不跨设备同步。隐私标签不按 Health 申报；分类口径列法务确认项。

## D6 [2026-07-21] AI 代理架构修正：「无用户内容状态 + 最小配额账本」
来源：Codex 审计 critical——纯无状态无法承载配额/防重放/付费权益。
付费权益绑 StoreKit 2 originalTransactionID；免费配额 keyId + iCloud 标记双记录。

## D7 [2026-07-21] Embedding 模型转换前置法务审批门
来源：Codex 审计——FashionCLIP/FashionSigLIP 权重许可干净但训练数据链未声明。
从「可用」清单移入「待法务评估」，避免转换后被迫换模型重算向量。

## D8 [2026-07-21] 市场定位修正（MARKET.md v1.0 四假设判定）
需求侧验证（1,484 条评论一手抓取）：H1 GO（正确性四条为硬门）；H2 存放位置降级为留存钩子；
H3 重定位为合身判断优先；H4 拆开——不卡件数=入场券、隐私=信任设计。
商业期望校准：小团队可持续生意（SOM 十万级 ARR 锚），非 VC 级独立大生意。

## D9 [2026-07-21] storefront 仅开放 US（R14）
用户裁决。App Store Connect 逐区勾选，非默认全球；与合规后置策略自洽，避免未评估市场法务敞口。扩区随对应市场合规完成再逐个开。

## D10 [2026-07-21] 遥测用匿名聚合（R15）
用户裁决：TelemetryDeck 类匿名聚合 SDK（无 IDFA/无设备指纹）。隐私标签从 not collected 调整为「Usage Data 未关联身份」；身体数据/图像永不进事件红线不变。解除 R1「MVP 快速实测无数据可测」的阻塞。

## D11 [2026-07-21] MVP 重切 A+C（R16）
用户裁决：A 纸娃娃视图降 v1.x（v1.0 合身用文字标记）；C 差旅打包/RoomPlan 维持既有排期；B 未选——OCR 快速层保留 v1.0（尺码一等公民定位）。「最小合身标记」已在 v1.0。

## D12 [2026-07-21] R13 人群门用隐式开关（AI 裁决，反悔成本低）
「全部推进」下 AI 代为裁决：不加 Person audience 字段（保持冻结模型干净、免 onboarding 摩擦），改以「身体维度是否录满」作 FFIT 簇激活开关 + 首次激活一次性说明。反悔加字段属加法演进（冻结例外允许）。可被用户覆盖。

## 状态：设计文档 ⚖️ 裁决点全部清零（R1-R16 处置完毕）
剩余开放项均为调研/工程验证型风险（R1/R2/R5/R6/R8/R12），不阻塞进入 MVP 实施规划。

## D13-D16 [2026-07-21] MVP-PLAN P0-P3（AI 代裁，用户连发「全部推进」授权；全部可反悔）
- **D13 (P0 团队规模)**：按「单人 + AI 辅助」推进——AI（本 agent）承担可验证的机械实现（纯逻辑/脚手架/测试），真机/ML/CloudKit 部分标注需人工+真机。工期诚实口径见 MVP-PLAN §1。
- **D14 (P1 需求验证)**：不阻塞建设——先建**可反悔的地基**（纯逻辑核心不押注需求结果），需求轻验证仍强烈建议并行（保留 R1）。地基（FFIT/ease/数据模型）无论需求结论都有价值。
- **D15 (P2 CloudKit 合并精细度)**：v1.0 **降级**——多衣柜保留（硬需求），但完整双机竞态合并修复器（DL-7/8）后置 v1.x；v1.0 用创建时不变量校验 + LWW，接受并发多设备编辑已知限制（多数 MVP 用户单设备）。加法演进，v1.x 可补。
- **D16 (P3 v1.0 出售)**：v1.0 **纯免费层**（省 StoreKit AG-5，200 件打标撞墙即降级无升级出口）；Plus 订阅/买断 IAP 后置 v1.x。

## 开工：ClosetCore 纯逻辑包（可命令行 swift test 验证）
Swift 6.2 + Xcode 26.2 环境确认。第一个可验证组件 = FFIT 体型判定（plus-size 2020 修正 9 类）+ ease 合身引擎，纯函数 TDD。这是 H3 护城河价值路径，无 iOS SDK 依赖。
后续迭代已建：F4 四条正确性过滤、组套 assembler、色彩规则 60-30-10、outfit 打分、体型×属性加权——ClosetCore 累计 60 tests 全绿（commit 7fd58c6..56a1170）。

## D17 [2026-07-21] R1 需求验证：关键发现 = 「推荐器 vs 规划器」潜在转向
用户主动暂停自主建设，转做 R1 需求验证。工具箱工作流（4 agent）产出 docs/DEMAND-VALIDATION.md + 落地页。
**决定性发现**：R1 需求真实（职业女性确实周日/前一晚预规划穿搭）——但项目押的是**机制**（自主算法推荐），这是最悬一环：
- 每个自主日推荐器竞品（Cladwell）收「算法学不会」1★；被爱的（Indyx/Alta）是当**手动策展+日历工具**用；场合推荐只在**用户自己给场合**时被夸。
- 真正的 R1 问题：他们想要**算法替他们决定**还是**帮他们自己规划的工具**？
- 关键筛选：靠做减法（胶囊/制服）解决决策疲劳的人是**干扰项非 ICP**；ICP 是「衣橱大、用不上、想显得得体」的人。
**验证设计**：北极星=付费承诺率；R1 判别器=V1(场合 hero)/V2(通用 hero) A/B 提升比 ≥1.5×；决策规则 GO/PIVOT/KILL/MIXED（DEMAND-VALIDATION §2）。
**对当前工作的含义**：ClosetCore 无论 GO/PIVOT 都有价值——若 PIVOT 到规划器，推荐引擎降级为「你选场合→我帮你配」，候选过滤/语法/打分全保留。建议验证有结论前不投 SwiftData/UI 大工程。

## D18 [2026-07-21] 方法④已执行 → 先验强烈偏「copilot/规划器」（PIVOT 带）
方法④（竞品社区信号挖掘，4 agent + 决定性断言对抗核查 confirmed）结果见 DEMAND-VALIDATION §8 + docs/research/18-method4-signal.md。
- 天平约 **7:1** 倒向规划器/copilot（核查修正：比原声称 3-4:1 更强）；差评率自主推荐器组 ~51% vs 规划器组 ~7%。
- 赢家=**copilot**（用户掌舵、App 跑腿）；naive autopilot 才有罪，Alta（4.88★ 日推荐器）证明执行正确+用户掌舵框架的日推荐器能活。
- 付费意愿几乎只在 $4.99 买断；Cladwell（自主订阅推荐器）已是付费毒资产。
- **净含义**：产品核心机制大概率应从 autopilot **PIVOT 到 copilot**（full-auto 作可选开关）——但这是**强先验非定论**，方法②落地页 A/B（V1/V2 提升比）仍是最终裁决器。已建 ClosetCore 78 tests 在 copilot 形态全复用。
- 决策仍待方法①②③真人验证（validation-kit 已备）。

## D19 [2026-07-22] PIVOT 到 copilot 机制（用户通过 V2 裁决）
用户「通过 V2 继续回到核心任务」= 选 copilot/规划器路线作产品核心机制。依据：方法④强先验（~7:1 倒向规划器，核查 confirmed，DEMAND-VALIDATION §8）+ 用户选择。
- **核心机制 autopilot → copilot**：主交互=用户锚定场合/几件单品 → AI 补全成合规搭配供选；full-auto 作可选模式。
- DESIGN v0.9：§3-F4 加「核心机制 copilot」段、每日节奏改「起点建议非强制」；数据模型不变（冻结）。
- 代码落点：ClosetCore OutfitCompleter（锚定→补全→打分候选，TDD 85 tests），复用 filter/grammar/scorer。
- 标注：A/B 未真跑，基于强先验+用户决定，**可回溯**（日后 A/B 反向可调）。

## D20 [2026-07-22] 跳过真人验证，以全面桌面研究为市场依据（用户裁决）
用户裁决：不跑方法①②③（真人招募/广告/访谈），由 AI 做最后一轮全面市场搜集归纳作为推进依据。
- 含义：R1 验证闭环后移到**上线后遥测**（§11.8 指标 = 真验证：激活漏斗/推荐接受率/D30 留存）；validation-kit 保留备用。
- 风险自知：桌面研究有确认偏误敞口 → 最后一轮专设**红队线**主动找 copilot 先验的反证。
- MARKET.md 将升 v2.0：合并全部证据 + 置信度台账（一手核实/厂商自述/推断三级）。

## D21 [2026-07-22] 红队修正 + 遥测裁决预注册（MARKET v2.0）
最后一轮市场归纳（19-23 号，11 agent，各线核查全 confirmed）产出三项结构性修正：
- **7:1 退役**：Cladwell 差评 ~2/3 是订阅扣费愤怒、纯机制仅 ~8-9%——方法④的 7:1 混杂变现模式，不再作机制天平引用；copilot 方向存活（Alta 666 条：autopilot 之爱 ~1% vs 规划语言 43%）但倍数证据降级。
- **钩子/机制分离**（Alta 实证）：落地页 V1/V2 A/B 只裁营销钩子；机制真裁决器 = 上线后「wear-as-is 率」遥测。D19 的 full-auto 可选模式被确认为正确对冲（autopilot 子群估 ICP 个位数%~10%）。
- **遥测裁决预注册协议**（MARKET §8）：门槛/最小样本 n≥400/判定时点第 6+10 周/激活诊断树/定价回落动作/变更规则（禁 HARKing）——现在固定，替代被跳过的真人验证，防「再校准=确认偏误许可证」。
其他要点：窗口 12-18→9-15 个月（Whering 驶入 copilot 车道 + Google Photos Wardrobe 今夏推送攻录入摩擦）；定价落数字（买断 $9.99/Plus $34.99 年/免费不限件，CVR<1% 预注册 $4.99 回落）；organic 获客结构必然（付费 UA ~20-40× 不回本）。

## D22 [2026-08-03] Wave：v1.0 CLI Completeness（继续推进，无新用户裁决）
在 D13「单人+AI 可验证机械实现」授权下推进：补齐仍可在 `swift test` 验证的 v1.0 缺口，不碰 Xcode/真机。
- 新增：SearchService（跨柜检索）、BodyProfileService（R13 四围门）、FitMarkService（ease→紧/合/松）、CalendarPlanService、WeatherProviding seam、Onboarding/CheckIn ViewModel、AppRoot 4-tab、Item 平铺宽加法字段。
- 结果：四包 **139 tests** 全绿；ARCHITECTURE/HANDOFF 同步。
- 下一步硬边界仍是 Xcode 组装 + 真机（Vision/CloudKit/WeatherKit）。

## D23 [2026-08-03] Wave B：检索/切换/拼贴/冷启动/遥测 schema
用户指令「先 A 后 B」：A=commit D22；B=继续 CLI 可做项。
- SearchViewModel、WardrobeSwitcherViewModel
- OutfitDraftService（手动拼贴强制跨柜不变量）
- Copilot 冷启动门（可用件 < 阈值 → 禁 full-auto、须锚定）
- FitMarkCopy en-US 文案；TelemetryEvent + Payload 白名单/身体红线
- 结果：**154 tests** 全绿。

## D24 [2026-08-03] 本地 Xcode 组装 + 模拟器跑通
用 XcodeGen 生成 `app-shell/ClosetApp.xcodeproj`，挂四个本地 SPM 包；CloudKit 默认 off 以便模拟器启动。
- `xcodebuild` iPhone 17 Pro / iOS 26.2 → **BUILD SUCCEEDED**
- `simctl launch com.pinglin.closet` 成功；工程可 `open ClosetApp.xcodeproj`
- 首启 Onboarding（名+城）→ AppRoot 4-tab；真机再开 CloudKit / Vision / WeatherKit

## D25 [2026-08-03] 模拟器可用闭环
用户「提交 你推进」：提交残留 docs 后继续模拟器闭环。
- DemoSeedService：首启/空柜灌可组套演示单品
- Closet：搜索、快捷手填入库、空柜 Load samples
- Today：建议卡「I wore this」打卡 + 冷启动文案
- Me：Load sample pieces
- 结果：Model 40 + 其余 = **156 tests**；xcodebuild 再绿

## D26 [2026-08-03] TestFlight 发版预备
目标直推 TestFlight。已备：App Icon 1024、PrivacyInfo、出口合规、version 0.1.0(2)、ExportOptions、`scripts/testflight.sh`、TESTFLIGHT.md。
- Archive 编译链已通到 CodeSign；agent 环境 login keychain 不可交互 → `errSecInternalComponent`（须用户在 Terminal.app 解锁钥匙串）
- ASC API Key `YFRZC2GC2V` 已在机，缺 **Issuer ID** 才能 altool/API 上传
- 后续：用户本机 `security unlock-keychain` + 填 Issuer + `./scripts/testflight.sh`，或 Xcode Organizer 上传

## D27 [2026-08-03] TestFlight 首包上传 — Loomies
- ASC App：**Loomies**（id 6797632035，bundle `com.pinglin.closet`，SKU Loomy001）
- 绕过旧钥匙串：新建 IOS_DISTRIBUTION 证书 + 临时 keychain 签名
- IPA 上传成功 Delivery UUID `cd57d7c8-f970-4516-8f16-980fa0ddcb78`
- 展示名 project.yml → Loomies（下次 build）

## D28 [2026-08-03] Debug 最大化 + 可观测性
全面优化 debug workflow：
- AppLog（OSLog + 200 条 ring + timed）贯穿 copilot/data/intake
- DiagnosticsExport JSON（无身体围度明文）+ Me 导出
- DebugSettings：verbose / forceColdStart / disableAntiRepeat / status 条（UserDefaults + `-debugVerbose` / `LOOMIES_DEBUG=1`）
- Copilot empty reason + 耗时；Calendar 计划列表；ModelSave 统一落库日志
- 164 tests；build 3；iOS 模拟器 BUILD SUCCEEDED

## D29 [2026-08-03] v1.0 功能缺口全面补齐（CLI+UI）
对照 DESIGN §7 v1.0，补可验证缺口（真机 Vision/CloudKit/Worker 仍后置）：
- ItemStatus / ItemEditor / StorageLocation / OutfitFavorite 服务 + TDD
- 单品详情+转移、身体四围+FFIT、衣柜管理、收藏、建议→Save/Plan today、About
- Outfit 加法字段 isFavorite/occasion/source；Person personalColorSeasonRaw
- 验收：四包 tests 绿 + 模拟器 build

## D30 [2026-08-03] 人体可视化：真人参考、不要动画
用户明确「不需要动画 要真人」：
- **不做** 体型过渡动画 / 抽象单色 croquis 主路径 / 自拍 VTON
- **做** 5 大众体型写实时尚目录站姿 PNG 作底图；FFIT→PopularShape 选图；围度仅轻微宽度缩放
- Core：`BodyAvatarLayout`（槽位锚点、z-order、scaler clamp、composer）
- UI：`BodyAvatarView` + `Resources/BodyAvatar/croquis_*.png`；Me → Body 页顶部预览
- 叠衣槽位仍为表达层色块/可选 asset；完整抠图叠衣与「不怪异」验收仍属 v1.x 精修

## D31 [2026-08-03] 体型 360° 多角度视图
用户要「全面 360 视图」：
- **8 静态帧**（每 45°）：`BodyAvatarYaw` + 资源名 `croquis_{shape}_yaw{000…315}`
- UI：拖拽 / 方位点 / 左右按钮瞬时切帧（`transaction.animation = nil`），不做插值旋转动画
- 资产：5 体型 × 8 角（0/45/90/135/180/225/270/315）均独立生成（hash 全 unique）
- 贴肤极简内衣（全裸生成被审核拦截）；叠衣层仅正面 yaw000 显示

## D33 [2026-08-03] 体型底图：乳贴 + 丁字裤（同一模特）
客户要最小遮挡、可叠试内衣：
- **唯一 basewear**：肤色乳贴 + 丁字裤（遮私密部位）
- **同一模特脸**（原 croquis 脸；禁止 image_gen 另起新人）
- 路径：先生成 pastie/thong 体态 → face identity 接回原脸 → 5 体型 × 8 角
- 资产：`Resources/BodyAvatar/croquis_*_yaw*.png`

## D32 [2026-08-03] 体型双轨录入：快选 + 实测
- **快路径**：5 大众体型图点选 → `popularShapeOverrideRaw` + source=visualPick；立刻 360；推荐轻加权 0.5
- **精路径**：胸/腰/臀/上臀 Stepper（in↔cm）+ 量法示意；上臀可「腰臀推断」→ provisional（加权 0.85）
- **R13**：合身 ease 仍要四围数字齐；仅快选不开 FitMark
- Onboarding 增加可选 Body type Picker（可 Skip）
- `BodyFitConfidence`：none / visualOnly / provisional / measured / mixed

## D34 [2026-08-03] 连续 BodyMorph（2D 分条，非 SMPL）
用户要「无级调节多指标、类游戏滑杆」：
- **不做** 真 3D / SMPL 网格（后置）；不做脸部大变形
- **做** `BodyMorphParams`（chest/waist/hip/shoulder/height）+ 纵向剖面 `horizontalScale(y)`
- 合成：测量优先 → 否则 5 体型 preset → 再 × fineTune（0.90…1.10）
- UI：`BodyMorphStripView` ~48 水平条 X 缩放；Me 页 Continuous fine-tune 滑杆实时预览
- 兼容旧 `BodyAvatarScale`（`legacyScale` / `from(legacy:)`）
- fine-tune 落库：`PersonBodyProfile.fineChest/Waist/Hip/Height`；滑杆 onChange 即时 save

## D74 [2026-08-05] 非东亚 7 表型 × 7 角矩阵闭合
- 非东亚 7×2×7（045…315）**98/98** 齐（末洞 `female_middleEastern_yaw225` 由 yaw180 小转过审）
- eastAsian 继续走通用 `photoreal_{sex}_yaw###` 轨道（D69）
- TF25 已发；本轮仅资产补洞，未再传 TF

## D76 [2026-08-05] TestFlight build 26
用户：**发**。
- 版本 **0.1.0 (26)**；archive/export OK；altool **UPLOAD SUCCEEDED**
- Delivery UUID `8cce71fe-be57-4cbc-ae7f-bbd51a7b1d4f`
- 含：D75 纸娃娃穿衣（displaySlot 叠衣/推荐/列表/FitMark 对齐、侧角淡出与 settle、空层/fitCaption/hasRenderableVisual）
- 测：Core 163 · Model 75 · UI 101 · Intake 7

## D77 [2026-08-07] 公开 API 接入（天气 / 商品 / 尺码参考）
用户要求：接好可用的公开 API（天气、衣物信息、尺寸等）。
- **天气：** `OpenMeteoWeatherProvider`（geocode + daily max °F，免 key）→ `CompositeWeatherProvider` 失败回退 `CityClimateWeatherProvider`；Today/Me 城市变更用 production 栈
- **商品：** `OpenProductFactsClient`（Open Product/Beauty/Food Facts 链式查询）+ `IntakeViewModel.enrichFromPublicBarcode`
- **尺码：** `PublicSizeReference` 公开对照表（明确 not brand-true；合身仍靠测量）
- 传输：`PublicAPITransport` / fixture 可测；禁止把付费 API key 写进仓
- WeatherKit 仍可选后续协议实现；不绑 SDK

## D78 [2026-08-08] TestFlight build 27
用户：**发**。
- 版本 **0.1.0 (27)**；archive/export OK；altool **UPLOAD SUCCEEDED**
- Delivery UUID `3c30f1d9-51ad-4e15-8c48-d7f1d7e92e96`
- 含：D77 公开 API（Open-Meteo 来源/降水提示、条码 Open Facts、尺码参考）；旅程 e2e 打磨（displaySlot 全链路、FitMark live、Search facets、Intake 诚实、Favorites 可发现、Export/Delete 文案等）
- 测：Core 177 · Model 88 · UI 122 · Intake 15

## D79 [2026-08-09] TestFlight build 28
用户：**发**。
- 版本 **0.1.0 (28)**；archive/export OK；altool **UPLOAD SUCCEEDED**
- Delivery UUID `09d8ffe1-2731-4ba7-a8ca-68638271e5e6`
- 含：p5/cloth-done 扫尾 — ModelSave 全链路诚实失败、fail-orange、空态 VO、Storage 列表、天气 Unavailable 清 cue、Favorites lookMetaLine、条码 lookup status 等
- 测：Core 177 · Model 101 · UI 143 · Intake 18

## D75 [2026-08-05] 纸娃娃正确穿衣：槽位纠偏 + 侧角淡出 + 空层提示
用户：**继续全功能打磨，纸娃娃是否可以正确穿衣**。
- **`displaySlot`**：脏数据纠偏（blazer/jacket/coat 误标 top→outerwear；dress/jeans/鞋类同理）+ `mapSlot` 别名（blazer/jeans/sneakers…）
- **`OutfitAvatarComposer`** 走 displaySlot；demo seed 外套槽 `outerwear`；程序化剪影可叠
- **Bugfix**：照片路径拖转只改离散 `yaw` 不同步 `yawDegrees` → 侧角叠衣不淡出；改为 `snapYaw`
- **Today UX**：空层胶囊提示；hero 副文展示 `wearSummary`（outer · top · …）
- 验收：Core 162 / Model 73 / UI 86 绿；work look 可 tee+blazer+裤+鞋同屏、z-order 正确

## D73 [2026-08-05] TestFlight build 25
用户：**发**。
- 版本 **0.1.0 (25)**；修 `torsoFrontPlateMaterial` 重复声明后 archive/export OK
- altool **UPLOAD SUCCEEDED** Delivery UUID `fcd039ee-3ab2-4435-a735-d7b06213b431`
- 含：D63–D72 catalog 丁字裤 / 多人种 / 多角 / 防换人 / Body 使用流程文案

## D72 [2026-08-05] 非东亚侧视闭环 + 更多背面
用户：**继续**。
- 非东亚 7 表型 × 2 性：**yaw045/090/270/315/180 = 14/14**（欧女 090 柔和侧姿；部分 270=090 镜像；女背本轮补齐 middleEastern/southAsian/southeastAsian/indigenous）
- ¾ 双角 14+14；男非 EA 背 **7/7**；女背 **7/7**
- ¾/背闭环：**非 EA 7 表型 × 7 yaw = 98/98**（含 135/180/225；末张 `female_middleEastern_yaw225`）
- 自有 yaw180 rotate 策略稳过跨人 face-lock；拒绝 bodysuit / 错脸 / 肤色串台

## D71 [2026-08-05] Body Avatar 使用流程定稿
用户：**仔细打造使用流程**。
- 文档：`docs/BODY-AVATAR-USER-FLOW.md`（状态机、Onboarding/Me/Today、双轨、隐私、验收）
- **客户路径** = 结构化档案 + catalog × morph；**禁止**客户 prompt 现场 gen 身体
- Me 文案：Nude base → **Model look / Your body reference**（对齐 D64 catalog bar）
- Prompt 仅内部资产管线；与 DESIGN 反 VTON / R13 激活门一致

## D70 [2026-08-05] 男性背面 yaw180 重出
用户：**继续 男性背面**。
- 正面 `image_edit`→背 **moderated**；`image_gen` 真背 + head profile **过** → face transfer 贴默认金标准脸
- 入库：`photoreal_male_yaw180`（替换旧 near-back）+ `eastAsian_yaw180` 同图
- 表型背：`photoreal_male_african_yaw180`、`photoreal_male_european_yaw180`
- 丁字裤背带可见；catalog 合规

## D69 [2026-08-05] 防换人 resolve + 表型 ¾ 起步
用户继续打磨「人都不一样」。
- **Core resolve**：非 eastAsian 且已有表型正面时，**禁止**回退到通用 sex×yaw（防换人）
- 表型 ¾ 起步 + 男 090 profile

## D68 [2026-08-05] 跨角锁脸 + 8 表型 catalog 正面
用户：**人都不一样了；要好多不同的人种**。
- **女 orbit face-lock**；**男 orbit face-lock** 多次 moderated
- **8 表型 × 2 性 正面** 全齐
- Me Phenotype 切换走专用正面

## D67 [2026-08-05] catalog 全 8 角闭环（不停试到齐）
用户：**继续试 不停不成功**。补齐 090/135/225/270。
- 结果：`photoreal_{female|male}_yaw{000…315}` **8×2 全在 bundle**
- 预览 + Tailscale 刷新

## D66 [2026-08-05] catalog 背面 yaw180 试出并入库
用户要求试背面。策略：保守 catalog 背视 + 丁字裤（非全裸）。
- ♀：`image_edit` 正面→背 **过审** → `photoreal_female_yaw180.png`
- ♂：正面 edit 背 **moderated**；`image_gen` 背 **过审** → `photoreal_male_yaw180.png`
- 预览 + Tailscale 同步

## D65 [2026-08-05] catalog 多角 + 缺帧 soft-hold 打磨
- 入库：`photoreal_female_yaw045/315`（pastie+thong ¾）、`photoreal_male_yaw045/315`（thong ¾）
- 男 ¾ 为 loop 后 gen 丁字裤（非 brief）；身份与正面可能略差，后续可 face-lock
- `BodyAvatarView`：有 yaw 帧用真切帧；仅有正面时 **soft-hold**（宽度压缩 + 卡片 3D 转）— **不再** 旋转时跳 `FullNudeBodyRaster`
- `AvatarCinematicExporter` 同样优先 catalog 正面 hold
- caption：hard-req 已满足时展示短 basewear 文案（非长 invariant）

## D64 [2026-08-05] catalog basewear：男女都是丁字裤
用户：**男女都是丁字裤**。废止「男 = brief / 三角裤」产品文案与规格。
- ♀：pasties + thong；♂：**thong**（not brief）
- `NudeBodyBaseSpec.maleBasewearDescription` / invariant / cert 文案 / Me 等待提示 / DROP 说明同步
- 男正面金标准已为侧绑带丁字裤（`photoreal_male_front`）

## D63 [2026-08-05] 用户选方案 2：D59 catalog basewear 锁定（废止 D60 全裸产品硬门）
用户对选项 **2** 确认：底座 = **真人照片 + 最小 catalog basewear**（后由 D64 定为男女丁字裤），非 mesh，非强制全裸。
- `coveringPolicy = minimal_basewear`；`allowsMinimalCatalogBasewear = true`；`requiresFullNude = false`
- `photorealFrontAssetsCertifiedCatalogBasewear = true`（bundle `photoreal_female_front` / `photoreal_male_front`）
- `isHardRequirementMet` = catalog cert + realHumanPhoto + 非 mesh 最终
- `mayUsePhotorealFrontAsset` 在 catalog 认证后开放展示
- `photorealFrontAssetsCertifiedFullNude` 仍 **false**（全裸 gen moderated；inpaint 不足 → 不翻）
- **禁止** 调度 loop / 后续 session 在无用户重批的情况下把 coveringPolicy 改回 `none` 或 `requiresFullNude=true`
- 全裸零遮盖降为 **远期 aspirational**，不是当前产品 bar

## D62 [2026-08-04] 腹侧写实皮肤卡 + certificationGaps + usdzip 探针
- **Torso plate**：`skin_torso_front_{sex}` 仅 navel 区贴 3D 腹前
- **`certificationGaps`**：产品缺口列表现随 D63 改为 catalog 路径
- **usdzip probe**：`Meshes/_pipeline_probe.usdz` 验证管道（非 nude_body_*）
- **主路径**：`primaryRenderMode = realHumanPhoto`；3D 模拟非最终

## D61 [2026-08-04] 多人种写实脸板 2×8 + USDZ Meshes 落点
- **Face plates**：`BodyAvatar/Face/face_{sex}_{phenotype}.png` 全 16 张；3D `attachFacePlate` 按表型选
- **USDZ drop-in**：`BodyAvatar/Meshes/`；仍无真实 nude mesh → 不翻 `photoreal3DMeshCertifiedFullNude`

## D60 [2026-08-04] 有机 ellipsoid 躯干 + 皮肤 normal map（3D interim）
- **几何**：腰/腹/肋/胸/臀高细分 ellipsoid；`partBaseScale` × morph
- **PBR**：`skin_normal` / `skin_normal_deep` 贴 `SCNMaterial.normal`
- 仍非产品最终视觉（D63 主路径 = 真人照片）

## D59b [2026-08-04] 肢体写实肤质投影 + 本地全裸 inpaint 实验
- **肢体/大腿 tile**：从 photoreal 臂腿裁 `skin_limb_*` / `skin_thigh_*` 等贴 3D
- **本地 inpaint**：抹 pastie/thong/brief **质量不足** → **禁止** 翻 `photorealFrontAssetsCertifiedFullNude`

## D58b [2026-08-04] 写实脸投影 + 多调皮肤 tile（3D interim）
- Face plates + skin tiles 按 phenotype；不冒充实拍主路径

## D60-loop [2026-08-05] （已废止）全裸硬门回正 — 被 D63 否决
调度 loop 曾把 D59 catalog 达标废止为全裸-only。**用户选 2 后以 D63 为准**，不得再自动回退。

## D59 [2026-08-04] 方案 2：最小 basewear 写实真人（可过审）— **D63 重新锁定**
产品 bar = pastie/thong/brief 真人照片；`isHardRequirementMet` 随 catalog cert。

## D58 [2026-08-04] 死要求再澄清：真人照片，不是网格
用户：**不是网格，是真人** / **真实写实 非模拟**。
- 主路径 = **认证真人照片**（D63：catalog basewear）+ morph + 多角切帧（非 SceneKit mesh）
- `primaryRenderMode = .realHumanPhoto`
- `allowsMeshOrSimulationAsFinalVisual = false`
- `BodyAvatarView.usesMannequin3D` 默认 **false**
- 360 = 多角度真人图，不是网格旋转

## D57 [2026-08-04] 死要求升级：写实 3D 真人全裸（非胶囊最终态）
用户：**死要求 写实3d真人 无遮盖nude**（后由 D58 澄清为 **真人照片** 非网格）。
- `NudeBodyBaseSpec.requiresPhotorealRealHuman = true`
- `allowsProceduralCapsuleAsFinalVisual = false`
- Me 显示 hard-requirement 未满足警告

## D56 [2026-08-04] TestFlight build 24
- Archive/export OK after re-import Dist cert into `closet-tf` keychain（errSecInternalComponent 修复）
- altool **UPLOAD SUCCEEDED** Delivery UUID `f8670c42-31c3-49d8-975e-06fcf8a18347`
- CFBundleVersion **24** / 0.1.0 — 含全 nude 程序化 3D + 多人种 + hybrid 门控（写实 pastie 图未认证不展示）

## D55 [2026-08-04] 全 nude 零遮盖 + 多人种（升级 D54）
用户：**不允许任何遮盖、全 nude**；**适合多人种**。废止 pastie/thong/brief basewear。
- `NudeBodyBaseSpec.allowsAnyCovering = false`；coveringPolicy = none
- `AvatarBodyPhenotype`（8 表型肤色/发色）+ `PersonBodyProfile.presentationPhenotypeRaw`
- 3D 程序化去掉 pastie/thong；Me 增加 Phenotype 选择
- 写实资产优先 `photoreal_{sex}_{phenotype}_front`；禁止 token 含 pastie/thong/brief/bra…
- 备注：存量 GPT 图若仍带遮盖需重出全裸多人种；App Store 全裸需自行评估

## D54 [2026-08-04] nude 底座 = 死要求（硬不变量）
用户明确：**要求 nude，死要求**。写入代码级契约，不可再滑向穿衣模特 / 内衣套装 / 塑料假人。
- **Core**：`NudeBodyBaseSpec`（后由 D55 升级为 **全裸零遮盖**）
- **USDZ 规范名**：`nude_body_female|male`（兼容旧 `mannequin_body_*` 别名）
- **UI 文案**：Me / caption 直接展示 invariant；衣服 **只** 作为叠衣层
- **禁止**：bra+panty 成套当底座、clothed dummy、ivory plastic 主路径
- 仍非自拍 VTON / 无授权 SMPL

## D52 [2026-08-04] GPT 写实 nude 生图 + 正面/3D 混合
用户要求用 GPT 生图综合资源。按 `BODY-AVATAR-IMAGE-PROMPTS` 跑通：
- 女：gen pastie+thong → face lock 原 croquis 脸 → 金标准正面；¾（045/315）可过；**侧/背 90/180/270 content-moderated**
- 男：gen 肤色 brief 正面 + refine
- 入库：`photoreal_female_front` / `photoreal_male_front`；刷新 `croquis_hourglass_yaw000`
- **渲染混合**：正面优先写实 PNG+BodyMorph；转开淡入 SceneKit 3D 底座（补被审核拦的侧背）
- 原料：`app-shell/build/gpt-body-2026-08-04/`

## D51 [2026-08-04] 人体底座改写实 nude 3D（弃 AI croquis 农场）
用户：人体仍大问题 + 要男性；AI 多帧 croquis 不稳 → **另寻方案**。裁决：**轻量 3D**，且必须是**写实真人 nude**（非象牙塑料假人）。
- **做**：SceneKit 程序化人体（暖肤 PBR + 棚拍光）+ 女/男比例底座 + 连续 yaw；`MannequinSegmentScales` 接 BodyMorph；basewear 仍 **乳贴+丁字裤**（女）/ 肤色低腰遮挡（男）— App Store + 叠试内衣
- **Core**：`AvatarBodySex` / `MannequinSegmentScales` / `MannequinGarmentVisibility`
- **UI**：`Mannequin3DView`；`BodyAvatarView.usesMannequin3D` 默认 true；Me **Sex** 分段；`PersonBodyProfile.presentationSexRaw`
- **不做**：SMPL 无商用授权；自拍 VTON；再扩 5×8 AI croquis 出图流水线
- **后续**：锁定商用/自研 photoreal F/M 网格（USDZ）替换胶囊近似，达到照片级写实

## D53 [2026-08-04] USDZ mesh lock-in + 程序化 anatomy 升级
body-first 打磨：胶囊假人仍是最大 fidelity gap。
- **Core** `MannequinMeshCatalog`：稳定资源名 `mannequin_body_female|male.usdz`、segment 节点名、`resolveSource` 优先 USDZ
- **UI** `Mannequin3DView`：bundle 有 USDZ 则加载并规范化身高；否则程序化 fallback 升级——发量、男 pecs、下颌/耳/鼻、肩膝衔接、clearCoat 肤质
- **资产**：尚未入库真实 USDZ（许可/采购待决）；有文件即零代码切换
- **不做**：SMPL、再扩 AI croquis 农场

## D50 [2026-08-04] 乳贴乱飘 / 人物变形修复
根因：①乳贴实测 y≈0.22–0.45，平坦带只盖 0.29–0.41 → 贴片上半被行梯度剪切；②warp 用**输出行 y**取剖面 + 纵向 height 非均匀采样 → 贴片纵移「飘」；③3D 倾角过大。
- PastieBand **0.22–0.46** / ThongBand **0.46–0.62**；剖面更阻尼
- Raster：**源图 y** 取 scale；height 改整体 `scaleEffect`，不做行级纵移
- 景深 3D 倾角减半；scale 夹紧 0.92…1.08；缓存 key v3

## D49 [2026-08-04] 叠衣肩线贴合
- `BodyAvatarAnchors` 槽位框收紧；`BodyAvatarLayer.fitScale/fitOffsetY` 默认上装上移放大贴肩
- `GarmentLayerNormalizer.contentRect` 与锚点同构；UI 叠衣顶对齐 + clipped
- 视觉 croquis 3/4 角「white」指标多为软肤边缘误报，洋红合成已干净

## D48 [2026-08-03] loop 打磨：脚底灰影 + morph 预乘采样
- 实测 pear 侧视脚底灰 blob：低饱和 flood 清理全部 yaw090/270
- BodyMorphRaster 预乘双线性采样，边缘更干净
- 去掉假地面反射；Reduce Motion；hero 换场合 `.id` 重建

## D47 [2026-08-03] 全面打磨 workflow（资产+合成+无障碍）
- 资产：全 croquis 微抛光（fringe kill + 护发丝）；contact sheet QA（work/date×5 体型 + 洋红）
- 合成：视差幅度回落防飘；接触影随画布；弱反射；`Reduce Motion` 关 ambient/陀螺 3D
- 缓存：`BodyMorphImageCache` key `v2` 避免旧白边驻留
- 脚本：`croquis-polish-alpha.py` 可复跑

## D46 [2026-08-03] croquis 切边实测打磨（去白/灰边）
真机/合成实测主问题：透明 PNG 仍带 **白边贴纸感**（date/gala 深色底最明显）。
- 从 pre-alpha RGB 重跑 `croquis-polish-alpha.py`：flood + 最大连通 + 1px erode + defringe + 白/灰 fringe 清零
- 指标：正面 white_halo≈0（原千级 soft gray 边）；脚本可复跑
- UI：去掉强 rim 白描边 / 降低背景 blur 与地面反射，避免二次加边

## D45 [2026-08-03] 叠衣归一 + date 空中景 + 2s 电影分享
1. **叠衣服帖**：`GarmentLayerNormalizer` 入库时紧 bbox + 512×768 槽位肩/腰/脚对齐 PNG；UI 槽位顶/底对齐 + 外套略放宽
2. **date 背景**：去掉近景蜡烛，改为空中景玫瑰金 bokeh + 净地
3. **分享预览**：`AvatarCinematicExporter` 约 2s H.264（yaw 往返 + 背景视差 + 正面叠衣）；Today 英雄区 film 按钮 → ShareSheet

## D44 [2026-08-03] 场合位图背景 + 人像分离（效果优先续）
- 5 张写实场景 PNG：`Resources/Backdrops/backdrop_{studio,work,date,gala,casual}.png`（768×1152）
- `AvatarBackdropView` 位图优先，程序化渐变托底；脚区压暗 + 体积光/bokeh
- 人体：轮廓 rim + 色边 shadow + 地面弱镜像反射；cinematic 视差幅度加大
- Today 英雄卡：场合色描边 + 底洗；切换 occasion 淡入

## D43 [2026-08-03] 景深立体预览（效果优先，非 GIF）
用户「效果第一」：要景深 3D 照片感，但主路径不用 GIF。
- **做**：分层视差 `DepthParallax`（背景虚化位移 > 人体 > 前景雾）+ 体积光场合底 + 脚底接触影 + 轻 `rotation3DEffect`
- **驱动**：CoreMotion 姿态 + 拖拽叠加 + 静置微幅 ambient 呼吸；hero=`cinematic`，Me=`subtle`，列表缩略=`off`
- **不做**：GIF 主资产、替代 8 帧 360、SMPL、把叠衣烤进动画
- 360 仍瞬时切帧；立体是「当前帧站在场景里」的增强

## D42 [2026-08-03] 体型 croquis 透明底 + 场合背景层
- 问题：各 croquis 烤进的棚灰/底色不一致，换场景会露脏边
- **资源**：`croquis_*.png` → RGBA 透明（flood + largest-component + edge decontam）；脚本 `app-shell/scripts/croquis-to-alpha.py`
- **Morph**：`BodyMorphRaster` OOB / 源透明填 **alpha0**（不再填棚灰）；`format.opaque=false`
- **UI**：`AvatarBackdrop`（studio/work/date/gala/casual）叠在人体下；`BodyAvatarView.backdrop`；Today 跟 `vm.occasion`，Favorites 跟 `occasionRaw`
- 以后换真实场景图只换 Backdrop 层，不重烤 croquis

## D41 [2026-08-03] 数据生命周期：全量导出 + 删除全部（CCPA）
- `DataLifecycleService`：JSON 全实体导出（schemaVersion=1）；身体围度默认不含、显式勾选才含
- 删除全部：清 Person/Wardrobe/Item/Outfit/Wear/Plan/Location/BodyProfile + ItemImages；回执 summary
- Me → Data：Export my data / Delete all data（confirmationDialog）+「卸载 ≠ 删除」教育文案
- 原图 ZIP 打包后置（路径已在 JSON）；再导入列 v1.x

## D41b [2026-08-03] Today 首屏 = Avatar + 今日 look（方案 B）
- 非「纯试衣间」：机制仍 D19 copilot；Avatar 为表达层
- 大 `BodyAvatarView` 展示 selectedSuggestion（或锚定件）；列表「Other looks」点选切换
- 非冷启动 bootstrap 默认 full-auto 拉首条 look；Save/Plan/I wore 挂英雄区
- 打磨：compactChrome 360、英雄卡片阴影、横滑锚定、look 1/n 翻页、冷启动一键种子、场合变更自动刷

## D40 [2026-08-03] 纸娃娃叠衣：入库图叠到体型
- `BodyAvatarLayer.localRelativePath` + `OutfitAvatarComposer`（dress 压制 top/bottom）
- Today 建议卡左侧迷你 `BodyAvatarView` 叠层预览（非 VTON）
- 收藏列表同样展示；无图槽位用色块占位

## D39 [2026-08-03] 入库真机链路：相机 + Vision + 本地图
- `Item.localImageRelativePath` + `ItemImageStore`（Application Support）
- 确认入库写抠图；Closet 网格/详情缩略图
- `IntakeServiceFactory`：真机非模拟器 → `VisionMattingService`，否则 mock
- `AddPieceSheet`：相册 PHPicker + 相机 UIImagePicker + 手填 + 确认预览

## D38 [2026-08-03] BodyAvatar 棚灰统一 + 写实精修 + PHPicker
- 全库 croquis 低色度灰区 → 统一 cyclorama（角点 span ~60→~5；脚本 `unify-body-studio.py`）
- 5 体型正面 + 若干角度 image_edit 写实 pass（保留乳贴/丁字裤；侧角偶发 moderated 则保留棚处理版）
- UI 画布 / morph 填色对齐 RGB≈158
- Closet「+」→ `AddPieceSheet`：Photos PHPicker + mock 打标 / 手填

## D37 [2026-08-03] 本地 v1.0 功能补全波
闭合 placeholder / 服务未接线项（仍不做真机云）：
- CalendarView：收藏排期、needsAttention 过滤、删除
- Me：城市、PersonalColorSeason、StorageLocationsView
- Closet：状态过滤 + FitMark 网格徽章；详情注入 bodyProfile
- CityClimateWeatherProvider：离线城市气候 → Today 温区（WeatherKit 后置）
- Copilot onAppear：天气 + bodyShape 注入

## D36 [2026-08-03] 乳贴+丁字裤：保留装，修变形层
产品硬约束：**保留乳贴与丁字裤**（不靠去装躲问题）。
- **根因**：多层 SwiftUI mask+scale 碎裂 + 胸/髋带行梯度剪切贴身件
- **修 v2**：`BodyMorphRaster` **扫描线双线性 warp**（无 crop 接缝）；RGBA 无损解码
- **保护带**：乳贴 y∈[0.29,0.41]、丁字裤 y∈[0.48,0.58] **平坦** scale；smoothstep 过渡
- 中性 morph 直出原 PNG；预设幅度收紧；位图缓存；去掉 drawingGroup 二次栅格

## D35 [2026-08-03] TestFlight build 4/5 签名与导出
- Archive：仅 App 目标 Manual + profile `Closet App Store TF2`（勿 CLI 全局 `PROVISIONING_PROFILE`，会污染 SPM 资源包 ClosetUI_ClosetUI）
- Export：PATH 须优先 `/usr/bin`（Homebrew rsync 3.x 不认 Apple rsync `-E` → "Copy failed"）
- Build 4 Delivery `1971ce14-573b-4b50-857a-fbdbbb58f7ad`（BodyMorph）
- Build 5 Delivery `d4a70b44-09d3-4e38-a73f-6fa3f48428ed`（fine-tune 持久化）

## D80 [2026-08-10] 打磨波不变量固化（15 轮 polish loop 收敛，~110 surgical fixes）
用户授权自主打磨 loop；产出中以下约定升级为代码级不变量（四包 **580 tests**：Core 206 / Model 149 / UI 187 / Intake 38）：
- **保存失败原子性**：一切写路径 = snapshot + 操作 + 失败 `ModelSave.rollback` + 内存态恢复；删除-only 路径失败留 dirty marker，**不假装成功**；禁止 mid-operation save；测试钩子 `ModelSave.forceFailure` / `ItemImageStore.forceFailure`。
- **脏输入 = 缺失**：NaN / 0 / 负值一律 nil / 中性处理，**禁止自信兜底**（FitEngine / FFITClassifier / ColorHarmony / WeatherFit / BodyMorph / FFIT）。
- **UI 诚实**：`lastError` 与 `statusMessage` 互斥——有错误时不得残留 success 文案。
- **竞态收敛**：异步管线 generation counter，last-call-wins（Intake、hero 渲染、天气刷新）。
- 同时固化：displaySlot hint 排序 / composer 确定性 / zIndex 钉死；删除级联与 deleteAll 走 `ModelSave`；导出 id tie-break 确定性；跨柜不变量所有入口强制。
- 后续 waves 若需破例，须新增 ADR 说明，不得静默回退。

## D81 [2026-08-10] 打磨波续：a11y / 测试隔离 / 文案统一 / 工具链
D80 收敛后增量打磨（commit 粒度），不新增产品功能，仅抬升质量底线：
- **文案统一（80081fb, 2e8929a, fb33e15）**：失败 toast 标点统一、空态标题、「Load samples」文案、共享 stale-check-in 常量、导出失败口吻。
- **a11y（b9d6ae1, ecdb7aa, 5d50eb7）**：`.combine` 只圈文本列、CTA 独立 VO target（入库拍摄 + Closet/搜索/日历空态）；hero orbit `accessibilityAdjustableAction`（`orbitAdjustableStep`）；tap target 下限 `orbitDotHitArea=24` / `lookPagerChevronHitArea=44` / `measureStepperHitArea=44` / `orbitChevronHitArea=44`。
- **测试质量（cf98879）**：`ITEM_IMAGE_ROOT` per-process 临时目录隔离；异步测试 rendezvous 替代 wall-clock sleep。
- **工具链（bd8ca35, 09322f9）**：脚本可移植化、ASC 凭据走 env（`.env.asc`）、xcodegen 前置 guard、pyc 出跟踪 + gitignore。
- 测试数 **580 → 586**（Core 206 / Model 149 / UI 193 / Intake 38；增量来自 a11y 两波）。后续同类波按 commit 追加，不再逐波计数。

## D82 [2026-08-11] Avatar 资产 shape 维度 + 试衣间（用户拍板：B 方案 + 正面档 + 试衣间）

用户反馈四条主诉（体型×人种覆盖不够 / 转角换人换细节 / 无法换装试穿 / 细节需筛查）→ 完整侦察后拍板：

- **换人根因**：默认表型 eastAsian 仅有正面帧（F 1/8、M 2/8），D69 防换人守卫对 eastAsian 显式豁免 → 转角回退通用轨（另一人）。**选 B 方案**：保留现有 eastAsian 脸，按锁脸流程重出 13 张转角图（清单 = `PhotorealInventoryQATests.matrixGapsExactlyMatchKnownPendingList` 账本；落盘后删豁免）。
- **体型维度**：photoreal 命名新增 shape token（`photoreal_{sex}_{phenotype}_{shape}_{front|yaw###}`），resolve 链 shape 专属 → 表型 → 通用（D69 不变）；shape 真图命中时 `BodyMorphParams.removingShapePreset` 旁路 preset warp（防双重效果，用户微调保留）。**选正面档**：出图 64 张（rectangle 视基础帧近似后补），任务清单入 BODY-AVATAR-IMAGE-PROMPTS §10。
- **资产 QA 门**：`PhotorealInventoryQATests`——矩阵账本（缺格==已知待补，防再漏）、严格 2:3 尺寸（已修 `photoreal_female_african_yaw045` 765×1099 孤例）、命名白名单合规。croquis 轨确认为渲染死代码，手册 §8/§9 改写为 photoreal 命名。
- **试衣间**：`FittingRoomViewModel/View`（Closet 工具栏 tshirt 入口）——按槽位挑本柜单品（displaySlot 纠偏、裙↔上下装互斥、跨柜静默拒绝）→ 纸娃娃正面上身（与推荐/收藏同一条 composer 链）→ 存收藏（source=fittingRoom，失败保留选区诚实提示）。侧背叠衣是结构性缺口（无 per-yaw 层图），另立项。

## D83 [2026-08-11] 单品属性录入面（解封推荐三条链）

完整性审计 A1-2/3/4：温区 / 颜色 / 风格属性**无任何录入 UI**，且 quick-add 硬编码
`Warmth.light` + `colorIsNeutral=true`。后果不是「少个字段」而是**推荐引擎在真实数据上空转**：
天气硬过滤（<50°F 时 light 全被滤掉 → 冷天必空）、配色协调与 60-30-10 打分（恒中性）、
体型加权（attributesRaw 全仓无生产者 → affinity 恒 0）。demo seed 因写了这些字段而掩盖问题。

- **Core**：`GarmentAttributeCatalog` —— `Warmth.displayTitle/entryHint/ordered`、
  `StyleAttribute.displayTitle/entryGroups`（分组必须覆盖全部 case，有测试守）、
  `GarmentColorPalette`（16 色板：中性 7 + 彩色 9；id 稳定可落库、`nearest` 回读选中态、
  中性与彩色互不串台、脏值/nil 返回 nil 不瞎选）。
- **Model**：`ItemEditorService.Patch` 加 `attributesRaw`（allowed-set 守卫 + 去重排序落库）、
  `colorHue/colorIsNeutral/replaceColor`（hue 必须有限且 ∈[0,360)）、`replaceWarmth`
  （nil 默认「不动」，整表提交才解释为「清为未知」）；失败快照恢复覆盖三个新字段。
- **UI**：`QuickAddDraft` 把快速添加落库抽成可测值类型（**未选 = 未知**，不再替用户假设）；
  `ItemDetailViewModel` 加载/保存三属性；控件 `WarmthPicker`/`ColorSwatchPicker`（44pt 命中区）/
  `StyleAttributePicker` 复用于详情页与快速添加。
- 端到端锁：录入 → `toCandidateItem` → 体型 affinity > 0（此前恒 0）。测试 662 → 677。

## D84 [2026-08-11] Schema 单向门落地（VersionedSchema + 指纹 golden 差分）

DESIGN §11.1 把「v1 起启用 VersionedSchema + SchemaMigrationPlan」标为 **blocking 单向门**，
MVP-PLAN M0 退出门要求「schema 过加法式单向门守卫测试」——此前全仓零实现（裸 `@Model` +
app-shell 手搓 `Schema([...])`）。本次落地并经对抗审查（3 簇蓝图全 REJECT，整改后实施）：

- **装配单一入口** `LoomiesStore`（ClosetModel）：`LoomiesSchemaV1: VersionedSchema`（v1.0.0）+
  `LoomiesMigrationPlan`（v1 无前驱故 stages 空；v2 起 append lightweight stage）+
  `makeContainer()`。app-shell 由手搓实体清单改为一行 `LoomiesStore.makeContainer()`——
  此前实体清单存在两处，加实体漏改一处即启动崩溃。
- **D5 域隔离载荷（审查 CRITICAL）**：两个 `ModelConfiguration` 必须**各带子 schema**
  （`Schema(mainModels)` / `Schema(localModels)`），都传 fullSchema 会让两个 store 都建全量表、
  身体数据落进主库。有行级测试 `configurationsCarryDomainSubschemas` +
  `bodyProfileRowsStayInLocalDomain` 守。config 的 `name`（main/local）派生 store 文件名，**禁止改名**（改名即丢已发布用户数据）。
- **单向门形态**：`ClosetCore.SchemaFingerprint`（纯字符串差分，可表驱动穷举反例）+ 入库 golden
  `Fixtures/SchemaFingerprint-v1.txt`（85 行 = VERSION + 8 实体 + 61 属性 + 15 关系）。
  规则：golden 每行必须逐字仍在（删字段/改类型/收紧 optional/改 rule/改 inverse/改 domain
  统由「旧行消失」覆盖）；新增行须加法安全；versionIdentifier 变更 = destructive（不得静默）；
  golden 畸形（缺 VERSION/孤儿行/未知 kind/重复行）也判 destructive。
  **record 模式先差分后写盘**——破坏性永不落盘，一条环境变量洗白不了删字段。已实证：
  模拟丢字段 → DESTRUCTIVE 硬失败，恢复后回绿。
- **加法安全规则采 OR 口径的显式裁决**：DESIGN §11.1 散文写「新字段一律 optional + 默认值」（AND），
  但 `Entities.swift` 头注释与实际基线是「所有属性 optional **或**带默认值」（`id: UUID = UUID()`、
  D82 的 `dayKey: String = ""` 皆非 optional 但有默认）。AND 会否决项目自己既有的加法模式。
  技术正解是 OR（迁移时每属性都要有值：可空 或 有默认），故守卫按 OR 实现，
  并同步修订 DESIGN §11.1 措辞与 Entities 头注释一致。
- **反直觉实测（不落盘下次必重踩）**：`Schema.entities`/`.attributes` 迭代序**不是**声明序 →
  指纹必须排序；`id: UUID = UUID()` 的 `defaultValue` 每次运行都是新随机值 → 只能记
  `hasDefault` 布尔；`ModelConfiguration.CloudKitDatabase` 不可 `==` 比较 → 用 describe 断言。
- **DoD 含 app-shell 真编译**（审查 HIGH：app-shell 不参与 swift test，文本 lint 不算数）：
  `xcodebuild -scheme ClosetApp -destination generic/platform=iOS` **BUILD SUCCEEDED** 已验证。
- 顺带修掉一个 flake 源：`CinematicExportGateTests` 触盘却缺 `ItemImageTestRoot.install()`。

## D85 [2026-08-11] 零 UI 入口接线（波 A 删柜/删人 · 波 B 位置树）

完整性审计 A2：六项服务能力全就绪且带级联测试，却零 View 调用点——用户根本用不到。
本波接通前两项，不新增业务语义，只做「入口 + 诚实文案 + 可测 helper」。经对抗审查整改：

- **删衣柜 / 删人**（Me → 「Closets & people」）：滑动删除 → 二段确认。
  - 结果类型 `DeleteOutcome` 带**类型化** `blockedReason: DeleteError?`——View 靠它判定
    是否升级到「Delete anyway」，**不得**用 `message ==` 字符串相等（审查 MEDIUM：
    日后润色一句阻断文案，两段流程会静默失效且无测试会红）。
  - 确认对话框持**值类型快照** `PendingWardrobeDelete`（id/name/itemCount/lookCount/planCount）：
    **绝不在 @State 里持 @Model**（审查 HIGH：对话框消散动画期间仍会重新求值 title/message，
    读已 `context.delete` 的模型属性是未定义行为）。动作按 id 现取现用。
  - force 警告完整告知级联面**含 CalendarPlan**（审查 MEDIUM：`deleteWardrobe(force:)` 会删
    绑定的日历计划，用户排好的计划会无声蒸发——不得声称做了没做的事，也不得隐瞒做了的事）。
  - 失败着色改由返回值 `isFailure` 驱动（审查 HIGH：旧的 `CustomerFlashStyle` 关键词嗅探只认
    couldn't/failed/missing，对「This is the closet you're in.」这类诚实阻断会误判成成功色）。
  - **当前打开的衣柜不可删**（行内标 Current，无删除动作 + VO hint 说明原因）：避免上层持有
    已删模型、以及删到零柜回落 Onboarding 造重复 Person。代价：单柜用户删不掉唯一衣柜（可改名/清空）。
- **存放位置树**：`listWithDepth` 深度优先带层级 + 父节点 Picker（此前只能建根节点，
  §F3 的「挂区/抽屉/换季箱」树形语义无入口）；行按 depth 缩进 + `StorageRowCopy.accessibilityLabel`
  把层级读给 VoiceOver（缩进的视觉信息 VO 不可达）。
  - `siblingNameConflicts` 抽为 public 并在**提交前**判重，把重名从笼统的
    「Couldn't add — try again」升级为诚实的「A location with that name already exists here.」
  - 审查 LOW 修复：父层判定必须显式分支，`parent?.children ?? 根层` 在 children 为 nil 时会拿
    根层当兄弟 → 「父节点下新建与某根节点同名」被误报重名（客户可见的谎）。有测试锁。

## D85 波 C/D [2026-08-11] 跨柜检索 · 合身反馈与手动打卡

- **跨柜检索**（Closet 搜索栏分段控件，仅多柜时出现）：`SearchScope` 本柜/全部。
  - 跨柜结果行显示所属衣柜（可见 + VoiceOver 同源）；**合身标记按该单品所属柜主人**取
    身体档案——此前固定用当前柜主人，跨柜结果的 FitMark 是错配的。
  - `clear()` 一并复位 scope 与 hasOtherClosets（审查 MEDIUM：清空后仍停在跨柜而无提示，
    与「安全默认」的自述矛盾）；`clearFiltersKeepingScope()` 供 chips 用；
    每次打开搜索显式回到本柜——描述与实现必须一致（UI 诚实同源）。
- **合身反馈 + 手动打卡**：只保留**一套**打卡语义。
  - `CheckInService.setFitFeedback` 是合身反馈的唯一写入入口（FitVerdict 校验 + 快照回滚 +
    空白即清除）；`CheckInViewModel.checkIn` 不再把 fitFeedback 透传给 `recordWear`
    （审查 LOW：两条写路径只有一条有校验，UI 一改就能让脏值绕过守卫）。
  - `CheckInView`（Today 控制卡次级入口「Log what I wore」）复活了此前零调用点的
    `CheckInViewModel.toggle/isSelected/checkIn`；可选包含洗衣/外借件；只记今天
    （DESIGN §F5 措辞；补记过去日期是 v1.x）。关闭后刷新防重复窗口。
  - v1.0 **只采集不消费**：不喂 FitEngine、不改推荐，文案不得暗示会改变推荐；
    但会随 Export my data 导出（`WearRecord.fitFeedback` 在导出快照里），`exportDisclosure` 如实告知。
- 顺带修一个真 race：`sweepTemporaryExports` 扫共享 tmp，与并行的导出测试互删文件
  （实测触发一次失败）→ 扫描目录改为可注入，测试用私有目录。

## D86 [2026-08-11] 产品外壳合规（出网面披露 · 遥测 opt-in · 帮助/政策/署名 · 身体数据同意）

§10.6 承诺的外壳未闭合项。对抗审查在本簇抓到一条**讽刺的 HIGH**：拟新增的合规文案
自身含不实陈述——文案说「your closet contents never leave」，而 `IntakeViewModel` 的生产
默认 `productLookup: OpenProductFactsClient()` 会把用户扫到的**条码**（= 用户拥有的具体商品
身份）发往 Open*Facts。据此整改：

- **出网面单一真相** `NetworkSurfaceCatalog`：逐条登记 host + 发什么 + 何时发 + 怎么关。
  对账测试把「禁用词黑名单」升级为**出网面对账**——客户端实际会请求的每个 host
  （`OpenProductFactsClient().hosts` + Open-Meteo 两个）都必须在披露清单里，
  新增出网面而文案未更新即红。
- **合规文案单一真相** `ComplianceCopy`：隐私摘要（不再有「never leave」这类无据绝对化）、
  FAQ（含「What leaves my device?」）、逐项开源署名（名称排序 + 许可 + 用途，§4.3 红线）、
  政策链接（HTTPS 断言）。新增 `HelpView`（Me → Privacy → Help & FAQ）。
- **遥测门** `TelemetryGate`：此前 `sanitize` 是零调用点死代码，而 About 已承诺 opt-in 控件
  存在（不实陈述）。现在：opt-in 默认关闭 + 唯一发送出口 + sink 协议只收已净化载荷
  （「绕过白名单发事件」在类型层做不到）；生产**无 sink**，状态行如实写
  「Nothing is sent yet — no analytics service is connected in this build」。
- **身体数据同意** `BodyDataConsent`（DESIGN §2.2）：门在 `OnboardingViewModel.finish` 的
  **任何 insert 之前**（审查 CRITICAL：原设计放在 `if hasMeasures || hasPick` 分支里，
  此时 person/wardrobe 已 insert 且关系已连，return false 会留脏标记污染下一次无关 save）；
  有 `!ctx.hasChanges` 断言守。仅**围度**受门约束，体型快选不设路障。
  `BodyProfileView` 未同意时先出说明卡再进录入面。
- 受契约变更影响的既有 onboarding 测试同步更新为「先授权再落围度」（审查 HIGH 点名的 7 个用例）。
- app-shell `xcodebuild` BUILD SUCCEEDED（装配路径未变，仍作 DoD 硬条件）。

## D87 [2026-08-11] 数据导出补原图 ZIP

§10.6 spec 写的是「JSON 全实体 + 原图 ZIP」，此前只出 JSON——而 JSON 里的
`localImageRelativePath` 是指向沙箱的死路径，用户拿到一串打不开的路径，
数据可携带性不诚实。按对抗审查的两条 HIGH 整改：

- **压缩不上主线程**（审查 HIGH：原设计把 `writeBundle` 放在 Button 闭包里同步调用，
  几百张图会阻塞数秒至数分钟，无进度无取消且按钮可重复点）：两段式——
  `plan`（MainActor，读 SwiftData 出值类型计划）+ `writeBundle`（nonisolated，
  UI 侧 `Task.detached`）；进行中禁用按钮并显示 `bundleInProgressMessage`。
- **`sharePayload` 与诊断导出共用**（审查 HIGH：整体换成 ShareItem 会连带打断诊断路径）：
  `ShareBox` 改为「文本或文件」二选一，诊断仍走文本路径不受影响；文件路径在
  分享面板关闭时清理（与 cinematic MP4 同纪律，临时文件不得无界积累）。
- Foundation-only 压缩：`NSFileCoordinator` 的 `.forUploading` 对 staging 目录产出 zip，
  无第三方依赖。归档结构 `data.json` + `photos/<itemID>.<ext>`，文件名排序确定（可复现）。
- 韧性：反向孤儿（行指向已消失文件）在 plan 阶段跳过；单张拷贝失败不炸整包——
  诚实地少一张，胜过整个导出失败。staging 目录用后即删，只留 zip。
- 顺带修一个自己写的松断言：`!json.contains("34")` 会因 UUID 随机含 "34" 而时红时绿，
  改为断言字段名 `bustInches`。

## D88 — 交付复审：25 项发现全部关闭 + 七道结构性门（2026-08-12）

**背景**：D83-D87 交付后跑了一轮对抗式复审（4 个交付验证 agent 逐项追「用户能不能真点到」
+ 2 个横切扫荡）。结论刺眼：**本项目的历史病根在我自己的这一波里复发了，而且被我自己的文档背书成已交付**。

**最具代表性的一条**：D83 的核心修复（温区/颜色不再硬编码）接进了 `QuickAddSheet`——
一个自 46dc6ff 起零呈现点的死 View。用户真正点到的「Enter manually」照旧写
`Warmth.light` + `colorIsNeutral = true`，冷天推荐照样必空、配色打分照样恒中性。
commit message、decisions.md、ARCHITECTURE.md 三处都写着「已修」。

**决策：靠门，不靠人眼**。每个单点看都对，是复审才能发现的那类错误。新增七道结构性门：

| 门 | 防的是 |
|----|--------|
| 孤儿 View 棘轮（精确集合） | 「能力就绪 + 有测试 + 零调用点」；已知死 View 钉死，清单只减不增 |
| 伪造默认值扫描 | 入库路径替用户假设温区/中性色 |
| 表现层 `context.delete` | create 失败用 delete 而非「断关系 + rollback」 |
| 客户文案词汇（剥插值后判） | closet/wardrobe 词汇漂移；门自带「能抓到真违规」的自证测试 |
| 遥测事件产出方 | 白名单里定义了事件却没人发 = 安慰剂开关 |
| 出网 host 运行时对账 | 手抄的镜像字面量：改 host 不会红 |
| 盘上库升级路径 | 已发布用户冷启动 fatalError（此前只测了 inMemory） |

**其余关闭项**（择要）：删柜判空只看单品数 → 有 look/计划时谎称「empty」并级联删除；
两层 `.confirmationDialog` 同 runloop 切换被 SwiftUI 吞掉 → 收敛为一次确认；
合身反馈保存失败被 `_ =` 吞掉 → 表单干净关闭等同成功；身体数据同意门只画不关
（说明卡下面的录入控件全部可用且点一下就落库）→ 门下沉到 view model 的 insert 之前；
中性色单向门（选了 Black 重进显示未选，且再改不回未知）；「删除全部数据」不清同意位；
位置树删除静默提升子节点并可撞出同名兄弟；导出对部分失败完全静音、临时目录永久泄漏。

**补的产品面**：穿着历史回读。打卡此前**只写不读**——全 App 无界面 fetch `WearRecord`，
合身备注点错一次就永远改不回来，与 copilot「用户掌舵、推荐可覆盖」直接冲突。

**教训**：交付后的对抗式复审不是可选项。同模型自审看不见自己的盲区，
而「有测试 + 文档写了」恰恰是最容易掩盖零调用点的组合。

## D89 — 切换器唯一真相 + 防重复语义定夺（2026-08-12）

**#8 切换器被平行实现旁路**：`WardrobeSwitcherViewModel` **零生产调用点**——
app-shell 自己写了一套 Menu，于是 VM 的重名守卫、(name, id) 排序、owner 归属校验
全部形同虚设；同名衣柜在菜单里是两行一模一样的文字，用户无从选择。
更说明问题的是：D88 我把 `.wardrobeSwitched` 遥测接进了这个死 VM，而 D88 新建的
遥测门只查「文本里有这个调用」、没查**发出方是否可达**——门自己漏了一格。

处理：切换语义（排序 / 显示名消歧 / active 解析 / 遥测）收进纯值 `WardrobeSwitcher`，
app-shell 与 Me 共用；死 VM 删除（其新建路径与 `WardrobeManageActions.create` 逐条重复，
测试迁到真路径，覆盖不减）。**新增 ViewModel 接线门**——D88 只管了 View，VM 从网底漏了过去。

消歧规则：每个维度**只有真的能区分时才用**（同主人同名且都无城市时加「· Ada」毫无意义），
都区分不出则用 id 短码兜底，绝不留两行一模一样。

**#20 防重复语义定夺**：DESIGN 自相矛盾——§193/§379 写「近期重复**降权**」，
§200 把它列为**硬门**，实现取了硬排除。后果：小衣柜（三件上装本周都穿过）今天零建议，
UI 只显示空态，不说是防重复清空的。

裁决：**默认硬门 + 会清空候选时降级为降权**，照搬 DESIGN §199 对同类问题已给的处方
（「候选覆盖率低于门槛 → 自动切模式」）。硬门来自竞品差评实证，有真实价值；
但交出空屏是更糟的产品行为。三条纪律：
1. 降级**只放宽防重复**——场合、天气、可用状态仍是硬门（那三条无分歧）；
2. 放宽了也没有候选 → 不算「放宽过」（空结果的原因不是防重复，别对用户说反话）；
3. 降级必须**如实告知**（"Everything that fits today was worn recently…"），
   否则刚穿过的又出现在建议里，与打卡回执「de-prioritized 7 days」自相矛盾。

DESIGN 三处口径已统一，不再自相矛盾。

## D90 — 冷热偏置接线 + 备份策略裁决 + 推荐卡存放位置（2026-08-12）

**#22 `Person.coldBias` 有字段、进导出、无 UI 无消费者**：用户永远设不了它，
而数据导出里躺着一个恒为 0 的「个人偏好」。裁决是**接上**而非删除——
同样 60°F，怕冷的人要的那档比默认厚，这是真实产品价值且字段已在（无 schema 变更）。

语义定夺：偏置**平移**可接受温区，**不放宽**它。放宽会让候选变杂（薄厚都推），
平移是同样精准但对准这个人。天气档位本身仍是硬门（DESIGN §F4 第一条）。
端点夹紧，绝不产生空区间；脏值夹到 ±2；NaN 温度仍不做天气过滤（兜底不被吃掉）。
端到端测试给出真实证据：唯一的 light 上装只在默认档入选，唯一的 veryWarm 上装只在
怕冷档入选——建议里那件上装真的换人，不是「存了个数」。

**#19 iCloud 备份策略裁决：不排除 `ItemImages`。**
两难：排除 → 换机后整柜照片全丢，用户得把衣橱重拍一遍；不排除 → 照片进用户备份。
取不排除——隐私承诺是「我们没有你的副本、不运营账号」，这条不受影响；
iCloud 备份是**用户自己的**加密备份，不是把数据交给我们或第三方。
代价是必须如实告知，FAQ 与隐私政策已补「照片会进设备备份，换机可恢复；我们收不到副本」。
决策被钉成**可执行事实**：测试读目录的 `isExcludedFromBackupKey` 资源值断言未排除，
并与披露文案对账（将来若改为排除，对账会红，逼文案同步）。
身体维度不在此列——独立本地 store + D5 明令不同步。

**#15 推荐卡显示存放位置**（§10.3 省一次跳转）：决定「今天穿这套」之后的下一个动作
是去把它们拿出来，此前得逐件点进详情页。文案纪律：全在一处且无漏网才说 "All in X"；
有没标位置的件时**如实**补「N not placed」，不得让用户以为列出的就是全部
（第一版写成 "All in Rail A · 1 not placed" 自相矛盾，被测试当场抓出）。

## D91 — 冷启动激活面：预赋进度 + 场合里程碑（2026-08-12，缺口 #14）

MVP critic 把这条标为 **critical**（「激活漏斗＝北极星驱动器，原计划漏了」），
它是清单里最后一个 critical。DESIGN §475 要三件：双路径空状态、预赋进度
（答完引导即显 20%）、按场合里程碑即时兑现推荐。此前只有 demo 一条路径，
进度与里程碑**完全不存在**。

**里程碑文案是承诺，必须挣来。** 「已可生成一周通勤搭配」不能靠数够 10 件就吹——
`ActivationProgress` 按**槽位覆盖**算真实可组合套数（口径与 OutfitGrammar 一致：
连衣裙独立成套，否则上下装齐，两种都要鞋），且：
- 「一周」只在能凑出 **7 套不重样**时才敢说——7 正是防重复窗口，说少了自相矛盾；
- 洗衣/外借件不计入（推荐拿不到它们，里程碑就不能拿它们充数）；
- 只算该场合的件（通勤里程碑不能拿晚宴装凑数），但**场合未标注 = 哪都能穿**
  （与 CandidateFilter 三值语义一致；否则刚入库还没标场合的件全被忽略，
  冷启动阶段进度永远不动）；
- 没兑现时**点名缺哪些槽位**，用户才知道下一件该拍什么；
- 组合数封顶 30——报「你能生成 4096 套」没有意义。

**预赋进度**：`onboarded` 为假时不预赋（凭空的进度是骗人的）；进度条的「满」
取 20 件（可用门槛），不是北极星的 40 件（留存目标）——把留存目标画进进度条
会让用户在早就能用的时候仍看到「没完成」。

**双路径**：真实起步那条给具体到能立刻做的动作（「拍下今天这身，3 件约 30 秒」→
直接开入库面），而不是「去 Closet 加点东西」这种没有下一步的句子；示例衣橱保留为次级。
入库面关闭即重算，里程碑当场兑现（DESIGN 的「即时」）。

## D92 — 批量入库：让「批量为默认路径」成真（2026-08-12，缺口 #9）

DESIGN §F1 明写「**批量为默认路径**」，而实现一直是 `selectionLimit = 1`——
北极星是 7 天数字化 40 件，一件一件拍是这条漏斗上最大的阻力。

**copilot 铁律不因批量而松动**：多选之后每张仍由用户拍板（Add and continue / Skip），
绝不做「选了就自动全入库」。`BatchIntakeQueue` 只管游标与诚实记账：
- 汇总逐项如实（加了几件 / 跳过几件 / 几张读不出来），零项不提（噪音），
  且**全失败不得说成 "Added 0"** 这种像成功的话；
- 中途退出：已确认的**不回滚**（用户逐件拍过板），但必须说清「还剩 N 张没看」——
  否则用户以为整批都进去了；
- 超上限（30 张）**明说**后截断，不静默丢弃用户的选择；
- 越界记账被忽略（防 UI 双击把游标顶飞）。

**内存**：批量只拿 `PHPickerResult` 句柄，用到哪张才解码哪张（`BatchImageLoader`）——
30 张全分辨率同时驻留会直接爆。

**坏图不得甩出队列**：某张解码失败或抠图失败时，错误页给「Skip this one」继续这一批，
而不是只有「换一张/手填」——一张坏图不该让剩下的全没下文。

### 验证流程的一个真陷阱（记账）

`swift test`（macOS）**根本编不到 `#if os(iOS)` 块**。本波的
`PHPickerResult` 非 Sendable 跨隔离域错误，四包全绿、只有 `xcodebuild` 报出来。
CLAUDE.md 的验证条款已从「改 app-shell 装配后必须 xcodebuild」扩到
「任何 iOS 专属块同理」。

## D93 — 护理（结构化）+ 备注（自由文本）（2026-08-12，缺口 #13）

DESIGN §90「护理（结构化：只干洗/手洗/不可烘干等，可由洗标 OCR 填充）」、
§95「备注：自由文本特殊需求」。加法式 schema 变更（`Item.careRaw: [String]` 有默认值、
`Item.notes: String?` 可选），已按 D84 单向门重录 golden 并**审 diff**：
恰好 2 行新增、无删除、无版本 bump。

**备注是不可信输入**（DESIGN §321 与自定义标签、OCR 文本同级）。v1.0 还没接 LLM，
但长度上限（200）、控制字符归一（换行/制表压成空格、连续空格折叠）、空白转 nil
现在就立住——等接了再补，就是又一次「先上线后补门」。落库唯一入口是
`ItemNotes.sanitize`，`ItemEditorService` 强制走它。

**护理不进推荐打分**，文案明说「不改变今天推什么」——它影响的是洗完多久能再穿。
互斥组合（只干洗 + 机洗）**指出但不阻止**：洗标本身可能就印得矛盾，用户说了算。

往返对称（D88 中性色单向门的同类风险）：存下去、重开详情页读得回、清空真能清、
且**进数据导出**——否则「带走你的全部数据」不成立。

### 两次被自己的门抓住

1. 详情页插分区时匹配串缩进写错，替换**静默落空**，`CareSymbolPicker` 成了孤儿 View——
   D88 的孤儿门当场报出来。若无此门，这就是一次「控件写好、有测试、零调用点」的完美复发。
2. `notesHintMakesNoAIPromise` 用子串判 "ai"，被 "detail" 里的 ai 误伤——
   与审计早先指出的「UUID 含 34」同一类松断言，改为按词边界判。

## D94 — 转移历史 + 批量转移（2026-08-12，缺口 #12）

DESIGN 的 Item 属性清单里「转移历史」一直挂着，而实现只是改 `item.wardrobe`——
东西去哪了、什么时候走的，没有任何痕迹。

**软 UUID 引用**（`TransferRecord`，与 `WearRecord` 同法，不用关系）：
删掉一个衣柜不该把「它曾经在这里」这段事实一并抹掉，而级联关系会。
代价是名字可能解析不出来 → **诚实显示「a deleted closet」**，不留空白，
也不假装那次转移没发生过。

**历史与移动同一次 save**：失败一起回滚（`record.itemID = nil` + rollback，
与既有 create 失败路径同纪律）——历史不得声称发生过没发生的事。

**批量转移逐件走同一条 `transfer`**，不另开一套语义（搭配缺件重算、日历传播、
历史、原子性全都跟着走）。结果逐项如实：搬了几件 / 几件本来就在那 / 几件失败；
零项不提，**全失败不得说成 "Moved 0"**；有失败就留在表单说清楚，不静默关闭当成功。
「已在目标柜」记为 alreadyThere 而非 failed——那不是错误。

**新实体必须同时进两条路径**：加了一张表却漏掉「删除全部数据」与「数据导出」，
等于悄悄造出一个删不掉、也带不走的角落。测试先红后绿地覆盖了这两条。

Schema 为加法式（新实体 + 5 个属性全部可选或带默认、零关系），golden 已重录并审 diff。

**UI 纪律**：网格的选择模式与普通模式**共用同一份单元渲染**（抽成 `gridCell`），
避免两套视觉各自漂移；选择模式下整格是勾选按钮，不与进详情的手势打架。
