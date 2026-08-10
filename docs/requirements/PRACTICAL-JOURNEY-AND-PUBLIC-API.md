# 需求补全：客户旅程 × 公开 API × 实用性

> 2026-08-07。依据 DESIGN §F4 copilot、FEATURE-GAP、D77 公开 API、用户指令「修复/测试/拓展/实用性 + 调研与需求补充」。
> 验收标准均为 **pass/fail**；与代码冲突以代码为准并回写本文。

## 1. 问题陈述

内测用户从 **首次打开 → 日常用全功能** 时，不能只靠「槽位叠衣逻辑绿」：

1. **天气**曾仅用离线气候表，与真日温脱节 → 外套建议失真。  
2. **入库**真衣信息（品牌/尺码）依赖手填或 mock OCR；有吊牌条码时未用公开商品库。  
3. **尺码**无跨体系参考提示时用户不知 M/8 大致对应。  
4. **多角人体资产**背景/发型不一致（资产债，非本需求一次清零）。  
5. **功能修复**需有测；**拓展**须对客户路径有用，禁止为 API 而 API。

## 2. 调研摘要（公开数据，免 key 优先）

| 源 | 能力 | 限制 | 产品决策 |
|----|------|------|----------|
| [Open-Meteo](https://open-meteo.com) | 地理编码 + 预报（温、降水概率） | 非 Apple 官方；需归因 | **主天气路径** |
| 离线城市气候表 | 无网 | 粗 | **fallback** |
| WeatherKit | 高质量本地天气 | 账号/能力/SDK | v1.x 可选第二实现 |
| Open Product/Beauty/Food Facts | 条码 → 名称/品牌 | 服装覆盖参差；二手常无条码 | **入库增强，可选** |
| 商用 UPC API | 覆盖更好 | 付费 key | **不做进仓** |
| 公开尺码桥接表 | US/EU/UK 参考 | vanity sizing 不可信 | **仅 hint，不合身裁决** |
| 品牌官方 size chart API | — | 无统一公开 API | **不做**；合身靠测量 |

依据：`docs/research/07-sizing-entry.md`（尺码不可跨品牌换算）、D77。

## 3. 用户故事与验收

### W1 — Today 天气驱动温区（修复 + 拓展）

**故事：** 作为设了城市的用户，打开 Today 时看到 **合理 °F**，并知道数据来源（在线预报 vs 离线估计）。

| ID | 验收 | 测/证据 |
|----|------|---------|
| W1.1 | 有网且城市可 geocode → 使用 Open-Meteo 日高（°F） | `OpenMeteo*` fixture + 可选 live |
| W1.2 | 无网/失败 → 气候表，不崩溃，仍可 refresh | `CompositeWeatherProvider` 测 |
| W1.3 | UI 展示来源短标签（如 “Open-Meteo” / “Offline estimate”） | ViewModel 字段 + UI |
| W1.4 | 改 Me 城市后重新拉天气再 refresh | 既有 onChange 测扩展 |
| W1.5 | 降水概率 ≥50% 时 status/提示建议带外套（不强制） | 新字段 + 测 |

### W2 — 入库条码公开商品（拓展）

**故事：** 有吊牌条码时，一点即可预填品牌/名称，仍可全手改。

| ID | 验收 |
|----|------|
| W2.1 | 数字条码 → Open*Facts 链式查询 |
| W2.2 | 只填空字段，不覆盖用户已填 |
| W2.3 | 查无/失败有人话错误，可继续手填 |
| W2.4 | 单测 FakeLookup；无 key |

### W3 — 尺码参考提示（实用性）

| ID | 验收 |
|----|------|
| W3.1 | 输入 M/数字 US 等显示 “Ref. chart… not brand-true” |
| W3.2 | 合身标记仍只依赖身体围度 + 平铺宽 |

### W4 — 旅程可感缺口（持续 loop）

| 域 | 最低 bar |
|----|----------|
| Onboarding | 名+城；身体可跳过 |
| Today | seed / 锚定 / full-auto / Save·Plan·Wore 有失败反馈 |
| Closet | 槽位 chip displayTitle；搜索 resolved |
| Me | 城市驱动天气；体型同源 |
| Favorites/Calendar | 叠衣预览；Plan；缺件提示 |
| 数据 | 导出/删除 |

### W5 — 明确不做（范围）

- VTON / 自拍试穿  
- 付费条码 API、强依赖 WeatherKit  
- 本迭代批量重生 photoreal 全矩阵（单独立项）  
- 无用户令自动 commit/TF  

## 4. 测试策略

| 层 | 内容 |
|----|------|
| 单测 | JSON fixture、Composite fallback、size hint、barcode enrich |
| 旅程 | FeatureJourney 含 weather apply（可用 Fixed 或 Fixture） |
| 真机 | 有网城市改 New York vs Phoenix 温差；条码可选真查 |

## 5. 优先级（实现序）

1. **P0** W1.1–W1.3 天气诚实 + 来源标签（已部分完成 Open-Meteo）  
2. **P0** W2 条码（客户端 + 入库 UI 已接，补旅程测）  
3. **P1** W1.5 降雨外套提示  
4. **P1** W3 尺码 hint（UI 已接）  
5. **P2** 资产多角一致性专项  

## 6. 成功定义

客户能在美国区 TestFlight 上：**设城市 → 看到可信温度与来源 → 加衣（手填或条码）→ 得温区合理搭配 → 收藏/计划/打卡**；失败路径有文案、不静默。
