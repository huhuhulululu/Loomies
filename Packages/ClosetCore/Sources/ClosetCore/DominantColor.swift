import Foundation

/// 主色投票（D124）。
///
/// 颜色此前永远是「未知」，除非用户逐件手选色板——而颜色是 `OutfitScorer`
/// 的输入之一（配色协调、60-30-10、色季）：一个从没人填过颜色的衣柜，
/// 那几项打分全程不参与，推荐就只剩温度和场合。
///
/// 抠图已经算出来了，主色是顺手就能拿到的东西：对非透明像素投票、落到色板上。
/// **不需要任何模型**。
///
/// 判断标准与 D123 的 OCR 同源——**宁缺勿错**：猜错颜色会让推荐给出
/// 错误的配色理由，而用户不会想到去详情页改。票数不够集中就返回 nil。
public enum DominantColor {

    /// 主色至少要占这么多票才算数。低于它多半是花色/条纹/多色拼接——
    /// 那种布料本来就没有单一主色，硬给一个是错的。
    /// 取 0.55 而不是 0.5：五五开的双色衣服**没有**主色，
    /// 0.5 的门槛会让它随决胜规则给出一个必然一半时候是错的答案。
    public static let minimumShare = 0.55

    /// 样本太少不下结论（抠图失败、或只剩零星像素）。
    public static let minimumSamples = 20

    /// 离最近色板项**太远**就不认（D134）。
    ///
    /// 色板只有 16 项，而衣服颜色是连续的：荧光橙、松石绿、藕粉
    /// 都会被硬吸到某个八竿子打不着的项上，然后以那个名字参与配色打分。
    /// 归一化 RGB 空间里 0.35 的欧氏距离（平方 0.1225）约等于
    /// 「肉眼一看就不是同一个颜色」。
    public static let maximumSquaredDistance = 0.1225

    /// 对像素投票，返回票数最集中的色板项。
    ///
    /// 用**众数**而不是均值：红衣配蓝扣的均值是紫色，那个颜色一件衣服上根本不存在。
    public static func vote(samples: [RGB]) -> GarmentColorPalette.Entry? {
        guard samples.count >= minimumSamples else { return nil }
        var tally: [String: Int] = [:]
        for sample in samples {
            guard let entry = nearestEntry(to: sample) else { continue }
            // 离色板太远的像素**不投票**——硬吸到最近项会让一件荧光橙
            // 顶着「orange」的名字参与配色打分，而它们看起来毫无关系。
            guard distance(sample, RGB(entry.red, entry.green, entry.blue))
                <= maximumSquaredDistance else { continue }
            tally[entry.id, default: 0] += 1
        }
        guard let winner = tally
            // 票数降序；打平按 id 升序决胜——不得依赖字典遍历顺序
            .sorted(by: { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key })
            .first
        else { return nil }
        let share = Double(winner.value) / Double(samples.count)
        guard share >= minimumShare else { return nil }
        return GarmentColorPalette.entries.first { $0.id == winner.key }
    }

    /// 最近色板项（RGB 空间欧氏距离，**全表比**）。
    ///
    /// 曾先用「三通道极差」判中性再在同类里找——那是错的：
    /// 色板里的 navy(0.13,0.19,0.35)、denim、brown 都标为 `isNeutral`，
    /// 但它们的极差远大于灰阶阈值，于是海军蓝被推进彩色池、认成了「绿」。
    /// 色板项本来就带真实 RGB，直接全表比距离既简单又准：
    /// 灰阶自然落到 black/grey/white，navy 自然落到 navy。
    static func nearestEntry(to sample: RGB) -> GarmentColorPalette.Entry? {
        let pool = GarmentColorPalette.entries
        guard !pool.isEmpty else { return nil }
        return pool.min { a, b in
            let da = distance(sample, RGB(a.red, a.green, a.blue))
            let db = distance(sample, RGB(b.red, b.green, b.blue))
            return da != db ? da < db : a.id < b.id
        }
    }

    static func distance(_ a: RGB, _ b: RGB) -> Double {
        let dr = a.red - b.red, dg = a.green - b.green, db = a.blue - b.blue
        return dr * dr + dg * dg + db * db
    }
}
