import Foundation
import Observation
import SwiftData
import ClosetModel
import ClosetCore

/// 切换器的**纯值真相**（D89）。此前 app-shell 自己写了一套 Menu 绕开本文件：
/// 单键 `@Query(sort: \Wardrobe.name)` 排序、列全库衣柜、同名衣柜两行一模一样。
/// 排序 / 显示名 / active 解析三件事收在这里，两侧共用，不再各写各的。
public enum WardrobeSwitcher {

    /// 空名兜底（菜单里不得出现空白行）。
    public static let unnamedTitle = "Closet"

    /// (name, id) 双键——同名衣柜的顺序不得随 fetch 漂移。
    public static func ordered(_ wardrobes: [Wardrobe]) -> [Wardrobe] {
        wardrobes.sorted { ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString) }
    }

    public static func displayName(_ wardrobe: Wardrobe) -> String {
        TextNormalize.blankToNil(wardrobe.name) ?? unnamedTitle
    }

    /// 菜单显示名。同名时先用城市、再用主人区分；唯一时不加噪音后缀。
    /// 用户在切换器里必须分得清自己点的是哪个柜子。
    public static func menuTitle(_ wardrobe: Wardrobe, among all: [Wardrobe]) -> String {
        let base = displayName(wardrobe)
        let sameName = all.filter { displayName($0) == base }
        guard sameName.count > 1 else { return base }
        // 每个维度**只有真的能区分时才用**——否则两行仍会一模一样，
        // 只是多了个没用的后缀（同主人同名且都无城市就是这种情况）。
        if let city = TextNormalize.blankToNil(wardrobe.locationCity),
           sameName.filter({ TextNormalize.blankToNil($0.locationCity) == city }).count == 1 {
            return "\(base) · \(city)"
        }
        if let owner = wardrobe.owner.flatMap({ TextNormalize.blankToNil($0.name) }),
           sameName.filter({
               $0.owner.flatMap { TextNormalize.blankToNil($0.name) } == owner
           }).count == 1 {
            return "\(base) · \(owner)"
        }
        // 城市与主人都区分不出：用 id 短码兜底，绝不留两行一模一样
        return "\(base) · \(AppLog.ref(wardrobe.id))"
    }

    /// active 解析：给定 id 用它；id 失效（衣柜被删）→ 回落**排序后**首位，
    /// 不是 fetch 顺序的首位（否则重启后打开的柜子会随机漂）。
    public static func resolveActive(id: UUID?, among all: [Wardrobe]) -> Wardrobe? {
        let sorted = ordered(all)
        if let id, let hit = sorted.first(where: { $0.id == id }) { return hit }
        return sorted.first
    }

    /// 切柜遥测（无身份字段）。两条切换路径共用，别再各发各的。
    public static func trackSwitch() {
        TelemetryGate.shared.track(.wardrobeSwitched)
    }
}
