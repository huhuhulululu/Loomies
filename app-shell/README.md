# App 外壳组装（需 Xcode）

> 这里是**唯一需要 Xcode 才能构建/运行**的部分（薄壳）。核心逻辑与 UI 都在 SPM 包里，已 swift build/test 验证：
> `ClosetCore` 87 + `ClosetModel` 35 + `ClosetUI` 13 + `ClosetIntake` 4 = **139 tests** 全绿。

## 组装步骤

1. Xcode 26 新建 iOS App（min iOS 26，SwiftUI 生命周期），命名（品牌名待定，见 DESIGN §11.9）。
2. 删掉模板的 ContentView，把四个本地 SPM 包加为依赖：File → Add Package Dependencies → Add Local → 选 `Packages/ClosetCore`、`Packages/ClosetModel`、`Packages/ClosetUI`、`Packages/ClosetIntake`。
3. 用 `ClosetApp.swift.template` 内容替换 App 入口（填入你的 CloudKit container id）。
4. Signing & Capabilities 加：**iCloud（CloudKit 私有库）**、**Push（WidgetKit 刷新，见 §10.2）**、后续 **App Attest**（AI 代理，§4.4）。
5. `Info.plist` 加权限文案：相机（入库）、照片（PHPicker，§F1）、日历（EventKit 可选，§F4）。
6. 真机运行（Vision 抠图/CloudKit 同步需真机，模拟器不支持部分能力，§11.2）。

## 已在包里 / 待真机 target 补

| 已验证（swift build/test） | 待真机 target 接线 |
|---------------------------|-------------------|
| 推荐引擎（copilot 补全）、数据模型 + §2.3 全部语义、CopilotViewModel、CopilotView 编译 | CloudKit 真同步、Vision 抠图/OCR、WeatherKit 取温、Liquid Glass 自定义玻璃（≤2 处 glassEffect）、App Attest 代理、通知 |

## 数据层双域配置（D5：身体维度不进 CloudKit）

`ClosetApp.swift.template` 里演示双 ModelConfiguration：
- 主域（Person/Wardrobe/Item/... 7 实体）→ `cloudKitDatabase: .private(容器id)`
- 本地域（PersonBodyProfile）→ `cloudKitDatabase: .none`（身体维度只本地，D5/§5）
