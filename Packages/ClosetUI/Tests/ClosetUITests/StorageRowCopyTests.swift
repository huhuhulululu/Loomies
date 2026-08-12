import Testing
@testable import ClosetUI

/// D85 波 B：位置树行文案。层级靠缩进的视觉信息对 VoiceOver 不可达，
/// 必须在 accessibilityLabel 里说出父节点。
struct StorageRowCopyTests {

    @Test func indentedTitleGrowsWithDepthAndKeepsName() {
        #expect(StorageRowCopy.indentedTitle("Rail A", depth: 0) == "Rail A")
        let d1 = StorageRowCopy.indentedTitle("Rail A", depth: 1)
        let d2 = StorageRowCopy.indentedTitle("Rail A", depth: 2)
        #expect(d1.hasSuffix("Rail A") && d1.count > "Rail A".count)
        #expect(d2.count > d1.count)
        // 负深度不崩（防御脏输入）
        #expect(StorageRowCopy.indentedTitle("X", depth: -3) == "X")
    }

    @Test func accessibilityLabelSpeaksHierarchyAndCount() {
        let nested = StorageRowCopy.accessibilityLabel(
            name: "Rail A", parentName: "Closet 1", itemCount: 3)
        #expect(nested == "Rail A, inside Closet 1, 3 pieces")
        let root = StorageRowCopy.accessibilityLabel(
            name: "Attic", parentName: nil, itemCount: 1)
        #expect(root == "Attic, 1 piece")
        // 空白父名不得读出「inside 」空壳
        #expect(!StorageRowCopy.accessibilityLabel(name: "A", parentName: "  ", itemCount: 0)
            .localizedCaseInsensitiveContains("inside"))
        #expect(StorageRowCopy.accessibilityLabel(name: "  ", parentName: nil, itemCount: 0)
            .hasPrefix("Location"))
        #expect(!StorageRowCopy.topLevelTitle.isEmpty)
    }
}
