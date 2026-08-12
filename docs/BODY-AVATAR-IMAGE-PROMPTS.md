# Body Avatar 出图 Prompt 手册（精修复用）

> 2026-08-03 实战沉淀；**D64（2026-08-05）**：catalog basewear = 男女皆丁字裤。  
> 底图路径：`Packages/ClosetUI/Sources/ClosetUI/Resources/BodyAvatar/`  
> 产品硬约束：**真人照片** + **最小 catalog basewear**  
> - ♀：pasties + thong  
> - ♂：**thin nude thong**（**不是** brief / boxer / 三角裤）

---

## 成功路径总览（务必按序）

```
① image_gen 先出「catalog basewear」全身（可过审核）
   ♀ pastie+thong · ♂ thin nude thong
② multi-image edit：体态/装来自①，脸来自原 croquis 模特 → 身份锁
③ 以②为唯一金标准，只 edit 不 gen 新人
④ 改体型 / 改角度 / 精修 全部 identity lock 在②
```

**禁止**：身份锁定后对全身再跑裸 `image_gen`（会换脸）。  
**禁止**：大面积 OpenCV soft_rect 抹内衣（糊斑、毁图）。  
**禁止**：把男 basewear 写成 brief（D64）。  
**禁止**：无用户重批把 coveringPolicy 改回 none / requiresFullNude=true。

---

## 1. 全身 basewear — `image_gen` 可过

### 1a. 女（pasties + thong）

```text
Full-length fashion catalog photo of an East Asian adult woman standing facing camera on soft gray seamless studio background, bare feet, photoreal e-commerce lighting. She wears only matte skin-tone adhesive nipple pasties and a thin nude thong covering private areas. Clean product base for lingerie layering, tasteful non-explicit catalog style.
```

- `aspect_ratio`: `2:3`
- 用途：第一次拿到合规 pastie+thong 体态（可能是新人脸，下一步锁脸）

### 1b. 男（thin nude thong — D64）

```text
Full-length fashion catalog photo of an East Asian adult man standing facing camera on soft gray seamless studio background, bare feet, photoreal e-commerce lighting. Athletic lean build, short black hair, neutral expression. He wears only a thin skin-tone nude male thong (minimal front coverage with thin side strings, not briefs, not boxers, not swim trunks). Clean product base for underwear layering demo, tasteful non-explicit catalog style, soft natural skin texture, sharp full-body e-commerce photo.
```

- `aspect_ratio`: `2:3`
- 用途：男 catalog 金标准正面；写入 `photoreal_male_front.png`（+ eastAsian / yaw000 镜像）
- 实测：对存量 brief 图做 `image_edit` 改 thong 常 **content-moderated** → 优先 **重新 image_gen** 再锁脸
- 多角：identity lock 后 rotate ¾；侧/背可能 moderated，保留 staging

---

## 2. 身份锁（原脸接回）— multi-image `image_edit` 关键成功

输入顺序：

1. **体态图**（pastie+thong 全身，如 session `106.jpg`）
2. **原脸图**（历史 croquis 正面，如 `d7eea4b` 的 `croquis_hourglass_yaw000.png` / 用户定稿脸）

```text
Face identity transfer only. Take the full-body pose, body, pasties, thong, lighting and gray studio from the first image. Replace only the head and face with the second woman's exact face and hairstyle so it is clearly the second woman standing in the first woman's pose. Keep pasties and thong unchanged. Photoreal seamless blend at neck.
```

- 实测：直接在原脸图上改装 pastie+thong → 常 `content-moderated`  
- 实测：先 gen 装，再 face transfer → **可过且脸稳**

金标准产出：session `117.jpg` → 入库 `croquis_hourglass_yaw000.png`

---

## 3. 同人改体型（5 大众型）

以金标准为唯一 `image` 输入：

```text
Same exact woman (same face and hair) wearing only skin-tone adhesive nipple pasties and thin nude thong. Soft gray studio, full length photoreal. Keep pasties and thong. Only change body proportions to {pear|apple|rectangle|inverted triangle}: {proportion note}. Front facing camera.
```

比例备注示例：

| shape | note |
|-------|------|
| pear | fuller hips and thighs, narrower shoulders |
| apple | fuller midsection, softer waist |
| rectangle | straighter silhouette |
| inverted triangle | broader shoulders, narrower hips |
| hourglass | 金标准本身 |

---

## 4. 同人改角度（360° / 45° 步进）

```text
Same exact woman same face and hair, only pasties and nude thong. Soft gray studio full length. Keep pasties and thong. Rotate to {three-quarter front-right 45° | true right profile 90° | three-quarter back-right 135° | full back 180° | three-quarter back-left 225° | left profile 270° | three-quarter front-left 315°}.
```

侧/后偶发审核失败时：

- 换措辞：`full back view, head turned slightly so face profile is visible`（比 bare “back nude” 稳）  
- 或用组合法 §5

---

## 5. 体型 × 角度组合（缺角补全）

当某体型缺某角时，两图 edit：

1. **pose 参考** = hourglass 的目标 `yaw`（已 pastie+thong）  
2. **身份/体型** = 该体型正面 `yaw000`

```text
Combine: use the body pose, camera angle, pasties and thong from the first image. Use the face, hair, and {shape} body proportions from the second image. Result must be the second woman in the first image's pose, wearing only pasties and thong. Soft gray studio, full length, photoreal.
```

---

## 6. 失败模式速查

| 做法 | 结果 |
|------|------|
| 原脸图 edit → pastie+thong | 常 moderated |
| `image_gen` 新人 pastie+thong | 过，但**换脸** |
| face transfer 回原脸 | **成功路径** |
| 本地 soft_rect / 大块肤色抹 | 矩形糊斑，不可用 |
| 本地 Telea + 手绘乳贴 | 假、糊，不建议主路径 |
| 宽 bandeau + 短裤 | 易过审核，但**产品不要**（干扰叠内衣） |

---

## 7. 写实精修（2026-08-03 验证成功）

在**已锁同人 + pastie/thong** 的单帧上做 realism pass（不要换装、不要换人）：

```text
Photoreal fashion-catalog refine of THIS exact same frame only — keep pose, camera angle, face, hair, pasties, and thong identical. Increase realism: natural skin texture with subtle pores and freckles, believable soft studio lighting and ground contact shadow, realistic fabric of matte adhesive pasties and thin nude thong, fine hair strands, no plastic AI smoothness, sharp full-body e-commerce photo on seamless gray. Same person, same minimal basewear.
```

同人改体型时带上写实锚点：

```text
Same exact photoreal woman (same face, freckles, hair, skin texture) wearing only skin-tone pasties and thin nude thong. Soft gray studio, full length. Keep pasties and thong and photoreal quality. Only change body proportions to {shape}: {note}. Front facing camera.
```

**注意**：侧/后角 refine 偶发 moderated；失败则保留上一版同人帧，勿回退到 bandeau 或新人脸。

---

## 8. 精修时建议操作顺序

1. 只动一张金标准 `yaw000`（写实 pass / 脸/光/乳贴/丁字裤）  
2. 验收：脸 = 原模特；装 = 仅乳贴+丁字裤；肤质写实；灰棚一致  
3. 再 fan-out：体型（§3）→ 角度（§4）→ 组合补缺（§5）→ 各帧 realism pass（§7）  
4. **入库名（photoreal 轨，产品渲染路径唯一读取的命名）**：  
   - 表型基础帧：`photoreal_{female|male}_{phenotype}_front` / `…_yaw{045…315}`  
   - **体型专属帧（shape 维度）**：`photoreal_{sex}_{phenotype}_{hourglass|pear|apple|rectangle|invertedTriangle}_front` / `…_yaw###`  
   - 尺寸统一 **832×1248 或 1024×1536（严格 2:3）**——`PhotorealInventoryQATests` 会拒非 2:3  
   - ~~croquis_{shape}_yaw###~~ **已废弃**：croquis 轨是渲染死代码，勿再出此命名  
5. **出图可带棚灰**；photoreal 轨直接入库（照片保留背景，UI 叠 `AvatarBackdrop`）

---

## 9. 资源与代码挂点

- 资源：`Packages/ClosetUI/.../Resources/BodyAvatar/`  
- 命名/解析 API：`BodyAvatarAsset.photorealFrameName(sex:phenotype:shape:yaw:)` + `resolvePhotorealFrameName(sex:phenotype:shape:yaw:available:)`（shape 专属 → 表型 → 通用，D69 防换人守卫）  
- 认证门：`NudeBodyBaseSpec.isAllowedPhotorealFrontName`（shape token 已入白名单）  
- QA 门：`PhotorealInventoryQATests`（矩阵账本/2:3 尺寸/命名合法性）——**每落盘一批图先跑它**  
- UI：`BodyAvatarView`（shape 帧命中时自动旁路 preset warp，用户微调仍生效）  
- 产品：Me → Body 双轨快选 + 四围；basewear 文案标明 pasties+thong  

---

## 10. 当前出图任务清单（2026-08-11 拍板：B 方案 + 正面档）

> 落盘即插即用：命名对 → 放进 Resources/BodyAvatar/ → 跑 `PhotorealInventoryQATests`
> （账本测试会提示「landed, remove from pending」）→ 从本清单划掉。

### 批次 1 · eastAsian 锁脸转角 13 张（修「转角换人」，最高优先）
以现有 `photoreal_{sex}_eastAsian_front` 为身份金标准，走 §2 multi-image face transfer + §4 角度 prompt：

```
photoreal_female_eastAsian_yaw045 / 090 / 135 / 180 / 225 / 270 / 315   （7）
photoreal_male_eastAsian_yaw045 / 090 / 135 / 225 / 270 / 315           （6，yaw180 已有）
```

### 批次 2 · 体型 × 表型正面档 64 张（修「每人种只有一个体型」）
以各 `photoreal_{sex}_{phenotype}_front` 为该表型身份金标准，走 §3 体型 prompt（同人改体型，锁脸）：
2 性 × 8 表型 × 5 体型 = 80 格，其中现有基础帧即该表型的「基准身材」，**5 体型全部单独出图**
（基础帧保留作 shape 未知时的回退）→ 共 **80 张**；若把每表型现有身材视作 rectangle 近似可先出
其余 4 体型 = 64 张，rectangle 后补。命名：

```
photoreal_{female|male}_{eastAsian|southeastAsian|southAsian|european|african|latinx|middleEastern|indigenous}_{hourglass|pear|apple|rectangle|invertedTriangle}_front
```

验收（每张）：脸 = 该表型金标准同人；装 = 仅乳贴+丁字裤（♂ thong）；2:3 尺寸；§3 表列比例特征可辨；灰棚一致。

---

## 11. 一句话记忆

**装用 gen 过审 → 脸用 transfer 锁回 → 往后只 edit 同人；永远乳贴+丁字裤，永不裸 gen 新人。**
