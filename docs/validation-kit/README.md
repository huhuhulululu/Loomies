# R1 验证启动包（validation-kit/）

> 配套 `docs/DEMAND-VALIDATION.md`。这里是**你亲自启动方法①②③所需的开箱即用成品**。
> 方法④（竞品社区信号挖掘）由 AI 执行，结果写入 `docs/research/18-method4-signal.md` + DEMAND-VALIDATION 更新。
>
> **分工**：AI 能跑④（桌面研究）；①②③需真人招募/部署/花钱，AI 只备料。

## 文件清单

| 文件 | 用途 | 方法 |
|------|------|------|
| `wizard-of-oz-playbook.md` | 管家测试操作手册（每日流程 + 追踪表结构 + 判读） | ① 核心 |
| `landing-deploy-guide.md` | 落地页公网上线 + A/B + 广告 + 后端接线步骤 | ② |
| `screener.md` | 招募筛选表（分开 ICP vs 干扰项，可直接搬进 Google Form） | ①③ |
| `survey.md` | 在线问卷成品（含 Sean Ellis PMF，可直接搬进 Tally/Typeform） | 问卷 |
| `interview-guide.md` | Mom Test 1:1 访谈脚本（非诱导，可直接照读） | ③ |
| `community-posts.md` | ToS-safe 社区触达草稿（Reddit/Elpha/newsletter） | 招募 |

## 建议启动顺序（2-3 周并行）

1. **今天**：方法④（AI 已在跑）+ 落地页接后端上线（`landing-deploy-guide.md`）+ 用 `community-posts.md` 发招募（先确认各社区 mod 规则）
2. **第 1 周**：`screener.md` 筛出 8-12 名 ICP → 启动 `wizard-of-oz-playbook.md`；`survey.md` 上线收集；广告投放
3. **第 2 周**：管家测试进行中 + `interview-guide.md` 访谈 12-15 人
4. **第 2-3 周末**：三信号汇总，按 DEMAND-VALIDATION §2 判 GO / PIVOT / KILL / MIXED

## 最重要的一件事

所有方法都在回答同一个问题（R1 决定性发现）：**他们要算法替他们决定（推荐器），还是帮他们自己规划的工具（规划器）？**
- 管家测试的 override-rate（改穿自己选的频率）、落地页 V1/V2 A/B 提升比、访谈里"我想自己掌控 vs 想它直接告诉我"——三个信号都指向这一个判断。
- 别只测「有没有需求」（已知有），要测「哪种产品形态」。
