# Project Context

> 与 `ARCHITECTURE.md`（架构目录）和 `decisions.md`（ADR）配合使用。

## 项目

cloth — 每日穿搭与衣橱管理 iOS App，**copilot** 机制（用户掌舵、App 跑腿）。
Swift / SwiftUI / SwiftData | SwiftPM 4 包 + app-shell | min iOS 26，首发美国区
分支: main | 状态页: https://m424.tailb5f9cb.ts.net:10029/（仅 tailnet）

## 当前状态

- **584 tests** 全绿（Core 206 / Model 149 / UI 191 / Intake 38）
- **本地 v1.0 UI 闭环**：Today/Closet/Calendar/Me + BodyMorph + 合身网格 + 城市气候 + 数据导出/删除全部 + photoreal catalog 纸娃娃（D63–D75）
- CloudKit 默认 off；TestFlight **build 28** 在 ASC（D79）
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
| 数据生命周期 | 2026-08-03 | 全量导出 + CCPA 删除全部（D41） |
| Body Avatar catalog 波 | 2026-08-05 | catalog 丁字裤 basewear 真人照片底座 / 8 表型 × 8 角 / 纸娃娃穿衣 displaySlot（D63–D75） |
| 打磨波 | 2026-08-10 | 15 轮 polish 收敛（D80，~110 surgical fixes，不变量固化）+ 后续 a11y/测试质量/文案/工具链波（D81），584 tests |

## 下一步

1. 真机：CloudKit / Vision / WeatherKit 真 SDK
2. 叠衣肩线精修 / 原图 ZIP 打包
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
