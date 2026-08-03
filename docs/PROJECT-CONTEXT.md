# Project Context

> 与 `ARCHITECTURE.md`（架构目录）和 `decisions.md`（ADR）配合使用。

## 项目

cloth — 每日穿搭与衣橱管理 iOS App，**copilot** 机制（用户掌舵、App 跑腿）。
Swift / SwiftUI / SwiftData | SwiftPM 4 包 + app-shell | min iOS 26，首发美国区
分支: main | 状态页: https://m424.tailb5f9cb.ts.net:10029/（仅 tailnet）

## 当前状态

- **156 tests** 全绿（Core 92 / Model 40 / UI 20 / Intake 4）
- **Xcode 已组装**且模拟器闭环可用：种子数据、快捷入库、建议打卡、搜索
- CloudKit 默认 off；首启 Onboarding（自动灌 sample pieces）→ AppRoot 4-tab

## 里程碑

| 节点 | 日期 | 成果 |
|------|------|------|
| v1.0 CLI 完整性 | 2026-08 | search/fit/calendar/onboarding/check-in |
| Wave B | 2026-08-03 | 检索/切换 VM + 拼贴 + 冷启动 + 遥测 schema |
| Xcode 模拟器 | 2026-08-03 | XcodeGen + sim build/launch |
| 模拟器闭环 | 2026-08-03 | DemoSeed + Closet+/打卡（D25） |

## 下一步

1. 真机：CloudKit / Vision / WeatherKit
2. Calendar/Me 从 placeholder 补全
3. 多衣柜切换 UI 接到壳上

## 关键约束

- copilot（D19）；ClosetCore 零 iOS SDK；依赖 UI → Model → Core
- SwiftData 双域（D5）；遥测走 TelemetryEvents 白名单

## 验证

```bash
for p in ClosetCore ClosetModel ClosetUI ClosetIntake; do
  swift test --package-path Packages/$p
done
cd app-shell && xcodegen generate && xcodebuild -scheme ClosetApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' build
```
