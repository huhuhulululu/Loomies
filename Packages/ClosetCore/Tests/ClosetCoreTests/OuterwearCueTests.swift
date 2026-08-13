import Testing
import Foundation
@testable import ClosetCore

/// D204：「加件外套」那条提示，规则写了两遍。
///
/// - `WeatherDaySnapshot.suggestsOuterwearCue`（ClosetCore，规则层）——**零生产调用点**，
///   却带着权威措辞（「practical dress cue, not a hard filter」）住在规则该在的地方；
/// - `CopilotViewModel.weatherDressCue`（ClosetUI）——**真正跑的那份**，两条阈值内联。
///
/// 于是 `PublicAPITests` 里那三条断言验的是**产品不走的路**：
/// 改坏 VM 里的阈值，它们一条都不会红（本 session 第三次撞见这个形状，
/// 前两次是 D192 的 `filterWithRepeatFallback` 与 `RecommendationService`）。
///
/// 而且两份**已经分叉**：VM 那份多一道守卫——天气硬失败时不许拿保留下来的
/// 旧温度说「今天凉」。规则层那份没有，谁要是照它的名字去用，就会踩到那个坑。
///
/// 收口：阈值与措辞进 `OuterwearCue`，**守卫留在 VM**——
/// 它管的是「数据可不可信」，不是「几度算凉」。两件事本来就不该混在一起。
struct OuterwearCueTests {

    private func snapshot(temp: Double, precip: Int? = nil) -> WeatherDaySnapshot {
        WeatherDaySnapshot(
            daytimeTempF: temp, sourceLabel: "test", precipProbabilityPercent: precip)
    }

    /// `docs/requirements` W1.5 写死的那个数：**≥50%**。
    @Test func theRainThresholdIsTheOneTheRequirementFroze() {
        #expect(OuterwearCue.rainProbabilityThreshold == 50,
                "W1.5 冻的是 50%，改它要连需求文档一起改")
        #expect(snapshot(temp: 75, precip: 50).outerwearCue != nil)
        #expect(snapshot(temp: 75, precip: 49).outerwearCue == nil, "49% 不该提示")
    }

    /// 下雨优先于凉——两条都成立时，雨是更可行动的那条（凉能忍，湿不能）。
    @Test func rainOutranksCool() {
        let cue = snapshot(temp: 40, precip: 80).outerwearCue
        #expect(cue == .rain(percent: 80), Comment(rawValue:
            "又冷又下雨时说的是「凉」——而雨才是那条更该说的"))
    }

    /// 凉的判据。
    @Test func coolAloneStillCues() {
        #expect(snapshot(temp: 59).outerwearCue == .cool)
        #expect(snapshot(temp: 60).outerwearCue == nil, "60°F 是分界，不含")
    }

    /// 又暖又不下雨就不提示（别造噪声）。
    @Test func aWarmDryDaySaysNothing() {
        #expect(snapshot(temp: 75, precip: 10).outerwearCue == nil)
    }

    /// 降水未知不等于不下雨——但也不编（三值语义，同 D130）。
    @Test func unknownPrecipitationIsNotAClaim() {
        #expect(snapshot(temp: 75, precip: nil).outerwearCue == nil)
        #expect(snapshot(temp: 50, precip: nil).outerwearCue == .cool, "温度还是知道的")
    }

    /// 措辞要说清**为什么**，并带上那个百分比（用户据此判断值不值得拿伞）。
    @Test func theTextExplainsWhy() {
        #expect(OuterwearCue.rain(percent: 80).text.contains("80"))
        #expect(OuterwearCue.rain(percent: 80).text.localizedCaseInsensitiveContains("rain"))
        #expect(OuterwearCue.cool.text.localizedCaseInsensitiveContains("cool"))
    }

    /// 旧的布尔口径**逐字不变**（它是 public API，`PublicAPITests` 还在用）。
    @Test func theBooleanFormStillAgrees() {
        for temp in stride(from: 30.0, through: 90.0, by: 5) {
            for precip in [nil, 10, 49, 50, 90] as [Int?] {
                let s = snapshot(temp: temp, precip: precip)
                #expect(s.suggestsOuterwearCue == (s.outerwearCue != nil), Comment(rawValue:
                    "temp=\(temp) precip=\(precip.map(String.init) ?? "nil") 两个口径不一致"))
            }
        }
    }

    /// 结构门：**阈值不许再回到 View 层**。
    @Test func noViewLayerRedeclaresTheThresholds() throws {
        let ui = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ClosetUI/Sources/ClosetUI")
        var offenders: [String] = []
        for case let url as URL in FileManager.default
            .enumerator(at: ui, includingPropertiesForKeys: nil)!
        where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for (n, line) in text.split(separator: "\n").enumerated() {
                let t = line.trimmingCharacters(in: .whitespaces)
                guard !t.hasPrefix("//"), !t.hasPrefix("///") else { continue }
                // 「降水概率与 50 比」「温度与 60 比」——认构造，不认数字本身
                if (t.contains("precipProbabilityPercent") && t.contains("50"))
                    || (t.contains("daytimeTempF <") && t.contains("60")) {
                    offenders.append("\(url.lastPathComponent):\(n + 1)")
                }
            }
        }
        #expect(offenders.isEmpty, Comment(rawValue:
            "阈值又被抄回 View 层：\(offenders) —— 用 `WeatherDaySnapshot.outerwearCue`"))
    }
}
