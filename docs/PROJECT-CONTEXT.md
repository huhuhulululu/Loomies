# Project Context

> 与 `ARCHITECTURE.md`（架构目录）、`decisions.md`（ADR）、`HANDOFF.md`（交接指南）配合使用。

## 项目

cloth / **Loomies** — 每日穿搭与衣橱管理 iOS App，**copilot** 机制（用户掌舵、App 跑腿）。
Swift / SwiftUI / SwiftData | SwiftPM 4 包 + app-shell（XcodeGen）| min iOS 26，首发美国区
分支: main | 状态页: https://m424.tailb5f9cb.ts.net:10029/（仅 tailnet）

## 当前状态（2026-08-13）

- **1700 tests 全绿**（Core 580 / Model 424 / UI 614 / Intake 82）+ `xcodebuild` iOS 真编译
- **本地 v1.0 功能闭环 + 三轮完整性审计缺口清单全部清空**（第一轮 D100 / 第二轮 46-agent / 第三轮 64-agent，对账见 `.claude-state/requirements.md`）
- TestFlight **build 44** 在 ASC（无 Widget，待 C1）；CloudKit 默认 off
- 主屏 Widget（D197/D210）：今日搭配 + 配色色点，App Group 通道（**后台注册未做，见 HANDOFF**）
- 决策文档五份逐份核实过账（D195-D207），`DOC-SYNC.md` + `DocSyncMapTests` 守着不再过期
- 结构门体系 ~30 道 lint 门 + 空转自检（D208/D209）；三道性能门带机器负载判据（D211）

## 里程碑（近期）

| 节点 | 日期 | 成果 |
|------|------|------|
| 打磨波 | 2026-08-10 | 15 轮 polish 收敛（D80/D81），586 tests |
| 三轮对抗审计 | 2026-08-10→12 | 24+46+64 agent，缺口清单三轮全清（D98-D112） |
| 新代码复审四批 | 2026-08-13 | D133-D138 收口，TestFlight build 43 |
| 审计尾波+市场线 | 2026-08-13 | 合身反馈进排序（D196/D200）、Widget（D197/D210）、遥测判定契约（D201） |
| 文档过账+门体系 | 2026-08-13 | DOC-SYNC（D206/D207）、遍历门空转自检 12+9 道（D208/D209）、locale 时刻（D211） |

## 下一步（详单见 `HANDOFF.md`）

1. **用户侧**：App Group 后台注册 → `DEVICE-ACCEPTANCE.md` 真机验收全清单
2. **真机/云端**：CloudKit 同步与双机竞态、Vision/OCR 真推理、§11.4 性能预算（Instruments）
3. **产品决策**：体型 preset ≥5% vs uncanny（D202）、tight 惩罚权重 0.2（D200）
4. **基建**：CI（性能门需安静机器）、遥测 sink、云端 AI worker

## 关键约束

- copilot（D19）；ClosetCore 零 iOS SDK；依赖 UI → Model → Core；Widget 只依赖 Core
- SwiftData 双域（D5）；遥测走 TelemetryEvents 白名单；schema 单向门（D84，golden 指纹）
- 撞门纪律（D160-D172-D209）与遍历自证（D208）——见 `CLAUDE.md`

## 验证

```bash
for p in ClosetCore ClosetModel ClosetUI ClosetIntake; do
  swift test --package-path Packages/$p
done
xcodebuild -project app-shell/ClosetApp.xcodeproj -scheme ClosetApp \
  -destination 'generic/platform=iOS' build
```
