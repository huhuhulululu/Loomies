import Testing
import Foundation
@testable import ClosetCore

/// D124：**颜色永远是「未知」**，除非用户逐件手选色板。
/// 而颜色是 `OutfitScorer` 的输入之一（配色协调、60-30-10、色季）——
/// 一个从没人填过颜色的衣柜，那几项打分全程不参与，推荐就只剩温度和场合。
///
/// 抠图已经算出来了（`VisionMattingService`），主色是**顺手就能拿到的东西**：
/// 对非透明像素投票，落到色板上。不需要任何模型。
///
/// 判断标准与 D123 的 OCR 同源——**宁缺勿错**：猜错颜色会让推荐给出错误的
/// 配色理由，而用户不会想到去详情页改。所以票数不够集中就返回 nil。
struct DominantColorTests {

    private func rgb(_ hex: UInt32) -> RGB { RGB(hex: hex) }

    /// 纯色：直接落到对应色板项。
    @Test func aSolidColourLandsOnItsPaletteEntry() {
        let navy = GarmentColorPalette.entries.first { $0.id == "navy" }!
        let samples = Array(repeating: RGB(navy.red, navy.green, navy.blue), count: 100)
        #expect(DominantColor.vote(samples: samples)?.id == "navy")
    }

    /// 有噪声但主色明确时仍要认出来（真实照片不会是一个像素值）。
    @Test func noiseDoesNotDefeatAClearMajority() {
        let red = GarmentColorPalette.entries.first { $0.id == "red" }!
        var samples = Array(repeating: RGB(red.red, red.green, red.blue), count: 80)
        samples += (0..<20).map { i in rgb(0x333333 &+ UInt32(i) &* 0x010101) }
        #expect(DominantColor.vote(samples: samples)?.id == "red")
    }

    /// **票数不集中就不猜**——花色/条纹布料上强行给一个主色是错的。
    @Test func aScatteredPaletteYieldsNothing() {
        let ids = ["red", "green", "yellow", "teal", "purple", "navy"]
        var samples: [RGB] = []
        for id in ids {
            let e = GarmentColorPalette.entries.first { $0.id == id }!
            samples += Array(repeating: RGB(e.red, e.green, e.blue), count: 10)
        }
        #expect(DominantColor.vote(samples: samples) == nil,
                "花色布料被强行认成了一个主色")
    }

    /// 样本太少不下结论（抠图失败或只剩几个像素时）。
    @Test func tooFewSamplesYieldNothing() {
        let navy = GarmentColorPalette.entries.first { $0.id == "navy" }!
        let samples = Array(repeating: RGB(navy.red, navy.green, navy.blue), count: 5)
        #expect(DominantColor.vote(samples: samples) == nil)
    }

    @Test func noSamplesIsSafe() {
        #expect(DominantColor.vote(samples: []) == nil)
    }

    /// 近灰阶落到**中性**项而不是某个彩色——
    /// 黑白灰是衣橱里的多数，认错成「红」会让配色理由荒唐。
    @Test func nearGreyscaleLandsOnANeutral() {
        for hex in [0x1A1A1A, 0x8C8C8C, 0xF2F2F2] as [UInt32] {
            let samples = Array(repeating: rgb(hex), count: 60)
            let entry = DominantColor.vote(samples: samples)
            #expect(entry?.isNeutral == true,
                    Comment(rawValue: "\(String(hex, radix: 16)) 认成了 \(entry?.id ?? "nil")"))
        }
    }

    /// 结果确定：同样的像素两次得到同样的答案。
    @Test func votingIsDeterministic() {
        let samples = (0..<60).map { i in rgb(0x9E5540 &+ UInt32(i % 3)) }
        #expect(DominantColor.vote(samples: samples)?.id
            == DominantColor.vote(samples: samples)?.id)
    }

    /// 打平时按 id 决胜（不得依赖字典遍历顺序）。
    @Test func tiesAreBrokenDeterministically() {
        let a = GarmentColorPalette.entries.first { $0.id == "navy" }!
        let b = GarmentColorPalette.entries.first { $0.id == "denim" }!
        var samples = Array(repeating: RGB(a.red, a.green, a.blue), count: 30)
        samples += Array(repeating: RGB(b.red, b.green, b.blue), count: 30)
        // 五五开 → 达不到集中度门槛，宁可不给
        #expect(DominantColor.vote(samples: samples) == nil)
    }

    /// 集中度门槛是**可解释的常数**，不是魔法数字。
    @Test func theThresholdIsStated() {
        #expect(DominantColor.minimumShare > 0.4)
        #expect(DominantColor.minimumShare <= 0.6)
        #expect(DominantColor.minimumSamples >= 20)
    }
}
