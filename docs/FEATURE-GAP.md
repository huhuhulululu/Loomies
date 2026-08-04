# 功能缺口台账（相对 DESIGN §7 v1.0）

> 2026-08-03 D29 后。与代码不一致时以代码为准。

## 已闭合（本环境可验证）

| 能力 | 落点 |
|------|------|
| 推荐引擎 + copilot 补全 + 四条正确性 | ClosetCore |
| SwiftData 实体 + 转移/删除/不变量 | ClosetModel |
| 打卡防重复 | CheckInService |
| 检索 / 体型门 / 合身标记 / 日历计划 | Search/BodyProfile/FitMark/CalendarPlan |
| 入库 seam + mock | ClosetIntake |
| Onboarding / Today / Closet 网格 / 打卡 | ClosetUI |
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
| **纸娃娃叠衣预览** | `OutfitAvatarComposer` + Today 建议卡 / 收藏列表 |
| TestFlight build 7–11 | 体型/入库/叠衣持续迭代 |

## 真机 / 云端仍缺（不阻塞本地闭环）

| 能力 | 说明 |
|------|------|
| PHPicker / 相机连拍 | **相册 + 相机** 已接线（`AddPieceSheet`）；真机验相机 |
| Vision 抠图 / OCR 真推理 | **Vision 真机优先**（`IntakeServiceFactory`）；模拟器 mock |
| 单品本地图 | `Item.localImageRelativePath` + `ItemImageStore`；网格/详情缩略图 |
| WeatherKit | 协议已隔离；现用城市气候表，真机可换实现 |
| CloudKit 私有库 | D5 双域已模板，Capability 待开 |
| AI 打标 Worker + App Attest | 独立服务 |
| 通知 / Widget | 权限与真机 |
| 叠衣槽位真图 | **Today/收藏已叠入库图**（表达层）；肩线精修仍后置 |

## v1.x（明确后置）

embedding 语义搜、LLM 编排、尺码表种子、统计簇、差旅、IAP；纸娃娃叠衣精细化（肩线微调 / 小样本「不怪异」验收）；真 3D/SMPL 体型
