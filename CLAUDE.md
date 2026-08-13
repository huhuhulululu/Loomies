# cloth — 每日穿搭与衣橱管理 iOS App

用户掌舵、App 跑腿的 copilot 式穿搭助手（min iOS 26，首发美国区）。
Swift / SwiftUI / SwiftData | SwiftPM 4 包 + app-shell（需 Xcode）| 主分支 main

## 关键约束

- 核心机制 = **copilot**（用户掌舵、App 跑腿，D19）——推荐永远可被用户覆盖，不做全自动决策
- ClosetCore 保持纯 Swift（零 iOS SDK 依赖，Foundation only），依赖方向只能 UI → Model → Core
- SwiftData 双域 ModelConfiguration（D5）；遥测字段走 TelemetryEvents/Payload 白名单
- 每包独立 `swift test` 必须全绿（Core 449 / Model 325 / UI 465 / Intake 57 = 1296）
- **Schema 单向门（D84）**：改实体前先读 `docs/decisions.md` D84；破坏性变更会让 `SchemaGuardTests` 硬失败，加法式变更需 `LOOMIES_SCHEMA_GOLDEN=record swift test --package-path Packages/ClosetModel --filter SchemaGuard` 重录 golden 并进 diff 审查；改 app-shell 装配后必须 `xcodebuild` 真编译验证（不参与 swift test）；**任何 `#if os(iOS)` 块同理**——macOS 的 swift test 根本编不到它（D92 实证：并发 Sendable 错误只有 xcodebuild 报）
- Debug：`LOOMIES_DEBUG=1` 或 scheme 参数 `-debugVerbose` / `-debugPanel`；Me → 调试台 / Export diagnostics

## 文档

| 文件 | 用途 |
|------|------|
| `docs/ARCHITECTURE.md` | 架构目录 — 检修/搭建唯一真相（每次提交维护） |
| `docs/DESIGN.md` | 产品设计真相 |
| `docs/MVP-PLAN.md` | MVP 计划（含完整 SPM 结构规划） |
| `docs/decisions.md` | ADR — 技术决策及理由 |
| `docs/BODY-AVATAR-IMAGE-PROMPTS.md` | 人体 croquis 出图/精修 prompt 手册（乳贴+丁字裤·同人锁脸） |
| `docs/PROJECT-CONTEXT.md` | 项目状态、里程碑、工作流 |
| `preview/` | 预览/设计/文档（`ts-publish.sh` 发布，状态页 :10029） |

## 验证

```bash
for p in ClosetCore ClosetModel ClosetUI ClosetIntake; do swift test --package-path Packages/$p; done
```
