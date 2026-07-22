# 交接文档（HANDOFF）

> 2026-07-22。本次连续 loop 建成 v1.0 的**完整可验证核心**（109 tests 全绿 + UI 编译通过）。
> 这份文档是你在 Xcode 接手时的入口。

## 一句话状态

方向已定 **copilot**（用户掌舵、App 跑腿），数据模型冻结，**推荐引擎 + 数据层 + UI 逻辑 + 记录闭环全部命令行验证**；剩下是 Xcode 组装 + 真机验证（渲染/CloudKit/Vision）。

## 已建并验证（命令行 swift test/build，无需模拟器）

| 包 | 内容 | 验证 |
|----|------|------|
| `Packages/ClosetCore` | 纯逻辑：FFIT 体型 / ease 合身 / 尺码归一化 / F4 四条正确性 / 组套 / 配色 60-30-10 / 体型加权 / 场合正式度 / **copilot 补全器** | 85 tests |
| `Packages/ClosetModel` | SwiftData 7 实体 + §2.3 全语义（跨柜不变量/转移缺件/删除级联）+ 适配层 + RecommendationService + **打卡防重复闭环** | 20 tests（内存 ModelContainer）|
| `Packages/ClosetUI` | DesignSystem（§10）+ CopilotViewModel/View + IntakeView + AppRootView（TabView 壳）+ ClosetGridView | 4 ViewModel tests + 全部视图 swift build 编译 |
| `Packages/ClosetIntake` | F1 入库 capability seam：抠图/打标/OCR 协议 + mock + IntakeViewModel + **VisionMattingService（真实抠图，编译验证）** | 4 tests（mock）+ Vision swift build 编译；真机跑推理 |

一键回归：
```bash
for p in ClosetCore ClosetModel ClosetUI; do swift test --package-path Packages/$p; done
```

## v1.0 核心回路（已闭合验证）

```
入库 → 管理（多衣柜/转移/删除，跨柜不变量）→ 推荐（copilot 补全，四条正确性）→ 记录（打卡）
                                                          ↑___________防重复反哺__________|
```
端到端已测：真实 SwiftData 单品 → 适配器 → copilot 补全 → 打分候选（含「为什么推荐」）；打卡 → 穿着历史 → 下次推荐避开近 7 天穿过的。

## 你接手要做的（需 Xcode / 真机）

1. **组装 Xcode App target**：见 `app-shell/README.md` + `ClosetApp.swift.template`（填 CloudKit container id）。加三个本地 SPM 包。
2. **真机验证**（本环境验不了）：
   - CopilotView 渲染与交互（模拟器）
   - CloudKit 私有库真同步 + 双机竞态（真机 ×2）
   - Vision 抠图 / OCR（真机，模拟器不支持）
   - Liquid Glass 自定义玻璃 ≤2 处（glassEffect，§10.2）+ WeatherKit 取温接线
3. **未建（v1.0 待补，多数需真机或有 mock 可先测）**：
   - 扫描入库流水线 F1（连拍/PHPicker/Vision 抠图）——SI-0 capability 协议+mock 可先在本环境测，真实推理需真机
   - 洗标 OCR、体型可视化文字标记 UI、设置页、通知、遥测接入
   - 幂等转移操作记录 DL-6（CloudKit 合并，D15 已降级 v1.x）

## 关键决策速查（详见 `docs/decisions.md`）

- D19 核心机制 = copilot（方法④强先验 ~7:1 + 用户通过 V2 裁决；**可回溯**，落地页 A/B 未真跑）
- D5 身体维度仅本地域（不进 CloudKit）；D15 CloudKit 完整合并降 v1.x；D16 v1.0 纯免费层
- 数据模型冻结（§2）；加法 schema 演进不算破冻（§11.1）

## 还没做的验证（最大剩余风险）

- **R1 真人验证**：方法④（AI 已跑）只是强先验；管家测试 + 落地页 A/B（`docs/validation-kit/` 启动包已备，`landing/` V1/V2 双臂已建）需你去跑，确认 copilot 方向。
- 建议：动 Xcode UI 前或并行跑一轮真人验证。
