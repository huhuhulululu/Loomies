# 交接文档（HANDOFF）

> 2026-08-03。v1.0 **CLI 可验证面**完整（**139 tests** 全绿 + UI 编译通过）。
> 这份文档是你在 Xcode 接手时的入口。

## 一句话状态

方向已定 **copilot**（用户掌舵、App 跑腿），数据模型冻结，**推荐引擎 + 数据层服务全集 + UI 逻辑 + 记录/日历/检索/体型门/合身标记**均可命令行验证；剩下是 Xcode 组装 + 真机验证（渲染/CloudKit/Vision/WeatherKit）。

## 已建并验证（命令行 swift test/build，无需模拟器）

| 包 | 内容 | 验证 |
|----|------|------|
| `Packages/ClosetCore` | FFIT / ease / F4 四条正确性 / 组套 / 配色 / 体型加权 / 场合 / **copilot 补全器** / **WeatherProviding** | **87 tests** |
| `Packages/ClosetModel` | 7 实体 + §2.3 全语义 + 适配层 + RecommendationService + 打卡防重复 + **Search / BodyProfile(R13) / FitMark / CalendarPlan** + 平铺宽字段 | **35 tests** |
| `Packages/ClosetUI` | DesignSystem + Copilot（wear/body/weather 注入）+ IntakeView + **Onboarding/CheckIn VM** + **AppRoot 4-tab**（Today/Closet/Calendar/Me） | **13 tests** + swift build |
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

## 你接手要做的（需 Xcode / 真机）

1. **组装 Xcode App target**：见 `app-shell/README.md` + `ClosetApp.swift.template`（填 CloudKit container id）。加四个本地 SPM 包（含 ClosetIntake）。
2. **真机验证**：
   - Copilot / Onboarding / CheckIn 渲染与交互（模拟器可先）
   - CloudKit 私有库真同步 + 双机竞态（真机 ×2）
   - Vision 抠图 / OCR（真机）
   - WeatherKit 实现 `WeatherProviding`（替换 Fixed）
   - Liquid Glass 自定义玻璃 ≤2 处
3. **未建 / 真机侧待补**：
   - 连拍/PHPicker 全流水线 UI 接线
   - 洗标 OCR 真实现、设置页完整、通知、遥测接入
   - Calendar/Me 从 placeholder → 完整 View（服务已就绪）
   - 幂等转移操作记录 DL-6（CloudKit 合并，D15 降级 v1.x）
   - AI Worker + App Attest（v1.0 最小打标基建）

## 关键决策速查（详见 `docs/decisions.md`）

- D19 核心机制 = copilot；D20 跳过真人验证；D21 遥测预注册；D22 本 wave CLI 完整性
- D5 身体维度仅本地域；D15 CloudKit 完整合并降 v1.x；D16 v1.0 纯免费层
- 数据模型冻结（§2）；加法 schema 演进不算破冻（§11.1）

## 还没做的验证（最大剩余风险）

- **R1 真人验证**：已跳过（D20）；上线后按 MARKET §8 遥测裁决协议验证
- 端侧抠图真机方差、CloudKit 生产 schema 单向门
