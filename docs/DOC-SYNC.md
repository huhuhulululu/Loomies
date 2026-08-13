# 改动 → 该复查哪条承诺

> D206。**这份表的用途只有一个：改代码时告诉你哪份决策文档在替这段代码说话。**

## 为什么需要它

本 session 逐份核实了五份决策文档，四份都有过期条目：

| 文档 | 过期的 | 谁发现的 |
|---|---|---|
| `FEATURE-GAP.md` | 三条（批量入库/跨柜检索/通知说「未做」而早已交付） | D195 |
| `MARKET.md` §8 | 判定协议冻结了，但没人验过那五条算不算得出来 | D201 |
| `DESIGN.md` §236/§393 | 「体型可辨差异 ≥5%」实测最大 3.6% | D202 |
| `MVP-PLAN.md` | M2/M3 **一个标记都没有**，而 M2 两条早就过了 | D203 |
| `requirements` W1.1/W3.2 | 「日高」实为「日间时段」；「只依赖围度+平铺宽」已被 D196 改掉 | D204/D205 |

**四份都不是没人维护——是维护的时机不对。** 全都在「回头审计时」维护，
而该在**改动时**维护。W3.2 那条尤其说明问题：它是被本 session 自己的 D196
改过期的，而当时没人想到去读那份文档。

一句话：**「我读过的文档」与「这次改动涉及的文档」是两个集合，后者才是该查的那个。**

## 怎么用

改了左边的文件，就去右边那几条看一眼——**看一眼，不是重写**。
真的不一致再改，并在 ADR 里记一句。

```docsync
# 改动文件 glob                                              | 该复查的承诺
Packages/ClosetCore/Sources/ClosetCore/PublicAPI/OpenMeteo*  | requirements W1.1-W1.5（日间时段温度、来源标签、降水 ≥50%）
Packages/ClosetCore/Sources/ClosetCore/WeatherProviding.swift | requirements W1.5；DESIGN §204 正确性硬门①（只按日间时段）
Packages/ClosetCore/Sources/ClosetCore/Recommendation/**     | DESIGN §204 四条正确性硬门；MVP-PLAN M2 退出门
Packages/ClosetModel/Sources/ClosetModel/FitMarkService.swift | requirements W3.2（尺码标签不得当合身证据）；MVP-PLAN M2「ease 引擎单测」
Packages/ClosetCore/Sources/ClosetCore/FitEngine.swift       | requirements W3.2；MVP-PLAN M2
Packages/ClosetCore/Sources/ClosetCore/BodyAvatar/**         | DESIGN §236/§393 纸娃娃验收（≥5% 可辨差异、肩线 ≤5%）
Packages/ClosetCore/Sources/ClosetCore/TelemetryEvents.swift | MARKET §8.1 判定门槛 + §8.4b 数据通路对账
Packages/ClosetCore/Sources/ClosetCore/ComplianceCopy.swift  | MVP-PLAN M3「隐私一致性审计门」；DESIGN §286 隐私叙事
Packages/ClosetModel/Sources/ClosetModel/LoomiesSchema.swift | DESIGN §503 schema 演进规则；MVP-PLAN M0 单向门
Packages/ClosetUI/Sources/ClosetUI/PhotoCaptureViews.swift   | FEATURE-GAP 入库行；MVP-PLAN M1 退出门
Packages/ClosetIntake/Sources/ClosetIntake/**                | FEATURE-GAP 入库行；MVP-PLAN M1；requirements W2（条码）
Packages/ClosetCore/Sources/ClosetCore/PublicAPI/PublicSizeReference.swift | requirements W3.1（not brand-true）
```

## 这张表自己也会过期

所以 `DocSyncMapTests` 守着它：

- 右边点名的**文档都得存在**；
- 左边的 **glob 都得匹配到真文件**（文件改名/删除后这一行就是死的）；
- **每一份决策文档都得在表里出现**——新加一份而不进表，当场红。

**它守不住的**：某一行的「该复查的承诺」写错了或写漏了——那是自然语言，
没法用 lint 判真伪（与 D195/D203 同一条判断：硬造只会得到一道假绿）。
所以这张表**不替代读**，只负责把「该读哪份」这件事从记忆里搬到磁盘上。
