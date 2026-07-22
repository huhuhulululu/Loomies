#!/usr/bin/env python3
"""R1 验证决策计算器 — 按 DEMAND-VALIDATION §2 决策规则，从收集到的数字自动出裁决。

用法：
    python3 decide.py                       # 跑内置示例场景（含方法④预测场景）
    编辑 my_metrics 或 import decide; decide.decide({...})

指标口径（收集后填入）：
- email_conv:        合格访客邮箱转化率（0-1）
- costed_commitment: 付费承诺率（可退定金/预购，0-1）——揭示性偏好，最重
- v2_over_v1_lift:   V2(copilot) / V1(autopilot) 转化提升比。>1=copilot 赢（印证 D19 pivot）
- sean_ellis:        「非常失望」占比（0-1），对现有 workaround 测
- interviews_pain:   15 场访谈中显示「反复、有成本、有失败 workaround」痛点的场数
- interviews_dominant: 'costly_pain' | 'generic_indecision' | 'nice_to_have'

注意（post-pivot 口径）：D19 已把核心机制 pivot 到 copilot。落地页 A/B 现在测 autopilot(V1) vs copilot(V2)。
方法④强先验：V2 应赢 V1（v2_over_v1_lift > 1）。若 V1(autopilot) 反而大赢，则挑战 D19，需回看。
"""


def decide(m):
    """返回 (verdict, reasons) —— verdict ∈ {GO, PIVOT, KILL, MIXED}。"""
    e = m["email_conv"]; c = m["costed_commitment"]
    lift = m["v2_over_v1_lift"]; se = m["sean_ellis"]
    ip = m["interviews_pain"]; dom = m["interviews_dominant"]
    r = []

    # GO：copilot 方向强确认（注意 lift>1 = copilot 赢，与 D19 一致）
    go = (e >= 0.10 and c >= 0.025 and lift >= 1.5 and se >= 0.40
          and ip >= 8 and dom == "costly_pain")
    if go:
        r.append("邮箱≥10% + 付费承诺≥2.5% + V2/V1≥1.5× + SeanEllis≥40% + 访谈≥8/15 有成本痛点")
        return "GO", r

    # KILL：需求本身缺拉力
    kill = (e < 0.05 and c < 0.01 and se < 0.25 and dom == "nice_to_have")
    if kill:
        r.append("邮箱<5% + 付费承诺<1% + SeanEllis<25% + 访谈多为锦上添花")
        return "KILL", r

    # PIVOT：真需求但需调整（含机制/楔子层面）
    if e >= 0.10 and (lift < 1.2 or 0.25 <= se < 0.40 or dom == "generic_indecision"):
        if lift < 1.2:
            r.append("V2/V1 提升比 <1.2×：copilot 相对 autopilot 优势不明显，两种框架都试或换楔子")
        if 0.25 <= se < 0.40:
            r.append("SeanEllis 25-40%：低于 40% PMF 线，需求真但非强 must-have")
        if dom == "generic_indecision":
            r.append("访谈显示痛点是泛泛决策困难而非场合特异：降级场合楔子，测『记住我拥有什么』JTBD")
        return "PIVOT", r

    r.append("落在判据带之间：延长广告到 n≥800 合格访客再定；付费承诺率与 V2/V1 提升比为 tie-breaker")
    return "MIXED", r


SCENARIOS = {
    "方法④预测（copilot 明显赢）": dict(
        email_conv=0.12, costed_commitment=0.03, v2_over_v1_lift=1.8,
        sean_ellis=0.45, interviews_pain=9, interviews_dominant="costly_pain"),
    "copilot/autopilot 难分（PIVOT 带）": dict(
        email_conv=0.11, costed_commitment=0.02, v2_over_v1_lift=1.1,
        sean_ellis=0.38, interviews_pain=6, interviews_dominant="generic_indecision"),
    "需求薄（KILL）": dict(
        email_conv=0.03, costed_commitment=0.005, v2_over_v1_lift=1.0,
        sean_ellis=0.20, interviews_pain=3, interviews_dominant="nice_to_have"),
    "中间地带（MIXED）": dict(
        email_conv=0.08, costed_commitment=0.015, v2_over_v1_lift=1.3,
        sean_ellis=0.42, interviews_pain=7, interviews_dominant="costly_pain"),
}

if __name__ == "__main__":
    for name, m in SCENARIOS.items():
        verdict, reasons = decide(m)
        print(f"[{verdict}] {name}")
        for x in reasons:
            print(f"    - {x}")
