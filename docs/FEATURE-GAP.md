# 功能缺口台账（相对 DESIGN §7 v1.0）

> **最近核实：2026-08-13（D195），逐条对着代码查过。** 与代码不一致时以代码为准。
>
> ⚠️ **这份台账是决策文档——过期比缺失更危险。** 本次核实前它至少三条已经与代码不符
>（批量入库说「未做」而 D92 早已交付、跨柜检索说「UI 恒钉当前柜」而 Picker 就在
> `AppRootView` 里、通知说「权限与真机」而 D118 的 `DailyRitualScheduler` 已接线）。
> 照着它规划，就是 `.claude-state/requirements.md` 开头警告过的那句：
>「不对账就照着它干活 = 照着虚构的缺口干活」。
>
> **改功能的那一波，顺手核实这张表。**

## 已闭合（本环境可验证）

| 能力 | 落点 |
|------|------|
| 推荐引擎 + copilot 补全 + 四条正确性 | ClosetCore |
| SwiftData 实体 + 转移/删除/不变量 | ClosetModel |
| 打卡防重复 | CheckInService |
| 检索（**含跨柜**：`SearchScope.thisCloset/allClosets`，Picker 在 `AppRootView`；§2.3 全局检索**已闭合**，2026-08-13 核实）/ 体型门 / 合身标记 / 日历计划 | Search/BodyProfile/FitMark/CalendarPlan |
| 入库 seam + mock | ClosetIntake |
| Onboarding / Today / Closet 网格 / 打卡 | ClosetUI |
| **Today Avatar 首屏（方案 B）** | 大 BodyAvatar + 今日 look；Other looks 点选；非冷启动自动 full-auto |
| 调试台 + 诊断导出 | DebugSettings / DiagnosticsExport |
| **数据导出 + 删除全部** | `DataLifecycleService`（JSON 全实体；身体围度默认不含；CCPA 删除权 + 二次确认 + 清 ItemImages） |
| **单品状态机** | ItemStatusService + ItemDetailView |
| **单品编辑** | ItemEditorService |
| **转移 UI** | TransferViewModel |
| **存放位置树** | StorageLocationService |
| **收藏搭配 + 入日历** | OutfitFavoriteService + OutfitActionsViewModel |
| **身体四围 + FFIT** | BodyProfileViewModel |
| **真人体型参考 + 360°** | BodyAvatarYaw 8 角切帧 + 5 体型写实图；Me 体型页拖拽/点选（非 VTON / 无插值动画） |
| **连续 BodyMorph** | `BodyMorphParams` + 分条变形；测量/预设/精调滑杆（胸腰臀高）实时预览；非 SMPL |
| **BodyMorph fine-tune 持久化** | `PersonBodyProfile.fine*` + saveFineTune；重进 Me 保留 |
| **体型双轨录入** | 5 图快选 + 四围 Stepper（in/cm）+ 上臀推断 + Fit confidence；Onboarding 可选体型 |
| **衣柜管理/切换** | WardrobeManageView + Root menu |
| **About** | AboutView |
| **日历完整 UI** | CalendarView：列表/关注/从收藏排期/删除 |
| **Me 补全** | 城市编辑、个人色彩季型、存放位置树 |
| **合身标记网格** | Closet 格徽章 + 状态过滤；详情页 FitMark |
| **离线城市天气** | CityClimateWeatherProvider → Today 温区 |
| **公开 API 天气（D77）** | Open-Meteo + Composite fallback；来源标签 + 降水外套提示 |
| **公开条码商品（D77）** | Open Product/Beauty/Food Facts → 入库 enrich |
| **尺码参考提示（D77）** | PublicSizeReference（not brand-true） |
| **纸娃娃叠衣预览** | `OutfitAvatarComposer` + Today 建议卡 / 收藏列表 |
| **主路径旅程测试** | `FeatureJourneyTests`：种子→推荐→收藏/计划→打卡→检索→体型→导出/删除 |
| TestFlight build 7–13 | 体型/入库/叠衣/打磨持续迭代 |

## 真机 / 云端仍缺（不阻塞本地闭环）

| 能力 | 说明 |
|------|------|
| 相机真机验证 | 相册**批量多选已交付**（D92 `BatchIntakeQueue`，`selectionLimit = BatchIntakeQueue.maxSelection = 30`，逐张确认 + 诚实汇总）；**仍缺的只有相机在真机上的实拍验证** |
| Vision 抠图 / OCR 真推理 | **Vision 真机优先**（`IntakeServiceFactory`）；模拟器 mock |
| WeatherKit | 协议已隔离；现主路径 Open-Meteo，真机可再实现 `WeatherProviding` |
| CloudKit 私有库 | D5 双域已模板，两个 store 当前都是 `cloudKitDatabase: .none`；Capability 待开。**D170 已证「身体数据不同步靠分区而非没开同步」**，端到端仍需真机 + 云端容器 |
| AI 打标 Worker + App Attest | 独立服务；`IntakeServiceFactory.recognitionAvailable = false`，未接前披露文案会说清「类型/场合是起点猜测，不是照片识别」 |
| Widget | **已交付**（D197 快照+target；D210 配色色点+单色渲染诚实降级）。仍缺：App Group 开发者后台注册（未注册前 inert）+ 真机验收 §5（HANDOFF C1/B1）。通知早于它交付（D118），缺真机权限流验证 |
| 叠衣槽位真图 | **Today/收藏已叠入库图**（表达层）；肩线精修仍后置 |

## v1.x（明确后置）

embedding 语义搜、LLM 编排、尺码表种子、统计簇、差旅、IAP；纸娃娃叠衣精细化（肩线微调 / 小样本「不怪异」验收）；真 3D/SMPL 体型
