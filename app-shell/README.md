# App 外壳（Xcode）

> 薄壳 App target + 四个本地 SPM 包。逻辑/UI 在 `Packages/`，本目录只负责组装与运行。
> 包测试：Core 92 + Model 38 + UI 20 + Intake 4 = **154 tests**。

## 一键：生成 / 构建 / 跑模拟器

```bash
cd app-shell

# 1) 从 project.yml 生成工程（改 yml 后重跑）
xcodegen generate

# 2) 模拟器构建
xcodebuild -scheme ClosetApp -project ClosetApp.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' \
  -configuration Debug build

# 3) 安装并启动（先 boot 模拟器）
APP=~/Library/Developer/Xcode/DerivedData/ClosetApp-*/Build/Products/Debug-iphonesimulator/Closet.app
UDID=$(xcrun simctl list devices available | grep 'iPhone 17 Pro' | grep -v unavailable | head -1 | grep -oE '[A-F0-9-]{36}')
xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator
xcrun simctl install "$UDID" $APP
xcrun simctl launch "$UDID" com.pinglin.closet

# 或直接在 Xcode 打开
open ClosetApp.xcodeproj
```

## 工程要点

| 项 | 值 |
|----|-----|
| Bundle ID | `com.pinglin.closet` |
| Team | `28626PSX5Y`（Automatic signing） |
| min iOS | 26.0 |
| SPM 本地包 | ClosetCore / ClosetModel / ClosetUI / ClosetIntake |
| CloudKit | **默认关闭**（`cloudKitDatabase: .none`），模拟器可直接起 |
| 首启 | 无衣柜 → Onboarding（名+城）→ AppRoot 4-tab |

## 真机下一步

1. Signing 选你的 Development Team（已写 `28626PSX5Y`）。
2. Capabilities：iCloud（CloudKit 私有库）→ container 建议 `iCloud.com.pinglin.closet`。
3. `ClosetApp.swift` 里把 mainConfig 改为  
   `cloudKitDatabase: .private("iCloud.com.pinglin.closet")`。
4. 可选：Push、App Attest、WeatherKit。
5. Vision 抠图 / OCR 仅真机可靠。

## 文件

```
app-shell/
  project.yml              ← XcodeGen 真相源
  ClosetApp.xcodeproj/     ← xcodegen generate 产出
  ClosetApp/
    ClosetApp.swift        ← @main + RootView + Onboarding
    ClosetApp.entitlements ← 本地空；真机再加 CloudKit
    Assets.xcassets/
  ClosetApp.swift.template ← 历史模板（CloudKit 版参考）
  README.md
```
