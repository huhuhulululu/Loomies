# cloth — 每日穿搭与衣橱管理 iOS App

用户掌舵、App 跑腿的 copilot 式穿搭助手（min iOS 26，首发美国区）。
Swift / SwiftUI / SwiftData | SwiftPM 4 包 + app-shell（需 Xcode）| 主分支 main

## 关键约束

- 核心机制 = **copilot**（用户掌舵、App 跑腿，D19）——推荐永远可被用户覆盖，不做全自动决策
- ClosetCore 保持纯 Swift（零 iOS SDK 依赖，Foundation only），依赖方向只能 UI → Model → Core
- SwiftData 双域 ModelConfiguration（D5）；遥测字段走 TelemetryEvents/Payload 白名单
- 每包独立 `swift test` 必须全绿（Core 568 / Model 423 / UI 610 / Intake 82 = 1683）
- **Schema 单向门（D84）**：改实体前先读 `docs/decisions.md` D84；破坏性变更会让 `SchemaGuardTests` 硬失败，加法式变更需 `LOOMIES_SCHEMA_GOLDEN=record swift test --package-path Packages/ClosetModel --filter SchemaGuard` 重录 golden 并进 diff 审查；改 app-shell 装配后必须 `xcodebuild` 真编译验证（不参与 swift test）；**任何 `#if os(iOS)` 块同理**——macOS 的 swift test 根本编不到它（D92 实证：并发 Sendable 错误只有 xcodebuild 报）
- **结构门写完必须撞一次**（D160-D163）：用一次**真实的破坏**去撞你刚写的门，看它是否当场点名。本仓实测里初版判据常比意图松——四种形态：只 grep 旧符号名（挡不住下一个同类）、断言符号存在而非用在决策点、固定字数窗口、同义词串味（一个实体的说法替另一个背书）。
  - **最危险的方向**：「不存在」断言 + 有限作用域 = 看不见的地方等于不存在（假绿，无征兆）；「存在」断言作用域过小只会误红（烦，但看得见）
  - 撞门时**用它声称的范围内**的破坏。范围外抓不到不是漏洞，是窄——窄而诚实（文档写明）可以接受
  - 扫全仓收集违规的 lint 门，最好带一条**自测**（喂一个已知违规，断言抓得到），防止过滤逻辑写坏后整体空转
  - **撞门之后先确认破坏真的生效了**（D172）：一次「注入了但门没红」有**三**种解释——门是假绿、**破坏根本没走到那条路**（实测把 `break` 塞进不可达的 catch，门自然不红）、或**我没在看它红的地方**（D209 实测：swift-testing 的失败在 stdout，我抓 stderr，一次判了 12 道门"全是假的"）。先验破坏、再验观察通道、最后才判门
  - **遍历型门必须自证「扫到过东西」**（D208/D209）：目录遍历 + 「不存在」断言 = 遍历根一错就无声全绿。计数扫过的文件并断言下界，下界**贴住实际值**（当前 137 → 断言 ≥80）——`> 0` 只挡得住路径全错，挡不住少一层目录。同类还有 `guard let walker = … else { return }`：那是连断言都不跑，比空转更彻底，改成 `Issue.record` 再 return。物证：空转 0.012s，真扫 1.759s
- **改行为之前先看谁在替它说话**（D206）：`docs/DOC-SYNC.md` 按 glob 列出「改了这个文件，
  去复查哪条承诺」。本 session 逐份核实五份决策文档，**四份都有过期条目**——
  四份都不是没人维护，是**维护的时机不对**（全在回头审计时维护，该在改动时维护）。
  最刺眼的一条是本 session 自己的 D196 把 `requirements` W3.2 改过期了，
  而当时没人想到去读那份文档。**「我读过的文档」与「这次改动涉及的文档」是两个集合。**
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
| `docs/DEVICE-ACCEPTANCE.md` | **真机验收清单** — 自动化照不到的那部分（相机/OCR/跨午夜/渲染/云端）|
| `docs/DOC-SYNC.md` | **改动 → 该复查哪条承诺**（glob → 决策文档条款；`DocSyncMapTests` 守着它不过期）|
| `preview/` | 预览/设计/文档（`ts-publish.sh` 发布，状态页 :10029） |

## 验证

```bash
for p in ClosetCore ClosetModel ClosetUI ClosetIntake; do swift test --package-path Packages/$p; done
```
