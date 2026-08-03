# Project Context

> 与 `ARCHITECTURE.md`（架构目录）和 `decisions.md`（ADR）配合使用。

## 项目

cloth — 每日穿搭与衣橱管理 iOS App，**copilot** 机制（用户掌舵、App 跑腿）。
Swift / SwiftUI / SwiftData | SwiftPM 4 包 + app-shell | min iOS 26，首发美国区
分支: main | 状态页: https://m424.tailb5f9cb.ts.net:10029/（仅 tailnet）

## 当前状态

- **154 tests** 全绿（Core 92 / Model 38 / UI 20 / Intake 4）
- **Xcode 已组装**：`app-shell/ClosetApp.xcodeproj`，模拟器 iPhone 17 Pro / iOS 26.2 **BUILD SUCCEEDED** 且可 launch
- CloudKit 默认 off；首启 Onboarding → AppRoot 4-tab

## 里程碑

| 节点 | 日期 | 成果 |
|------|------|------|
| v1.0 CLI 完整性 | 2026-08 | search/fit/calendar/onboarding/check-in |
| Wave B | 2026-08-03 | 检索/切换 VM + 拼贴 + 冷启动 + 遥测 schema |
| Xcode 模拟器 | 2026-08-03 | XcodeGen + sim build/launch |

## 下一步

1. 模拟器可用闭环：演示种子数据 + Closet「+」入库 mock + 建议打卡 + 衣柜切换
2. 真机：CloudKit / Vision / WeatherKit
3. Calendar/Me 从 placeholder 补全

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
