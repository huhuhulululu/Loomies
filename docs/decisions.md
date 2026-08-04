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

## D41 [2026-08-03] Today 首屏 = Avatar + 今日 look（方案 B）
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
