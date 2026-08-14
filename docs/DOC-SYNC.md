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
# 改动文件 glob | 该复查的承诺（锚点用「」括起，必须能在该文档里 grep 到）
Packages/ClosetCore/Sources/ClosetCore/PublicAPI/OpenMeteo* | requirements「有网且城市可 geocode」；DESIGN「四条正确性验收」
Packages/ClosetCore/Sources/ClosetCore/WeatherProviding.swift | requirements「降水概率 ≥50%」；DESIGN「四条正确性验收」
Packages/ClosetCore/Sources/ClosetCore/PublicAPI/OpenProductFacts* | requirements「入库条码公开商品」
Packages/ClosetCore/Sources/ClosetCore/Recommendation/** | DESIGN「四条正确性验收」；MVP-PLAN「F4 四条正确性自动化用例全绿」
Packages/ClosetModel/Sources/ClosetModel/FitMarkService.swift | requirements「尺码标签不得当合身证据」；MVP-PLAN「ease 引擎单测」
Packages/ClosetCore/Sources/ClosetCore/FitEngine.swift | requirements「尺码标签不得当合身证据」；MVP-PLAN「ease 引擎单测」
Packages/ClosetCore/Sources/ClosetCore/BodyAvatar/** | DESIGN「两档体型下同一衣物呈现可辨差异」
Packages/ClosetCore/Sources/ClosetCore/TodayWidgetSnapshot.swift | DESIGN「Widget 主屏 clear/tinted 去饱和模式」
Packages/ClosetCore/Sources/ClosetCore/TelemetryEvents.swift | MARKET「遥测裁决预注册协议」
Packages/ClosetCore/Sources/ClosetCore/ComplianceCopy.swift | MVP-PLAN「隐私一致性审计门」；MARKET「遥测裁决预注册协议」
Packages/ClosetModel/Sources/ClosetModel/LoomiesSchema.swift | DESIGN「VersionedSchema」；MVP-PLAN「schema 过加法式单向门守卫测试」
Packages/ClosetUI/Sources/ClosetUI/PhotoCaptureViews.swift | FEATURE-GAP「相机真机验证」；MVP-PLAN「抠图在 M0 基准语料上」
Packages/ClosetIntake/Sources/ClosetIntake/** | FEATURE-GAP「相机真机验证」；requirements「入库条码公开商品」
Packages/ClosetCore/Sources/ClosetCore/PublicAPI/PublicSizeReference.swift | requirements「not brand-true」
```

## 这张表自己也会过期

所以 `DocSyncMapTests` 守着它：

- 右边点名的**文档都得存在**；
- 左边的 **glob 都得匹配到真文件**（文件改名/删除后这一行就是死的）；
- **每一份决策文档都得在表里出现**——新加一份而不进表，当场红。

- **每个「」锚点都能在它指的那份文档里 grep 到**（D207 新增）。

### 为什么锚点是**引文**而不是行号

第一版用的是 `DESIGN §503` 这种行号引用——**而行号每次编辑都会平移**。
D202 往 DESIGN 里插了一段 ⚠️，插入点之后的引用当场全部指错：
`§503` 从「schema 演进规则」变成了「数据导出 spec」，`§286` 变成了一张 ASCII 图。

这个坑不是本表独有：**整个仓的 ADR 一直在用行号引 DESIGN**，
而那些引用在每次编辑后静默烂掉，没有任何东西会红。

引文锚点相反——**文改了它就找不到，门当场红**；文没改它就一直对。

**它守不住的**：锚点找得到，不代表那条承诺**与这个 glob 真的相关**——
那是自然语言判断，没法 lint（与 D195/D203 同一条：硬造只会得到一道假绿）。
所以这张表**不替代读**，只负责把「该读哪份」这件事从记忆里搬到磁盘上。
