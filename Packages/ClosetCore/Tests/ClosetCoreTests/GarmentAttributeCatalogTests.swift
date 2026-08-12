import Testing
import Foundation
@testable import ClosetCore

/// 单品属性录入面（D83）：温区/颜色/风格属性此前无任何录入 UI ——
/// 天气硬过滤、配色打分、体型加权三条链在真实衣柜数据上空转。
/// 录入需要人话标题 + 可点选的颜色调色板（Core 纯 Swift，不依赖 SwiftUI）。
struct GarmentAttributeCatalogTests {

    @Test func warmthTitlesAreHumanDistinctAndOrdered() {
        let all = Warmth.allCases.sorted { $0.rawValue < $1.rawValue }
        #expect(all.count == 5)
        let titles = all.map(\.displayTitle)
        #expect(Set(titles).count == 5)
        for t in titles {
            #expect(!t.isEmpty)
            #expect(t.first?.isUppercase == true)
            // 不得泄露 raw camelCase（veryLight/veryWarm）
            #expect(!t.contains("very") || t.hasPrefix("Very"))
        }
        // 排序即由薄到厚，供 UI 直接铺 5 档
        #expect(Warmth.ordered == all)
        #expect(Warmth.veryLight.displayTitle != Warmth.veryWarm.displayTitle)
        // 每档带一句人话提示，用户不必猜「medium 是什么」
        for w in all { #expect(!w.entryHint.isEmpty) }
    }

    @Test func styleAttributeTitlesCoverAllCasesInHumanWords() {
        let cases = StyleAttribute.allCases
        #expect(cases.count >= 14)
        let titles = cases.map(\.displayTitle)
        #expect(Set(titles).count == cases.count)
        for (attr, title) in zip(cases, titles) {
            #expect(!title.isEmpty)
            // 人话：不得直接吐 rawValue（straightNoWaist 这种）
            #expect(title != attr.rawValue)
            #expect(title.first?.isUppercase == true)
        }
        // 分组供 UI 分区展示，且分组必须覆盖全部 case（不漏项）
        let grouped = StyleAttribute.entryGroups.flatMap(\.attributes)
        #expect(Set(grouped) == Set(cases))
        #expect(grouped.count == cases.count)   // 不重复
        for g in StyleAttribute.entryGroups { #expect(!g.title.isEmpty) }
    }

    @Test func colorPaletteHasNeutralsAndChromaticsWithStableIDs() {
        let palette = GarmentColorPalette.entries
        #expect(palette.count >= 12)
        #expect(Set(palette.map(\.id)).count == palette.count)     // id 唯一
        #expect(Set(palette.map(\.title)).count == palette.count)  // 标题唯一
        #expect(palette.contains { $0.isNeutral })
        #expect(palette.contains { !$0.isNeutral })
        for e in palette {
            #expect(e.hueDegrees >= 0 && e.hueDegrees < 360)
            #expect(e.red >= 0 && e.red <= 1)
            #expect(e.green >= 0 && e.green <= 1)
            #expect(e.blue >= 0 && e.blue <= 1)
            #expect(!e.title.isEmpty)
            // id 稳定（落库/回读用），必须是 kebab 风格标识而非本地化标题
            #expect(e.id == e.id.lowercased())
        }
        // 常见中性必须在（黑白灰米海军）——否则用户只能被迫选彩色
        let neutralIDs = Set(palette.filter(\.isNeutral).map(\.id))
        #expect(neutralIDs.isSuperset(of: ["black", "white", "grey", "beige", "navy"]))
    }

    @Test func nearestSwatchRoundTripsAndRespectsNeutrality() {
        for e in GarmentColorPalette.entries {
            let color = GarmentColor(hueDegrees: e.hueDegrees, isNeutral: e.isNeutral)
            #expect(GarmentColorPalette.nearest(to: color)?.id == e.id)
        }
        // 中性/彩色不混淆：中性输入只会命中中性色板
        let neutralish = GarmentColor(hueDegrees: 120, isNeutral: true)
        #expect(GarmentColorPalette.nearest(to: neutralish)?.isNeutral == true)
        // 环绕最近：355° 应落到红（0°）而非紫
        let nearRed = GarmentColorPalette.nearest(to: GarmentColor(hueDegrees: 355, isNeutral: false))
        #expect(nearRed?.id == "red")
        // 脏值（NaN/inf）与 nil → 无匹配，不得崩、不得瞎选
        #expect(GarmentColorPalette.nearest(to: GarmentColor(hueDegrees: .nan)) == nil)
        #expect(GarmentColorPalette.nearest(to: nil) == nil)
    }

    @Test func paletteLookupByIDIsStable() {
        #expect(GarmentColorPalette.entry(id: "black")?.isNeutral == true)
        #expect(GarmentColorPalette.entry(id: "red")?.isNeutral == false)
        #expect(GarmentColorPalette.entry(id: "nope") == nil)
        // 大小写/空白容错（落库脏值回读）
        #expect(GarmentColorPalette.entry(id: " Black ")?.id == "black")
    }
}
