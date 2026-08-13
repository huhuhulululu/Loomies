import Testing
import Foundation
@testable import ClosetCore

/// D130：三条引擎缺陷，共同点是**引擎在拿不到事实时替用户做了决定**。
///
/// 1. **天气取不到仍按伪造的 70°F 硬过滤**。`daytimeTempF` 有个 70 的默认值
///    供打分用，D116 已让**显示**说实话（「—°F」），但**过滤照旧**：
///    零下的日子没网，App 会把大衣全筛掉、端出短袖——
///    比不给建议糟得多，因为它看起来像个正常答案。
///    三值语义在别处都遵守了（未知温区不过滤、未知场合不过滤），
///    唯独「今天几度未知」这一格没有。
///
/// 2. **冷天没有任何机制偏好「带外套」的那身**。补全器在冷天会枚举
///    「带外套」和「不带外套」两种，而打分对外套零加成——
///    最终是否带外套由 UUID 序决定。用户在 28°F 的早上打开 App，
///    第一条推荐有没有大衣，纯属偶然。
///
/// 3. **「不许两件同型外套」的规则在真实数据上是死的**：它键控
///    `CandidateItem.subtype`，而 `Item.subtype` **生产里没有任何写入方**——
///    规则写了、测了，永远不触发。
struct WeatherUnknownTests {

    private func item(_ id: String, _ slot: GarmentSlot, _ warmth: Warmth?) -> CandidateItem {
        CandidateItem(id: id, slot: slot, occasions: [], warmth: warmth, status: .available)
    }

    // MARK: - 1. 温度未知时不硬过滤

    /// 温度未知 → **温区门整条跳过**（与「未知温区不过滤」同一条三值纪律）。
    @Test func anUnknownTemperatureSkipsTheWeatherGate() {
        let pool = [
            item("tank", .top, .veryLight),
            item("coat", .outerwear, .veryWarm),
        ]
        let ctx = FilterContext(occasion: "work", daytimeTempF: nil)
        let kept = CandidateFilter.filter(pool, context: ctx)
        #expect(kept.count == 2, "温度未知却按某个温度筛掉了衣服")
    }

    /// 温度已知时照旧硬过滤（这条门的价值不能被顺手削掉）。
    @Test func aKnownTemperatureStillFilters() {
        let pool = [
            item("tank", .top, .veryLight),
            item("coat", .outerwear, .veryWarm),
        ]
        let kept = CandidateFilter.filter(
            pool, context: FilterContext(occasion: "work", daytimeTempF: 85))
        #expect(kept.map(\.id) == ["tank"])
    }

    /// 未知温度不得被当成某个具体温度参与打分说明。
    @Test func anUnknownTemperatureIsNotAnumber() {
        #expect(FilterContext(occasion: "work", daytimeTempF: nil).daytimeTempF == nil)
    }

    // MARK: - 2. 冷天偏好外套

    /// 冷天：带外套的那身分更高。
    @Test func aColdDayPrefersTheLookWithOuterwear() {
        let cold = ScoringContext(daytimeTempF: 28)
        let withCoat = Outfit(items: [
            item("t", .top, .warm), item("b", .bottom, .warm),
            item("s", .shoes, .medium), item("c", .outerwear, .veryWarm),
        ])
        let without = Outfit(items: [
            item("t", .top, .warm), item("b", .bottom, .warm), item("s", .shoes, .medium),
        ])
        #expect(OutfitScorer.score(withCoat, context: cold).value
                > OutfitScorer.score(without, context: cold).value,
                "28°F 的早上，有没有大衣由 UUID 序决定")
    }

    /// 暖天不因为「带了外套」而加分（那会让人在 85°F 穿大衣）。
    @Test func aWarmDayDoesNotRewardOuterwear() {
        let warm = ScoringContext(daytimeTempF: 85)
        let withCoat = Outfit(items: [
            item("t", .top, .light), item("b", .bottom, .light),
            item("s", .shoes, .light), item("c", .outerwear, .veryWarm),
        ])
        let without = Outfit(items: [
            item("t", .top, .light), item("b", .bottom, .light), item("s", .shoes, .light),
        ])
        #expect(OutfitScorer.score(withCoat, context: warm).value
                <= OutfitScorer.score(without, context: warm).value)
    }

    /// 温度未知时不表态（不知道冷暖就不该替用户决定要不要外套）。
    @Test func anUnknownTemperatureTakesNoSideOnOuterwear() {
        let unknown = ScoringContext(daytimeTempF: nil)
        let withCoat = Outfit(items: [
            item("t", .top, .light), item("c", .outerwear, .veryWarm),
        ])
        let without = Outfit(items: [item("t", .top, .light)])
        #expect(OutfitScorer.score(withCoat, context: unknown).value
                == OutfitScorer.score(without, context: unknown).value)
    }

    /// 冷天加了外套要**说得出理由**（不解释的加分等于黑箱）。
    @Test func theOuterwearReasonIsStated() {
        let cold = ScoringContext(daytimeTempF: 28)
        let withCoat = Outfit(items: [
            item("t", .top, .warm), item("c", .outerwear, .veryWarm),
        ])
        let reasons = OutfitScorer.score(withCoat, context: cold).reasons
        #expect(reasons.contains { $0.localizedCaseInsensitiveContains("layer")
                || $0.localizedCaseInsensitiveContains("cold") },
                Comment(rawValue: "\(reasons)"))
    }
}
