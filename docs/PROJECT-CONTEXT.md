# Project Context

> 与 `ARCHITECTURE.md`（架构目录）和 `decisions.md`（ADR）配合使用。

## 项目

cloth — 每日穿搭与衣橱管理 iOS App，**copilot** 机制（用户掌舵、App 跑腿）。
Swift / SwiftUI / SwiftData | SwiftPM 4 包 + app-shell | min iOS 26，首发美国区
分支: main | 状态页: https://m424.tailb5f9cb.ts.net:10029/（仅 tailnet）

## 当前状态

- **~215 tests** 全绿（Core 123 / Model 54 / UI 34 / Intake 4）
- **本地 v1.0 UI 闭环**：Today/Closet/Calendar/Me + BodyMorph + 合身网格 + 城市气候
- CloudKit 默认 off；TestFlight build 7+ 在 ASC
- 真机/云（WeatherKit 真接、Vision、相机、CK）仍后置

## 里程碑

| 节点 | 日期 | 成果 |
|------|------|------|
| v1.0 CLI 完整性 | 2026-08 | search/fit/calendar/onboarding/check-in |
| Wave B | 2026-08-03 | 检索/切换 VM + 拼贴 + 冷启动 + 遥测 schema |
| Xcode 模拟器 | 2026-08-03 | XcodeGen + sim build/launch |
| 模拟器闭环 | 2026-08-03 | DemoSeed + Closet+/打卡（D25） |
| BodyMorph + TF | 2026-08-03 | 连续塑形 / 乳贴保护 / build 4–7 |
| 本地功能补全 | 2026-08-03 | Calendar/Me/Fit 网格/城市气候（D37） |

## 下一步

1. 真机：CloudKit / Vision / WeatherKit 真 SDK
2. 叠衣真图（入库抠图后）
3. 通知 / Widget
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
