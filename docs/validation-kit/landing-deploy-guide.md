# 方法② 落地页部署 + A/B + 广告指南

> 落地页成品已建：`landing/index.html`（V1 推荐器）+ `landing/v2.html`（V2 规划器）。
> 这里是把它们从 tailnet 预览变成**公网可测**的步骤。

## 1. 接表单后端（把 FORM_ENDPOINT 换掉）

页面里两处 `action="FORM_ENDPOINT"` 需接真实后端。最省事三选一：
- **Tally**（推荐，免费）：建一个含 email + dress_code + priority 的 form，用其 embed 或把 `<form>` 换成 Tally 链接跳转
- **Formspree**：注册后拿一个 endpoint URL，替换 `FORM_ENDPOINT`，`method="post"` 不变
- **ConvertKit / Mailchimp**：若要直接进邮件列表

微调研（提交后的 priority 单选）目前是客户端模拟——接后端时把选中的 `priority` 值一并 POST（页面 JS 已有选中态，加一行把它塞进隐藏字段或第二次提交）。

## 2. 换真实素材（上线前必做）

- `.photo-slot`：换成一张真实 flat-lay 衣物/衣橱照（自拍或授权图，别用 stock 微笑女性 cliché）
- wordmark「Cleo」：换成你的品牌名（`nav .wordmark` 处 + `<title>`）
- footer 的 Privacy 链接、contact 邮箱换成真实的

## 3. 公网部署

- **Vercel / Netlify**（免费，拖拽 `landing/` 目录即可）或你的域名
- V1 部署到 `你的域名/`，V2 部署到 `你的域名/b` 或用 A/B 工具分流
- 加隐私政策页（复用 DESIGN §5 法务要点）

## 4. A/B 设置（R1 判别器）

- **50/50 分流** V1（推荐器 hero）vs V2（规划器 hero）——同一批广告流量
- 两页只差 hero/how-it-works/首卡，其余一致 → 隔离「推荐器 vs 规划器」这一个自变量
- 工具：Vercel A/B、Google Optimize 替代品、或广告层面用两个 landing URL 各投一半预算
- **核心读数**：V1 转化 ÷ V2 转化的**提升比**——这是「他们要算法决定还是自己规划」的市场投票

## 5. 广告导流

- **Meta（IG/FB）**：定向 25-45 女性、美国、职业/管理岗兴趣；~$400-650 预算
- 目标 ≥500 合格访客（≥250/臂）——足够检测 1.5× 提升
- 素材用落地页 hero 的同款文案，别夸大

## 6. 判读（对照 DEMAND-VALIDATION §2）

| 指标 | GO 阈值 |
|------|---------|
| 邮箱转化 | ≥10% 合格访客 |
| 付费承诺（可退定金/$15 预购） | ≥2.5% |
| **V1/V2 提升比** | **≥1.5×**（<1.2× = PIVOT 到规划器的最强信号） |

> 付费承诺（真金白银）> 邮箱（陈述兴趣）。若只想先测便宜信号，先跑邮箱转化 + A/B 提升比，付费承诺作第二关。
