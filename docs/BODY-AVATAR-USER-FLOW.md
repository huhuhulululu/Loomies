# Body Avatar 使用流程（产品真相）

> 2026-08-05 · 对齐 D63–D70：catalog 真人 + 丁字裤档 basewear + morph 适配。  
> **不**做：客户现场 gen 身体、自拍 VTON、默认「按 prompt 生成我的裸体」。

---

## 1. 一句话定位

客户只提供**结构化身体档案**；App 用 **catalog 真人底座 × 体型 morph × 叠衣** 表达穿搭比例。  
Prompt / 生图只发生在**你们资产管线**，不进客户操作流。

---

## 2. 客户永远不会看到的东西

| 禁止出现在客户 UI | 原因 |
|------------------|------|
| 「生成我的身体」/ 自由 prompt 生图 | 审核、成本、换脸、隐私、反 VTON |
| 强制全裸零遮盖文案作产品 bar | 产品 bar = catalog 最小 basewear（D64） |
| 未录全围度就强开 FFIT 合身簇 | R13 激活门 |
| 用别人表型的多角图硬凑旋转 | D69 防换人 |

---

## 3. 档案字段（客户可改）

| 字段 | 来源 | 必填？ | 作用 |
|------|------|--------|------|
| Sex | Me / Onboarding | 建议先填 | 选 F/M catalog 底座与叠衣锚点 |
| Phenotype | Me 肤色圆点 | 默认 East Asian | 选 catalog 模特外观（8 档） |
| Quick shape | 5 图快选 | 二选一路径 | 无测量时的 morph preset |
| Bust/Waist/Hip/High-hip | 步进录入 | 合身/FFIT 需满 4 | 连续 morph + 合身文案 |
| Fine-tune | 滑杆 0.90–1.10 | 可选 | 叠在测量/预设上的微调 |
| Unit | in/cm | 可选 | 仅显示 |

**优先级（morph 合成，代码已实现）**  
`测量（可推断上臀） > 快选 PopularShape preset > 中性`，再 × fine-tune。

---

## 4. 主路径状态机

```
                    ┌─────────────┐
                    │  无档案     │
                    └──────┬──────┘
           onboarding 或 Me 打开
                           │
           ┌───────────────▼────────────────┐
           │  S0 空参考                       │
           │  预览：默认女 + eastAsian + 中性  │
           │  可转 360，无合身文案             │
           └───┬─────────────────┬───────────┘
               │                 │
     选 Sex/表型            快选 5 型
               │                 │
               ▼                 ▼
           S1 外观就绪        S2 体型就绪 (visualOnly)
           换 catalog 模特     morph 用 preset
               │                 │
               └────────┬────────┘
                        │
              录入 ≥3 围 + 上臀(可估)
                        │
                        ▼
                  S3 测量就绪
                  · 3 围齐 → 可估上臀 → provisional 预览
                  · 4 围齐 → measured / FFIT 激活
                        │
                        ▼
                  S4 精调（任意时刻）
                  滑杆即时预览 + 落库
```

### 置信度文案（`BodyFitConfidence`）

| 状态 | 用户看到的意思 | 预览行为 |
|------|----------------|----------|
| none | 还没选体型也没量 | 中性 morph |
| visualOnly | 只有快选 | preset morph；提示可加尺寸 |
| provisional | 三围齐、上臀估 | 可 morph；合身提示弱 |
| measured | 四围齐 | 全 morph + FFIT 簇 |
| mixed | 测量 + 手选体型并存 | 测量优先 morph；快选作偏好标签 |

---

## 5. 端到端用户旅程

### 5.1 首次 Onboarding（轻量，可跳过身体）

**目标**：30 秒内能进 App；身体不挡主路径。

| 步 | 界面 | 客户动作 | 系统 |
|----|------|----------|------|
| 1 | 名字 + 城市 | 必填 | Person + 主衣柜 |
| 2 | Body（可跳过） | 可选：点 1 个大众体型 | `popularShapeOverride` · confidence=visualOnly |
| 3 | （可选）三围粗录 | 可跳过 | 未齐不激活 FFIT |
| 4 | Done | — | 进 Today |

**原则**：跳过身体 → 今日推荐仍可用（无体型加权）；纸娃娃用默认女 eastAsian 中性。

### 5.2 Me → Body reference（主设置流）

**信息架构（推荐顺序，对应 `BodyProfileView`）**

```
① 实时预览（BodyAvatarView）     ← 永远在最顶，所有改动即时反映
② Sex + Phenotype                 ← 「模特外观」
③ 状态条：Fit confidence / 进度   ← 诚实告知完整度
④ Quick pick 5 型                 ← 快路径
⑤ Fine-tune 滑杆                  ← 微调
⑥ 单位 + 四围录入                 ← 准路径
⑦ Save（测量区显式保存；快选/性/表型/精调已即时存）
```

#### 客户心智文案（建议替换旧「Nude base」）

| 区块 | 标题 | Footer 一句 |
|------|------|-------------|
| 预览 | Your body reference | Catalog model + your proportions. Drag to turn. Clothes layer on top. |
| 性/表型 | Model look | Choose presentation sex and skin tone family. Not a medical category. |
| 快选 | Body shape (quick) | Closest silhouette. Refine with measures anytime. |
| 精调 | Fine-tune | Optional. Live preview. |
| 测量 | Measurements | Full set unlocks fit tips. Stays on device. |

#### 操作细则

1. **改 Sex** → 即时换 F/M catalog；表型保留；morph 不变。  
2. **改 Phenotype** → 优先 `photoreal_{sex}_{phenotype}_front`；转角：有表型 yaw 用真帧，否则 **soft-hold 本表型正面**（不借东亚角）。  
3. **快选 shape** → 即时落库 + morph preset；文案鼓励补测量。  
4. **步进围度** → 预览 live；点 Save 落库；三围齐可「Estimate high hip」。  
5. **精调** → onChange 预览 + `saveFineTune`；Reset 回 1.0。  
6. **360** → 仅展示；不要求客户理解 yaw 资源。

### 5.3 Today / Copilot / Favorites（消费预览）

| 场景 | 身体从哪来 | 叠衣 |
|------|------------|------|
| Today 英雄 | 当前 Person 的 sex/phenotype/morph | 当日建议 outfit 槽位 |
| Copilot 建议卡 | 同上（compact） | 每套 look 的 layers |
| Favorites / Calendar | 同上 | 已存 outfit |
| 分享 lookbook | 同上 + 场合底 | 导出帧 |

客户**不**在这些页改身体；一律链到 **Me → Body**。

### 5.4 入库叠衣（间接）

衣物抠图 → 标准画布 → 叠到当前 morph 的锚点。  
客户流程仍是「加衣」；身体适配对客户透明。

---

## 6. 系统合成流水线（给实现 / 验收）

```
PersonBodyProfile
  ├─ presentationSexRaw
  ├─ presentationPhenotypeRaw
  ├─ popularShapeOverrideRaw?
  ├─ bust/waist/hip/highHip?
  └─ fineChest/Waist/Hip/Height
           │
           ▼
BodyMorphParams.resolve(measures?, shape?, fineTune)
           │
           ▼
BodyAvatarView
  ├─ resolvePhotorealFrame(sex, phenotype, yaw)   // D69 防换人
  ├─ BodyMorphImageView(asset, morph)             // 扫线变形
  ├─ 缺角 → soft-hold 本表型正面
  └─ layers[] 叠衣 + 场合底 + 景深
```

**无客户 gen 步骤。**

---

## 7. 双轨说明（对客户怎么讲）

| 轨道 | 适合谁 | 得到什么 | 得不到什么 |
|------|--------|----------|------------|
| 快选 | 嫌量尺 | 立刻 360 比例感 | 精准合身文案 |
| 测量 | 在意合身 | morph 更贴 + FFIT/合身标记 | — |
| 两者都有 | 多数认真用户 | 测量驱动 morph；快选作标签 | — |

话术：**「先点一个像你的体型，想更准再填尺寸。」**  
不要：**「上传自拍生成你的身体。」**

---

## 8. 隐私与信任（流程内触点）

1. 首次进入 Body：一行说明「Measurements stay on this device.」  
2. 四围录满激活合身：一次性说明「Fit tips use women's proportion models.」（R13）  
3. 设置里可清身体数据（走 Data lifecycle，若已有）。  
4. 出网 payload **永不含** 围度/体型分类（DESIGN 不变量）。

---

## 9. 异常与空态

| 情况 | UI |
|------|-----|
| 无 catalog 认证（不应发生） | 橙条 + 缺口文案；interim 不冒充实拍 |
| 表型无多角 | soft-hold 正面 + 角标可省略（不教育客户缺资源） |
| 仅 Sex 未选 | 默认 female |
| 极端 morph | clamp；不崩锚点（pastie/thong 保护带） |
| 换 Person | 换档案；预览跟新 Person |

---

## 10. 验收清单（流程级）

- [ ] 跳过 Onboarding 身体仍能进 App  
- [ ] 只快选：预览明显随 pear/apple 变  
- [ ] 只测量：预览随腰臀变；满 4 围出现 FFIT 相关能力  
- [ ] 改表型：正面换模特；转角不跳到另一人种全角  
- [ ] 改性别：F/M 底座切换  
- [ ] 精调：松手后重进 Me 仍在  
- [ ] Today 迷你纸娃娃与 Me 同一 morph 来源  
- [ ] 全程无「生成身体 / prompt」入口  
- [ ] 文案无 flattering/slimming；只谈衣与比例  

---

## 11. 与「prompt 给客户」的边界

| 角色 | 流程 |
|------|------|
| 客户 | 选/填 → 即时 morph 预览 → 用在搭配 |
| 内部资产 | prompt 手册 → gen/QA → 入库 photoreal_* → 发版 |
| 未来可选（非本流） | 授权参考照仅锁脸 — 需单独同意与 ADR |

---

## 12. 推荐实现顺序（流程落地）

1. **文案与 IA**：Me 去掉「Nude base / Fully nude」产品 bar 表述 → catalog model look  
2. **Onboarding**：保留可跳过快选；不塞四围强迫症  
3. **预览永远第一**：任何改动 16ms 级 recompute（已有）  
4. **Today 同源**：只读 PersonBodyProfile → morph（查引用一致）  
5. **资产继续内补**：表型 090/180 等 — 不挡用户流  

---

## 13. 流程图（总览）

```
[Onboarding] --可选快选--> [App]
                              │
                              ▼
                         [Today 搭配]
                         使用当前 morph
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
        [Me → Body]                     [加衣 / 叠衣]
        改 sex/表型/体型/围度/精调              │
              │                               │
              └──────────► 同一 PersonBodyProfile
                              │
                              ▼
                    BodyAvatarView 合成
                    catalog × morph × layers
```

**结束条件（客户侧）**：客户能在 2 分钟内完成「外观 + 一种体型表达」，并在 Today 看到比例说得通的叠衣预览；无需理解生成或资源文件。
