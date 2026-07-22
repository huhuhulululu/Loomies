# R1 真人验证 · 一页 runbook（今天就开跑）

> 分工再明确一次：**方法④ AI 已跑完**（`docs/research/18` + DEMAND-VALIDATION §8，7:1 倒向 copilot）。
> 下面①②③是**你**执行的真人验证。所有材料已备（`validation-kit/`），照做即可。

## 今天（Day 0，~2 小时铺设）

- [ ] **落地页上线**：`landing/index.html`(V1 autopilot) + `landing/v2.html`(V2 copilot)
  1. 注册 Formspree（免费），建一个 form，拿到 endpoint URL
  2. 把两个 html 里的 `FORM_ENDPOINT` 替换成该 URL
  3. 换 `.photo-slot` 为真实衣物平铺照、换品牌名「Cleo」、填 footer 邮箱
  4. 拖进 Vercel/Netlify 部署；V1→`/`、V2→`/b`（或用广告分流）
- [ ] **问卷上线**：把 `survey.md` 的题搬进 Tally（免费），拿链接
- [ ] **社区招募发出**：用 `community-posts.md`——先私信 mod 求批准（r/FFA）
- [ ] **访谈招募开**：`screener.md` 搬进 Google Form，投到社区/Prolific

## 第 1-2 周（并行跑）

- [ ] **方法① Wizard-of-Oz**（核心）：`wizard-of-oz-playbook.md`
  - 招 8-12 名 ICP（screener 筛掉胶囊派）→ 每晚手动发次日穿搭 → 填 `wizard-of-oz-tracker.csv`
  - 测：穿着率 / **覆盖率(改穿自己选的频率)** / 7 天后「请继续发」
- [ ] **方法② 广告投放**：Meta 定向 25-45 美国女性，~$400-650，目标 ≥500 合格访客(≥250/臂)
- [ ] **方法③ 访谈**：`interview-guide.md`，12-15 场，Mom Test 纪律（绝不提场合/App）

## 第 2-3 周末（出裁决）

- [ ] 汇总数字 → **跑决策计算器**：
  ```bash
  # 编辑 decide.py 里 my_metrics，或：
  python3 -c "import decide; print(decide.decide(dict(
      email_conv=0.__, costed_commitment=0.__, v2_over_v1_lift=_._,
      sean_ellis=0.__, interviews_pain=__, interviews_dominant='costly_pain')))"
  ```
- [ ] 计算器输出 GO / PIVOT / KILL / MIXED + 理由 → 据此定 v1.0 方向

## 三个数字最关键（其余是佐证）

1. **V2/V1 提升比**（copilot vs autopilot 的市场投票）——方法④预测 V2 赢，实测确认即锁 copilot
2. **付费承诺率**（真金白银 > 邮箱陈述兴趣）
3. **Wizard-of-Oz 覆盖率**（她多常改穿自己选的 = 要工具还是要算法的行为证据）

## 如果结果是 PIVOT/KILL

- ClosetCore/ClosetModel（109 tests）在 copilot 甚至规划器形态**全复用**，不白费
- PIVOT 到「记住我拥有什么」楔子：衣橱编目/防重复购买是现成能力，换 onboarding 叙事即可
