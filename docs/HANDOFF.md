# 交接文档（HANDOFF）

> 2026-08-03。CLI **156 tests** 全绿 + **Xcode 模拟器可跑闭环**（种子/入库/打卡）。

## 一句话状态

方向已定 **copilot**，数据模型冻结；引擎 + 数据服务 + UI 逻辑（含检索/衣柜切换/冷启动/拼贴草稿/遥测 schema）均可命令行验证。剩下是 Xcode 组装 + 真机（渲染/CloudKit/Vision/WeatherKit）。

## 已建并验证（命令行 swift test/build，无需模拟器）

| 包 | 内容 | 验证 |
|----|------|------|
| `Packages/ClosetCore` | FFIT / ease / F4 / copilot 补全 / WeatherProviding / **FitMarkCopy** / **TelemetryEvents** | **92 tests** |
| `Packages/ClosetModel` | 7 实体 + §2.3 + 推荐/打卡 + Search/BodyProfile/FitMark/CalendarPlan + **OutfitDraft** | **38 tests** |
| `Packages/ClosetUI` | DesignSystem + Copilot（冷启动门）+ Onboarding/CheckIn/**Search/WardrobeSwitcher** + 4-tab 壳 | **20 tests** + build |
| `Packages/ClosetIntake` | F1 capability seam + VisionMattingService | **4 tests** + Vision build |

一键回归：
```bash
for p in ClosetCore ClosetModel ClosetUI ClosetIntake; do
  swift test --package-path Packages/$p
done
```

## v1.0 核心回路（已闭合验证）

```
Onboarding → 入库 → 管理（多衣柜/转移/删除/跨柜检索）
                         ↓
              copilot（天气×场合×体型×近7天防重复）
                         ↓
              打卡 → WearHistory 反哺 ──┘
                         ↓
              日历计划 ↔ Outfit 缺件 needsAttention
```

## Xcode / TestFlight 状态（2026-08-03）

发版预备见 `app-shell/TESTFLIGHT.md`：图标/隐私/脚本已就绪；**须在 Terminal.app 解锁钥匙串后 archive**，并提供 ASC **Issuer ID**（Key `YFRZC2GC2V` 已在 `~/.appstoreconnect/private_keys/`）。

## Xcode 状态（2026-08-03）

**已本地组装并模拟器跑通**：
- `app-shell/project.yml` + `xcodegen generate` → `ClosetApp.xcodeproj`
- `xcodebuild` → **BUILD SUCCEEDED**（iPhone 17 Pro / iOS 26.2）
- `simctl launch com.pinglin.closet` 已起；`open ClosetApp.xcodeproj` 可继续改

```bash
cd app-shell && xcodegen generate
open ClosetApp.xcodeproj   # ⌘R 跑模拟器
```

## 你接手要做的（真机 / 产品化）

1. **真机**：Signing Team 已填 `28626PSX5Y`；开 iCloud CloudKit 后改 mainConfig 为 `.private("iCloud.com.pinglin.closet")`。
2. **真机验证**：CloudKit 双机、Vision 抠图/OCR、WeatherKit 实接 `WeatherProviding`、Liquid Glass ≤2。
3. **未建 / 待补**：
   - 连拍/PHPicker 全流水线 UI 接线
   - 洗标 OCR 真实现、设置页完整、通知、遥测 SDK 接入
   - Calendar/Me 从 placeholder → 完整 View
   - DL-6 幂等转移（D15 降 v1.x）、AI Worker + App Attest

## 关键决策速查（详见 `docs/decisions.md`）

- D19 核心机制 = copilot；D20 跳过真人验证；D21 遥测预注册；D22 本 wave CLI 完整性
- D5 身体维度仅本地域；D15 CloudKit 完整合并降 v1.x；D16 v1.0 纯免费层
- 数据模型冻结（§2）；加法 schema 演进不算破冻（§11.1）

## 还没做的验证（最大剩余风险）

- **R1 真人验证**：已跳过（D20）；上线后按 MARKET §8 遥测裁决协议验证
- 端侧抠图真机方差、CloudKit 生产 schema 单向门
