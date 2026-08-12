import Testing
import Foundation
@testable import ClosetCore

/// D90：`Person.coldBias`（怕冷 + / 怕热 −）此前**有字段、进导出、无 UI 无消费者**——
/// 用户永远设不了它，而数据导出里躺着一个恒为 0 的「个人偏好」。
/// 要么接上要么删掉；接上更有价值：同样 60°F，怕冷的人要的那档比默认厚。
///
/// 语义定夺：偏置**平移**可接受温区，不是放宽它。放宽 = 候选变杂（薄厚都推），
/// 平移 = 同样精准但对准这个人。天气档位本身仍是硬门（DESIGN §F4 第一条）。
struct ColdBiasTests {

    @Test func zeroBiasIsUnchanged() {
        for t in [20.0, 40, 60, 70, 90] {
            #expect(WeatherFit.acceptableWarmth(daytimeTempF: t, coldBias: 0)
                    == WeatherFit.acceptableWarmth(daytimeTempF: t))
        }
    }

    /// 怕冷（+1）：同样温度要更厚的一档，而不是「薄的也行」。
    @Test func coldBiasShiftsWarmerWithoutWidening() {
        let base = WeatherFit.acceptableWarmth(daytimeTempF: 60)          // .light ... .warm
        let cold = WeatherFit.acceptableWarmth(daytimeTempF: 60, coldBias: 1)
        #expect(cold.lowerBound > base.lowerBound)
        #expect(cold.upperBound >= base.upperBound)
        // 宽度不变 = 平移而非放宽（放宽会让候选变杂）
        #expect(cold.upperBound.rawValue - cold.lowerBound.rawValue
                == base.upperBound.rawValue - base.lowerBound.rawValue)
    }

    /// 怕热（−1）：同样温度要更薄的一档。
    @Test func heatBiasShiftsCooler() {
        let base = WeatherFit.acceptableWarmth(daytimeTempF: 60)
        let warm = WeatherFit.acceptableWarmth(daytimeTempF: 60, coldBias: -1)
        #expect(warm.upperBound < base.upperBound)
        #expect(warm.lowerBound <= base.lowerBound)
    }

    /// 平移到端点时**夹紧**，不得产生空区间（空区间 = 该温度下无一件可穿）。
    @Test func shiftClampsAtTheEndsWithoutEmptyRange() {
        for bias in ColdBias.allowedRange {
            for t in [-40.0, 0, 32, 50, 75, 100, 130] {
                let r = WeatherFit.acceptableWarmth(daytimeTempF: t, coldBias: bias)
                #expect(r.lowerBound <= r.upperBound,
                        Comment(rawValue: "空区间 t=\(t) bias=\(bias)"))
            }
        }
    }

    /// 超范围偏置被夹到允许区间（脏数据不得把天气门推成全通或全禁）。
    @Test func outOfRangeBiasIsClamped() {
        let hi = WeatherFit.acceptableWarmth(daytimeTempF: 60, coldBias: 99)
        let capped = WeatherFit.acceptableWarmth(
            daytimeTempF: 60, coldBias: ColdBias.allowedRange.upperBound)
        #expect(hi == capped)
        let lo = WeatherFit.acceptableWarmth(daytimeTempF: 60, coldBias: -99)
        let floored = WeatherFit.acceptableWarmth(
            daytimeTempF: 60, coldBias: ColdBias.allowedRange.lowerBound)
        #expect(lo == floored)
    }

    /// 垃圾温度仍不做天气过滤——偏置不得把这条兜底吃掉。
    @Test func nonFiniteTemperatureStillDisablesTheGate() {
        for bias in ColdBias.allowedRange {
            let r = WeatherFit.acceptableWarmth(daytimeTempF: .nan, coldBias: bias)
            #expect(r == .veryLight ... .veryWarm)
        }
    }

    /// 文案说人话，且不承诺做不到的事（它只影响温区档位，不改场合/配色）。
    @Test func copyIsHonestAboutScope() {
        for bias in ColdBias.allowedRange {
            let title = ColdBias.title(bias)
            #expect(!title.isEmpty)
        }
        #expect(ColdBias.title(0).localizedCaseInsensitiveContains("average"))
        #expect(ColdBias.explainer.localizedCaseInsensitiveContains("warmth"))
        // 不得声称它能改场合/配色——但**明说这两条不受影响**是诚实的
        #expect(ColdBias.explainer.localizedCaseInsensitiveContains("unchanged"))
        // 每档标题互不相同（否则 Picker 里分不清）
        let titles = ColdBias.allowedRange.map { ColdBias.title($0) }
        #expect(Set(titles).count == titles.count)
    }
}
