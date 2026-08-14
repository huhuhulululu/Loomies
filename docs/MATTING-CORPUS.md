# 抠图基准语料约定（C6）

> 约定，不是实现。仓里**没有**语料图，也**没有**评分器。
> 空目录 + 空 scorer 会让人以为 M1 的「≥90%」已经有分母——那是假的。
> 真机清单仍在 `DEVICE-ACCEPTANCE.md` §7。

## 这张表要解决什么

M0 要冻一套固定图，M1 的「抠图 ≥90%」只对这套图说话。
没有分母，那个百分比永远算不出来。

生产路径是 `VisionMattingService`（`VNGenerateForegroundInstanceMaskRequest`）→ PNG。
评分器必须打**这条路**，不要另写一套「更好抠」的离线模型来凑数。

## 目录（人到齐再建模，现在不要建空壳）

```
fixtures/matting-corpus/
  manifest.json
  images/<id>.jpg          # 原图（衣服平铺或穿着，与入库同一类）
  masks/<id>.png           # 人工前景 mask，与原图同尺寸
```

`manifest.json` 一行一张：

| 字段 | 含义 |
|---|---|
| `id` | 稳定文件名，无空格 |
| `bin` | `solid` / `light` / `print` / `dark`（四档都要有，别全是白 T） |
| `notes` | 可选：蕾丝、透明、与背景同色 |
| `annotator` | 谁画的 mask |
| `date` | ISO 日 |

起步规模：**≥100** 张，四档都有。少了先别跑百分比。

## 评分器接口（有语料再写，现在不要空转）

输入：原图 Data + 人工 mask。
输出（每张）：

- 走了 `MattingService.removeBackground` 还是抛了 `noSubject` / `invalidImage`
- 若成功：预测 mask 与人工 mask 的 IoU（或等价重叠率）
- 一张总表：成功张数 / 总张数；IoU ≥ 0.90 的张数 / 总张数

「≥90%」指**后一个比例**，分母是语料张数，不是「感觉抠得干净」。
模拟器没有这路 Vision 推理——评分器要在真机或支持该 request 的环境跑。

## 不要做的

- 不要用生成图冒充衣服照片（和 D69 锁脸是同一类诚实问题）
- 不要把 demo 种子 9 件算进这 100
- 不要在没有图的时候先提交一个永远绿的 scorer
