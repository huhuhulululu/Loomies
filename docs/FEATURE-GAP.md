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
| **单品状态机** | ItemStatusService + ItemDetailView |
| **单品编辑** | ItemEditorService |
| **转移 UI** | TransferViewModel |
| **存放位置树** | StorageLocationService |
| **收藏搭配 + 入日历** | OutfitFavoriteService + OutfitActionsViewModel |
| **身体四围 + FFIT** | BodyProfileViewModel |
| **真人体型参考 + 360°** | BodyAvatarYaw 8 角切帧 + 5 体型写实图；Me 体型页拖拽/点选（非 VTON / 无插值动画） |
| **体型双轨录入** | 5 图快选 + 四围 Stepper（in/cm）+ 上臀推断 + Fit confidence；Onboarding 可选体型 |
| **衣柜管理/切换** | WardrobeManageView + Root menu |
| **About** | AboutView |
| TestFlight build 3 上传 | Loomies ASC |

## 真机 / 云端仍缺（不阻塞本地闭环）

| 能力 | 说明 |
|------|------|
| PHPicker / 相机连拍 | 需 PhotosUI 真机 |
| Vision 抠图 / OCR 真推理 | 模拟器不全 |
| WeatherKit | 实接 WeatherProviding |
| CloudKit 私有库 | D5 双域已模板，Capability 待开 |
| AI 打标 Worker + App Attest | 独立服务 |
| 通知 / Widget | 权限与真机 |
| 合身标记全量 UI 网格 | 服务已有，详情页已挂 |
| 叠衣槽位真图 | 纸娃娃锚点已有；衣物 PNG 叠层待入库抠图 |

## v1.x（明确后置）

embedding 语义搜、LLM 编排、尺码表种子、统计簇、差旅、IAP；纸娃娃叠衣精细化（肩线微调 / 小样本「不怪异」验收）
