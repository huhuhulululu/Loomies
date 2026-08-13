# 架构目录（唯一真相）

> 与代码不一致时以代码为准并立即更新本文档。
> 最近同步：2026-08-12 — D104 日间天气/打分权重/导出场合/派生档可达/a11y 单列。四包 **1424 tests**（Core 488 / Model 367 / UI 512 / Intake 57）。D82：photoreal shape 维度 + 资产 QA 门 + 试衣间。D83：属性录入面（温区/颜色/风格属性）。D84：Schema 单向门（VersionedSchema + 指纹 golden + 装配单一入口）。D85：零 UI 入口接线全部完成（删柜/删人、位置树、跨柜检索、合身反馈、手动打卡）。D86：产品外壳合规（出网面披露、遥测 opt-in 门、帮助/FAQ、政策与署名、身体数据同意）。D87：导出包（JSON + 原图 ZIP，后台压缩）。**D88：D83-D87 交付复审的 25 项发现全部关闭**——属性录入接到了真正的新增路径（此前打在零呈现点的 `QuickAddSheet` 上）、删柜判空与单次确认、合身反馈失败不再静默、身体数据同意门真正关上、颜色往返、删除权重置同意位、遥测真接线、位置树删除告知/深度上限/防成环、导出诚实计数与临时目录回收、穿着历史回读（打卡此前只写不读）。新增结构性门：孤儿 View 棘轮、伪造默认值、表现层 `context.delete`、客户文案词汇、遥测事件产出方、出网 host 运行时对账、盘上库升级路径。**D89**：切换器唯一真相（`WardrobeSwitcher` 纯值：排序/同名消歧/active 解析；死 VM 删除，app-shell 平行实现收编）+ 防重复语义定夺（默认硬门，会清空候选时降级为降权并如实告知）+ ViewModel 接线门（D88 只管了 View）。**D90**：冷热偏置接线（`ColdBias` 平移温区，Me → Profile 入口，端到端证据）+ iCloud 备份策略裁决（`ItemImages` 不排除备份，决策钉成可执行断言 + 文案对账）+ 推荐卡存放位置提示（`OutfitStorageHint`）。**D91**：冷启动激活面（`ActivationProgress` 预赋进度 + 场合里程碑按槽位覆盖真实计算，双路径空状态）——清单最后一个 critical 项。**D92**：批量入库（PHPicker 多选 + 逐张懒加载 + `BatchIntakeQueue` 诚实记账，每张仍由用户拍板）。**D93**：护理（`CareSymbol` 结构化，不进推荐打分）+ 备注（`ItemNotes`，不可信输入的长度/控制字符闸）——加法 schema，golden 已重录审 diff。**D94**：转移历史（`TransferRecord` 软 UUID 引用，删柜不抹历史）+ 批量转移（多选网格 → `transferAll`，逐件走同一条服务路径）——新实体同步进删除权与导出。**D95**：三派生缩略图管线（`ItemImageVariant` grid/detail + 原图，ImageIO 生成、落盘复用；孤儿对账与删除全链认账）。**D96**：抠图边缘手修（`MatteRetouch` 笔画式，撤销＝少一笔重渲染；找回从原图取像素）——**缺口清单功能项至此全部清空**。**D97**：补齐 #14 的「场合构成」问题（`OccasionMix`，onboarding 可跳过 → Today 默认过滤 + 里程碑打头；修掉「全休闲衣柜今天空屏」的真 bug），并修正里程碑口径措辞（衣柜完备度 ≠ 今天能穿）。**D98**：24-agent 对抗审计发现**整个激活面在真实首启路径上不可达**（onboarding 自动播 9 件 demo 越过冷启动阈值 8）——去掉自动播种让双路径真成用户的选择，并修掉删库死结、横幅三数打架、demo 死键、场合承诺无兑现路径、onboarding 死字段与假漏斗指标、快选绕过同意门、真实起步文案不符；§206 胶囊模板补拍显式记为延期。**D99**：收口审计尾项（回归门抽 `forToday` 工厂才守得住、里程碑不再替未标场合的件点名、Oxford 列表连接、删恒真死参数、姓名不再当激活闸门）。**D100**：tab 口径裁决（DESIGN 自相矛盾 → 以实现 4 tab 为准 + 双向对账门）+ F2 死码族逐族处置（Sizing/DressCode 删除并留复活条件；`hipFlatWidthInches` 接进下装合身判定，取腰/臀更紧者）——第一轮完整性审计缺口清单全部清空。**D101**：第二轮审计（46 agent）修 6 条 HIGH——onboarding 同意控件缺失致体型选择器永远拒绝、网格与详情合身判定不一致、Today 不跟随切柜、空态甩锅给已放宽的门 + 开发者语言外泄、AppLog 违反自身 PII 规则且 lint 有两个洞、「iCloud 已同步」假声明（正确文案零调用点）。**D102**：收掉剩余 3 条 HIGH——日历静默跨柜回退（且滑删会删别柜的）、一条结构上不可能失败的迁移测试（改为说清边界 + 补实体注册完整性门）、识别是永久 mock 而成功路径零披露。**D103**：删柜残害别柜搭配（数据损坏）、「Plan」隐藏收藏副作用 + 失败留孤儿、入库偷加 casual 架空场合硬门。**D107-D110**：录入质量波——城市改为**标准名选择器**（`CitySearch` + Open-Meteo geocoding，三个入口统一）、尺寸录入 locale 容错（`MeasurementEntry` 按分隔符**位置**判小数点，不按 locale）、场合改多选（打错字不再让衣服永久不被推荐）、缩略图后台解码 + NSCache（`ThumbnailImageCache`）；D110 另修**标准名打断离线气候回退**（表按裸城市名建，取第一段再查）与**切柜后 @State 不跟随**（日历/收藏/存放树留着上一个柜的数据，且删除会真删到那个柜）——门通用化为「持 `let wardrobe` + 缓存 @State 必须跟随切柜」。**D111**（隐私/发布 16-agent 审计）：**用户原始照片旁挂档**（`<stem>@source.jpg` ≤2048px —— 此前只存归一层图，相机拍的原图被永久丢弃，导出承诺的「original photos」兑现不了；删除/对账/导出全链认账）、政策正文按 `hasSink` 实况生成（D105 只修了状态行）、城市搜索纳入出网面披露与运行时对账（打字即发，第一条请求在欢迎屏）、`PolicySite` 从同一份文案生成可托管静态页 + `ReleaseReadiness` 把提审缺口（Privacy/Support URL、客服联系方式）做成可执行清单。**D112**（引擎/性能/数据层 48-agent 审计）：防重复降级判定从单品层移到**搭配层**（按一次「Wore it」就空屏的真 bug）+ 搭配层排序纳入近期穿着降权；`ownerProfile` 三处由渲染路径 fetch 改 `@Query` 内存查找、背景图接 `BodyAvatarImageCache`（含负缓存）；`discardOrphan`/位置 create/demo 播种三处补「rollback 前还原关系」，并加 `RollbackDisciplineLintTests` 类级门。**D113**：测试可信度——25 处 `@Test(.serialized)` 是无操作（移到 `@Suite`）、测试对生产图片根做整目录破坏（收口 + `TestIsolationLintTests`）；缓存一致性——删库接 `removeAll()`、换图后 `@State decoded` 不重置致永久显示旧图（抽 `shouldDropStaleDecoded` 纯函数可测）。**D114**：两条入库路径的场合从单选改为与详情页同一个 `OccasionChips`（拍照建的衣柜此前每件只带一个场合，换场合被硬门筛成零；空集还被显示成「已选 Casual」）；`CalendarPlan.outfit` 无反向关系致悬挂引用 —— 加反向端被 golden 判为破坏性且 TF 已有安装数据，改由 `CalendarPlanService.unbindPlans` 维持 + `PlanUnbindLintTests` 守。**D115**（市场/设计盘点第一波）：**深色模式**——`Palette`（纯值进 Core，对比度可测）+ `DS` 按配色方案解析，新增 `onAccent`/`hairline` token，类别色（槽位/场合）进系统；修掉只在浅色下发作的「白色叠加等于没有边界」；文案红线 `BodyLanguageRedLineTests`（推荐理由「Flatters your body shape」违反 DESIGN §10.4）。**D116**（市场盘点 Wave 0/1）：采纳信号从「翻轮播」移到「真穿了」+ `wear_as_is`（§8.1 判定协议此前量错了）、`TelemetryGate.configure(sink:)` 可注入且无 sink 进提审阻断项、天气未解析显示「—°F」不再伪造 70、Today 加「settled」常驻带（打卡不再被当场抹掉，跨启动回读）、冷启动文案改说人话。**D117**（Wave 2 两个 ★ 差异化）：`OutfitFitMark` 把合身结论端进 Today 建议行与试衣间（此前 `FitMarkService` 在两个决策现场零引用，取最紧那件 + 如实报未实测数 + 全无实测时给入口）；头像加「Make it look like me」叠加式入口（刻意不整块可点，避免吞掉 orbit 手势）。**D118**：**每日回访**（此前全仓 0 处 `UNUserNotificationCenter`，D30 留存证伪线无从谈起）——策略纯函数 `DailyRitual` 进 Core，`DailyRitualScheduler` 排**七条按周重复**（一条每日重复会让星期名变假话）；衣柜凑不出一身不排、文案不点名单品不承诺已选好、授权被拒把开关拨回去、排程点在 Today 而非设置页；通知点击经 `NotificationRouter` 归因（`source`=nudge/organic，读取即清零）。**D119**：`WearStatsService` 把穿着记录回读到详情页（此前写了一年零出口，DEMAND-VALIDATION 的 #1 JTBD）；激活阶梯从「<8 件」延到「<20 件」（8 正是北极星区间起点，此前 8→20 无人引导）+ 跨阈值的一次性毕业卡。**D120**：检索加**色板筛**+「你已经有 N 件」+ 每行「上次穿」——回答 #1 JTBD 的后半句（店里那一刻的检索词是颜色+品类，不是名字；未标颜色不算命中，只给数不给相似度分数）。**D121**：`DS.Text` 六档语义字阶（serif 标题，全部从 Dynamic Type 文本样式派生）——此前 caption/caption2 占全部字号调用 83%、主视觉标题与列表行一样大，而 DESIGN §462/§566 早有规范。**D122**：`ImportService` 数据导入（此前只出不进）——只增不改（永建新柜、id 重生成、同名加后缀）、收据点名照片不在 JSON 里、拒绝更高 schema 而不猜、失败整体回滚；并修掉 D111 埋的缺陷：`preview/` 整体 gitignore 使防漂移门比对的是一个没入库的文件（政策页已白名单入库）。**D123**：洗标 OCR 真接 Vision——`LabelTextParser`（纯函数，宁缺勿错：成分百分比/洗涤温度/RN 编号都不算尺码）+ `VisionOCRService`；能力位刻意分成 `labelOCRAvailable`（真接）与 `recognitionAvailable`（打标仍 mock），披露分两句：猜的说猜的、读的说读的。**D124**：主色识别（`DominantColor` 众数投票 + `DominantColorSampler` 像素采样）——此前颜色永远未知致配色打分全程不参与；众数不用均值、集中度 <55% 不给、只在抠图成功时取、不覆盖打标结果。**D125**：搜索防抖 0.25s + 代际号（`run` 也必须作废在途代号——测试抓到的真 bug）、铺整柜单品的两处改 `LazyHStack`、首屏前的扫盘家务事（导出残留回收 / 图片目录对账）挪到画完之后。**D126**：锚定互斥（两条下装/裙+上装/两双鞋此前可同时锚定 = 永远拼不出）——后选替换先选同类 + 如实告知，判据直接问 `OutfitGrammar` 不另写规则。**D127**：体型项加上限 `maxBodyShapeContribution`（此前无界求和会独吞值域，配色对排序完全不起作用）+ 理由按对最终分的贡献排序（UI 只显示第一条）。**D128**：空态点名缺失槽位（缺鞋时「换个场合」是走不通的路；顺带修掉 `available < 3` 老捷径对「有裙有鞋」用户的错误建议）+ `FailureCopy` 按「重试有没有可能成功」分类（40 处失败提示此前几乎都以「try again」收尾）。**D129**：`DS.Space` 间距尺度 + 修三个离格值（3/9/11）+ 2pt 网格门（刻意不重排已在格上的四十处）；剩余失败文案逐条判类后确认多数「重试」是诚实的，只改真正重试无用的两处。**D130**：`FilterContext.daytimeTempF` 改可选（天气未知时整条温区门跳过，此前按伪造的 70°F 筛衣服）、冷天偏好带外套（此前由 UUID 序决定）、`GarmentSubtype` 按名判型让「不许两件同型外套」的规则真的可触发。**D131**：排序加浮点容差并收进 `OutfitScorer.ranksBefore`（1-ULP 噪声此前能决定名次）、撞色时不再同时夸「配色平衡」、锚定件与今天不搭时如实提示（仍照用，不筛掉）。**D134**（新代码复审第一批）：修 D117 的 `else` 绑定错位（正常 Today 也渲染「没有匹配」卡）、导入读不了自家导出（zip vs json → 补「数据文件」导出 + zip 如实指路）、导入补齐六类数据（穿着历史/计划/位置/主人/身体档案，此前导入的柜永远没有主人）。**D135**（复审第二批）：Vision 双 resume 会 trap 进程（一次性闸）、通知归因暖启动永不落地（改发事件时消费）、颜色筛清不掉、OCR 披露零调用点、主色缺拒识半径、转移后穿着记录归零。**D136**（复审第三批）：删库后提醒成幽灵且无关闭入口、撤权后开关仍显示「开」、衣柜变化不重排、settled 带跨午夜不刷新；入库主线程全分辨率解码（降到 512 + 挪后台 + 修指针逃逸）。**D137**（复审第四批）：白字门看不见三元式（漏了五处 2.6:1）、VoiceOver 念虚构温度、洗标品牌黑名单永远不完整（改唯一候选才给）、失败文案靠关键词着色（改结果位）。**D138**（复审收口）：导入绕过备注净化门/有件没柜留孤儿、穿着日期超一年不带年份、送洗把衣柜推回阶梯、毕业卡与空态自相矛盾。**D133**：槽位截断预排序纳入色季与「有颜色」（此前只按体型 affinity，没体型档案的用户等于随机抽 12 件，配色权重白算）。**D132**：`ImageCaches.purgeAll` 统一清理 + 切后台接线（六个缓存合计 440MB 上限、此前只有一个有清空 API、全 app 无后台清理点 → 真装满会被 jetsam）。**D139**：删柜对话框的两处不诚实——「Wear history is kept」（行确实留着，但唯一读它的界面按已删柜的 id 过滤，技术上为真实际为假）与「删柜会把**别的柜**里的搭配标为永久缺件」只字不提（`DeleteService.foreignOutfitsAffected` 同源计数进对话框）。**D140**：每日回访从「设置里藏着的开关」变成**用完之后的一次邀请**——D118 建好了全套（策略/排程/归因/撤权对账）却没有任何一处告诉用户它存在，而 MARKET §8.1 的 D30 证伪线整个押在它上面；`mayAskForPermission` 长期零调用点正是这件事的化石。邀请出在**刚打完卡**那一秒（`DailyRitual.shouldInvite`），只问一次（拒绝落 UserDefaults），衣柜凑不出一身不问；开启路径收成唯一一条 `DailyRitualScheduler.enable`（邀请卡与设置开关同源），12 小时制标签也收成一处。**D141**：`FailureCopy.outOfSpace` 零调用点（`classify` 按 `NSFileWriteOutOfSpaceError`/`ENOSPC` 认，认不出一律回落 transient——不猜；接进三处导出 catch）、`ExportError.noCroquis` 长短文案自相矛盾（长的说「再试一次」，短的说去设体型）、`writerFailed` 替系统猜「腾空间」、`displayName` 把 `J.CREW` 改成 `J.crew`（改按字母段大写，`L.L.Bean`/`Saint-Laurent` 同时修好）、检索每敲一字按柜各扫一遍全表（`stats(forItemIDs:)` 一次取完）。**D142**：零调用点族收尾——`CopilotEmptyReason` 的 `available` 与 `candidates` 同源却分开传，造出「表达得出、生产上永不发生」的状态并有一条分支挂在上面被测绿（删参数让矛盾写不出来；顺带发现件数少的用户真正看到的那句话没有下一步，改成祈使句）；`nextFireDate` 零调用点 → `nextNudgeLine` 写在开关旁（不会响时不显示时间）；`ReleaseReadiness` 零调用点 → `ReleaseFacts` 唯一真相 + Debug 面板显示实况阻断项（刻意不做成永远红的测试——域名此刻确实不存在）。**D143**：测试钩子按堆地址记名（`forceFailureIDs` 存 `ObjectIdentifier`，注册过的 context 释放后新对象同址即凭空继承「强制失败」）→ 改持弱引用并按对象校验、死条目当场清；`ItemImageTestRoot.install()` 每例都 `setenv`（POSIX 并发不安全）→ `static let` 一次性。**D144**：删库披露两处各写一份且已走岔（a11y hint 比可见文案少说穿着历史与计划，两处都漏存放位置与转移历史）→ 收成唯一一份 `deleteAllDisclosure` + 结构门（删库每多抹一张表必须跟着点名）；回执补 `deletedTransferRecords`（此前删了却不记）；顺带纠正三条「默认值兼容旧回执解码」的假注释（Swift 合成 Decodable 不看默认值，缺键直接 keyNotFound）。**D145**：`TransferService.transfer` 缺同柜守卫——转到它已经在的柜会静默抹掉 `item.location` 并写一条「从 A 到 A」的历史（批量版与单件 VM 各自在外面挡过，唯独服务自己没挡）；同时把「删柜失败留假警示」这条审计项**证否**并钉成测试（跨柜搭配的 `needsAttention` 删除前本来就是 true，翻不动的位不会被翻错），代码不动。**D146**：删存放位会给提升上来的子格改名而警告只字不提（`DeletePlan.renamedChildren` 预测与执行同源——问 `deduplicatedSiblingName` 本人，新增 `alsoTaken` 让预测看得见前面已占的名字）；删掉两处零调用点死码并留复活条件——`CalendarPlanService.refreshAttention`（语义与本仓「重算并进自己那次 save」的写入模型相冲）、`SearchViewModel.applyIfCurrent`（模拟异步落地，而搜索是同步现读现查，那条「旧结果盖新结果」的路不存在，其测试却让人以为防线被验过了）。**D147**：D105 判定的崩溃路径在**第二处**原样留着——`WearHistoryViewModel.load` 用 `Dictionary(uniqueKeysWithValues:)` 按单品 id 建表（单品比衣柜多两个数量级，暴露面更大），重复 id 直接 fatalError；改带决胜合并 + 结构门（Sources 下任何非注释行再出现该构造器即红，已证明可红）。**D148**：三值语义只做了一半——温区未标时天气门整条跳过（引擎对），而录入提示写「不确定就留空」却不说后果，厚外套留空在 85°F 照样被推出来；文案改成说清后果 + 门锁住文案与引擎同向。同波把「按名字排序、同名按 id 决胜」从 19 处手抄收成 `sortedByName()`（`NamedRecord` 协议，ClosetModel）——元组比较会先算出两侧全部分量，于是名字不同也照样格式化两个 UUID：网格每帧近万次无谓分配；同名才付这笔代价 + 结构门禁止再手抄。**D149**：`Outfit.itemIDs` 由计算属性改存储（`items` 是 `let`，构造时算一次）——排序口径一次比较取它四遍、去重每套再取一遍，冷天无锚定时上千套全在主线程重复 map+sort；删 `croquisAssetName`/`croquisImage` 整条零调用点取图链。**工具链陷阱记档**：给 Core 的 struct 加存储属性后依赖包不重编 → 运行时 SIGSEGV 且无编译错，先 `rm -rf Packages/<依赖包>/.build` 再怀疑代码。**D150**：分享片导出每帧新建一整块全尺寸像素缓冲（720×1080 BGRA 约 3MB × 48 帧）→ 改从 `adaptor.pixelBufferPool` 取（`acquirePixelBuffer`，池子 nil 时回落直接创建——回落失败会让导出在某些时序下直接崩，比慢一点糟得多）；测试直接验证「释放后再取拿到同一块内存」。**D151**：实测冷天 240 件衣柜的推荐是 **3013ms 主线程同步冻结**（暖天 188ms）——枚举 2.2 万套并**全部物化**后才排序取 3。改为枚举时只留前 K（`ranksBefore` 是全序，等价性已钉成测试）+ 槽位候选提出循环头 → **1959ms**。剩余 ~2s 需减少组合数，属产品判断，未擅自砍（合成 fixture 的「砍一半外套不影响前 3」是并列假象，证据不足）。**D152**：推荐计算挪出主线程——`refresh` 拆成「主线程快照成纯值 → `nonisolated` 纯计算 → 回主线程按代际落地」三段，同步与异步共用同一组（不给漂移留机会）；实测**主线程被占 2036ms → 87ms**。过期结果按代际丢弃（D125 搜索、D116 天气各栽过一次）；冷启动早退分支仍就地处理，不派后台计算。**D153**：demo 种子从不设剪裁属性 → `BodyShapeStyling` affinity 恒为 0，MARKET §2 的唯一纵深（合身/体型）在「先看效果」那条路上**一点差别都产生不出来**（实测 0/5 种体型）；给自家 fixture 标上它们本就有的剪裁（不碰用户入库路径），门问的是「体型维真的动了吗」而非「字段填了吗」→ 5/5。同波钉住 D152 的加载指示契约——spinner 在同步路径下从来渲染不出来（主线程被占满，SwiftUI 观察不到 true）。

## 项目定位

每日穿搭与衣橱管理 iOS App（min iOS 26，首发美国区）。核心机制 = **copilot**（用户掌舵、App 跑腿，D19）。
设计真相见 `docs/DESIGN.md`，市场见 `docs/MARKET.md`，MVP 计划见 `docs/MVP-PLAN.md`，裁决见 `docs/decisions.md`，交接见 `docs/HANDOFF.md`。

## 代码模块

| 模块 | 路径 | 职责 | 验证 |
|------|------|------|------|
| ClosetCore | `Packages/ClosetCore/` | 引擎 + AppLog + Weather/FitMark/Telemetry + **BodyAvatar + BodyMorph + MannequinSegmentScales / AvatarBodySex / MannequinMeshCatalog（USDZ 名）** | `swift test` |
| ClosetModel | `Packages/ClosetModel/` | SwiftData + BodyProfile 双轨（快选/实测/`presentationSexRaw`）+ ItemStatus/… | `swift test` |
| ClosetUI | `Packages/ClosetUI/` | 全 tab + **BodyAvatarView（2D catalog + 叠衣，产品视觉）+ AvatarBackdrop + Me 精调/性别**。`Mannequin3DView` 是未接线能力探针，不是最终视觉 | `swift test` + build |
| ClosetIntake | `Packages/ClosetIntake/` | F1 入库 capability seam：抠图/打标/OCR 协议 + mock + IntakeViewModel + VisionMattingService（编译验证） | `swift test` + Vision swift build |

> App 外壳（`app-shell/`）：**XcodeGen `project.yml` → `ClosetApp.xcodeproj`**，本地 SPM 四包；模拟器 **BUILD SUCCEEDED**（2026-08-03，iPhone 17 Pro / iOS 26.2）。CloudKit 默认 off；Onboarding → AppRoot 4-tab。

> 计划中完整 SPM 结构见 `MVP-PLAN.md §3`。当前 4 包覆盖 RulesEngine 先行部分 + 数据层 + UI 逻辑 + 入库 seam。

## 模块依赖 DAG

```
ClosetUI ──► ClosetModel ──► ClosetCore
   │              ▲
   └─► ClosetIntake ─┘
```

- ClosetCore：零外部 SPM 依赖（Foundation only）
- ClosetModel → ClosetCore
- ClosetIntake → ClosetCore（+ ClosetModel for confirm 落库）
- ClosetUI → ClosetModel + ClosetCore + ClosetIntake

## 核心回路（已闭合、可测）

```
Onboarding → 入库(Intake) → 管理(网格/转移/删除/检索)
                              ↓
                    copilot 补全（天气×场合×体型×防重复）
                              ↓
                    打卡(CheckIn) → WearHistory ──┘
                              ↓
                    日历计划(CalendarPlan) ↔ 缺件 needsAttention
```

## 对外链接登记

| 链接 | 用途 | 可见性 |
|------|------|--------|
| https://m424.tailb5f9cb.ts.net:10029/ | 项目状态页 + 审阅制品 | 仅 tailnet |
| https://m424.tailb5f9cb.ts.net:10029/body-avatar/ | **Body Avatar（D68）** 8 表型正面 + 女锁脸 8 角 + 男 8 角 | 仅 tailnet |
| https://m424.tailb5f9cb.ts.net:10029/body-avatar/assets/phenotypes/ | 8×2 表型 catalog 正面 PNG | 仅 tailnet |
| https://m424.tailb5f9cb.ts.net:10029/body-avatar/assets/ | 入库 photoreal 正面/多角 PNG | 仅 tailnet |
| https://m424.tailb5f9cb.ts.net:10029/body-avatar/multi-angle-staging/ | 多角 staging 与 README | 仅 tailnet |
| https://m424.tailb5f9cb.ts.net:10029/body-avatar/pipeline/ | GPT 中间原料 JPG + README | 仅 tailnet |
| https://m424.tailb5f9cb.ts.net:10029/landing/ | 落地页 V1（推荐器 hero） | 仅 tailnet |
| https://m424.tailb5f9cb.ts.net:10029/landing/v2.html | 落地页 V2（规划器 hero） | 仅 tailnet |
| https://m424.tailb5f9cb.ts.net:10029/mockup/ | 产品 UI mockup | 仅 tailnet |
| https://m424.tailb5f9cb.ts.net:10029/mockup/redesign.html | UI 重构 mockup（Dawn/Mist） | 仅 tailnet |

## 文档结构

| 文件 | 职责 |
|------|------|
| `docs/DESIGN.md` | 产品与技术设计 |
| `docs/BODY-AVATAR-USER-FLOW.md` | Body 使用流程（客户路径 / 状态机 / 验收） |
| `docs/MARKET.md` | 市场与竞品 |
| `docs/decisions.md` | 裁决日志（只追加） |
| `docs/HANDOFF.md` | Xcode 接手入口 |
| `docs/MVP-PLAN.md` | 实施计划 |
| `docs/research/*` | 调研报告 |
| `docs/validation-kit/` | R1 真人验证启动包（D20 已跳过，备用） |

## 模块详情表

<!-- AUTO-MANAGED:module-table -->
| 模块 | 关键类型/服务 | 说明 |
|------|--------------|------|
| ClosetCore | OutfitCompleter, FitEngine, FFITClassifier, BodyMorphParams, BodyAvatarLayout, MannequinMeshCatalog, WeatherProviding, **OpenMeteo / OpenProductFacts / PublicSizeReference**, FitMarkCopy, TelemetryEvent | 纯逻辑 + 公开 API 客户端（免 key）+ 遥测 |
| ClosetModel | Transfer/Delete/Search/BodyProfile/FitMark/CalendarPlan/OutfitDraft/DemoSeed/Recommendation/CheckIn/**DataLifecycle** | 持久化 + 语义服务 + 导出/删除全部 |
| ClosetUI | BodyAvatarView/Mannequin3DView/AvatarBackdrop/DepthParallax/AvatarCinematicExporter/BodyMorphRaster, CalendarView, MeView, Copilot | 真人照片 catalog basewear 主路径（D63）+ 3D interim fallback + 景深/分享 |
| ClosetModel | … + **GarmentLayerNormalizer**（入库叠衣标准画布）+ **OutfitAvatarComposer**（displaySlot 叠衣） | 叠衣层 PNG 归一 + look→layers |
| ClosetIntake | MattingService, TaggingService, OCRService, IntakeViewModel | 入库能力缝 |
<!-- /AUTO-MANAGED:module-table -->

> **能力探针 / 未接线（D104）**：`Mannequin3DView` 与 USDZ 解析仍在仓里，但产品面 7 处 `usesMannequin3D: false`，且 `NudeBodyBaseSpec.allowsMeshOrSimulationAsFinalVisual == false` 在编译期关掉网格最终视觉。ARCHITECTURE 不得把它写成 live avatar 路径。复活条件：开关打开 + 至少一处产品调用点。

### 纸娃娃叠衣链路（D40 / D75）

```
Item[] / ScoredOutfit.itemIDs
  → OutfitAvatarComposer.layers  (displaySlot 纠偏 blazer-as-top 等)
  → BodyAvatarComposer.layers    (dress 压 top/bottom；z-order 鞋<裤<衣<外套)
  → BodyAvatarView.garmentLayer  (hasVisual → fullCanvas；侧角 MannequinGarmentVisibility)
```

- Demo seed：slot=`outerwear` + `DemoGarmentSilhouette` 512×768 PNG  
- 入库：`GarmentLayerNormalizer` 同画布（尊重 source-alpha：抠图半成品按 alpha 边界归一，不整画布铺满）；禁止槽位框再套一层（防胸前小贴纸）  
- 空层：Today 英雄区胶囊提示，非静默裸体

### 打磨不变量（Polish wave 2026-08，15 轮收敛（D80）+ 后续 a11y/测试质量/文案/工具链波（D81），655 tests）

- **保存失败原子性**：全部写路径走 `ModelSave`（snapshot → 操作 → 失败 `rollback` + 内存态恢复）；删除-only 失败留 dirty marker、不假装成功；测试中点保存禁止（no mid-operation saves）；测试钩子 `ModelSave.forceFailure` / `ItemImageStore.forceFailure`（图文件删除同样原子 + orphan 清理）。create 失败一律「断关系 + rollback」而非 `context.delete`（delete 只删行，关系幻影与脏标记滞留污染后续 save）——衣柜/Onboarding/QuickAdd/Intake confirm 全对齐 OutfitDraftService 模式。
- **Toast 代际**：自动消失计时器一律持单调 token 判「自己那条还在」，不按消息值判等（同文案连发会被旧计时器提前清）。
- **日志隐私**：AppLog 消息禁止插值用户内容——实体一律 `AppLog.ref(id)`（前 8 位稳定标识）、错误一律 `AppLog.errRef`（domain#code，禁 `\(error)` 全量 dump——NSFilePath 泄露容器路径）、城市/条码只报有无/长度；OSLog 全级别 `.private`（sysdiagnose 兜底脱敏）；LogRing 单条 512 字符截断；诊断包 `WardrobeSummary` 不携带衣柜名/城市（id 前缀 + hasCity）；静态隐私 lint 测试（`appLogCallSitesCarryNoPIIPatterns`）+ 端到端负向断言双锁；debug 面板入口仅 DEBUG 构建可见。
- **脏输入即缺失**：NaN / 0 / 负值在 FitEngine / FFITClassifier / ColorHarmony / WeatherFit / BodyMorph / FFIT 一律按 nil / 中性处理，绝不做「自信兜底」；持久化入口同标准——`ItemEditorService` 拒绝非有限/非正平铺宽、未知风格属性（allowed-set，与 warmthRaw 同款）、越界/非有限 hue，导出 encoder `convertToString` 兜底历史脏 Double。
- **属性录入面（D83）**：温区/颜色/风格属性是推荐三条链（天气硬过滤 / 配色打分 / 体型加权）的**唯一**输入，此前无录入 UI 导致真实衣柜数据上空转（demo seed 掩盖）。`ClosetCore.GarmentAttributeCatalog` 提供人话标题 + `GarmentColorPalette`（16 色板，id 稳定、中性/彩色不串台、`nearest` 回读）；`ItemEditorService.Patch` 加 `attributesRaw` / `colorHue+colorIsNeutral+replaceColor` / `replaceWarmth`（nil 默认「不动」，整表提交才是「清为未知」）；`QuickAddDraft` 把快速添加落库抽成可测值类型——**未选 = 未知（nil）**，禁止替用户假设成 `Warmth.light` / 中性（旧硬编码是冷天必空推荐的根因）。控件 `WarmthPicker` / `ColorSwatchPicker`（44pt 命中区）/ `StyleAttributePicker` 复用于详情与快速添加。
- **UI 诚实**：`lastError` 与 `statusMessage` 互斥（失败清空 success 文案）；异步竞态用 generation counter last-call-wins（Intake process/enrich、Copilot applyWeather）；Intake 空图早退显式复位 `isProcessing`；Intake 分阶段失败文案 + rollback 清 orphan 文件。
- **日界口径**：穿着防重复窗口按日历日算（`WearHistory.recentlyWornItemIDs` 注入 `Calendar`，DST 安全），与 UI 承诺「de-prioritized 7 days」一致，不随打卡钟点漂移。天气「今天」按**衣柜城市时区**取日（geocode 的 IANA `timezone` 字段 → dayString 与请求参数同源；无字段退回设备历 + auto）——设备时区 ≠ 城市时区（出差/双城柜）不再取错日。离线气候表月份保持设备历（粗估 ±数°F，不为月界数小时加时区表——已评估不修）。**CalendarPlan 以 `dayKey`（"yyyy-MM-dd"，加法 schema）为日历日真相**：`date`（本地午夜瞬时值）跨时区会漂到前一天——查询/去重/展示（`displayDate` 本地正午反解）/导出全走 dayKey；空键旧数据退回 date 按设备历解释，覆盖写时顺带固化。
- **关键词折叠**：名称关键词分类（剪影/displaySlot）与搜索一律走 `TextNormalize.foldedKey`（大小写 locale 无关 + 变音符号折叠）；禁用 `localizedCaseInsensitiveContains` 做关键词匹配（tr locale 下 I≠i）；失败文案样式判定（"couldn't"，无 i 字符）不受限。
- **文本判空统一**：可选文本字段（brand/size/位置名/名称）「空白即缺失」一律走 `ClosetCore.TextNormalize`（trim 后判空/转 nil）；实时 TextField 绑定不 trim（输入中），落库口与判定口必 trim；空白名 patch 拒绝（return false）而非静默丢弃。
- **零 UI 入口接线（D85）**：服务层就绪但用户够不着的能力逐项接通——删衣柜/删人（`WardrobeManageActions.DeleteOutcome` 带**类型化** `blockedReason`，View 靠它升级二段确认，不得用 message 字符串相等；确认对话框持**值类型快照** `PendingWardrobeDelete`，绝不在 @State 里持 @Model——删后重求值是未定义行为；force 警告完整告知级联面含 CalendarPlan；当前打开的衣柜不可删；失败着色由返回值驱动而非关键词嗅探）；存放位置树（`listWithDepth` 缩进展示 + 父节点 Picker + `siblingNameConflicts` 提交前诚实报重名——父层判定显式分支，不用 `parent?.children ?? 根层` 的回落，否则子层与根层同名会被误报）。
- **导出包（D87）**：`ExportBundleService` 两段式——`plan` 在 MainActor 读 SwiftData 出值类型计划，`writeBundle` **nonisolated**（几百张图的拷贝+压缩在主线程会冻结 UI 数秒到数分钟，`AvatarCinematicExporter` 已有同类判例）；UI 侧 `Task.detached` + 进行中禁用按钮。Foundation-only 压缩（`NSFileCoordinator .forUploading`，无第三方依赖）；反向孤儿与单张拷贝失败静默跳过（诚实地少一张胜过整包失败）；staging 目录用后即删；分享面板关闭清理临时 zip（与 cinematic MP4 同纪律）。`ShareBox` 支持文本/文件两种载荷，诊断导出路径不受影响。
- **合规诚实（D86）**：**出网面单一真相** `NetworkSurfaceCatalog`——任何新增网络请求必须登记，否则对账测试 `everyOutboundHostIsDisclosed` 变红（比「禁用词黑名单」强得多；旧 About 笼统写「images never leave」，而条码查询确实会把用户扫到的商品条码发往 Open*Facts）。`ComplianceCopy` 是帮助/FAQ/隐私/署名/政策链接的唯一真相（署名按名排序，含许可与用途）。**遥测**：`TelemetryGate` 是唯一发送出口——opt-in 默认关闭、`sanitize` 是 `track` 的内部步骤、sink 协议不暴露原始 payload（绕过白名单在类型层就做不到）；生产无 sink，状态行如实说「Nothing is sent yet」。**身体数据同意** `BodyDataConsent`：门必须在**任何 insert 之前**（insert 之后 return false 会留 pending insert + 关系幻影污染下一次 save），仅围度受门约束、体型快选不设路障。
- **检索作用域（D85 波 C）**：`SearchScope`（本柜/全部）——服务层早支持 `wardrobeID = nil`，UI 此前恒钉当前柜使 §2.3 承诺的全局检索无入口。`effectiveWardrobeID` 由 scope 派生；跨柜结果行**必须**显示所属衣柜（可见文案与 VO 同源，否则同名单品分不清）；跨柜结果的合身标记按**该单品所属柜主人**取身体档案（不能用当前柜主人）；`clear()` 一并复位 scope（清空后不得仍停在跨柜而用户不知情），`clearFiltersKeepingScope()` 保留作用域；每次打开搜索回到本柜（安全默认，与文档描述一致）。
- **打卡语义唯一（D85 波 D）**：Today「Wore it」与手动 `CheckInView` 写的是**同一种** WearRecord，不是两套打卡概念；合身反馈是同一条记录的 update，`CheckInService.setFitFeedback` 是**唯一**写入入口（校验 FitVerdict + 快照回滚），`recordWear` 的宽松签名保留给历史用例但 UI 不再走它——两条 UI 路径共用同一守卫，脏值不会绕过。v1.0 只采集不喂 FitEngine，文案不得暗示会改变推荐，且如实披露会随 Export my data 导出。
- **命名完整性**：衣柜 create/rename 与存放位置同级 create 拒绝重名（大小写/空白不敏感，`WardrobeManageActions.nameConflicts`）；运行时所有 name 排序按 `(name, id.uuidString)` 决胜，与导出快照约定一致——Swift sort 不稳定，同名顺序不得随 fetch 漂移。
- **推荐确定性**：同输入必同输出，不随 SwiftData 关系数组顺序/进程 hash seed 漂移——六三一聚族先按色相排序（置换不变性测试锁）、体型 affinity 按属性 rawValue 排序累加（防权重表引入非整数后浮点结合律绕过 tie-break）、Adapter 保「中性无 hue」语义可达（quick-add 衣柜不得全并列退化为 UUID 序推荐）。组合枚举按 grammar 硬规则拆枝（裙枝/上下装枝分开，N=12 冷天 34 万次迭代 → 2.4 万），grammar 仍是最终裁判；每槽截断前按体型 affinity 预打分（(预分, id) 序——纯 id 前缀截断等于打分前随机抽样，大衣柜最合体型单品可能从未被评估）。程序化裸体栅格走 `FullNudeBodyImageCache`（View body 不得每次重求值全画布重绘）。
- **同槽择优口径**：`OutfitAvatarComposer` 的「有图」= 文件真实存在（`ItemImageStore.fileExists`，stat 不读内容），非路径非空——反向孤儿死路径不得劫持择优。`Int(CGFloat)` 转换一律浮点域先钳非有限值（GeometryReader 首帧 0/∞ → `Int(NaN)` 是运行时陷阱；3 处修复）。
- **图片对账**：`ImageReconcileService`（Today bootstrap 触发）——孤儿文件（无行引用）删文件、死路径（文件消失）清 nil 落库（失败内存还原 + rollback），崩溃窗口/部分失败产生的两类孤儿自愈闭环；文件名即 `{itemID}.{ext}` 使对账 O(n)。
- **叠衣确定性**：`OutfitAvatarComposer` displaySlot hint 排序 + composer 确定性 + zIndex 钉死 + dirty-dress 抑制；`OutfitCompleter.maxOptionsPerSlot` 限每槽候选数。
- **Schema 单向门（D84）**：容器装配唯一入口 `LoomiesStore.makeContainer()`（`LoomiesSchemaV1: VersionedSchema` + `LoomiesMigrationPlan`）——实体清单只此一处，app-shell 不得手搓 `Schema([...])`（有 lint）。两个 `ModelConfiguration` **各带子 schema**（D5 载荷：都传 fullSchema 会让身体数据落主库），`name`（main/local）派生 store 文件名**禁止改名**。破坏性 schema 变更由 `ClosetCore.SchemaFingerprint` + 入库 golden `Fixtures/SchemaFingerprint-v1.txt` 硬拦（旧行消失/版本 bump/golden 畸形皆 destructive；record 模式先差分后写盘，破坏性永不落盘）；加法安全 = 属性 optional **或**有默认且非 unique、关系 optional 且有 inverse。改 app-shell 装配须 `xcodebuild` 真编译验证。
- **数据生命周期**：删除级联 person→profiles、wardrobe→plans+图文件、**deleteItem 随 commit 删本地图**（责任在服务层，调用方重复删幂等）、deleteAll 全走 `ModelSave`；`wipeItemImageDirectory` 全删才算成功，失败经 `DeleteReceipt.imageWipeFailed` 在 summaryLine 诚实提示（CCPA 删除权）；导出确定性（id tie-break 排序）；`Item.barcode` 端到端。
- **cinematic 临时文件**：MP4 生命周期闭环——分享面板 onDismiss 即删、换新前删旧、导出失败清残片（cancelWriting + removeItem）、Today bootstrap 扫尾 `sweepTemporaryExports`；exporter 内置衣物下限守卫（层声明本地照片但全部读不出 → `garmentsUnavailable`，不得静默产出纯裸体底座视频）。
- **跨柜不变量**在所有入口点强制（transfer / draft / search / copilot），非仅服务层。
- **Hero/cinematic**：30fps 解码缓存、yaw 门控、VO 标签、空层门、writer-death 挂起修复、确定性帧 fallback；`AvatarCinematicExporter` **非 MainActor**（48 帧合成 + 编码在协作池跑，主线程不冻结；bundle 探测走线程安全 `BodyAvatarImageCache`）。
- **Photoreal shape 维度**：命名 `photoreal_{sex}_{phenotype}_{shape}_{front|yaw###}`，resolve 链 shape 专属 → 表型 → 通用（D69 防换人守卫不变）；shape 真图命中时 View 旁路 preset warp（`BodyMorphParams.removingShapePreset`，防「真体型 + 拉伸」双重效果）；认证白名单已收 shape token。**资产 QA 门 `PhotorealInventoryQATests`**：矩阵账本（缺格 == 已知待补清单，当前 = eastAsian 13 张锁脸转角）、全库严格 2:3 尺寸、命名合法性——出图落盘必先过此门（任务清单见 BODY-AVATAR-IMAGE-PROMPTS §10）。
- **设备传感器单例**：`SharedDeviceMotion` 是全 App 唯一 `CMMotionManager`（Apple 明文单实例），引用计数启停 + 弱引用自愈；`DepthParallaxMotion` 薄壳幂等 start/stop；View 侧 `onChange(reduceMotion)` 带可见性守卫（离屏视图树不得重启传感器）。
- **位图缓存边界**：`BodyAvatarImageCache` / `BodyMorphImageCache` 走 `NSCache` 按字节 cost 限额（128MB/96MB + countLimit 兜底；条目数限容会让解码位图峰值数百 MB → jetsam），近似 LRU 且内存压力自动清；负缓存语义保留（miss 也存，缺资产不得每 tick 打盘）——morph 缓存补齐 miss 负缓存；bundle probe 表 512 上限（key 域数据驱动防泄漏）；`bundleUIImage/NSImage` 平台原图独立计费缓存（morph render 输入不再每次读盘+全量解码）。
- **a11y**：`.combine` 只圈文本列、CTA 保持独立 VO target（入库拍摄、Closet 空态同规则）；hero orbit `accessibilityAdjustableAction`（`orbitAdjustableStep`）；tap target 下限 `orbitDotHitArea=24` / `lookPagerChevronHitArea=44` / `measureStepperHitArea=44` / `orbitChevronHitArea=44`。Closet 网格与 Body 表型/体型格在 `DynamicTypeSize >= .accessibility1` 收成单列（`AccessibilityGridColumns`）。
- **测试隔离**：`ITEM_IMAGE_ROOT` per-process 临时目录——**全部触盘套件**（Model/Intake/UI 三包共 12+ 套件）init 装 `ItemImageTestRoot.install()`，勿写真机目录（reconcile 类测试在真目录上会误删）；异步测试用 rendezvous 替代 wall-clock sleep。
- **存储目录 fail-closed**：`ItemImageStore` 基目录取不到时不退 tmp（tmp 被系统按存储压力清空 = 全部单品图必然反向孤儿）——`rootDirectory: URL?` 返回 nil → save 诚实失败。

## 模块依赖 DAG

<!-- AUTO-MANAGED:dep-dag -->
```
ClosetCore
  ↑
ClosetModel ← ClosetIntake
  ↑              ↑
  └──── ClosetUI ┘
```
<!-- /AUTO-MANAGED:dep-dag -->

## API 表

<!-- AUTO-MANAGED:api-table -->
| 外部公开 API | 用途 | 鉴权 | 实现 |
|--------------|------|------|------|
| Open-Meteo Geocoding | 城市 → lat/lon | 无 | `OpenMeteoWeatherProvider` |
| Open-Meteo Forecast | 日间高气温 °F | 无 | 同上；失败 → `CityClimateWeatherProvider` |
| Open Product Facts | 条码 → 品名/品牌 | 无 | `OpenProductFactsClient` |
| Open Beauty Facts | 个护条码回退 | 无 | 同上链式 host |
| Open Food Facts | 末位回退 | 无 | 同上 |
| （表数据）尺码参考桥 | US/EU/UK 提示 | n/a | `PublicSizeReference` |
| WeatherKit | 可选真机增强 | Apple | 未接；可实现 `WeatherProviding` |
<!-- /AUTO-MANAGED:api-table -->
