import Foundation

/// 「按名字排序、同名按 id 决胜」——**一条规则，一处实现**（D148）。
///
/// 此前这条规则在仓里手抄了 19 遍，写法是
/// `($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString)`。
/// 两个问题：
///
/// 1. **每次比较分配两个 UUID 字符串。** 元组比较会先算出两侧的全部分量再比，
///    于是名字明明不同（绝大多数情况）也照样把 UUID 格式化成字符串。
///    衣柜网格在每次 `body` 求值里跑三遍全柜排序：200 件 ≈ 1500 次比较
///    × 2 次分配 × 3 遍 = 单帧近万次无谓分配。同名才需要决胜，那时再取。
///
/// 2. **19 份手抄是 19 次写错的机会。** 其中任何一处把决胜写反，
///    同名两行的顺序就会在不同界面之间打架——而「排序确定性」正是本仓
///    反复钉过的东西（导出快照可复现、默认目的地不漂移）。
public protocol NamedRecord {
    var name: String { get }
    var id: UUID { get }
}

extension Item: NamedRecord {}
extension Wardrobe: NamedRecord {}
extension Person: NamedRecord {}
extension StorageLocation: NamedRecord {}
extension Outfit: NamedRecord {}

extension Sequence where Element: NamedRecord {
    /// 名字升序；同名按 id 决胜（与手抄那版逐个结果一致，`NameOrderTests` 钉住）。
    public func sortedByName() -> [Element] {
        sorted { lhs, rhs in
            lhs.name == rhs.name
                ? lhs.id.uuidString < rhs.id.uuidString   // 只有同名才付这笔分配
                : lhs.name < rhs.name
        }
    }
}
